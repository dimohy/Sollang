"""Capture LLVM predicates before cleanup and verify their retained proof chain."""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def require(value, message):
    if not value:
        raise ValueError(message)


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def local(root, name):
    path = (root / name).resolve()
    require(path.is_relative_to(root.resolve()), "LLVM_OBSERVATION_PATH_ESCAPE")
    return path


def contract_cases(root, contract):
    require(contract.get("schemaVersion") == 1 and isinstance(contract.get("fixtures"), list)
            and contract["fixtures"], "LLVM_OBSERVATION_CONTRACT_INVALID")
    cases = {}
    for case in contract["fixtures"]:
        name = case.get("name")
        require(isinstance(name, str) and name and name not in cases,
                "LLVM_OBSERVATION_FIXTURE_INVALID")
        source = local(root, case["source"])
        require(source.is_file() and source.suffix == ".slg", "LLVM_OBSERVATION_SOURCE_MISSING")
        checks = case.get("checks")
        require(isinstance(checks, list) and checks, "LLVM_OBSERVATION_CHECKS_MISSING")
        identifiers = set()
        for check in checks:
            require(set(check) == {"id", "text", "expected"}
                    and isinstance(check["id"], str) and check["id"]
                    and check["id"] not in identifiers
                    and isinstance(check["text"], str) and check["text"]
                    and type(check["expected"]) is bool, "LLVM_OBSERVATION_CHECK_INVALID")
            identifiers.add(check["id"])
        if "runtime" in case:
            runtime = case["runtime"]
            require(isinstance(runtime, dict) and set(runtime) == {"exit", "stdout", "stderr"}
                    and type(runtime["exit"]) is int and -(2**31) <= runtime["exit"] < 2**31
                    and isinstance(runtime["stdout"], str)
                    and isinstance(runtime["stderr"], dict)
                    and set(runtime["stderr"]) == {"managed", "selfhost"}
                    and all(isinstance(value, str) for value in runtime["stderr"].values()),
                    "LLVM_OBSERVATION_RUNTIME_CONTRACT_INVALID")
        cases[name] = case
    return cases


def observe(root, contract_path, fixture, llvm_path, compiler):
    case = contract_cases(root, read(contract_path))[fixture]
    payload = llvm_path.read_bytes()
    text = payload.decode("utf-8-sig")
    checks = [{**check, "contains": check["text"] in text,
               "passed": (check["text"] in text) == check["expected"]}
              for check in case["checks"]]
    return {"schemaVersion": 1, "fixture": fixture,
            "contractPath": str(contract_path.resolve()), "contractSha256": sha(contract_path),
            "sourcePath": str(local(root, case["source"])),
            "sourceSha256": sha(local(root, case["source"])),
            "compilerPath": str(compiler.resolve()), "compilerSha256": sha(compiler),
            "llvmPath": str(llvm_path.resolve()), "llvmSha256": sha(llvm_path),
            "checks": checks, "status": "passed" if all(c["passed"] for c in checks) else "failed"}


def verify_proof(root, contract_path, proof_path):
    cases = contract_cases(root, read(contract_path))
    proof = read(proof_path)
    require(proof.get("status") == "passed" and proof.get("inputsStable") is True
            and proof.get("processesStopped") is True
            and proof.get("completed") == proof.get("total") == len(cases),
            "LLVM_OBSERVATION_PARENT_INCOMPLETE")
    start, end = proof["inputHashesStart"], proof["inputHashesEnd"]
    require(start == end and start.get(str(contract_path.resolve())) == sha(contract_path),
            "LLVM_OBSERVATION_INPUT_DRIFT")
    require(start.get(str(Path(__file__).resolve())) == sha(Path(__file__)),
            "LLVM_OBSERVATION_PRODUCER_NOT_PINNED")
    for name, digest in start.items():
        path = Path(name)
        require(path.is_file() and sha(path) == digest, "LLVM_OBSERVATION_INPUT_DRIFT: " + name)
    runs = [run for run in proof["runs"] if run["compiler"] == "selfhost"]
    require(len(proof["runs"]) == 2 * len(cases)
            and {(run["fixture"], run["compiler"]) for run in proof["runs"]}
            == {(name, side) for name in cases for side in ("managed", "selfhost")}
            and all(type(run.get(stage)) is int and run[stage] == 0
                    for run in proof["runs"] for stage in
                    ("buildExit", "llvmAsExit", "directCallExit"))
            and all(type(run.get("nativeExit")) is int
                    and run["nativeExit"] == cases[run["fixture"]].get("runtime", {}).get("exit", 0)
                    for run in proof["runs"]),
            "LLVM_OBSERVATION_PAIRED_STAGES_INCOMPLETE")
    for run in proof["runs"]:
        runtime = cases[run["fixture"]].get("runtime")
        if runtime is not None:
            require(run.get("runtimeStdout") == runtime["stdout"]
                    and run.get("runtimeStderr") == runtime["stderr"][run["compiler"]],
                    "LLVM_OBSERVATION_RUNTIME_OUTPUT_MISMATCH")
    require(len(runs) == len(cases) and {run["fixture"] for run in runs} == set(cases),
            "LLVM_OBSERVATION_COVERAGE_MISMATCH")
    module_path = Path(__file__).with_name("verify-structural-parity-detail.py")
    spec = importlib.util.spec_from_file_location("llvm_cleanup_proof", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    output = {}
    for run in runs:
        link = run["llvmObservation"]
        path = local(root, link["path"])
        require(path.is_relative_to(proof_path.parent.resolve()) and sha(path) == link["sha256"],
                "LLVM_OBSERVATION_RECORD_CHANGED")
        observation, case = read(path), cases[run["fixture"]]
        require(observation["status"] == "passed" and observation["fixture"] == run["fixture"]
                and observation["contractPath"] == str(contract_path.resolve())
                and observation["contractSha256"] == sha(contract_path)
                and observation["sourcePath"] == str(local(root, case["source"]))
                and observation["sourceSha256"] == sha(local(root, case["source"]))
                and observation["sourceSha256"] == run["sourceSha256"]
                and observation["compilerSha256"] == run["compilerSha256"]
                and start.get(observation["compilerPath"]) == observation["compilerSha256"],
                "LLVM_OBSERVATION_IDENTITY_MISMATCH")
        require(len(observation["checks"]) == len(case["checks"]), "LLVM_OBSERVATION_CHECKS_CHANGED")
        actual = {}
        for check, expected in zip(observation["checks"], case["checks"]):
            require(all(check.get(k) == v for k, v in expected.items())
                    and type(check.get("contains")) is bool and check.get("passed") is True
                    and check["contains"] == expected["expected"], "LLVM_OBSERVATION_CHECKS_CHANGED")
            actual[check["id"]] = check["contains"]
        llvm = local(root, observation["llvmPath"])
        plan = proof_path.parent / "artifact-cleanup-plan.json"
        execution = Path(str(plan) + ".execution.json")
        cleanup = None if llvm.exists() else {
            "plan": {"path": str(plan.relative_to(root)), "sha256": sha(plan)},
            "execution": {"path": str(execution.relative_to(root)), "sha256": sha(execution)}}
        module.validate_fixture_binary(root, {"path": str(llvm.relative_to(root)),
                                             "sha256": observation["llvmSha256"]}, cleanup)
        output[run["fixture"]] = actual
    return {"status": "passed", "fixtures": output, "completed": len(output), "total": len(cases)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--check-fixtures")
    parser.add_argument("--fixture")
    parser.add_argument("--llvm", type=Path)
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify-proof", type=Path)
    args = parser.parse_args()
    root = args.repo.resolve()
    contract = local(root, args.contract)
    if args.check_fixtures is not None:
        cases = contract_cases(root, read(contract))
        names = args.check_fixtures.split(",")
        require(len(names) == len(set(names)) and set(names) == set(cases), "LLVM_OBSERVATION_COVERAGE_MISMATCH")
        require(all(local(root, cases[name]["source"]) ==
                    (root / "examples/regression" / (name + ".slg")).resolve() for name in names),
                "LLVM_OBSERVATION_FIXTURE_SOURCE_MISMATCH")
        print(json.dumps({"status": "passed", "fixtures": len(cases)}))
    elif args.verify_proof:
        print(json.dumps(verify_proof(root, contract, local(root, args.verify_proof))))
    else:
        require(all((args.fixture, args.llvm, args.compiler, args.output)), "LLVM_OBSERVATION_ARGUMENTS_MISSING")
        output = local(root, args.output)
        require(not output.exists(), "LLVM_OBSERVATION_OUTPUT_EXISTS")
        result = observe(root, contract, args.fixture, local(root, args.llvm), local(root, args.compiler))
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        require(result["status"] == "passed", "LLVM_OBSERVATION_PREDICATE_FAILED")
        print(json.dumps({"status": "passed", "fixture": args.fixture}))


if __name__ == "__main__":
    main()
