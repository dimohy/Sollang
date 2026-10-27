"""Run one declared, fixed-input compiler-source emission after focused proof.

This reuses the supervised execution and artifact guards. It builds a bounded
library harness, never links a new general compiler product, and gives no Stage
credit. Witness groups establish only the coverage declared in the plan.
"""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

from completed_artifact_plan import assert_build_space, initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

ROOT = Path(__file__).resolve().parent.parent
BUDGETS = {"producerBuildSeconds": 180, "fullEmissionSeconds": 3600,
           "assemblySeconds": 180, "closureSeconds": 180}


def require(condition, failure_id):
    if not condition:
        raise ValueError(failure_id)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def owned(name, *, file=True):
    path = (ROOT / name).resolve()
    require(path.is_relative_to(ROOT) and (not file or path.is_file()),
            "FULL_SOURCE_INVALID_OWNED_PATH:" + str(name))
    return path


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def passed(record):
    return (record.get("status") == "passed" and record.get("inputsStable") is True
            and record.get("processesStopped") is True
            and type(record.get("completed")) is int
            and type(record.get("total")) is int
            and record["completed"] == record.get("total"))


def validate_inputs(pins):
    require(isinstance(pins, dict) and bool(pins), "FULL_SOURCE_INPUT_PINS_MISSING")
    for name, digest in pins.items():
        path = Path(name)
        require(isinstance(digest, str) and re.fullmatch(r"[a-fA-F0-9]{64}", digest)
                and path.is_file() and sha(path) == digest.upper(),
                "FULL_SOURCE_INPUT_CHANGED:" + name)


def preflight(plan_path, focused_override=None):
    plan_path = owned(plan_path)
    plan = read(plan_path)
    require(plan.get("schemaVersion") == 1 and plan.get("budgets") == BUDGETS,
            "FULL_SOURCE_PLAN_OR_BUDGET_CHANGED")
    focused_path = owned(focused_override or plan["focusedQualification"])
    focused = read(focused_path)
    require(passed(focused), "FULL_SOURCE_FOCUSED_PROOF_INCOMPLETE")
    cases = focused.get("cases", [])
    ids = [case["id"] for case in cases]
    require(len(ids) == len(set(ids)) == focused["completed"]
            and all(case.get("status") == "passed" for case in cases),
            "FULL_SOURCE_FOCUSED_CASE_INVENTORY_INVALID")
    groups = plan.get("qualificationWitnesses")
    require(isinstance(groups, dict) and bool(groups)
            and all(isinstance(group, list) and bool(group)
                    and all(isinstance(case, str) and case for case in group)
                    for group in groups.values()), "FULL_SOURCE_WITNESSES_MISSING")
    missing = sorted({case for group in groups.values() for case in group} - set(ids))
    require(not missing, "FULL_SOURCE_FOCUSED_WITNESS_MISSING:" + ",".join(missing))
    comparison = plan["sourceComparisonRecord"]
    comparison_path = owned(comparison["path"])
    require(sha(comparison_path) == comparison["sha256"]
            and read(comparison_path).get("status") == "compared-before-slg-edit",
            "FULL_SOURCE_SOURCE_COMPARISON_CHANGED")
    semantic_path = owned(plan["semanticQualification"])
    semantic = read(semantic_path)
    require(passed(semantic) and semantic["completed"] == 4
            and semantic.get("codegenInvoked") is False,
            "FULL_SOURCE_SEMANTIC_PROOF_INCOMPLETE")
    validate_inputs(focused.get("inputHashes"))
    validate_inputs(semantic.get("inputHashes"))
    providers = plan["providers"]
    compiler_sources = plan["compilerSources"]
    stdlib_sources = plan["standardLibrarySources"]
    require(len(providers) == len(set(providers)) == 150
            and len(compiler_sources) == len(set(compiler_sources)) == 151
            and compiler_sources[1:] == providers
            and len(stdlib_sources) == len(set(stdlib_sources)) == 144,
            "FULL_SOURCE_INVENTORY_CHANGED")
    require(focused["reusableCheckedProducer"]["additionalSources"] == providers
            and all(case.get("observedSourceOrder", [])[:144] == stdlib_sources
                    for case in cases), "FULL_SOURCE_FOCUSED_PROVIDER_OR_AUTHORITY_CHANGED")
    source_paths = set([plan["producer"], *compiler_sources, *stdlib_sources, *providers])
    require(set(plan["sourceHashes"]) == source_paths, "FULL_SOURCE_SOURCE_PIN_INVENTORY_CHANGED")
    for name, digest in plan["sourceHashes"].items():
        require(sha(owned(name)) == digest, "FULL_SOURCE_SOURCE_CHANGED:" + name)
    managed = owned(plan["managedCompiler"])
    require(sha(managed.with_suffix(".dll")) == plan["expectedManagedDllSha256"],
            "FULL_SOURCE_MANAGED_COMPILER_CHANGED")
    command = list(focused["processes"][0]["command"])
    require(command[:2] == [str(managed), "build"]
            and command[3:command.index("-o")] == [str(owned(name)) for name in providers],
            "FULL_SOURCE_BUILD_COMMAND_CHANGED")
    inputs = list(dict.fromkeys([
        Path(__file__), plan_path, focused_path, semantic_path, comparison_path,
        ROOT / "scripts/verification_execution.py", ROOT / "scripts/verification_contract_lease.py",
        ROOT / "scripts/completed_artifact_plan.py", ROOT / "scripts/Invoke-CompletedArtifactCleanup.ps1",
        ROOT / "scripts/ArtifactLifecycle.ps1", ROOT / "scripts/contracts/artifact-lifecycle.json",
        ROOT / "scripts/verify-llvm-direct-call-closure.ps1",
        ROOT / ".tools/llvm-22.1.8/bin/llvm-as.exe", ROOT / ".tools/llvm-22.1.8/bin/clang.exe",
        *managed_runtime_inputs(managed), *[owned(name) for name in source_paths],
        *map(Path, focused["inputHashes"]), *map(Path, semantic["inputHashes"])]))
    pins = {str(path): sha(path) for path in inputs}
    return plan, command, pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", required=True)
    parser.add_argument("--output")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--focused-proof", help="Check-only negative-control proof override")
    args = parser.parse_args()
    require(args.check or (args.output and not args.focused_proof),
            "FULL_SOURCE_OUTPUT_REQUIRED_OR_EXECUTION_OVERRIDE_FORBIDDEN")
    plan, command, pins = preflight(args.plan, args.focused_proof)
    if args.check:
        print(json.dumps({"status": "passed", "mode": "preflight-only",
                          "buildStarted": False, "witnessGroups": plan["qualificationWitnesses"]}))
        return 0
    output = owned(args.output, file=False)
    require(not output.exists(), "FULL_SOURCE_OUTPUT_ALREADY_EXISTS")
    reusable = [owned(name, file=False) for name in plan["reusableCompilerDirectories"]]
    initialize_output(ROOT, output, reusable_directories=reusable)
    assert_build_space(output)
    output.mkdir()
    record = dict(schemaVersion=1, status="running", completed=0, total=4,
                  inputHashes=pins, cases=[], scope=plan["scope"],
                  qualificationWitnesses=plan["qualificationWitnesses"],
                  generalCompilerProductCreated=False, stageCredit=0,
                  wholeSourceOrRuntimeCredit=0, claimsGoalComplete=False)
    stable = lambda: all(Path(name).is_file() and sha(name) == digest for name, digest in pins.items())
    llvm = ROOT / ".tools/llvm-22.1.8/bin"
    with VerificationContractLease(list(map(Path, pins))):
        execution = VerificationExecution(ROOT, output, record, stable, sha)
        error = None
        try:
            command[2] = str(owned(plan["producer"]))
            command[command.index("-o") + 1] = str(output / "probe.exe")
            steps = [
                ("fixed-input-producer-build", command, "producer-build", BUDGETS["producerBuildSeconds"]),
                ("fixed-full-slg-emission", [str(output / "probe.exe")], "emission", BUDGETS["fullEmissionSeconds"]),
                ("llvm-assembly", [str(llvm / "llvm-as.exe"), str(output / "emission.stdout"),
                                   "-o", str(output / "compiler.bc")], "assembly", BUDGETS["assemblySeconds"]),
                ("llvm-call-closure", ["pwsh", "-NoProfile", "-File",
                                      str(ROOT / "scripts/verify-llvm-direct-call-closure.ps1"),
                                      "-LlvmPath", str(output / "emission.stdout")], "closure", BUDGETS["closureSeconds"])]
            for name, argv, prefix, budget in steps:
                result = execution.run(argv, output / prefix, timeout=budget)
                require(result.returncode == 0 and not result.stderr.strip(),
                        "FULL_SOURCE_STAGE_FAILED:" + name + ":" + result.stderr[:1600])
                record["cases"].append({"id": name, "status": "passed"})
                record["completed"] += 1
                execution.save()
            record["status"] = "passed"
        except BaseException as failure:
            error = failure
        finally:
            record["generatedOutputHashes"] = {str(path): sha(path) for path in
                [output / "probe.exe", output / "probe.exe.ll", output / "compiler.bc",
                 output / "emission.stdout"] if path.is_file()}
            execution.finalize(error, cleanup=False)
    print(json.dumps({key: record.get(key) for key in
                      ["status", "completed", "total", "failure", "inputsStable", "processesStopped"]}))
    return 0 if record["status"] == "passed" else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError as error:
        print(json.dumps({"status": "failed", "failureId": str(error), "buildStarted": False}), file=sys.stderr)
        sys.exit(1)
