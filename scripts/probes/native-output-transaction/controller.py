"""Run bounded staging allocation controls against existing current products."""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from verification_execution import VerificationExecution


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "native"), required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(strict=True), args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / "artifacts"):
        raise ValueError("STAGING_PROBE_OUTPUT_INVALID")
    if (args.mode == "managed") != (args.probe is not None):
        raise ValueError("STAGING_PROBE_MODE_INPUT_INVALID")
    contract_path = Path(__file__).with_name("contract.json")
    contract = json.loads(contract_path.read_text(encoding="utf-8-sig"))
    dotnet = shutil.which("dotnet")
    if args.mode == "managed" and dotnet is None:
        raise ValueError("STAGING_PROBE_DOTNET_MISSING")
    probe = args.probe.resolve(strict=True) if args.probe else None
    inputs = [Path(__file__), contract_path, compiler,
              ROOT / "scripts/verification_execution.py",
              ROOT / "scripts/verification-process.ps1"]
    if probe:
        inputs += [probe, Path(__file__).with_name("reference-harness.cs"),
                   ROOT / "src/Sollang.Compiler/Cli/NativeOutputTransaction.cs"]
        for product in (compiler, probe):
            inputs += [product.with_suffix(ext) for ext in (".deps.json", ".runtimeconfig.json")]
    else:
        inputs += [ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.slg",
                   *sorted((ROOT / "stdlib").rglob("*.slg")),
                   *sorted((ROOT / ".tools/llvm-22.1.8/bin").glob("*.exe"))]
    if any(not path.is_file() for path in inputs):
        raise ValueError("STAGING_PROBE_DEPENDENCY_MISSING")
    output.mkdir(parents=True)
    source = output / "probe-input.slg"
    source.write_bytes(contract["source"].encode("utf-8"))
    inputs.append(source)
    for case in contract["cases"]:
        folder = output / case["id"]
        folder.mkdir()
        for ordinal in range(case.get("occupied", 0)):
            if ordinal == case.get("hole"):
                continue
            if case["kind"] == "work":
                name = f".w{ordinal}" if probe else f".l{ordinal}.ll.slg-tmp"
                seed = folder / name / "preserved-input.txt"
                seed.parent.mkdir()
            else:
                seed = folder / (f".l{ordinal}.ll" if case["kind"] == "llvm"
                                 else f".e{ordinal}.exe")
            seed.write_bytes(f"retained-input-{ordinal}\n".encode("ascii"))
            inputs.append(seed)
        if case["kind"] in ("lock", "llvm-lock", "invalid", "invalid-executable"):
            seed = folder / {"lock": "output.exe.sollang-txn-lock",
                             "llvm-lock": "output.exe.ll.sollang-txn-lock",
                             "invalid": ".l0.ll/preserved-input.txt",
                             "invalid-executable": ".e0.exe/preserved-input.txt"}[case["kind"]]
            seed.parent.mkdir(exist_ok=True)
            seed.write_bytes(b"preserved-input\n")
            inputs.append(seed)
    pins = {str(path): sha(path) for path in inputs}
    stable = lambda: all(Path(path).is_file() and sha(path) == digest
                         for path, digest in pins.items())
    result = dict(status="running", completed=0, total=len(contract["cases"]),
                  inputHashes=pins, cases=[], scope=contract["scope"], claimsGoalComplete=False)
    execution = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        for case in contract["cases"]:
            folder = output / case["id"]
            if probe:
                command = [dotnet, str(probe), str(compiler), str(folder)]
            else:
                command = [str(compiler), "build", str(source), "-o", str(folder / "output.exe"),
                           "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                           "--stdlib", str(ROOT / "stdlib"), "--keep-temps", "--jobs", "1", "-O0"]
            run = execution.run(command, output / (case["id"] + ".claim"),
                                timeout=contract["maximumCaseSeconds"])
            expected_failure = case.get("expectedFailure", False)
            passed = run.returncode != 0 if expected_failure else run.returncode == 0
            if expected_failure:
                passed &= bool(run.stderr) and not (folder / "output.exe").exists()
                passed &= not (folder / ".l1.ll").exists()
                passed &= all(not (folder / name).exists()
                              for name in case.get("absentOwnedStages", []))
                if case["kind"] != "lock":
                    passed &= not (folder / "output.exe.sollang-txn-lock").exists()
                if case["kind"] != "llvm-lock":
                    passed &= not (folder / "output.exe.ll.sollang-txn-lock").exists()
            elif probe and passed:
                actual = json.loads(run.stdout)
                ordinal = case["expectedOrdinal"]
                passed &= Path(actual["llvmStage"]) == folder / f".l{ordinal}.ll"
                passed &= Path(actual["executableStage"]) == folder / f".e{ordinal}.exe"
                passed &= Path(actual["workDirectory"]) == folder / f".w{ordinal}"
                passed &= all(Path(value).exists() for value in actual.values())
                passed &= not (folder / "output.exe.sollang-txn-lock").exists()
                passed &= not (folder / "output.exe.ll.sollang-txn-lock").exists()
            elif not probe and passed:
                passed &= not run.stderr
                passed &= (folder / f".l{case['expectedOrdinal']}.ll.slg-tmp").is_dir()
                if passed:
                    program = execution.run([str(folder / "output.exe")],
                                            output / (case["id"] + ".run"), timeout=30)
                    passed &= (program.returncode == 0 and not program.stderr
                               and program.stdout == "staging-ok\n")
            passed &= stable()
            result["cases"].append(dict(id=case["id"], passed=bool(passed),
                                        actualExit=run.returncode,
                                        expectedFailure=expected_failure))
            result["completed"] += int(passed)
            execution.save()
            print(case["id"] + (" passed" if passed else " FAILED"), flush=True)
        result["status"] = "passed" if result["completed"] == result["total"] else "failed"
        if result["status"] == "failed":
            result["failure"] = "STAGING_ALLOCATION_CONTRACT_MISMATCH"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in
                     ("status", "completed", "total", "failure", "inputsStable", "processesStopped")}))
    if error:
        raise error
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
