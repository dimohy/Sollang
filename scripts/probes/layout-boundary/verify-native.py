"""Compare current Native bounded-layout CLI behavior to completed CSharp controls."""

import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from completed_artifact_plan import initialize_output
from verification_execution import VerificationExecution
from verification_source_proof import current_build_inputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--managed-compiler", type=Path, required=True)
    parser.add_argument("--managed-proof", type=Path, required=True)
    parser.add_argument("--native-build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    managed, output = args.managed_compiler.resolve(), args.output.resolve()
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    reference = args.managed_proof.resolve()
    previous = json.loads(reference.read_text(encoding="utf-8-sig"))
    assert previous["status"] == "passed" and previous["completed"] == previous["total"] == 9
    assert previous["inputsStable"] and previous["processesStopped"]
    assert previous["inputHashes"].get(str(managed)) == digest(managed), "LAYOUT_NATIVE_MANAGED_IDENTITY_MISMATCH"
    pins = dict(previous["inputHashes"])
    assert all(digest(path) == value for path, value in pins.items()), "LAYOUT_NATIVE_MANAGED_PROOF_DRIFT"
    build_path = args.native_build.resolve() / "result.json"
    build = json.loads(build_path.read_text(encoding="utf-8-sig"))
    native = build_path.parent / "compiler.exe"
    assert build["status"] == "passed" and build["inputsStable"] and digest(native) == build["compilerSha256"]
    llvm = ROOT / ".tools/llvm-22.1.8"
    providers = [Path(__file__), reference, build_path, native, *current_build_inputs(ROOT, build)]
    for name in ("overflow-build.stdout", "overflow-build.stderr", "normal-run.stdout", "normal-run.stderr"):
        providers.append(reference.parent / name)
    for path in providers:
        pins[str(path.resolve())] = digest(path)
    stable = lambda: all(Path(path).is_file() and digest(path) == value for path, value in pins.items())
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    result = dict(schemaVersion=1, status="running", completed=0, total=2, inputHashes=pins, cases=[],
                  maximumCaseSeconds=180, claimsGoalComplete=False, scope="Actual Native overflow rejection and valid bounded-value runtime, exact CSharp streams")
    execution = VerificationExecution(ROOT, output, result, stable, digest)
    error = None
    try:
        for name in ("overflow", "normal"):
            started = time.monotonic()

            def run(command, label):
                remaining = 180 - (time.monotonic() - started)
                if remaining <= 0:
                    raise TimeoutError("NATIVE_LAYOUT_CASE_BUDGET_EXHAUSTED")
                return execution.run(list(map(str, command)), output / label, timeout=remaining)

            target = output / (name + ".exe")
            done = run([native, "build", Path(__file__).with_name(name + ".slg"), "-o", target,
                        "--target", "windows-x64", "--llvm", llvm, "--stdlib", ROOT / "stdlib",
                        "--jobs", "1", "-O0", "--keep-temps"], name + "-build")
            if name == "overflow":
                passed = done.returncode == 1 and done.stdout == (reference.parent / "overflow-build.stdout").read_text(encoding="utf-8") and done.stderr == (reference.parent / "overflow-build.stderr").read_text(encoding="utf-8") and not target.exists()
            else:
                passed = done.returncode == 0 and done.stderr == ""
                if passed:
                    done = run([target], "normal-run")
                    passed = done.returncode == 0 and done.stdout == (reference.parent / "normal-run.stdout").read_text(encoding="utf-8") and done.stderr == (reference.parent / "normal-run.stderr").read_text(encoding="utf-8")
            result["cases"].append(dict(id=name, passed=passed, observedExit=done.returncode, stdout=done.stdout, stderr=done.stderr))
            result["completed"] += int(passed)
            execution.save()
        assert result["completed"] == result["total"], "NATIVE_LAYOUT_CLI_MISMATCH"
        result["status"] = "passed"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in ("status", "completed", "total", "cases", "failure", "inputsStable", "processesStopped")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
