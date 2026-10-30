"""Compare tiny actual SLG layout API calls against completed CSharp decisions."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from completed_artifact_plan import initialize_output
from verification_execution import VerificationExecution


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--managed-proof", type=Path, required=True)
    parser.add_argument("--semantic-proof", type=Path, required=True)
    parser.add_argument("--provider-contract", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    output, compiler = args.output.resolve(), args.compiler.resolve()
    sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    managed = json.loads(args.managed_proof.read_text(encoding="utf-8-sig"))
    semantic = json.loads(args.semantic_proof.read_text(encoding="utf-8-sig"))
    assert managed["completed"] == managed["total"] == 7
    pins = {}
    for path, record in ((args.managed_proof, managed), (args.semantic_proof, semantic)):
        assert record["status"] == "passed" and record["inputsStable"] and record["processesStopped"]
        for name, digest in record["inputHashes"].items():
            assert sha(name) == digest, "LAYOUT_SOURCE_REFERENCE_DRIFT:" + name
            pins[name] = digest
        pins[str(path.resolve())] = sha(path)
    contract = json.loads(args.provider_contract.read_text(encoding="utf-8-sig"))
    providers = [ROOT / name for name in contract["reusableCheckedProducer"]["additionalSources"]]
    source = Path(__file__).with_name("layout.slg")
    llvm = ROOT / ".tools/llvm-22.1.8"
    for path in [Path(__file__), source, args.provider_contract, *providers,
                 *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-lib.exe")]]:
        pins[str(path.resolve())] = sha(path)
    stable = lambda: all(Path(path).is_file() and sha(path) == value for path, value in pins.items())
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    result = dict(schemaVersion=1, status="running", completed=0, total=7, inputHashes=pins,
                  cases=[], maximumCaseSeconds=180, claimsGoalComplete=False,
                  scope="Actual SLG layoutsFor API, two tiny semantic types; no huge array/backing/LLVM allocation or new Native compiler")
    execution = VerificationExecution(ROOT, output, result, stable, sha)
    error, started = None, time.monotonic()

    def run(command, label):
        remaining = 180 - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("LAYOUT_SOURCE_CASE_BUDGET_EXHAUSTED")
        return execution.run(list(map(str, command)), output / label, timeout=remaining)

    try:
        target = output / "layout.exe"
        done = run([compiler, "build", source, *providers, "-o", target, "--target", "windows-x64",
                    "--llvm", llvm, "--jobs", "1", "-O0", "--keep-temps"], "build")
        assert done.returncode == 0 and done.stderr == "", "LAYOUT_SOURCE_BUILD_FAILED"
        for index, reference in enumerate(managed["cases"]):
            done = run([target] + ["extra"] * index, f"run{index}")
            match = re.fullmatch(r"capacity=(-?\d+) status=(-?\d+) size=(-?\d+) align=(-?\d+)\s*", done.stdout)
            observed = dict(zip(("capacity", "status", "size", "align"), map(int, match.groups()))) if match else None
            passed = done.returncode == 0 and done.stderr == "" and observed is not None and observed["capacity"] == reference["capacity"]
            if passed:
                passed = (observed["status"] == 0 and observed["size"] == reference["size"] and observed["align"] == 8
                          if reference["status"] == "known" else observed["status"] != 0)
            result["cases"].append(dict(capacity=reference["capacity"], expected=reference["expected"], actual=observed, passed=passed))
            result["completed"] += int(passed)
            execution.save()
            print(json.dumps(result["cases"][-1]), flush=True)
        assert result["completed"] == result["total"], "LAYOUT_SOURCE_BOUNDARY_MISMATCH"
        result["status"] = "passed"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in ("status", "completed", "total", "failure", "inputsStable", "processesStopped")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
