"""Check that the readable structural parity status agrees with its contracts."""

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from context_suite_evidence import suite_required_inputs, validate_focused_suite
from verification_build_stdout import validate_build_stdout, validate_policy


ROOT = Path(__file__).resolve().parent.parent
PHASE_SCOPES = {
    "parsing": {
        "managed": ["src/Sollang.Compiler/Parsing",
                    "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs",
                    "src/Sollang.Compiler.Generators/LexerSourceGenerator.cs",
                    "src/Sollang.Compiler/Cli/GrammarCompiler.cs",
                    "src/Sollang.Compiler/Cli/Utf8SourceDecoder.cs",
                    "src/Sollang.Compiler/Cli/CompilerApp.cs",
                    "src/Sollang.Compiler/Cli/SourceFormatter.cs",
                    "src/Sollang.Compiler/Lexing", "src/Sollang.Compiler/Syntax"],
        "selfhost": ["selfhost/syntax", "selfhost/source_style.slg",
                     "selfhost/ir/interpolation.slg", "selfhost/llvm/text/text_literals.slg",
                     "selfhost/llvm/text/entrypoints.slg", "selfhost/cli_grammar.slg",
                     "selfhost/cli_format.slg", "selfhost/cli_language_server.slg"],
    },
    "semantic-analysis": {"managed": ["src/Sollang.Compiler/Semantics"],
                          "selfhost": ["selfhost/semantic", "selfhost/llvm/emitter/diagnostics.slg"]},
    "type-commit": {"managed": ["src/Sollang.Compiler/Semantics"],
                    "selfhost": ["selfhost/semantic", "selfhost/ir/typed"]},
    "expression-lowering": {"managed": ["src/Sollang.Compiler/CodeGen"],
                            "selfhost": ["selfhost/ir"]},
    "control-flow": {"managed": ["src/Sollang.Compiler/CodeGen"],
                     "selfhost": ["selfhost/ir/typed", "selfhost/llvm/text/function_scheduling.slg",
                                  "selfhost/llvm/text/control_regions.slg", "selfhost/llvm/text/function_expressions.slg"]},
    "ownership": {"managed": ["src/Sollang.Compiler/Semantics", "src/Sollang.Compiler/CodeGen"],
                  "selfhost": ["selfhost/semantic", "selfhost/ir/typed", "selfhost/llvm/text/ownership.slg"]},
    "llvm-generation": {"managed": ["src/Sollang.Compiler/CodeGen"], "selfhost": ["selfhost/llvm"]},
}
PARSING_PRODUCERS = [
    "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs",
    "src/Sollang.Compiler.Generators/LexerSourceGenerator.cs",
    "src/Sollang.Compiler/Cli/GrammarCompiler.cs",
    "src/Sollang.Compiler/Sollang.Compiler.csproj",
    "src/Sollang.Compiler.Generators/Sollang.Compiler.Generators.csproj",
]
PARSING_DERIVED = {
    "src/Sollang.Compiler/obj/generated/Sollang.Compiler.Generators/Sollang.Compiler.Generators.ParserSourceGenerator/GeneratedParser.g.cs": PARSING_PRODUCERS[0],
    "src/Sollang.Compiler/obj/generated/Sollang.Compiler.Generators/Sollang.Compiler.Generators.LexerSourceGenerator/GeneratedLexer.g.cs": PARSING_PRODUCERS[1],
    "syntax/generated/sollang_grammar.slg": PARSING_PRODUCERS[2],
}
PARSING_SHARED_DEPENDENCIES = ["syntax/sollang.lexer", "syntax/sollang.grammar",
                               *PARSING_PRODUCERS, *PARSING_DERIVED]


def read(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text(encoding="utf-8-sig"))


class PhaseClosureError(ValueError):
    """A phase claim cannot be reproduced from its inventory and records."""


def known_implementation_unit_counts(progress):
    """Count durable implementation identities, independent of the active task."""
    completed = progress["completedUnits"]
    queued = progress["queuedUnits"]
    units = completed + queued
    require(all(isinstance(unit, dict) and isinstance(unit.get("id"), str)
                and unit["id"] for unit in units), "implementation unit identity missing")
    require(len({unit["id"] for unit in units}) == len(units),
            "implementation unit identity counted twice")
    require(all(unit.get("status") == "complete" for unit in completed),
            "completed implementation unit is incomplete")
    require(all(unit.get("status") != "complete" for unit in queued),
            "completed implementation unit remains queued")
    return len(completed), len(units)


def require(condition, message):
    if not condition:
        raise PhaseClosureError(message)


def expected_stage_outcome(expected_stages, stage, side):
    """Select an exact oracle; both compile sides must be valid before capture."""
    require(side in ("managed", "selfhost"), "unknown compiler side")
    value = expected_stages.get(stage)
    require(isinstance(value, dict), "exact stage oracle required")
    def exact(candidate):
        require(isinstance(candidate, dict) and set(candidate) in ({"exitCode", "stdout", "stderr"}, {"exitCode", "stdout", "stderr", "stdoutPolicy"})
                and type(candidate.get("exitCode")) is int
                and isinstance(candidate.get("stdout"), str) and isinstance(candidate.get("stderr"), str),
                "exact stage oracle required")
        try:
            validate_policy(candidate, stage)
        except ValueError as error:
            raise PhaseClosureError(str(error)) from error
        return candidate
    if "compilerSides" in value:
        require(stage in ("compile", "grammar") and set(value) == {"compilerSides"}, "compiler sides allowed only for compile or grammar")
        sides = value["compilerSides"]
        require(isinstance(sides, dict) and set(sides) == {"managed", "selfhost"}, "both compiler side oracles required")
        managed, selfhost = exact(sides["managed"]), exact(sides["selfhost"])
        require(managed["exitCode"] == selfhost["exitCode"], "compiler side exits must match")
        value = sides[side]
    else:
        value = exact(value)
    if stage == "grammar":
        require(set(expected_stages) == {"grammar"} and value["exitCode"] == 1,
                "grammar rejection requires exactly one nonzero command stage")
        return value
    compile_value = expected_stages.get("compile", {})
    compile_exit = (compile_value.get("compilerSides", {}).get("managed", {}).get("exitCode")
                    if "compilerSides" in compile_value else compile_value.get("exitCode"))
    require(set(expected_stages) == ({"compile", "run"} if compile_exit == 0 else {"compile"}),
            "compile/run stage graph differs from oracle")
    return value


def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalize_phase_digest_fields(value, field=""):
    """Compare typed SHA-256 metadata independently of hexadecimal casing.

    Preserve paths, oracles and raw record bytes. Only digest fields and digest
    maps are normalized; changed digest values still fail the file-backed checks.
    """
    if isinstance(value, dict):
        if field.endswith(("Hashes", "HashesStart", "HashesEnd")):
            return {key: item.upper() if isinstance(item, str)
                    and re.fullmatch(r"[0-9a-fA-F]{64}", item) else item
                    for key, item in value.items()}
        return {key: normalize_phase_digest_fields(item, key) for key, item in value.items()}
    if isinstance(value, list):
        return [normalize_phase_digest_fields(item) for item in value]
    if (field == "sha256" or field.endswith("Sha256")) and isinstance(value, str):
        return value.upper() if re.fullmatch(r"[0-9a-fA-F]{64}", value) else value
    return value


def validate_decision_source_scope(named, sources):
    require(bool(named) and set(named) <= sources, "decision source outside scope")


def phase_path(root, relative):
    """Keep source authority local; admit evidence in the existing owned artifact root."""
    from completed_artifact_plan import assert_artifact_path, reparse
    path = Path(os.path.abspath(root / relative))
    if not path.is_relative_to(root.resolve()):
        try:
            return assert_artifact_path(root, path)
        except ValueError as error:
            raise PhaseClosureError("source/record path leaves repository or owned artifacts") from error
    for ancestor in (path, *path.parents):
        require(not (ancestor.exists() and reparse(ancestor)), "phase path is a reparse point")
        if ancestor == root.resolve():
            break
    return path


def validate_fixture_binary(root, reference, cleanup_evidence=None):
    """Accept live bytes or an owned, completed cleanup; never missing evidence."""
    require(isinstance(reference, dict) and set(reference) == {"path", "sha256"},
            "invalid fixture binary identity")
    path = phase_path(root, reference["path"])
    if path.exists():
        require(path.is_file() and file_hash(path) == reference["sha256"],
                "compiled output binary changed")
        return
    require(isinstance(cleanup_evidence, dict) and set(cleanup_evidence) == {"plan", "execution"},
            "missing fixture binary cleanup evidence")
    linked = {}
    for kind, value in cleanup_evidence.items():
        require(isinstance(value, dict) and set(value) == {"path", "sha256"},
                "invalid fixture cleanup linkage")
        try:
            evidence_path = phase_path(root, value["path"])
        except PhaseClosureError as error:
            raise PhaseClosureError("fixture cleanup linkage changed") from error
        require(evidence_path.is_file()
                and file_hash(evidence_path) == value["sha256"], "fixture cleanup linkage changed")
        linked[kind] = evidence_path
    require(linked["execution"] == Path(str(linked["plan"]) + ".execution.json"),
            "fixture cleanup execution belongs to another plan")
    plan = json.loads(linked["plan"].read_text(encoding="utf-8-sig"))
    execution = json.loads(linked["execution"].read_text(encoding="utf-8-sig"))
    require(Path(plan.get("repoRoot", "")).resolve() == root.resolve(),
            "fixture cleanup belongs to another repository")
    from completed_artifact_plan import validate_plan
    try:
        validate_plan(plan)
    except (ValueError, OSError, KeyError) as error:
        raise PhaseClosureError("fixture cleanup plan invalid: " + str(error)) from error
    require(execution.get("schemaVersion") == 1 and execution.get("status") == "completed"
            and type(execution.get("plannedFiles")) is int and execution["plannedFiles"] == plan["files"]
            and type(execution.get("plannedDirectories")) is int
            and execution["plannedDirectories"] == plan["directories"]
            and execution.get("logicalBytes") == plan["logicalBytes"],
            "fixture cleanup execution incomplete")
    targets = [target for target in plan["targets"] if Path(target["path"]).resolve() == path]
    require(len(targets) == 1 and targets[0]["sha256"].upper() == reference["sha256"].upper(),
            "fixture binary differs from cleanup target")
    owner = targets[0]["output"]
    receipts = [item for item in plan["completionRecords"] if item["output"] == owner]
    require(len(receipts) == 1 and receipts[0]["disposition"] == "verified-complete",
            "fixture cleanup lacks successful verification")
    dispositions = execution.get("completionDispositions", [])
    require({"output": owner, "disposition": "verified-complete", "recordStatus": "passed"} in dispositions,
            "fixture cleanup execution lacks verified owner")
    record = json.loads(Path(receipts[0]["path"]).read_text(encoding="utf-8-sig"))
    require(record.get("processesStopped", record.get("processShutdownConfirmed")) is True,
            "fixture cleanup lacks process shutdown")
    expected = record.get("generatedOutputHashes", {}).get(str(path))
    require(isinstance(expected, str) and expected.upper() == reference["sha256"].upper(),
            "fixture binary lacks verified generated hash")
    require(all(not Path(target["path"]).exists() for target in plan["targets"]),
            "fixture cleanup execution left planned files")


def validate_phase_closure(detail, phases, root):
    """Validate promotion without executing compilers or trusting recorded hashes."""
    require(detail["schemaVersion"] == 2, "phase closure requires schema version 2")
    requirements = detail["promotionRequirements"]
    require(requirements == {
        "decisionFields": ["structure", "branches", "logic", "diagnostics"],
        "compiledProofMode": "phase-exhaustive",
        "sourceExtensions": {"managed": ".cs", "selfhost": ".slg"},
    }, "promotion requirements cannot be weakened")
    rows = detail["phaseProgress"]
    require([row["phase"] for row in rows] == list(PHASE_SCOPES),
            "phase inventory must retain all seven phases")
    require([row["phase"] for row in rows] == [phase["phase"] for phase in phases],
            "phase mapping and progress differ")

    def local_file(relative):
        path = phase_path(root, relative)
        require(path.is_file(), f"missing file: {relative}")
        return path

    def record(relative, phase, status="passed"):
        require(isinstance(relative, str) and bool(relative), "missing proof record")
        value = normalize_phase_digest_fields(json.loads(local_file(relative).read_text(encoding="utf-8-sig")))
        require(value.get("status") == status and value.get("phase") == phase,
                f"record status/phase mismatch: {relative}")
        return value

    def link(value, field, relative):
        require(value.get(field) == {"path": relative, "sha256": file_hash(local_file(relative))},
                f"record linkage mismatch: {field}")

    def terminal_success(value):
        require(type(value.get("exitCode")) is int and value["exitCode"] == 0,
                "nonzero or absent execution exit code")
        require(value.get("failureIds") == [] and value.get("orphanProcessIds") == []
                and value.get("canceled") is False, "failed, canceled, or orphaned execution")

    complete = 0
    for row, mapping in zip(rows, phases):
        phase = row["phase"]
        require(row["status"] in ("partial", "complete"), f"invalid phase status: {phase}")
        require(mapping["aligned"] == ("complete" if row["status"] == "complete" else "partial-behavior"),
                f"phase status mismatch: {phase}")
        inventory = row["decisionInventory"]
        require(phase in PHASE_SCOPES and inventory["sourceScopes"] == PHASE_SCOPES[phase],
                "phase source scope cannot be narrowed")
        if phase == "parsing":
            require(inventory.get("sharedDependencies") == PARSING_SHARED_DEPENDENCIES,
                    "parsing shared dependency manifest cannot be narrowed")
        require(inventory["status"] in ("pending", "reviewed"), "invalid inventory status")
        decisions = inventory["decisions"]
        ids = [decision["id"] for decision in decisions]
        required_ids = inventory["requiredDecisionIds"]
        require(len(ids) == len(set(ids)) and len(required_ids) == len(set(required_ids)),
                "duplicate decision identity")
        require(set(ids) == set(required_ids), "required decision inventory differs")
        for decision in decisions:
            require(decision["status"] in ("pending", "complete"), "invalid decision status")
        if row["status"] != "complete":
            continue
        require(inventory["status"] == "reviewed" and bool(decisions),
                f"phase has no reviewed decision inventory: {phase}")
        source_hashes = {}
        side_sources = {}
        for side, extension in requirements["sourceExtensions"].items():
            scopes = inventory["sourceScopes"][side]
            require(bool(scopes), f"missing {side} source scope")
            sources = set()
            for scope in scopes:
                path = (root / scope).resolve()
                require(path.is_relative_to(root.resolve()) and path.exists(), "invalid source scope")
                prefixes = ("src/Sollang.Compiler/", "src/Sollang.Compiler.Generators/") if side == "managed" else ("selfhost/",)
                require(path.relative_to(root.resolve()).as_posix().startswith(prefixes),
                        "source scope belongs to the wrong compiler")
                candidates = [path] if path.is_file() else path.rglob("*" + extension)
                sources.update(p.relative_to(root.resolve()).as_posix() for p in candidates
                               if p.is_file() and p.suffix == extension)
            require(bool(sources), f"empty {side} source scope")
            covered = set()
            for decision in decisions:
                require(decision["status"] == "complete", "pending phase decision")
                for field in requirements["decisionFields"]:
                    require(isinstance(decision.get(field), str) and bool(decision[field].strip()),
                            f"missing decision comparison: {field}")
                named = decision[side + "Sources"]
                validate_decision_source_scope(named, sources)
                covered.update(named)
            require(covered == sources, f"unreviewed {side} sources")
            side_sources[side] = sources
            source_hashes.update({source: file_hash(local_file(source)) for source in sources})

        shared_hashes = {}
        if phase == "parsing":
            shared_hashes = {path: file_hash(local_file(path)) for path in PARSING_SHARED_DEPENDENCIES}
            generation_path = inventory.get("generationRecord")
            generation = record(generation_path, phase)
            terminal_success(generation)
            require(generation.get("method") == "current-producer-reproduction"
                    and type(generation.get("completed")) is int and generation["completed"] == 3
                    and type(generation.get("total")) is int and generation["total"] == 3,
                    "incomplete current producer reproduction")
            generation_inputs = {path: shared_hashes[path] for path in
                                 ["syntax/sollang.lexer", "syntax/sollang.grammar", *PARSING_PRODUCERS]}
            require(generation.get("inputStable") is True
                    and generation.get("inputHashesStart") == generation_inputs == generation.get("inputHashesEnd"),
                    "generation does not cover current producer and grammar inputs")
            require(generation.get("producerHashes") == {path: shared_hashes[path] for path in PARSING_PRODUCERS},
                    "generation producer stamp differs")
            outputs = generation.get("outputs")
            require(isinstance(outputs, list) and [output.get("path") for output in outputs] == list(PARSING_DERIVED),
                    "derived parser/lexer output inventory differs")
            for output in outputs:
                require(output.get("sha256") == shared_hashes[output["path"]]
                        and output.get("producerPath") == PARSING_DERIVED[output["path"]],
                        "derived output or producer is stale")
                reproduced = output.get("reproducedFile")
                require(isinstance(reproduced, dict) and reproduced.get("path") not in PARSING_SHARED_DEPENDENCIES
                        and not local_file(reproduced["path"]).samefile(local_file(output["path"]))
                        and file_hash(local_file(reproduced["path"])) == reproduced.get("sha256") == output["sha256"],
                        "derived output lacks current producer reproduction")
                execution = output.get("execution")
                require(isinstance(execution, dict), "missing producer generation execution")
                terminal_success(execution)
                require(execution.get("status") == "passed" and execution.get("inputStable") is True
                        and execution.get("inputHashesStart") == generation_inputs == execution.get("inputHashesEnd")
                        and execution.get("producerPath") == output["producerPath"]
                        and execution.get("producerSha256") == shared_hashes[output["producerPath"]]
                        and execution.get("producedFile") == reproduced,
                        "producer execution does not establish derived file linkage")
            lexer = local_file("syntax/sollang.lexer").read_text(encoding="utf-8-sig")
            grammar = local_file("syntax/sollang.grammar").read_text(encoding="utf-8-sig")
            stamp = hashlib.sha256((lexer + "\n---grammar---\n" + grammar).encode("utf-8")).hexdigest()
            generated = local_file("syntax/generated/sollang_grammar.slg").read_text(encoding="utf-8-sig")
            require(f"# Source SHA-256: {stamp}" in generated, "generated grammar input stamp is stale")

        comparison = record(inventory["sourceComparisonRecord"], phase, "compared")
        if phase == "parsing":
            require(comparison.get("sharedDependencyHashes") == shared_hashes, "comparison shared dependencies differ")
            link(comparison, "generationRecord", generation_path)
        require(comparison.get("sourceHashes") == source_hashes, "source comparison is stale")
        require(comparison.get("decisions") == decisions, "comparison omits inventory decisions")
        managed = record(inventory["managedFirstRecord"], phase)
        paired = record(inventory["pairedRecord"], phase)
        link(comparison, "managedFirstRecord", inventory["managedFirstRecord"])
        link(paired, "sourceComparisonRecord", inventory["sourceComparisonRecord"])
        require(paired.get("mode") == requirements["compiledProofMode"], "focused proof cannot close a phase")
        expected_managed = {**{p: source_hashes[p] for p in side_sources["managed"]}, **shared_hashes}
        for proof, expected in ((managed, expected_managed), (paired, {**source_hashes, **shared_hashes})):
            if phase == "parsing":
                link(proof, "generationRecord", generation_path)
            terminal_success(proof)
            require(proof.get("inputStable") is True, "unstable or canceled proof")
            require(proof.get("sourceHashesStart") == expected == proof.get("sourceHashesEnd"),
                    "compiled proof does not cover current sources")
            require(proof.get("decisionIds") == required_ids, "compiled decision coverage differs")
            require(type(proof.get("total")) is int and proof["total"] > 0
                    and type(proof.get("completed")) is int
                    and proof["completed"] == proof["total"], "incomplete compiled proof")
            cases = proof.get("cases")
            require(isinstance(cases, list) and len(cases) == proof["total"],
                    "compiled case inventory differs from totals")
            case_ids = set()
            covered_decisions = set()
            execution_inputs = proof.get("executionInputs")
            require(isinstance(execution_inputs, dict) and set(execution_inputs) == {"runner", "contract"},
                    "missing runner or contract execution linkage")
            execution_hashes = {}
            for reference in execution_inputs.values():
                require(file_hash(local_file(reference["path"])) == reference["sha256"],
                        "runner or contract changed")
                execution_hashes[reference["path"]] = reference["sha256"]
            execution_contract = normalize_phase_digest_fields(json.loads(local_file(execution_inputs["contract"]["path"]).read_text(encoding="utf-8-sig")))
            require(execution_contract.get("schemaVersion") == 1 and execution_contract.get("phase") == phase
                    and execution_contract.get("decisionIds") == required_ids, "execution contract scope differs")
            contract_cases = execution_contract.get("cases")
            require(isinstance(contract_cases, list) and bool(contract_cases), "empty execution case contract")
            require([case.get("id") for case in cases] == [case.get("id") for case in contract_cases],
                    "compiled case IDs differ from execution contract")
            for case, expected_case in zip(cases, contract_cases):
                require(isinstance(case.get("id"), str) and bool(case["id"])
                        and case["id"] not in case_ids, "missing or duplicate compiled case ID")
                case_ids.add(case["id"])
                terminal_success(case)
                require(case.get("status") == "passed", "compiled case did not pass")
                require(case.get("compilerBinaries") == proof.get("compilerBinaries"),
                        "compiled case used another compiler")
                outcomes = case.get("outcomes")
                fixture = case.get("fixture")
                require(fixture == expected_case.get("fixture")
                        and case.get("decisionIds") == expected_case.get("decisionIds"),
                        "case differs from contracted fixture or decisions")
                require(isinstance(fixture, dict)
                        and file_hash(local_file(fixture["path"])) == fixture["sha256"],
                        "compiled case fixture changed")
                require(isinstance(outcomes, dict) and set(outcomes) == set(proof["compilerBinaries"]),
                        "case lacks compiler execution outcomes")
                for side, stages in outcomes.items():
                    require(set(stages) in ({"compile"}, {"compile", "run"}, {"grammar"}), "invalid case execution stages")
                    expected_stages = expected_case["expectedStages"]
                    require(set(stages) == set(expected_stages), "case stages differ from execution contract")
                    require(("grammarCommand" in expected_case) == (set(stages) == {"grammar"}),
                            "grammar command cannot substitute for compile/run")
                    compiled_output = None
                    for stage in ("compile", "run", "grammar"):
                        if stage not in stages:
                            continue
                        reference = stages[stage]
                        outcome_path = local_file(reference["path"])
                        require(file_hash(outcome_path) == reference["sha256"], "case execution record changed")
                        outcome = normalize_phase_digest_fields(json.loads(outcome_path.read_text(encoding="utf-8-sig")))
                        expected_outcome = expected_stage_outcome(expected_stages, stage, side)
                        require(type(expected_outcome.get("exitCode")) is int
                                and outcome.get("expectedExitCode") == expected_outcome["exitCode"],
                                "expected exit differs from execution contract")
                        for stream in ("Stdout", "Stderr"):
                            expected_output = expected_outcome.get(stream.lower())
                            actual_output = outcome.get("actual" + stream)
                            if stream == "Stdout" and "stdoutPolicy" in expected_outcome:
                                helper = "scripts/verification_build_stdout.py"
                                require(outcome.get("inputHashesStart", {}).get(helper) == file_hash(local_file(helper)),
                                        "build stdout validator not pinned")
                                log_ref = outcome.get("stdoutRecord", {})
                                log_file = local_file(log_ref.get("path", ""))
                                require(file_hash(log_file) == log_ref.get("sha256")
                                        and log_file.read_bytes().decode("utf-8") == actual_output,
                                        "build stdout raw stream differs")
                                process_ref = outcome.get("processRecord", {})
                                process_file = local_file(process_ref.get("path", ""))
                                require(file_hash(process_file) == process_ref.get("sha256"), "build stdout process record changed")
                                process = json.loads(process_file.read_text(encoding="utf-8-sig"))
                                require(process.get("exit") == 0 and process.get("failure") is None
                                        and process.get("processesStopped") is True and process.get("finishedAtUtc")
                                        and type(process.get("pid")) is int and process["pid"] > 0
                                        and Path(process.get("stdoutPath", "")).resolve() == log_file,
                                        "build stdout process unconfirmed")
                                stderr_ref = outcome.get("stderrRecord", {})
                                stderr_file = local_file(stderr_ref.get("path", ""))
                                require(file_hash(stderr_file) == stderr_ref.get("sha256")
                                        and stderr_file == Path(process.get("stderrPath", "")).resolve()
                                        and stderr_file.read_bytes().decode("utf-8") == outcome.get("actualStderr"),
                                        "build stderr raw stream differs")
                                product = local_file(outcome.get("outputBinary", {}).get("path", ""))
                                command = process.get("command", [])
                                output_flags = [i for i, part in enumerate(command) if part == "-o"]
                                offset = 2 if proof["compilerBinaries"][side]["path"].lower().endswith(".dll") else 1
                                require(len(command) > offset and command[offset] == "build"
                                        and Path(command[offset - 1]).resolve() == local_file(proof["compilerBinaries"][side]["path"])
                                        and str(local_file(expected_case["fixture"]["path"])) in command
                                        and len(output_flags) == 1 and output_flags[0] + 1 < len(command)
                                        and Path(command[output_flags[0] + 1]).resolve() == product,
                                        "build stdout product command differs")
                                try:
                                    comparison = validate_build_stdout(log_file.read_bytes(), product, side)
                                except (ValueError, OSError) as error:
                                    raise PhaseClosureError(str(error)) from error
                                require(outcome.get("stdoutComparison") == comparison, "build stdout comparison differs")
                                actual_output = comparison["semanticStdout"]
                            elif stream == "Stdout":
                                require("stdoutComparison" not in outcome, "undeclared stdout interpretation")
                            require(isinstance(expected_output, str)
                                    and actual_output == expected_output,
                                    "case behavior or diagnostic differs from execution contract")
                            require("expected" + stream not in outcome
                                    or outcome["expected" + stream] == expected_output,
                                    "outcome expected output differs from execution contract")
                        require(outcome.get("status") == "passed" and outcome.get("compilerSide") == side
                                and outcome.get("stage") == stage, "case execution identity differs")
                        require(type(outcome.get("expectedExitCode")) is int
                                and type(outcome.get("exitCode")) is int
                                and outcome["exitCode"] == outcome["expectedExitCode"],
                                "case execution exit differs")
                        require(outcome.get("failureIds") == [] and outcome.get("orphanProcessIds") == []
                                and outcome.get("canceled") is False, "case execution failed or was canceled")
                        binary = proof["compilerBinaries"][side]
                        require(outcome.get("compilerBinary") == {"path": binary["path"], "sha256": binary["sha256"]},
                                "execution outcome used another compiler")
                        inputs = outcome.get("inputHashesStart")
                        require(isinstance(inputs, dict) and bool(inputs)
                                and outcome.get("inputHashesEnd") == inputs,
                                "case execution inputs unstable")
                        for input_path, expected_hash in inputs.items():
                            if (stage == "run" and compiled_output is not None
                                    and (root / input_path).resolve() == (root / compiled_output["path"]).resolve()):
                                require(expected_hash == compiled_output["sha256"], "case ran another executable")
                                validate_fixture_binary(root, compiled_output, outcome.get("artifactCleanupEvidence"))
                            else:
                                require(file_hash(local_file(input_path)) == expected_hash,
                                        "case execution input changed")
                        required_inputs = {**execution_hashes, fixture["path"]: fixture["sha256"]}
                        require(all(inputs.get(path) == sha for path, sha in required_inputs.items()),
                                "case execution lacks runner, contract, or fixture linkage")
                        if stage == "grammar":
                            command_case = expected_case.get("grammarCommand")
                            require(isinstance(command_case, dict) and set(command_case) == {"lexer", "grammar"}
                                    and command_case["grammar"] == fixture, "grammar command case linkage missing")
                            for input_ref in command_case.values():
                                require(file_hash(local_file(input_ref["path"])) == input_ref["sha256"]
                                        and inputs.get(input_ref["path"]) == input_ref["sha256"],
                                        "grammar command input not pinned")
                            require(outcome["exitCode"] == 1 and "outputBinary" not in outcome
                                    and "executableBinary" not in outcome, "grammar rejection produced a binary")
                            process_ref = outcome.get("processRecord", {})
                            process_file = local_file(process_ref.get("path", ""))
                            require(file_hash(process_file) == process_ref.get("sha256"), "grammar process record changed")
                            process = json.loads(process_file.read_text(encoding="utf-8-sig"))
                            command = process.get("command", [])
                            offset = 2 if binary["path"].lower().endswith(".dll") else 1
                            require(type(process.get("pid")) is int and process["pid"] > 0
                                    and process.get("finishedAtUtc") and process.get("processesStopped") is True
                                    and process.get("failure") is None and process.get("exit") == 1,
                                    "grammar command process unconfirmed")
                            require(len(command) == offset + 6
                                    and Path(command[offset-1]).resolve() == local_file(binary["path"])
                                    and command[offset:offset+2] == ["grammar", "build"]
                                    and Path(command[offset+2]).resolve() == local_file(command_case["lexer"]["path"])
                                    and Path(command[offset+3]).resolve() == local_file(fixture["path"])
                                    and command[offset+4] == "-o", "grammar command was substituted")
                            generated = Path(command[-1]).resolve()
                            expected_generated = Path(str(outcome_path)[:-len(".grammar.json")] + ".generated.slg").resolve()
                            require(outcome_path.name.endswith(".grammar.json") and generated == expected_generated
                                    and generated.is_relative_to(root.resolve()) and not generated.exists(),
                                    "grammar rejection generated an output")
                            for stream in ("stdout", "stderr"):
                                log_ref = outcome.get(stream + "Record", {})
                                log_file = local_file(log_ref.get("path", ""))
                                require(file_hash(log_file) == log_ref.get("sha256")
                                        and log_file == Path(process.get(stream + "Path", "")).resolve()
                                        and log_file.read_bytes().decode("utf-8") == expected_outcome[stream],
                                        "grammar command log differs from oracle")
                        elif stage == "compile":
                            require((outcome["exitCode"] == 0) == ("run" in stages),
                                    "successful compile lacks run outcome or negative compile was run")
                            if outcome["exitCode"] == 0:
                                compiled_output = outcome.get("outputBinary")
                                validate_fixture_binary(root, compiled_output, outcome.get("artifactCleanupEvidence"))
                        else:
                            require(outcome["exitCode"] == 0, "case run failed")
                            require(outcome.get("executableBinary") == compiled_output
                                    and inputs.get(compiled_output["path"]) == compiled_output["sha256"],
                                    "case ran another executable")
                case_decisions = case.get("decisionIds")
                require(isinstance(case_decisions, list) and bool(case_decisions)
                        and set(case_decisions) <= set(required_ids), "case decision linkage differs")
                covered_decisions.update(case_decisions)
            require(covered_decisions == set(required_ids), "compiled cases omit required decisions")

        binaries = paired["compilerBinaries"]
        require(set(binaries) == {"managed", "selfhost"}, "missing compiler binary")
        require(managed.get("compilerBinaries") == {"managed": binaries["managed"]},
                "managed-first compiler differs from paired compiler")
        for side, binary in binaries.items():
            path = Path(binary["path"])
            if not path.is_absolute():
                path = root / path
            require(path.is_file() and file_hash(path) == binary["sha256"], "compiler binary changed")
            build = record(binary["buildRecord"], phase)
            terminal_success(build)
            require(type(build.get("total")) is int and build["total"] == 1
                    and type(build.get("completed")) is int and build["completed"] == 1,
                    "incomplete compiler build")
            expected = {**{p: source_hashes[p] for p in side_sources[side]}, **shared_hashes}
            if phase == "parsing":
                link(build, "generationRecord", generation_path)
            require(build.get("inputStable") is True and build.get("compilerSide") == side,
                    "unstable compiler build")
            require(build.get("sourceHashesStart") == expected == build.get("sourceHashesEnd"),
                    "binary was not built from current phase sources")
            require(build.get("binary") == {"path": binary["path"], "sha256": binary["sha256"]},
                    "build output and tested compiler differ")
            require(file_hash(local_file(binary["buildRecord"])) == binary.get("buildRecordSha256"),
                    "compiler build record changed")
        complete += 1
    closure = detail["phaseClosure"]
    require(closure["completed"] == complete and closure["total"] == len(rows), "phase closure count differs")
    expected_status = "complete" if complete == len(rows) else "all-partial" if complete == 0 else "partial"
    require(closure["status"] == expected_status, "phase closure status differs")
    return complete


def verify_detail():
    detail = read("scripts/contracts/structural-parity-detail.json")
    progress = read("scripts/contracts/active-goal-progress.json")
    semantic = read("scripts/contracts/interpolation-semantic-parity.json")
    phases = read(detail["phaseSource"])["phaseMapping"]

    rows = detail["phaseProgress"]
    assert len(rows) == len(phases) == detail["phaseClosure"]["total"]
    assert [row["phase"] for row in rows] == [phase["phase"] for phase in phases]
    completed_phases = sum(phase["aligned"] == "complete" for phase in phases)
    assert completed_phases == detail["phaseClosure"]["completed"]
    validate_phase_closure(detail, phases, ROOT)

    ownership = detail["measuredSubscopes"]["interpolationSemanticOwnedKinds"]
    assert len(semantic["semanticOwnedKinds"]) == ownership["completed"]
    assert len(semantic["kinds"]) == ownership["total"]
    assert set(semantic["semanticOwnedKinds"]).isdisjoint(semantic["emitterOwnedKinds"])
    assert len(semantic["semanticOwnedKinds"]) + len(semantic["emitterOwnedKinds"]) == ownership["total"]
    index_progress = detail["measuredSubscopes"]["indexPreIrBranches"]
    index_contract = read(index_progress["source"])
    assert index_contract["kind"] == 7 and index_contract["finalSemanticOwnerPromotion"] == "complete"
    assert index_contract["finalSemanticOwnerProof"] == semantic["memberResultSemanticTypeEvidence"]
    assert len(index_contract["branches"]) == index_progress["total"]
    assert len({row["id"] for row in index_contract["branches"]}) == index_progress["total"]
    assert sum(row["status"] == "complete" for row in index_contract["branches"]) == index_progress["completed"]
    assert (ROOT / index_contract["managedSource"]).is_file()
    assert (ROOT / index_contract["selfhostSource"]).is_file()
    assert re.fullmatch(r"[A-F0-9]{64}", index_contract["managedSourceSha256"])
    assert re.fullmatch(r"[A-F0-9]{64}", index_contract["selfhostSourceSha256"])
    for row in index_contract["branches"]:
        assert row["status"] in ("complete", "pending")
        if row["status"] == "complete":
            assert read(row["evidence"])["status"] == "passed"
    if 1 in semantic["semanticOwnedKinds"]:
        assert semantic["lexicalNamePreIrEvidence"] == "artifacts/scratch/c580-lexical-name-preir-unit-20260928-01.json"
    assert ownership["currentProof"] == semantic["resultPropagationSemanticOwnerEvidence"]
    subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(ROOT / "scripts/verify-c613-result-propagation-semantic-owner.ps1")],
        cwd=ROOT,
        check=True,
    )

    identified = detail["measuredSubscopes"]["identifiedImplementationUnits"]
    identified_complete, identified_total = known_implementation_unit_counts(progress)
    assert identified_complete == identified["completed"]
    assert identified_total == identified["total"]

    recent = detail["measuredSubscopes"]["recentFocusedUnits"]
    first_unit, last_unit = recent["firstUnit"], recent["lastUnit"]
    focused = {}
    focused_history = read(progress["focusedGateHistory"])
    for gate in focused_history["focusedGates"]:
        match = re.match(r"^C(5\d\d)\b", gate["name"])
        if match and first_unit <= int(match.group(1)) <= last_unit:
            focused.setdefault(int(match.group(1)), []).append(gate)
    assert set(focused) == set(range(first_unit, last_unit + 1))
    assert len(focused) == recent["total"]
    assert sum(all(gate["status"] == "complete" and gate["completed"] == gate["total"]
                   for gate in gates) for gates in focused.values()) == recent["completed"]

    current = detail["measuredSubscopes"]["currentFocusedCases"]
    source = read(current["source"])
    assert source["unit"].startswith((current["unit"] + "-", current["unit"] + " "))
    assert (source.get("focusedCompleted", source.get("completed")),
            source.get("focusedTotal", source.get("total"))) == (
        current["completed"], current["total"]
    )
    assert progress["implementationParity"]["detailContract"] == "scripts/contracts/structural-parity-detail.json"
    closure = detail["measuredSubscopes"]["sourceHashClosure"]
    audit = read(closure["audit"])
    assert len(audit) == closure["total"] == 9
    matches = {
        row["source"]: hashlib.sha256((ROOT / row["source"]).read_bytes()).hexdigest().upper() == row["currentSha"]
        for row in audit
    }
    compiler_matches = [matched for name, matched in matches.items() if name.startswith("selfhost/")]
    fixture_matches = [matched for name, matched in matches.items() if not name.startswith("selfhost/")]
    assert closure["currentHashMatches"] == {"completed": sum(matches.values()), "total": len(matches)}
    assert closure["currentCompilerHashMatches"] == {"completed": sum(compiler_matches), "total": len(compiler_matches)}
    assert closure["currentFixtureHashMatches"] == {"completed": sum(fixture_matches), "total": len(fixture_matches)}
    assert closure["status"] == ("current-source-closed" if all(matches.values()) else "historical-proof-current-source-drift")
    if not all(matches.values()):
        drifted = [name for name, matched in matches.items() if not matched]
        raise RuntimeError(f"current-source hash closure pending: {len(matches) - len(drifted)}/{len(matches)} match; drifted={drifted}")
    # Current source closure is proven by the linked focused suite below.
    # Historical branch-match counters cannot describe a refreshed audit.
    assert all(row.get("currentProofMatched") is True
               and row.get("currentVerificationReference") == closure["fixtureProof"]
               for row in audit)
    assert sum(row["source"].startswith("selfhost/") for row in audit) == closure["compilerSourcesTotal"] == 5
    assert closure["closed"] == closure["compilerSourcesClosed"] + closure["fixturePairedClosed"]
    assert closure["fixtureInitializersVerified"] == closure["fixtureTotal"] == 4
    assert closure["fixtureManifestsVerified"] == closure["fixtureTotal"]
    assert closure["producerInitializerVerified"] == closure["producerInitializerTotal"] == 1
    fixture_proof = read(closure["fixtureProof"])
    assert fixture_proof["status"] in ("pending-pair", "passed")
    paired_fixtures = {
        row["fixture"]
        for value in fixture_proof["pairedProofs"]
        for row in read(value)["runs"]
    }
    if fixture_proof["suitePairedProofs"]:
        assert len(fixture_proof["suitePairedProofs"]) == 1
        suite_pair = json.loads(Path(fixture_proof["suitePairedProofs"][0]).read_text(encoding="utf-8-sig"))
        assert suite_pair["status"] == "passed" and suite_pair["inputStable"]
        paired_fixtures.update(Path(source).stem for source in fixture_proof["currentSourceHashes"])
        assert closure["compilerSourcesClosed"] == closure["compilerSourcesTotal"]
        for row in audit:
            if row["source"].startswith("selfhost/"):
                path = str((ROOT / row["source"]).resolve())
                assert suite_pair["inputHashesStart"][path] == suite_pair["inputHashesEnd"][path] == row["currentSha"]
    elif fixture_proof.get('focusedSuiteProofs'):
        assert len(fixture_proof['focusedSuiteProofs']) == 1
        evidence = validate_focused_suite(
            ROOT, fixture_proof['focusedSuiteProofs'][0], Path(fixture_proof['currentCompiler']),
            suite_required_inputs(ROOT, fixture_proof['currentSourceHashes'],
                                  fixture_proof['currentManifestHashes']))
        paired_fixtures.update(evidence['fixtures'])
        assert closure['compilerSourcesClosed'] == closure['compilerSourcesTotal']
        for row in audit:
            path = str((ROOT / row['source']).resolve())
            assert evidence['currentInputHashes'][path] == row['currentSha']
    else:
        assert closure["compilerSourcesClosed"] == 0
    assert len(paired_fixtures) == closure["fixturePairedClosed"]
    assert (fixture_proof["status"] == "passed") == (closure["closed"] == closure["total"])
    assert len(fixture_proof.get("priorCandidatePairedProofs", [])) == closure["fixturePriorCandidatePassed"]
    assert len(fixture_proof.get("canceledAttempts", [])) == closure["fixtureCanceledUnverified"]
    assert len(fixture_proof.get("currentTimedOutAttempts", [])) == closure["fixtureCurrentTimeout"]
    assert len(fixture_proof["failedAttempts"]) == 2 + closure["fixturePairedTimeout"]
    assert sum(
        read(attempt["result"])["status"] == "failed"
        and read(attempt["result"])["inputStable"]
        and attempt["classification"] == "managed-pass-selfhost-semantic-diagnostic-mismatch"
        for attempt in fixture_proof["failedAttempts"]
    ) == closure["fixturePairedFailed"] == 1
    assert sum(
        attempt["classification"] == "selfhost-build-timeout-20min-concurrent"
        and read(attempt["result"])["status"] == "failed"
        and read(attempt["result"])["inputStable"]
        and "exceeded the configured verification limit" in read(attempt["result"])["failure"]
        for attempt in fixture_proof["failedAttempts"]
    ) == closure["fixturePairedTimeout"] == 4
    subprocess.run(
        [sys.executable, str(ROOT / "scripts/verify-context-fixture-source-closure.py"),
         *([] if fixture_proof["status"] == "passed" else ["--static-only"])],
        cwd=ROOT,
        check=True,
    )

    print(
        f"[structural parity detail] PASS phases {completed_phases}/{len(phases)}, "
        f"semantic owners {ownership['completed']}/{ownership['total']}, "
        f"identified units {identified['completed']}/{identified['total']}, "
        f"recent focused units {recent['completed']}/{recent['total']}, "
        f"{current['unit']} cases {current['completed']}/{current['total']}"
    )


if __name__ == "__main__":
    if sys.argv[1:] == ["--phase-closure-only"]:
        detail = read("scripts/contracts/structural-parity-detail.json")
        completed = validate_phase_closure(detail, read(detail["phaseSource"])["phaseMapping"], ROOT)
        print(f"[phase closure contract] PASS declared closure {completed}/{detail['phaseClosure']['total']}")
    elif sys.argv[1:]:
        raise SystemExit("usage: verify-structural-parity-detail.py [--phase-closure-only]")
    else:
        verify_detail()
