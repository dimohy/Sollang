"""Focused file-backed controls for structural phase promotion; no compiler build."""

import copy
import importlib.util
import json
import os
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "structural_detail", Path(__file__).with_name("verify-structural-parity-detail.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PhaseClosureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sources = {"managed": "src/Sollang.Compiler/Parsing/Parser.cs",
                        "selfhost": "selfhost/syntax/parser.slg"}
        for side, path in self.sources.items():
            self.write(path, "source " + side)
        self.side_sources = {}
        for side, scopes in MODULE.PHASE_SCOPES["parsing"].items():
            paths = [self.sources[side]]
            for scope in scopes:
                path = scope if scope.endswith((".cs", ".slg")) else scope + "/InventorySource" + (".cs" if side == "managed" else ".slg")
                self.write(path, "canonical source " + path)
                paths.append(path)
            self.side_sources[side] = sorted(set(paths))
        self.hashes = {path: MODULE.file_hash(self.root / path)
                       for paths in self.side_sources.values() for path in paths}
        for path in MODULE.PARSING_SHARED_DEPENDENCIES:
            if not (self.root / path).exists():
                self.write(path, "canonical dependency " + path)
        import hashlib
        lexer = (self.root / "syntax/sollang.lexer").read_text()
        grammar = (self.root / "syntax/sollang.grammar").read_text()
        stamp = hashlib.sha256((lexer + "\n---grammar---\n" + grammar).encode()).hexdigest()
        self.write("syntax/generated/sollang_grammar.slg", "# Source SHA-256: " + stamp + "\n")
        self.shared_hashes = {path: MODULE.file_hash(self.root / path) for path in MODULE.PARSING_SHARED_DEPENDENCIES}
        generation_inputs = {path: self.shared_hashes[path] for path in
                             ["syntax/sollang.lexer", "syntax/sollang.grammar", *MODULE.PARSING_PRODUCERS]}
        outputs = []
        for index, (path, producer) in enumerate(MODULE.PARSING_DERIVED.items()):
            reproduced = "reproduced/" + str(index) + ".generated"
            self.write(reproduced, (self.root / path).read_text())
            outputs.append({"path": path, "sha256": self.shared_hashes[path], "producerPath": producer,
                            "reproducedFile": self.link(reproduced), "execution": {
                                "status": "passed", "exitCode": 0, "failureIds": [], "orphanProcessIds": [],
                                "canceled": False, "inputStable": True, "inputHashesStart": generation_inputs,
                                "inputHashesEnd": generation_inputs, "producerPath": producer,
                                "producerSha256": self.shared_hashes[producer], "producedFile": self.link(reproduced)}})
        self.write_record("records/generation.json", {"phase": "parsing", "status": "passed",
            "exitCode": 0, "failureIds": [], "orphanProcessIds": [], "canceled": False,
            "method": "current-producer-reproduction", "completed": 3, "total": 3,
            "inputStable": True, "inputHashesStart": generation_inputs, "inputHashesEnd": generation_inputs,
            "producerHashes": {path: self.shared_hashes[path] for path in MODULE.PARSING_PRODUCERS}, "outputs": outputs})
        decisions = [{"id": "parse-boundary", "status": "complete",
                      "structure": "declaration dispatch", "branches": "header success and failure",
                      "logic": "commit before expression fallback", "diagnostics": "exact location and text",
                      "managedSources": self.side_sources["managed"],
                      "selfhostSources": self.side_sources["selfhost"]}]
        self.binaries = {}
        for side in self.sources:
            binary = "build/" + side + ".bin"
            self.write(binary, "compiled " + side)
            value = {"path": binary, "sha256": MODULE.file_hash(self.root / binary)}
            build_path = "records/" + side + "-build.json"
            hashes = {**{path: self.hashes[path] for path in self.side_sources[side]}, **self.shared_hashes}
            self.write_record(build_path, {"phase": "parsing", "status": "passed",
                "exitCode": 0, "failureIds": [], "orphanProcessIds": [], "canceled": False,
                "completed": 1, "total": 1,
                "generationRecord": self.link("records/generation.json"),
                "inputStable": True, "compilerSide": side, "sourceHashesStart": hashes,
                "sourceHashesEnd": hashes, "binary": value})
            self.binaries[side] = {**value, "buildRecord": build_path,
                                   "buildRecordSha256": MODULE.file_hash(self.root / build_path)}
        managed_hashes = {**{path: self.hashes[path] for path in self.side_sources["managed"]}, **self.shared_hashes}
        self.write("runner.py", "controlled runner")
        expected_cases = []
        for case_id in ("positive-header", "negative-header"):
            fixture = "fixtures/" + case_id + ".slg"
            self.write(fixture, "fixture " + case_id)
            expected_stages = {"compile": {"exitCode": 0 if case_id == "positive-header" else 1,
                "stdout": "", "stderr": "" if case_id == "positive-header" else "invalid header\n"}}
            if case_id == "positive-header":
                expected_stages["run"] = {"exitCode": 0, "stdout": "ok\n", "stderr": ""}
            expected_cases.append({"id": case_id, "decisionIds": ["parse-boundary"],
                                   "fixture": self.link(fixture), "expectedStages": expected_stages})
        self.write_record("contract.json", {"schemaVersion": 1, "phase": "parsing",
                          "decisionIds": ["parse-boundary"], "cases": expected_cases})
        execution_inputs = {"runner": self.link("runner.py"), "contract": self.link("contract.json")}
        base = {"phase": "parsing", "status": "passed", "inputStable": True,
                "generationRecord": self.link("records/generation.json"),
                "executionInputs": execution_inputs,
                "exitCode": 0, "failureIds": [], "orphanProcessIds": [], "canceled": False,
                "decisionIds": ["parse-boundary"], "completed": 2, "total": 2}
        def cases(binaries):
            values = []
            for expected_case in expected_cases:
                case_id = expected_case["id"]
                fixture = "fixtures/" + case_id + ".slg"
                self.write(fixture, "fixture " + case_id)
                fixture_ref = self.link(fixture)
                inputs = {fixture: fixture_ref["sha256"], **{
                    ref["path"]: ref["sha256"] for ref in execution_inputs.values()}}
                outcomes = {}
                for side, binary in binaries.items():
                    stages = ["compile", "run"] if case_id == "positive-header" else ["compile"]
                    outcomes[side] = {}
                    output_binary = None
                    if "run" in stages:
                        output_path = f"build/{case_id}-{side}.exe"
                        self.write(output_path, "compiled fixture " + side)
                        output_binary = self.link(output_path)
                    for stage in stages:
                        path = f"records/{case_id}-{side}-{stage}.json"
                        exit_code = 1 if case_id == "negative-header" else 0
                        outcome = {"status": "passed", "compilerSide": side, "stage": stage,
                            "actualStdout": expected_case["expectedStages"][stage]["stdout"],
                            "actualStderr": expected_case["expectedStages"][stage]["stderr"],
                            "exitCode": exit_code, "expectedExitCode": exit_code, "failureIds": [],
                            "orphanProcessIds": [], "canceled": False,
                            "compilerBinary": {"path": binary["path"], "sha256": binary["sha256"]},
                            "inputHashesStart": dict(inputs), "inputHashesEnd": dict(inputs)}
                        if output_binary:
                            outcome["outputBinary" if stage == "compile" else "executableBinary"] = output_binary
                            if stage == "run":
                                for field in ("inputHashesStart", "inputHashesEnd"):
                                    outcome[field][output_binary["path"]] = output_binary["sha256"]
                        self.write_record(path, outcome)
                        outcomes[side][stage] = self.link(path)
                values.append({"id": case_id, "status": "passed", "exitCode": 0,
                     "failureIds": [], "orphanProcessIds": [], "canceled": False,
                     "decisionIds": ["parse-boundary"], "compilerBinaries": binaries,
                     "outcomes": outcomes, "fixture": fixture_ref})
            return values
        self.write_record("records/managed.json", {**base,
            "cases": cases({"managed": self.binaries["managed"]}),
            "sourceHashesStart": managed_hashes, "sourceHashesEnd": managed_hashes,
            "compilerBinaries": {"managed": self.binaries["managed"]}})
        self.write_record("records/comparison.json", {"phase": "parsing", "status": "compared",
            "sharedDependencyHashes": self.shared_hashes, "generationRecord": self.link("records/generation.json"),
            "sourceHashes": self.hashes, "decisions": decisions,
            "managedFirstRecord": self.link("records/managed.json")})
        self.write_record("records/paired.json", {**base, "mode": "phase-exhaustive",
            "cases": cases(self.binaries),
            "sourceHashesStart": {**self.hashes, **self.shared_hashes}, "sourceHashesEnd": {**self.hashes, **self.shared_hashes},
            "compilerBinaries": self.binaries,
            "sourceComparisonRecord": self.link("records/comparison.json")})
        requirements = {"decisionFields": ["structure", "branches", "logic", "diagnostics"],
                        "compiledProofMode": "phase-exhaustive",
                        "sourceExtensions": {"managed": ".cs", "selfhost": ".slg"}}
        self.detail = {"schemaVersion": 2, "promotionRequirements": requirements,
            "phaseClosure": {"completed": 1, "total": 7, "status": "partial"},
            "phaseProgress": [{"phase": "parsing", "status": "complete", "decisionInventory": {
                "status": "reviewed", "sourceScopes": copy.deepcopy(MODULE.PHASE_SCOPES["parsing"]),
                "sharedDependencies": MODULE.PARSING_SHARED_DEPENDENCIES[:], "generationRecord": "records/generation.json",
                "requiredDecisionIds": ["parse-boundary"], "decisions": decisions,
                "managedFirstRecord": "records/managed.json",
                "sourceComparisonRecord": "records/comparison.json", "pairedRecord": "records/paired.json"}}]}
        self.phases = [{"phase": "parsing", "aligned": "complete"}]
        for phase in list(MODULE.PHASE_SCOPES)[1:]:
            self.detail["phaseProgress"].append({"phase": phase, "status": "partial",
                "decisionInventory": {"status": "pending", "sourceScopes": MODULE.PHASE_SCOPES[phase],
                                      "requiredDecisionIds": [], "decisions": []}})
            self.phases.append({"phase": phase, "aligned": "partial-behavior"})

    def write(self, path, value):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(value, encoding="utf-8")

    def write_record(self, path, value):
        self.write(path, json.dumps(value, indent=2))

    def link(self, path):
        return {"path": path, "sha256": MODULE.file_hash(self.root / path)}

    def change_record(self, path, **changes):
        value = json.loads((self.root / path).read_text(encoding="utf-8"))
        value.update(changes)
        self.write_record(path, value)

    def validate(self):
        return MODULE.validate_phase_closure(self.detail, self.phases, self.root)

    def rejects(self, message):
        with self.assertRaisesRegex(MODULE.PhaseClosureError, message):
            self.validate()

    def install_side_oracles(self):
        contract = json.loads((self.root / "contract.json").read_text())
        for case in contract["cases"]:
            shared = case["expectedStages"]["compile"]
            case["expectedStages"]["compile"] = {"compilerSides": {
                side: {**shared, "stdout": "compiled " + side + "\n"}
                for side in ("managed", "selfhost")}}
        self.write_record("contract.json", contract)
        self.refresh_execution_links(update_actual=True)

    def install_build_telemetry(self):
        from verification_build_stdout import POLICY, validate_build_stdout
        helper = "scripts/verification_build_stdout.py"
        self.write(helper, Path(__file__).with_name("verification_build_stdout.py").read_text(encoding="utf-8"))
        contract = json.loads((self.root / "contract.json").read_text())
        contract["cases"][0]["expectedStages"]["compile"]["stdoutPolicy"] = POLICY
        self.write_record("contract.json", contract)
        for side in ("managed", "selfhost"):
            path = f"records/positive-header-{side}-compile.json"
            outcome = json.loads((self.root / path).read_text())
            binary = self.root / outcome["outputBinary"]["path"]
            cache = binary.parent / ".sollang-cache" / (binary.stem + ".windows-x64")
            if side == "managed":
                lines = [f"[frontend-cache] cold; rebuilt and published 1 sources; {cache}.sources",
                    f"[codegen-cache] cold; reused 0/1 units; {cache}.cgu",
                    f"[semantic-cache] cold; reused 0/1 functions; main rebuilt; mapped 0/1 functions, 0/1 call sites; {cache}.semantic",
                    f"[product-cache] rebuilt; linked and published; {cache}.product",
                    f"Wrote {binary} ({binary.stat().st_size:,} bytes)"]
            else:
                lines = [f"[semantic-cache] load-status 50; reused 0/1 sources; rejected 0; uncached 1; {cache}.semantic", f"Wrote {binary}"]
            raw = ("\r\n".join(lines)+"\r\n").encode()
            log = f"records/{side}-build.stdout.log"
            (self.root / log).write_bytes(raw)
            outcome["actualStdout"] = raw.decode()
            outcome["stdoutRecord"] = self.link(log)
            stderr_log = f"records/{side}-build.stderr.log"
            (self.root / stderr_log).write_bytes(b"")
            outcome["stderrRecord"] = self.link(stderr_log)
            process_path = f"records/{side}-build.process.json"
            self.write_record(process_path, {"pid":1,"finishedAtUtc":"2026-10-19T00:00:00Z","exit":0,
                "failure":None,"processesStopped":True,"stdoutPath":str(self.root/log),"stderrPath":str(self.root/stderr_log),
                "command":[str(self.root/self.binaries[side]["path"]),"build",
                    str(self.root/contract["cases"][0]["fixture"]["path"]),"-o",str(binary)]})
            outcome["processRecord"] = self.link(process_path)
            outcome["stdoutComparison"] = validate_build_stdout(raw,binary,side)
            for field in ("inputHashesStart","inputHashesEnd"):
                outcome[field][helper] = self.link(helper)["sha256"]
            self.write_record(path,outcome)
        self.refresh_execution_links()

    def test_declared_build_telemetry_preserves_raw_and_passes(self):
        self.install_build_telemetry()
        self.validate()

    def test_build_telemetry_requires_pinned_helper(self):
        self.install_build_telemetry()
        self.write("scripts/verification_build_stdout.py", "changed")
        self.rejects("input changed|not pinned")

    def test_build_telemetry_rejects_fabricated_comparison(self):
        self.install_build_telemetry()
        self.change_record("records/positive-header-managed-compile.json", stdoutComparison={"semanticStdout":""})
        self.refresh_execution_links()
        self.rejects("comparison differs")

    def test_build_telemetry_rejects_other_product_command(self):
        self.install_build_telemetry()
        process_path = "records/managed-build.process.json"
        process = json.loads((self.root/process_path).read_text())
        process["command"][-1] = str(self.root/"build/other.exe")
        self.write_record(process_path,process)
        self.change_record("records/positive-header-managed-compile.json",processRecord=self.link(process_path))
        self.refresh_execution_links()
        self.rejects("product command differs")

    def test_build_telemetry_cannot_hide_raw_stderr(self):
        self.install_build_telemetry()
        self.write("records/managed-build.stderr.log", "warning: must not be hidden")
        self.rejects("stderr raw stream differs")

    def refresh_execution_links(self, update_actual=False):
        contract = json.loads((self.root / "contract.json").read_text())
        paired_cases = json.loads((self.root / "records/paired.json").read_text())["cases"]
        for expected in contract["cases"]:
            for side in ("managed", "selfhost"):
                for stage in expected["expectedStages"]:
                    paired_case = next(case for case in paired_cases if case["id"] == expected["id"])
                    path = paired_case["outcomes"][side][stage]["path"]
                    outcome = json.loads((self.root / path).read_text())
                    for field in ("inputHashesStart", "inputHashesEnd"):
                        outcome[field]["contract.json"] = self.link("contract.json")["sha256"]
                    if update_actual:
                        oracle = MODULE.expected_stage_outcome(expected["expectedStages"], stage, side)
                        outcome["actualStdout"], outcome["actualStderr"] = oracle["stdout"], oracle["stderr"]
                    self.write_record(path, outcome)
        for proof_path in ("records/managed.json", "records/paired.json"):
            proof = json.loads((self.root / proof_path).read_text())
            proof["executionInputs"]["contract"] = self.link("contract.json")
            for case in proof["cases"]:
                for stages in case["outcomes"].values():
                    for stage, ref in stages.items():
                        stages[stage] = self.link(ref["path"])
            self.write_record(proof_path, proof)
        comparison = json.loads((self.root / "records/comparison.json").read_text())
        comparison["managedFirstRecord"] = self.link("records/managed.json")
        self.write_record("records/comparison.json", comparison)
        paired = json.loads((self.root / "records/paired.json").read_text())
        paired["sourceComparisonRecord"] = self.link("records/comparison.json")
        self.write_record("records/paired.json", paired)

    def mutate_side_oracle(self, mutate):
        self.install_side_oracles()
        contract = json.loads((self.root / "contract.json").read_text())
        mutate(contract["cases"][0]["expectedStages"])
        self.write_record("contract.json", contract)
        self.refresh_execution_links()

    def install_grammar_rejection(self):
        """Isolated file-backed authority; never operational compiler evidence."""
        self.write("fixtures/predicate.lexer", "token End = end\n")
        contract = json.loads((self.root / "contract.json").read_text())
        case = contract["cases"][1]
        case["grammarCommand"] = {"lexer": self.link("fixtures/predicate.lexer"), "grammar": case["fixture"]}
        case["expectedStages"] = {"grammar": {"exitCode": 1, "stdout": "", "stderr": "invalid header\n"}}
        self.write_record("contract.json", contract)
        for side in ("managed", "selfhost"):
            path = f"records/negative-header-{side}.grammar.json"
            outcome = json.loads((self.root / f"records/negative-header-{side}-compile.json").read_text())
            outcome["stage"] = "grammar"
            for field in ("inputHashesStart", "inputHashesEnd"):
                outcome[field]["fixtures/predicate.lexer"] = self.link("fixtures/predicate.lexer")["sha256"]
            logs = {}
            for stream in ("stdout", "stderr"):
                log = f"records/{side}.{stream}.log"
                self.write(log, case["expectedStages"]["grammar"][stream])
                (self.root / log).write_bytes(case["expectedStages"]["grammar"][stream].encode("utf-8"))
                outcome[stream + "Record"] = self.link(log)
                logs[stream + "Path"] = str((self.root / log).resolve())
            process_path = f"records/{side}.grammar-process.json"
            output = str((self.root / path.replace(".grammar.json", ".generated.slg")).resolve())
            self.write_record(process_path, {"pid": 123, "finishedAtUtc": "test-only", "processesStopped": True,
                "failure": None, "exit": 1, **logs, "command": [str((self.root / self.binaries[side]["path"]).resolve()),
                "grammar", "build", str((self.root / "fixtures/predicate.lexer").resolve()),
                str((self.root / case["fixture"]["path"]).resolve()), "-o", output]})
            outcome["processRecord"] = self.link(process_path)
            self.write_record(path, outcome)
        for path in ("records/managed.json", "records/paired.json"):
            proof = json.loads((self.root / path).read_text())
            value = proof["cases"][1]
            for side in value["outcomes"]:
                value["outcomes"][side] = {"grammar": self.link(f"records/negative-header-{side}.grammar.json")}
            self.write_record(path, proof)
        self.refresh_execution_links()

    def test_grammar_rejection_closes_only_with_actual_command_linkage(self):
        self.install_grammar_rejection()
        self.assertEqual(self.validate(), 1)

    def test_grammar_rejection_rejects_substituted_command(self):
        self.install_grammar_rejection()
        process = json.loads((self.root / "records/managed.grammar-process.json").read_text())
        process["command"][1] = "build"
        self.write_record("records/managed.grammar-process.json", process)
        self.change_record("records/negative-header-managed.grammar.json", processRecord=self.link("records/managed.grammar-process.json"))
        self.refresh_execution_links()
        self.rejects("grammar command was substituted")

    def test_grammar_rejection_rejects_generated_output(self):
        self.install_grammar_rejection()
        self.write("records/negative-header-managed.generated.slg", "unexpected output")
        self.rejects("grammar rejection generated an output")

    def test_grammar_rejection_rejects_unpinned_lexer(self):
        self.install_grammar_rejection()
        path = "records/negative-header-managed.grammar.json"
        outcome = json.loads((self.root / path).read_text())
        for field in ("inputHashesStart", "inputHashesEnd"):
            del outcome[field]["fixtures/predicate.lexer"]
        self.write_record(path, outcome)
        self.refresh_execution_links()
        self.rejects("grammar command input not pinned")

    def test_grammar_rejection_rejects_fabricated_stdout(self):
        self.install_grammar_rejection()
        self.write("records/managed.stdout.log", "forged")
        self.change_record("records/negative-header-managed.grammar.json", stdoutRecord=self.link("records/managed.stdout.log"))
        self.refresh_execution_links()
        self.rejects("grammar command log differs from oracle")

    def test_distinct_compile_side_outputs_promote(self):
        self.install_side_oracles()
        self.validate()

    def test_wrong_compile_side_output_rejects(self):
        self.install_side_oracles()
        self.change_outcome("compile", actualStdout="compiled managed\n")
        self.rejects("behavior or diagnostic differs")

    def test_missing_compile_side_rejects_managed_first(self):
        self.mutate_side_oracle(lambda stages: stages["compile"]["compilerSides"].pop("selfhost"))
        self.rejects("both compiler side oracles required")

    def test_tampered_compile_oracle_rejects(self):
        self.mutate_side_oracle(lambda stages: stages["compile"]["compilerSides"]["managed"].update(stdout="tampered"))
        self.rejects("behavior or diagnostic differs")

    def test_swapped_compile_oracles_reject(self):
        def swap(stages):
            sides = stages["compile"]["compilerSides"]
            sides["managed"], sides["selfhost"] = sides["selfhost"], sides["managed"]
        self.mutate_side_oracle(swap)
        self.rejects("behavior or diagnostic differs")

    def test_stale_side_oracle_contract_hash_rejects(self):
        self.install_side_oracles()
        self.write("contract.json", (self.root / "contract.json").read_text() + " ")
        self.rejects("runner or contract changed")

    def test_compile_side_exits_cannot_diverge(self):
        self.mutate_side_oracle(lambda stages: stages["compile"]["compilerSides"]["selfhost"].update(exitCode=1))
        self.rejects("compiler side exits must match")

    def test_run_oracle_remains_shared(self):
        self.mutate_side_oracle(lambda stages: stages.update(run={"compilerSides": {
            side: {"exitCode": 0, "stdout": "ok\n", "stderr": ""} for side in ("managed", "selfhost")}}))
        self.rejects("compiler sides allowed only for compile")

    def test_compile_shared_and_side_fields_cannot_mix(self):
        self.mutate_side_oracle(lambda stages: stages["compile"].update(stdout=""))
        self.rejects("compiler sides allowed only for compile")

    def test_side_oracle_acceptance_contract_is_frozen(self):
        acceptance = json.loads((Path(__file__).parent / "contracts/native-exact-compile-side-oracle-acceptance.json").read_text())
        self.assertEqual(acceptance["status"], "frozen-before-implementation")
        self.assertEqual({case["id"] for case in acceptance["cases"]}, {
            "distinct-positive", "legacy-shared", "wrong-side", "missing-side",
            "tampered-oracle", "swapped-oracles", "stale-contract-hash", "unequal-exits",
            "side-specific-run", "mixed-shared-and-sided"})

    def retire_fixture_output(self):
        import completed_artifact_plan as lifecycle
        old_path = "build/positive-header-selfhost.exe"
        new_path = "artifacts/phase-fixture/probe.exe"
        self.write(new_path, (self.root / old_path).read_text())
        binary = self.link(new_path)
        output = self.root / "artifacts/phase-fixture"
        self.write_record("artifacts/phase-fixture/result.json", {
            "status": "passed", "completed": 1, "total": 1, "inputsStable": True,
            "processesStopped": True, "cases": [{"id": "fixture", "status": "passed",
                "passed": True, "buildExit": 0, "runExit": 0}],
            "generatedOutputHashes": {str(self.root / new_path): binary["sha256"]}})
        plan = lifecycle.create_plan(self.root, self.root / "artifacts", minimum_age_hours=0,
                                     selected_outputs={str(output)}, reusable_directories=[])
        plan_path = "artifacts/phase-fixture/artifact-cleanup-plan.json"
        self.write_record(plan_path, plan)
        execution_path = plan_path + ".execution.json"
        self.write_record(execution_path, {"schemaVersion": 1, "status": "completed",
            "plannedFiles": plan["files"], "plannedDirectories": plan["directories"],
            "logicalBytes": plan["logicalBytes"], "completionDispositions": [{
                "output": str(output), "disposition": "verified-complete", "recordStatus": "passed"}]})
        cleanup = {"plan": self.link(plan_path), "execution": self.link(execution_path)}
        for stage in ("compile", "run"):
            path = f"records/positive-header-selfhost-{stage}.json"
            outcome = json.loads((self.root / path).read_text())
            outcome["outputBinary" if stage == "compile" else "executableBinary"] = binary
            outcome["artifactCleanupEvidence"] = cleanup
            for field in ("inputHashesStart", "inputHashesEnd"):
                outcome[field].pop(old_path, None)
                if stage == "run": outcome[field][new_path] = binary["sha256"]
            self.write_record(path, outcome)
        self.refresh_execution_links()
        (self.root / new_path).unlink()
        return binary, cleanup

    def test_verified_cleaned_fixture_output_keeps_execution_proof(self):
        self.retire_fixture_output()
        self.assertEqual(self.validate(), 1)

    def test_missing_fixture_output_without_cleanup_is_rejected(self):
        (self.root / "build/positive-header-selfhost.exe").unlink()
        with self.assertRaises((MODULE.PhaseClosureError, FileNotFoundError)):
            self.validate()

    def test_failed_cleanup_execution_cannot_prove_missing_output(self):
        binary, cleanup = self.retire_fixture_output()
        self.change_record(cleanup["execution"]["path"], status="failed")
        cleanup["execution"] = self.link(cleanup["execution"]["path"])
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "execution incomplete"):
            MODULE.validate_fixture_binary(self.root, binary, cleanup)

    def test_cleanup_target_hash_cannot_replace_executed_identity(self):
        binary, cleanup = self.retire_fixture_output()
        plan_path = cleanup["plan"]["path"]
        plan = json.loads((self.root / plan_path).read_text())
        plan["targets"][0]["sha256"] = "0" * 64
        self.write_record(plan_path, plan)
        cleanup["plan"] = self.link(plan_path)
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "differs from cleanup target"):
            MODULE.validate_fixture_binary(self.root, binary, cleanup)

    def test_cleanup_cannot_admit_failed_owner_record(self):
        binary, cleanup = self.retire_fixture_output()
        self.change_record("artifacts/phase-fixture/result.json", status="failed")
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "cleanup plan invalid"):
            MODULE.validate_fixture_binary(self.root, binary, cleanup)

    def test_cleanup_cannot_hide_missing_execution_source_input(self):
        self.retire_fixture_output()
        (self.root / "runner.py").unlink()
        with self.assertRaises(MODULE.PhaseClosureError):
            self.validate()

    def test_recreated_changed_binary_cannot_use_old_cleanup(self):
        binary, cleanup = self.retire_fixture_output()
        self.write(binary["path"], "different binary")
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "binary changed"):
            MODULE.validate_fixture_binary(self.root, binary, cleanup)

    def test_cleanup_evidence_path_escape_is_rejected(self):
        binary, cleanup = self.retire_fixture_output()
        cleanup["execution"]["path"] = "../outside.json"
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "linkage changed"):
            MODULE.validate_fixture_binary(self.root, binary, cleanup)

    def test_current_compiled_phase_promotes(self):
        self.assertEqual(self.validate(), 1)

    def test_empty_inventory_cannot_fake_complete(self):
        inventory = self.detail["phaseProgress"][0]["decisionInventory"]
        inventory.update(status="pending", decisions=[], requiredDecisionIds=[])
        self.rejects("no reviewed decision inventory")

    def test_source_drift_rejects_historical_proof(self):
        self.write(self.sources["selfhost"], "new source")
        self.rejects("comparison is stale")

    def test_binary_drift_rejects_historical_proof(self):
        self.write(self.binaries["selfhost"]["path"], "different binary")
        self.rejects("binary changed")

    def test_failed_paired_proof_rejects(self):
        self.change_record("records/paired.json", status="failed")
        self.rejects("status/phase mismatch")

    def test_unstable_proof_rejects(self):
        self.change_record("records/paired.json", inputStable=False)
        self.rejects("unstable or canceled")

    def test_focused_proof_cannot_close_phase(self):
        self.change_record("records/paired.json", mode="focused")
        self.rejects("focused proof cannot close")

    def test_incomplete_compiled_cases_reject(self):
        self.change_record("records/paired.json", completed=1)
        self.rejects("incomplete compiled proof")

    def test_unreviewed_source_file_rejects(self):
        self.write("selfhost/syntax/other.slg", "unreviewed source")
        self.rejects("unreviewed selfhost sources")

    def test_source_scope_cannot_be_narrowed(self):
        self.detail["phaseProgress"][0]["decisionInventory"]["sourceScopes"]["managed"] = [self.sources["managed"]]
        self.rejects("scope cannot be narrowed")

    def test_missing_diagnostic_decision_rejects(self):
        del self.detail["phaseProgress"][0]["decisionInventory"]["decisions"][0]["diagnostics"]
        self.rejects("missing decision comparison: diagnostics")

    def test_missing_required_decision_rejects(self):
        self.detail["phaseProgress"][0]["decisionInventory"]["requiredDecisionIds"].append("missing")
        self.rejects("required decision inventory differs")

    def test_build_source_linkage_rejects(self):
        self.change_record("records/selfhost-build.json", sourceHashesEnd={})
        self.rejects("not built from current phase sources")

    def test_tested_binary_must_be_build_output(self):
        self.change_record("records/selfhost-build.json", binary={"path": "wrong.bin", "sha256": "0" * 64})
        self.rejects("build output and tested compiler differ")

    def test_proof_source_linkage_rejects(self):
        self.change_record("records/paired.json", sourceHashesEnd={})
        self.rejects("does not cover current sources")

    def test_proof_record_linkage_rejects(self):
        self.change_record("records/paired.json", sourceComparisonRecord={"path": "records/comparison.json", "sha256": "0" * 64})
        self.rejects("record linkage mismatch")

    def test_lowercase_digest_metadata_preserves_phase_proof(self):
        def lowercase(value, field=""):
            if isinstance(value, dict):
                if field.endswith(("Hashes", "HashesStart", "HashesEnd")):
                    return {key: item.lower() for key, item in value.items()}
                return {key: lowercase(item, key) for key, item in value.items()}
            if isinstance(value, list):
                return [lowercase(item) for item in value]
            if (field == "sha256" or field.endswith("Sha256")) and isinstance(value, str):
                return value.lower()
            return value

        paired = json.loads((self.root / "records/paired.json").read_text())
        for case in paired["cases"]:
            for stages in case["outcomes"].values():
                for ref in stages.values():
                    outcome = json.loads((self.root / ref["path"]).read_text())
                    self.write_record(ref["path"], lowercase(outcome))
        self.refresh_execution_links()
        paired = json.loads((self.root / "records/paired.json").read_text())
        self.write_record("records/paired.json", lowercase(paired))
        self.assertEqual(self.validate(), 1)

    def test_digest_normalization_preserves_oracle_text_and_paths(self):
        digest = "ab" * 32
        value = {"sha256": digest, "stdout": digest, "path": digest,
                 "inputHashesStart": {"source": digest}}
        self.assertEqual(MODULE.normalize_phase_digest_fields(value),
                         {"sha256": digest.upper(), "stdout": digest, "path": digest,
                          "inputHashesStart": {"source": digest.upper()}})

    def test_partial_inventory_does_not_promote(self):
        self.detail["phaseProgress"][0]["status"] = "partial"
        self.detail["phaseProgress"][0]["decisionInventory"]["status"] = "pending"
        self.phases[0]["aligned"] = "partial-behavior"
        self.detail["phaseClosure"].update(completed=0, status="all-partial")
        self.assertEqual(self.validate(), 0)

    def test_repository_declared_phase_closure_is_reproducible(self):
        detail = MODULE.read("scripts/contracts/structural-parity-detail.json")
        phases = MODULE.read(detail["phaseSource"])["phaseMapping"]
        self.assertEqual(MODULE.validate_phase_closure(detail, phases, MODULE.ROOT),
                         detail["phaseClosure"]["completed"])

    def test_cannot_drop_unfinished_phases(self):
        self.detail["phaseProgress"] = self.detail["phaseProgress"][:1]
        self.phases = self.phases[:1]
        self.detail["phaseClosure"].update(total=1, status="complete")
        self.rejects("must retain all seven phases")

    def test_contradictory_paired_exit_cannot_promote(self):
        self.change_record("records/paired.json", completed=1, total=1, cases=[], exitCode=1,
                           failureIds=["PAIR_FAILED"], mode="phase-exhaustive")
        self.rejects("execution exit code")

    def test_contradictory_build_exit_cannot_promote(self):
        for side in ("managed", "selfhost"):
            self.change_record("records/" + side + "-build.json", exitCode=1, completed=0,
                               total=1, failureIds=["BUILD_FAILED"])
        self.rejects("execution exit code")

    def test_empty_actual_cases_cannot_promote(self):
        self.change_record("records/paired.json", cases=[])
        self.rejects("case inventory differs")

    def test_failed_actual_case_cannot_promote(self):
        path = "records/paired.json"
        value = json.loads((self.root / path).read_text())
        value["cases"][0]["exitCode"] = 1
        self.write_record(path, value)
        self.rejects("execution exit code")

    def test_orphaned_actual_case_cannot_promote(self):
        path = "records/paired.json"
        value = json.loads((self.root / path).read_text())
        value["cases"][0]["orphanProcessIds"] = [123]
        self.write_record(path, value)
        self.rejects("orphaned execution")

    def test_actual_case_cannot_use_other_binary(self):
        path = "records/paired.json"
        value = json.loads((self.root / path).read_text())
        value["cases"][0]["compilerBinaries"] = {}
        self.write_record(path, value)
        self.rejects("case used another compiler")

    def test_actual_cases_must_cover_decisions(self):
        path = "records/paired.json"
        value = json.loads((self.root / path).read_text())
        value["cases"][0]["decisionIds"] = []
        self.write_record(path, value)
        self.rejects("contracted fixture or decisions")

    def test_failed_build_with_zero_exit_cannot_promote(self):
        self.change_record("records/selfhost-build.json", failureIds=["BUILD_FAILED"])
        self.rejects("failed, canceled, or orphaned")

    def test_incomplete_build_with_zero_exit_cannot_promote(self):
        self.change_record("records/selfhost-build.json", completed=0)
        self.rejects("incomplete compiler build")

    def change_outcome(self, stage, **changes):
        path = "records/positive-header-selfhost-" + stage + ".json"
        self.change_record(path, **changes)
        paired_path = "records/paired.json"
        paired = json.loads((self.root / paired_path).read_text())
        paired["cases"][0]["outcomes"]["selfhost"][stage] = self.link(path)
        self.write_record(paired_path, paired)

    def test_execution_outcome_nonzero_unexpected_exit_rejects(self):
        self.change_outcome("run", exitCode=1)
        self.rejects("execution exit differs")

    def test_execution_outcome_failure_id_rejects(self):
        self.change_outcome("run", failureIds=["RUN_FAILED"])
        self.rejects("execution failed or was canceled")

    def test_execution_outcome_other_executable_rejects(self):
        self.change_outcome("run", executableBinary={"path": "other.exe", "sha256": "0" * 64})
        self.rejects("ran another executable")

    def test_execution_outcome_missing_fixture_linkage_rejects(self):
        self.change_outcome("compile", inputHashesStart={"runner.py": MODULE.file_hash(self.root / "runner.py")},
                            inputHashesEnd={"runner.py": MODULE.file_hash(self.root / "runner.py")})
        self.rejects("lacks runner, contract, or fixture linkage")

    def test_case_execution_record_hash_drift_rejects(self):
        self.change_record("records/positive-header-selfhost-run.json", exitCode=1)
        self.rejects("execution record changed")

    def test_runner_drift_rejects(self):
        self.write("runner.py", "changed runner")
        self.rejects("runner or contract changed")

    def test_boolean_completed_is_not_case_count(self):
        self.change_record("records/paired.json", completed=True, total=1)
        self.rejects("incomplete compiled proof")

    def test_wrong_behavior_with_valid_record_hash_rejects(self):
        self.change_outcome("run", actualStdout="wrong behavior", expectedStdout="correct behavior")
        self.rejects("behavior or diagnostic differs")

    def test_wrong_diagnostic_with_valid_record_hash_rejects(self):
        self.change_outcome("compile", actualStderr="wrong diagnostic", expectedStderr="correct diagnostic")
        self.rejects("behavior or diagnostic differs")

    def test_changed_expectation_cannot_override_execution_contract(self):
        self.change_outcome("compile", exitCode=1, expectedExitCode=1)
        self.rejects("expected exit differs from execution contract")

    def test_actual_case_id_must_be_contracted(self):
        path = "records/paired.json"
        value = json.loads((self.root / path).read_text())
        value["cases"][0]["id"] = "uncontracted-case"
        self.write_record(path, value)
        self.rejects("IDs differ from execution contract")

    def test_generator_manifest_input_cannot_be_omitted(self):
        self.detail["phaseProgress"][0]["decisionInventory"]["sharedDependencies"].remove(MODULE.PARSING_PRODUCERS[0])
        self.rejects("dependency manifest cannot be narrowed")

    def test_generator_source_drift_rejects(self):
        self.write(MODULE.PARSING_PRODUCERS[0], "changed generator implementation")
        self.rejects("current producer and grammar inputs")

    def test_shared_lexer_input_drift_rejects(self):
        self.write("syntax/sollang.lexer", "new lexer contract")
        self.rejects("current producer and grammar inputs")

    def test_derived_managed_parser_drift_rejects(self):
        self.write(list(MODULE.PARSING_DERIVED)[0], "stale generated parser")
        self.rejects("derived output or producer is stale")

    def test_derived_managed_lexer_drift_rejects(self):
        self.write(list(MODULE.PARSING_DERIVED)[1], "stale generated lexer")
        self.rejects("derived output or producer is stale")

    def test_matching_historical_grammar_stamp_is_insufficient(self):
        self.detail["phaseProgress"][0]["decisionInventory"]["generationRecord"] = None
        self.rejects("missing proof record")

    def test_producer_stamp_must_cover_current_sources(self):
        self.change_record("records/generation.json", producerHashes={})
        self.rejects("producer stamp differs")

    def test_reproduction_must_match_actual_generated_file(self):
        self.write("reproduced/0.generated", "different reproduced parser")
        self.rejects("lacks current producer reproduction")

    def test_comparison_must_track_shared_dependency_hashes(self):
        self.change_record("records/comparison.json", sharedDependencyHashes={})
        self.rejects("comparison shared dependencies differ")

    def test_paired_input_map_cannot_omit_generator_dependency(self):
        path = "records/paired.json"
        value = json.loads((self.root / path).read_text())
        for field in ("sourceHashesStart", "sourceHashesEnd"):
            del value[field]["src/Sollang.Compiler.Generators/Sollang.Compiler.Generators.csproj"]
        self.write_record(path, value)
        self.rejects("does not cover current sources")

    def test_build_input_map_cannot_omit_shared_lexer(self):
        path = "records/selfhost-build.json"
        value = json.loads((self.root / path).read_text())
        for field in ("sourceHashesStart", "sourceHashesEnd"):
            del value[field]["syntax/sollang.lexer"]
        self.write_record(path, value)
        self.rejects("not built from current phase sources")

    def test_failed_generation_execution_cannot_promote(self):
        path = "records/generation.json"
        value = json.loads((self.root / path).read_text())
        value["outputs"][0]["execution"]["exitCode"] = 1
        self.write_record(path, value)
        self.rejects("execution exit code")

    def test_stale_generated_grammar_stamp_rejects_even_with_reproduction(self):
        path = "records/generation.json"
        value = json.loads((self.root / path).read_text())
        derived = "syntax/generated/sollang_grammar.slg"
        self.write(derived, "# Source SHA-256: " + "0" * 64 + "\n")
        self.write("reproduced/2.generated", (self.root / derived).read_text())
        output = value["outputs"][2]
        output["sha256"] = MODULE.file_hash(self.root / derived)
        output["reproducedFile"] = self.link("reproduced/2.generated")
        output["execution"]["producedFile"] = output["reproducedFile"]
        self.write_record(path, value)
        self.rejects("grammar input stamp is stale")

    def test_reproduction_cannot_be_an_alias_of_original_output(self):
        import os
        path = self.root / "reproduced/0.generated"
        path.unlink()
        os.link(self.root / list(MODULE.PARSING_DERIVED)[0], path)
        self.rejects("lacks current producer reproduction")


class OwnershipSourceScopeTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).resolve().parent.parent
        self.detail = MODULE.read("scripts/contracts/structural-parity-detail.json")
        self.row = next(row for row in self.detail["phaseProgress"] if row["phase"] == "ownership")
        self.phases = MODULE.read(self.detail["phaseSource"])["phaseMapping"]

    def test_actual_partial_field_emitter_decision_is_in_authoritative_scope(self):
        inventory = self.row["decisionInventory"]
        self.assertEqual(inventory["sourceScopes"], MODULE.PHASE_SCOPES["ownership"])
        decision = next(item for item in inventory["decisions"]
                        if item["id"] == "ownership.partial-field-literal-transfer-sibling")
        sources = set()
        for scope in inventory["sourceScopes"]["selfhost"]:
            path = self.root / scope
            sources.update([scope] if path.is_file() else
                           (item.relative_to(self.root).as_posix() for item in path.rglob("*.slg")))
        MODULE.validate_decision_source_scope(decision["selfhostSources"], sources)
        self.assertTrue((self.root / decision["selfhostSources"][0]).is_file())
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "outside scope"):
            MODULE.validate_decision_source_scope(["selfhost/llvm/text/platform_io.slg"], sources)

    def test_scope_addition_does_not_promote_partial_phases(self):
        self.assertEqual(self.row["status"], "partial")
        # Isolate this ownership rejection from already qualified phases. The
        # repository's actual complete phases are checked by the dedicated test.
        for row, phase in zip(self.detail["phaseProgress"], self.phases):
            row["status"] = "partial"
            phase["aligned"] = "partial-behavior"
        self.detail["phaseClosure"].update(completed=0, status="all-partial")
        self.assertEqual(MODULE.validate_phase_closure(self.detail, self.phases, self.root), 0)
        self.row["status"] = "complete"
        next(row for row in self.phases if row["phase"] == "ownership")["aligned"] = "complete"
        self.row["decisionInventory"]["managedFirstRecord"] = {"status": "passed", "completed": 1, "total": 1}
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "no reviewed decision inventory"):
            MODULE.validate_phase_closure(self.detail, self.phases, self.root)


class GrammarSourceScopeTests(unittest.TestCase):
    def test_real_grammar_build_sources_use_parsing_admission(self):
        root = Path(__file__).resolve().parent.parent
        detail = MODULE.read("scripts/contracts/structural-parity-detail.json")
        row = next(row for row in detail["phaseProgress"] if row["phase"] == "parsing")
        self.assertEqual(row["decisionInventory"]["sourceScopes"], MODULE.PHASE_SCOPES["parsing"])
        for side, source in (("managed", "src/Sollang.Compiler/Cli/GrammarCompiler.cs"),
                             ("selfhost", "selfhost/cli_grammar.slg")):
            sources = set()
            for scope in row["decisionInventory"]["sourceScopes"][side]:
                path = root / scope
                extension = ".cs" if side == "managed" else ".slg"
                sources.update([scope] if path.is_file() else
                               (item.relative_to(root).as_posix() for item in path.rglob("*" + extension)))
            self.assertTrue((root / source).is_file())
            MODULE.validate_decision_source_scope([source], sources)
            with self.assertRaisesRegex(MODULE.PhaseClosureError, "outside scope"):
                MODULE.validate_decision_source_scope(["selfhost/llvm/text/platform_io.slg"], sources)
        phases = MODULE.read(detail["phaseSource"])["phaseMapping"]
        # This source-scope control need not replay the operational evidence;
        # the repository closure test separately checks every complete phase.
        row["status"] = "complete"
        phases[0]["aligned"] = "complete"
        # This control is about rejecting an unreviewed inventory, independent
        # of the current project's legitimate review progress.
        row["decisionInventory"]["status"] = "pending"
        row["decisionInventory"]["managedFirstRecord"] = {"status": "passed"}
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "no reviewed decision inventory"):
            MODULE.validate_phase_closure(detail, phases, root)


class ImplementationUnitCountTests(unittest.TestCase):
    def test_active_task_changes_do_not_change_durable_counts(self):
        progress = {"completedUnits": [{"id": "original497", "status": "complete"}],
                    "queuedUnits": [{"id": "next-unit", "status": "pending"}]}
        for task in (None, {"id": "original497", "status": "complete"},
                     {"id": "oracle-review", "status": "pending"}):
            progress["currentWork"] = task
            self.assertEqual(MODULE.known_implementation_unit_counts(progress), (1, 2))

    def test_duplicate_identity_across_completed_and_queue_is_rejected(self):
        progress = {"completedUnits": [{"id": "same", "status": "complete"}],
                    "queuedUnits": [{"id": "same", "status": "pending"}]}
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "counted twice"):
            MODULE.known_implementation_unit_counts(progress)

    def test_pending_unit_cannot_be_counted_as_complete(self):
        progress = {"completedUnits": [{"id": "pending", "status": "pending"}],
                    "queuedUnits": []}
        with self.assertRaisesRegex(MODULE.PhaseClosureError, "is incomplete"):
            MODULE.known_implementation_unit_counts(progress)


class PhaseArtifactPathTests(unittest.TestCase):
    def test_owned_external_binary_and_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            root = base / 'repo'
            root.mkdir()
            binary = base / 'local' / 'Sollang' / 'verification' / 'compiler.exe'
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b'verified compiler')
            with patch.dict(os.environ, {'LOCALAPPDATA': str(base / 'local')}):
                if os.name != 'nt':
                    self.skipTest('Windows external artifact root')
                reference = {'path': str(binary), 'sha256': MODULE.file_hash(binary)}
                MODULE.validate_fixture_binary(root, reference)
                binary.write_bytes(b'changed')
                with self.assertRaisesRegex(MODULE.PhaseClosureError, 'binary changed'):
                    MODULE.validate_fixture_binary(root, reference)
                for path in (base / 'local' / 'Sollang-other' / 'compiler.exe',
                             base / 'local' / 'Sollang' / '..' / 'escaped.exe'):
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(b'outside')
                    with self.assertRaises(MODULE.PhaseClosureError):
                        MODULE.validate_fixture_binary(root, {'path': str(path), 'sha256': MODULE.file_hash(path)})


if __name__ == "__main__":
    unittest.main()
