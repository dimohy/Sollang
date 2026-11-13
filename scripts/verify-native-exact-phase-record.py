"""Read existing phase evidence without invoking its immutable record writer.

Context JSON must come from Get-NativeExactPhaseContext on stdin. The existing
phase producer, contracts, process records and cleanup validator stay unchanged.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

spec = importlib.util.spec_from_file_location(
    "phase_authority", Path(__file__).with_name("verify-structural-parity-detail.py"))
authority = importlib.util.module_from_spec(spec)
spec.loader.exec_module(authority)
ROOT = Path(__file__).resolve().parent.parent


def require(condition, code):
    if not condition:
        raise ValueError("READONLY_PHASE_" + code)


def read(path):
    return authority.normalize_phase_digest_fields(json.loads(path.read_text(encoding="utf-8-sig")))


def local(name):
    return authority.phase_local_file(ROOT, name)


def reference_path(reference):
    path = local(reference["path"])
    require(authority.file_hash(path) == reference["sha256"], "REFERENCE_CHANGED")
    return path


def linked(reference):
    return read(reference_path(reference))


def pins(values, binary=None, cleanup=None):
    require(isinstance(values, dict) and bool(values), "INPUTS_MISSING")
    for name, expected in values.items():
        if binary and (ROOT / name).resolve() == (ROOT / binary["path"]).resolve():
            require(expected == binary["sha256"], "EXECUTABLE_CHANGED")
            authority.validate_fixture_binary(ROOT, binary, cleanup)
        else:
            require(authority.file_hash(local(name)) == expected, "INPUT_CHANGED: " + name)


def compiler_runtime_pins(values, binary):
    binary_path = reference_path(binary)
    if binary_path.suffix.lower() == ".dll":
        pins(values)
        require(any(local(name) == binary_path for name in values), "MANAGED_RUNTIME_MAIN_MISSING")
    else:
        # The producer records .NET sidecars only for managed products. Native
        # products have an empty sidecar map; their executable still needs its
        # own current content hash, checked above.
        require(binary_path.suffix.lower() == ".exe" and values == {}, "NATIVE_RUNTIME_SCOPE")


def oracle(expected, outcome, process):
    """Only the static contract authorizes nonzero compiler/grammar exits."""
    exit_code = expected["exitCode"]
    require(type(exit_code) is int and type(outcome.get("exitCode")) is int
            and outcome["exitCode"] == exit_code
            and type(outcome.get("expectedExitCode")) is int
            and outcome["expectedExitCode"] == exit_code, "DECLARED_EXIT")
    require(type(process.get("exit")) is int and process["exit"] == exit_code
            and type(process.get("pid")) is int and process["pid"] > 0
            and process.get("finishedAtUtc") and process.get("processesStopped") is True
            and process.get("failure") is None, "PROCESS_UNCONFIRMED")
    require(outcome.get("actualStderr") == expected["stderr"], "DIAGNOSTIC")
    if "stdoutPolicy" not in expected:
        require(outcome.get("actualStdout") == expected["stdout"], "STDOUT")


def verify(context, record_path):
    context = authority.normalize_phase_digest_fields(context)
    contract = linked(context["ContractReference"])
    require(contract == context["Contract"], "CONTEXT_CONTRACT")
    side = context["CompilerSide"]
    require(side in ("managed", "selfhost"), "SIDE")
    proof = read(record_path)
    authority.phase_terminal_success(proof)
    count = len(contract["cases"])
    require(proof.get("status") == "passed" and proof.get("mode") == "phase-exhaustive"
            and proof.get("phase") == contract["phase"] and proof.get("inputStable") is True
            and proof.get("completed") == proof.get("total") == count
            and len(proof.get("cases", [])) == count, "INCOMPLETE")
    require(proof["decisionIds"] == contract["decisionIds"], "DECISION_SCOPE")
    require(proof["executionInputs"] == {"runner": context["RunnerReference"],
                                         "contract": context["ContractReference"]}, "EXECUTION_INPUTS")
    reference_path(context["RunnerReference"])
    require(proof["sourceHashesStart"] == proof["sourceHashesEnd"]
            == context["SideSourceHashes"], "SOURCE_SCOPE")
    require(proof["wholeFixtureInputHashesStart"] == proof["wholeFixtureInputHashesEnd"]
            == context["InputHashes"], "INPUT_SCOPE")
    require(proof["compilerRuntimeHashesStart"] == proof["compilerRuntimeHashesEnd"]
            == context["CompilerRuntimeHashes"], "RUNTIME_SCOPE")
    pins(context["InputHashes"])
    compiler_runtime_pins(context["CompilerRuntimeHashes"], context["CompilerBinary"])
    binaries = {side: contract["compilerBinaries"][side]}
    require(proof["compilerBinaries"] == binaries, "COMPILER")
    if contract["phase"] == "parsing":
        require(proof["generationRecord"] == contract["generationRecord"], "GENERATION")
        linked(contract["generationRecord"])
    batch_ref = proof["wholeFixtureBatch"]
    require(local(batch_ref["path"]) == local(contract["batchReports"][side]), "BATCH_LINK")
    batch = linked(batch_ref)
    plan = contract["wholeFixturePlan"]
    require(len(plan) == len(set(plan)) == 405 and batch["state"] == "passed"
            and batch["completed"] == batch["passed"] == batch["total"] == 405
            and batch["failed"] == batch["missing"] == 0
            and batch["compilerSha256"] == binaries[side]["sha256"]
            and batch["phaseFixturePlan"] == plan
            and sorted(r["Fixture"] for r in batch["results"]) == sorted(plan)
            and all(r["Success"] is True for r in batch["results"]), "WHOLE_BATCH")
    for expected_case, case in zip(contract["cases"], proof["cases"]):
        authority.phase_terminal_success(case)
        require(case["id"] == expected_case["id"] and case["fixture"] == expected_case["fixture"]
                and case["decisionIds"] == expected_case["decisionIds"]
                and case["status"] == "passed" and case["compilerBinaries"] == binaries
                and set(case["outcomes"]) == {side}, "CASE_SCOPE")
        require(authority.file_hash(local(case["fixture"]["path"])) == case["fixture"]["sha256"], "FIXTURE")
        stages = case["outcomes"][side]
        require(set(stages) == set(expected_case["expectedStages"]), "STAGE_SCOPE")
        compiled = None
        for stage in ("compile", "run", "grammar"):
            if stage not in stages:
                continue
            outcome = linked(stages[stage])
            expected = authority.expected_stage_outcome(expected_case["expectedStages"], stage, side)
            require(outcome["status"] == "passed" and outcome["compilerSide"] == side
                    and outcome["stage"] == stage and outcome["failureIds"] == []
                    and outcome["orphanProcessIds"] == [] and outcome["canceled"] is False
                    and outcome["processesStopped"] is True
                    and outcome["compilerBinary"] == context["CompilerBinary"], "OUTCOME_IDENTITY")
            process = linked(outcome["processRecord"])
            oracle(expected, outcome, process)
            for stream in ("stdout", "stderr"):
                ref = outcome[stream + "Record"]
                path = local(ref["path"])
                require(authority.file_hash(path) == ref["sha256"]
                        and Path(process[stream + "Path"]).resolve() == path
                        and path.read_bytes().decode("utf-8") == outcome["actual" + stream.title()], "RAW_STREAM")
            if "stdoutPolicy" in expected:
                product = local(outcome["outputBinary"]["path"])
                result = authority.validate_build_stdout(local(outcome["stdoutRecord"]["path"]).read_bytes(), product, side)
                require(result["semanticStdout"] == expected["stdout"], "BUILD_STDOUT")
            inputs = outcome["inputHashesStart"]
            require(inputs == outcome["inputHashesEnd"]
                    and all(inputs.get(k) == v for k, v in context["InputHashes"].items())
                    and outcome["compilerRuntimeHashesStart"] == outcome["compilerRuntimeHashesEnd"]
                    == context["CompilerRuntimeHashes"], "OUTCOME_INPUTS")
            pins(inputs, compiled if stage == "run" else None, outcome.get("artifactCleanupEvidence"))
            if stage == "compile":
                compiler = str(local(binaries[side]["path"]))
                offset = 1 if compiler.lower().endswith(".dll") else 0
                require(process["command"][offset] == compiler
                        and str(local(case["fixture"]["path"])) in process["command"], "COMPILE_COMMAND")
                if expected["exitCode"] == 0:
                    compiled = outcome["outputBinary"]
                    authority.validate_fixture_binary(ROOT, compiled, outcome.get("artifactCleanupEvidence"))
                    require(process["command"].count("-o") == 1
                            and Path(process["command"][process["command"].index("-o") + 1]).resolve()
                            == (ROOT / compiled["path"]).resolve(), "COMPILE_PRODUCT")
                else:
                    require("outputBinary" not in outcome and "executableBinary" not in outcome, "NEGATIVE_PRODUCT")
            elif stage == "run":
                require(compiled and outcome["executableBinary"] == compiled
                        and process["command"][0] == str((ROOT / compiled["path"]).resolve()), "RUN_COMMAND")
            else:
                grammar = expected_case["grammarCommand"]
                offset = 2 if binaries[side]["path"].lower().endswith(".dll") else 1
                cmd = process["command"]
                require(len(cmd) == offset + 6 and cmd[offset:offset + 2] == ["grammar", "build"]
                        and Path(cmd[offset - 1]).resolve() == local(binaries[side]["path"])
                        and Path(cmd[offset + 2]).resolve() == local(grammar["lexer"]["path"])
                        and Path(cmd[offset + 3]).resolve() == local(grammar["grammar"]["path"])
                        and cmd[offset + 4] == "-o" and not Path(cmd[-1]).exists()
                        and Path(cmd[-1]).resolve() == Path(str(local(stages[stage]["path"]))
                            [:-len(".grammar.json")] + ".generated.slg").resolve()
                        and "outputBinary" not in outcome and "executableBinary" not in outcome, "GRAMMAR_COMMAND")
    return {"status": "verified-read-only", "side": side, "completed": count, "total": count,
            "wholeFixtures": 405, "record": str(record_path), "recordSha256": authority.file_hash(record_path)}


def verify_pair(context, native_path, paired_path):
    context = authority.normalize_phase_digest_fields(context)
    require(context["CompilerSide"] == "selfhost", "PAIRED_SIDE")
    native, paired = read(native_path), read(paired_path)
    comparison = linked(context["SourceComparisonReference"])
    managed = linked(comparison["managedFirstRecord"])
    authority.phase_terminal_success(managed)
    authority.phase_terminal_success(paired)
    pins(managed["wholeFixtureInputHashesStart"])
    pins(managed["compilerRuntimeHashesStart"])
    require(managed["wholeFixtureInputHashesStart"] == managed["wholeFixtureInputHashesEnd"]
            and managed["compilerRuntimeHashesStart"] == managed["compilerRuntimeHashesEnd"], "MANAGED_STABILITY")
    contract = context["Contract"]
    count = len(contract["cases"])
    require(paired["status"] == "passed" and paired["mode"] == "phase-exhaustive"
            and paired["phase"] == contract["phase"] and paired["inputStable"] is True
            and paired["completed"] == paired["total"] == managed["completed"] == managed["total"] == count
            and len(paired["cases"]) == len(managed["cases"]) == count
            and paired["compilerBinaries"] == contract["compilerBinaries"]
            and paired["sourceHashesStart"] == paired["sourceHashesEnd"] == context["SourceHashes"]
            and paired["sourceComparisonRecord"] == context["SourceComparisonReference"]
            and paired["wholeFixtureBatches"] == {"managed": managed["wholeFixtureBatch"],
                                                  "selfhost": native["wholeFixtureBatch"]}, "PAIRED_SCOPE")
    for expected, mcase, ncase, pcase in zip(contract["cases"], managed["cases"], native["cases"], paired["cases"]):
        authority.phase_terminal_success(pcase)
        require(pcase["id"] == mcase["id"] == ncase["id"] == expected["id"]
                and pcase["fixture"] == expected["fixture"] and pcase["decisionIds"] == expected["decisionIds"]
                and pcase["compilerBinaries"] == contract["compilerBinaries"]
                and pcase["outcomes"] == {"managed": mcase["outcomes"]["managed"],
                                          "selfhost": ncase["outcomes"]["selfhost"]}, "PAIRED_COMPOSITION")
    return {"pairedCompleted": count, "pairedTotal": count,
            "pairedRecord": str(paired_path), "pairedRecordSha256": authority.file_hash(paired_path)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", required=True, type=Path)
    parser.add_argument("--paired-record", type=Path)
    args = parser.parse_args()
    context = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
    before = authority.file_hash(args.record)
    result = verify(context, args.record.resolve())
    if args.paired_record:
        paired_before = authority.file_hash(args.paired_record)
        result.update(verify_pair(context, args.record.resolve(), args.paired_record.resolve()))
        require(authority.file_hash(args.paired_record) == paired_before, "PAIRED_RECORD_MODIFIED")
    require(authority.file_hash(args.record) == before, "RECORD_MODIFIED")
    print(json.dumps(result))
