"""Project a verified prefix and resume only the unfinished direct focused cases.

The original canceled execution is immutable. Its missing exits never become
successes. New cases still run through verify-c385-preir-call-numeric.py.
"""
import argparse
import copy
import json
from pathlib import Path

import completed_artifact_plan as lifecycle
from verification_focused_proof import generic_proof, read, sha
from verification_json_records import write_json_atomic

ROOT = Path(__file__).resolve().parent.parent


def require(condition, code):
    if not condition:
        raise ValueError(code)


def stable(record):
    pins = record.get("inputHashes", {})
    require(bool(pins), "RESUME_INPUT_PINS_MISSING")
    for name, expected in pins.items():
        path = Path(name)
        require(path.is_file() and sha(path) == expected.upper(),
                "RESUME_INPUT_CHANGED: " + name)


def prefix_rows(record, contract):
    """Observed expected fields cannot override a declared static exit."""
    cases, rows = contract["cases"], record["cases"]
    require(record["total"] == len(cases), "RESUME_ORIGINAL_TOTAL_CHANGED")
    require([r["id"] for r in rows] == [c["id"] for c in cases[:len(rows)]],
            "RESUME_ORIGINAL_CASE_ORDER_CHANGED")
    require(not contract.get("reusableCheckedProducer")
            and not any(c.get("emittedLlvm") for c in cases),
            "RESUME_REQUIRES_DIRECT_CASES")
    selected, unfinished = [], False
    for row, case in zip(rows, cases):
        passed = row.get("status") == "passed" and row.get("passed") is True
        require(not (passed and unfinished), "RESUME_NONCONTIGUOUS_PASSED_PREFIX")
        if not passed:
            unfinished = True
            continue
        require(row.get("buildExit") == case["exit"], "RESUME_DECLARED_BUILD_EXIT_MISMATCH")
        require(row.get("buildStderr") == case["stderr"], "RESUME_DIAGNOSTIC_CHANGED")
        budget, elapsed = row.get("wholeCaseBudgetSeconds"), row.get("wholeCaseElapsedSeconds")
        require(isinstance(budget, (int, float)) and isinstance(elapsed, (int, float))
                and budget > 0 and 0 <= elapsed <= budget, "RESUME_COMPLETED_CASE_BUDGET_UNPROVEN")
        if case["exit"] == 0:
            require(row.get("runExit") == case.get("expectedRuntimeExit", 0)
                    and row.get("runStdout") == case["stdout"]
                    and row.get("runStderr") == case.get("runStderr", ""),
                    "RESUME_RUNTIME_ORACLE_MISMATCH")
        if case.get("requireNoLlvm"):
            require(row.get("rejectedBeforeLlvm") is True
                    and row.get("unexpectedLlvmOutputs") == [], "RESUME_REJECTION_NOT_PROVEN")
        if "expectedAllocations" in case:
            require(row.get("expectedAllocations") == case["expectedAllocations"]
                    and row.get("auditRunExit") == 0, "RESUME_ALLOCATION_AUDIT_MISSING")
        selected.append(copy.deepcopy(row))
    require(record["completed"] == len(selected), "RESUME_PREFIX_COUNT_MISMATCH")
    return selected


def case_processes(record, directory, ids):
    roots = [(directory / name).resolve() for name in ids]
    require(all(p.is_relative_to(directory.resolve()) for p in roots), "RESUME_CASE_PATH_ESCAPE")
    selected = []
    for process in record.get("processes", []):
        matches = False
        for value in process.get("command", []):
            if isinstance(value, str) and Path(value).is_absolute():
                matches |= any(Path(value).resolve().is_relative_to(root) for root in roots)
        if matches:
            require(type(process.get("exit")) is int
                    and process.get("shutdownConfirmed") is True, "RESUME_PREFIX_PROCESS_UNCONFIRMED")
            selected.append(copy.deepcopy(process))
    require(not ids or bool(selected), "RESUME_PREFIX_PROCESS_INVENTORY_MISSING")
    return selected


def union_pins(*maps):
    pins = {}
    for values in maps:
        for name, value in values.items():
            value = value.upper()
            require(name not in pins or pins[name] == value, "RESUME_CONFLICTING_INPUT_PIN: " + name)
            pins[name] = value
    return pins


def validate_output(path):
    path = path.resolve()
    require(path.is_relative_to(ROOT / "artifacts") and not path.exists(), "RESUME_OUTPUT_BOUNDARY")
    return path


def prepare(args):
    result_path, contract_path, managed_path = [p.resolve() for p in
                                               (args.result, args.contract, args.managed_proof)]
    old, contract = read(result_path), read(contract_path)
    require(old.get("status") == "canceled" and old.get("processesStopped") is True
            and old.get("inputsStable") is True, "RESUME_RECOVER_SHUTDOWN_FIRST")
    shutdown = Path(old["cancellationShutdownEvidence"])
    require(read(shutdown)["activeProcessIds"] == [], "RESUME_SHUTDOWN_UNPROVEN")
    stable(old)
    require(old["inputHashes"].get(str(contract_path)) == sha(contract_path), "RESUME_ORIGINAL_CONTRACT_CHANGED")
    birth = read(args.build.resolve() / "result.json")
    require(lifecycle.completed(birth) and lifecycle.current_input_failure(ROOT, birth) is None,
            "RESUME_NATIVE_PRODUCER_CHANGED")
    native = args.build.resolve() / "compiler.exe"
    require(old["inputHashes"].get(str(native)) == sha(native), "RESUME_NATIVE_BINARY_CHANGED")
    prefix = prefix_rows(old, contract)
    count = len(prefix)
    require(count < len(contract["cases"]), "RESUME_ALREADY_ALL_CASES_PASSED")
    managed = generic_proof(managed_path, contract_path, len(contract["cases"]), "managed")
    output = validate_output(args.output)
    output.mkdir(parents=True)
    remaining = copy.deepcopy(contract)
    remaining["cases"] = remaining["cases"][count:]
    remaining_path = output / "remaining-contract.json"
    write_json_atomic(remaining_path, remaining)
    selected_ids = [c["id"] for c in remaining["cases"]]
    managed_projection = copy.deepcopy(managed)
    managed_projection.update(cases=copy.deepcopy(managed["cases"][count:]), completed=len(selected_ids),
                              total=len(selected_ids), generatedOutputHashes={}, newCompilerExecutions=0,
                              scope="Current input-identical CSharp observation projection; no compilation.")
    managed_projection["processes"] = case_processes(managed, managed_path.parent, selected_ids)
    managed_projection["inputHashes"] = union_pins(managed["inputHashes"],
        {str(remaining_path): sha(remaining_path), str(managed_path): sha(managed_path),
         str(Path(__file__).resolve()): sha(Path(__file__).resolve())})
    cpp_path = output / "managed-projection" / "result.json"
    cpp_path.parent.mkdir()
    write_json_atomic(cpp_path, managed_projection)
    generic_proof(cpp_path, remaining_path, len(selected_ids), "managed")
    manifest = dict(schemaVersion=1, originalResult=str(result_path), originalContract=str(contract_path),
                    originalManagedProof=str(managed_path), originalTotal=len(contract["cases"]),
                    verifiedPrefixCount=count, remainingCaseIds=selected_ids,
                    remainingContract=str(remaining_path), managedProjection=str(cpp_path),
                    nativeBuild=str(args.build.resolve()), prefixCases=prefix,
                    prefixProcesses=case_processes(old, result_path.parent, [c["id"] for c in prefix]),
                    inputHashes={str(p): sha(p) for p in
                        [result_path, contract_path, managed_path, shutdown, remaining_path, cpp_path,
                         Path(__file__).resolve()]},
                    unverifiedPriorExecutions=[p for p in old["processes"] if p.get("exit") is None],
                    claimsPhaseComplete=False, claimsGoalComplete=False)
    write_json_atomic(output / "manifest.json", manifest)
    print(json.dumps({"verifiedPrefix": count, "remaining": len(selected_ids),
                      "manifest": str(output / "manifest.json"), "newCompilerExecutions": 0}))


def merge(args):
    manifest_path = args.manifest.resolve()
    manifest = read(manifest_path)
    stable(manifest)
    original_path, contract_path = Path(manifest["originalResult"]), Path(manifest["originalContract"])
    original, contract = read(original_path), read(contract_path)
    stable(original)
    require(prefix_rows(original, contract) == manifest["prefixCases"], "RESUME_PREFIX_CHANGED")
    suffix_path = args.suffix_result.resolve()
    suffix = generic_proof(suffix_path, Path(manifest["remainingContract"]),
                           len(manifest["remainingCaseIds"]), "paired")
    rows = manifest["prefixCases"] + suffix["cases"]
    require([r["id"] for r in rows] == [c["id"] for c in contract["cases"]], "RESUME_WHOLE_CASE_SCOPE_CHANGED")
    output = validate_output(args.output)
    merged = copy.deepcopy(original)
    for key in ("activeProcess", "cancellationReason", "cancellationShutdownEvidence", "failure"):
        merged.pop(key, None)
    merged.update(status="passed", completed=manifest["originalTotal"], total=manifest["originalTotal"],
                  cases=rows, processes=manifest["prefixProcesses"] + suffix["processes"],
                  inputsStable=True, processesStopped=True, generatedOutputHashes={},
                  artifactCleanupMode="plan-only", newCompilerExecutions=0,
                  scope="Whole original cohort from verified pre-interruption prefix and verified resumed suffix.",
                  preservedInterruptedSource=str(original_path), resumeManifest=str(manifest_path),
                  excludedUnverifiedPriorExecutions=manifest["unverifiedPriorExecutions"])
    merged["inputHashes"] = union_pins(original["inputHashes"], suffix["inputHashes"],
        manifest["inputHashes"], {str(manifest_path): sha(manifest_path), str(suffix_path): sha(suffix_path)})
    stable(merged)
    require(lifecycle.completed(merged), "RESUME_MERGED_EXECUTION_AUTHORITY_FAILED")
    output.mkdir(parents=True)
    path = output / "result.json"
    write_json_atomic(path, merged)
    generic_proof(path, contract_path, manifest["originalTotal"], "paired")
    print(json.dumps({"status": "passed", "completed": merged["completed"],
                      "total": merged["total"], "result": str(path)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="operation", required=True)
    prepare_parser = commands.add_parser("prepare")
    for name in ("result", "contract", "managed-proof", "build", "output"):
        prepare_parser.add_argument("--" + name, required=True, type=Path)
    merge_parser = commands.add_parser("merge")
    for name in ("manifest", "suffix-result", "output"):
        merge_parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    (prepare if args.operation == "prepare" else merge)(args)


if __name__ == "__main__":
    main()
