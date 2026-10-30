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
from verification_source_proof import current_build_inputs


def matches_layout(reference, observed):
    if observed is None or observed["capacity"] != reference["capacity"]:
        return False
    if reference["status"] == "known":
        return observed["status"] == 0 and observed["size"] == reference["size"] and observed["align"] == 8
    return reference["status"] == "overflow" and observed["status"] == 4 and observed["size"] == -1 and observed["align"] == 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--native-build", type=Path)
    parser.add_argument("--managed-proof", type=Path, required=True)
    parser.add_argument("--semantic-proof", type=Path)
    parser.add_argument("--provider-contract", type=Path)
    parser.add_argument("--arithmetic-only", action="store_true",
                        help="Test the independent production arithmetic module; no full layoutsFor API claim")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    output, compiler = args.output.resolve(), args.compiler.resolve()
    sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    managed = json.loads(args.managed_proof.read_text(encoding="utf-8-sig"))
    assert args.arithmetic_only or (args.semantic_proof and args.provider_contract), "LAYOUT_FULL_API_PROOFS_REQUIRED"
    assert managed["completed"] == managed["total"] == 9
    api_cases = [case for case in managed["cases"] if "capacity" in case]
    assert len(api_cases) == 7 and all(case["passed"] for case in api_cases)
    pins = {}
    references = [(args.managed_proof, managed)]
    if args.semantic_proof:
        references.append((args.semantic_proof, json.loads(args.semantic_proof.read_text(encoding="utf-8-sig"))))
    for path, record in references:
        assert record["status"] == "passed" and record["inputsStable"] and record["processesStopped"]
        for name, digest in record["inputHashes"].items():
            assert sha(name) == digest, "LAYOUT_SOURCE_REFERENCE_DRIFT:" + name
            pins[name] = digest
        pins[str(path.resolve())] = sha(path)
    if args.arithmetic_only:
        providers = [ROOT / "selfhost/llvm/emitter/layout_arithmetic.slg"]
        source = Path(__file__).with_name("arithmetic.slg")
    else:
        contract = json.loads(args.provider_contract.read_text(encoding="utf-8-sig"))
        providers = [ROOT / name for name in contract["reusableCheckedProducer"]["additionalSources"]]
        source = Path(__file__).with_name("layout.slg")
    llvm = ROOT / ".tools/llvm-22.1.8"
    for path in [Path(__file__), source, *([args.provider_contract] if args.provider_contract else []), *providers,
                 *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-lib.exe")]]:
        pins[str(path.resolve())] = sha(path)
    if args.native_build:
        build_path = args.native_build.resolve() / "result.json"
        build = json.loads(build_path.read_text(encoding="utf-8-sig"))
        assert compiler == args.native_build.resolve() / "compiler.exe"
        assert build["status"] == "passed" and build["inputsStable"]
        assert sha(compiler) == build["compilerSha256"]
        for path in [compiler, build_path, *current_build_inputs(ROOT, build)]:
            pins[str(path.resolve())] = sha(path)
    else:
        assert managed["inputHashes"].get(str(compiler)) == sha(compiler), "LAYOUT_MANAGED_COMPILER_IDENTITY_MISMATCH"
    stable = lambda: all(Path(path).is_file() and sha(path) == value for path, value in pins.items())
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    result = dict(schemaVersion=1, status="running", completed=0, total=7, inputHashes=pins,
                  cases=[], maximumCaseSeconds=180, claimsGoalComplete=False,
                  scope="Actual SLG layoutsFor API, two tiny semantic types; no huge array/backing/LLVM allocation or new Native compiler")
    if args.arithmetic_only:
        result["scope"] = "Independent production checked arithmetic module only; no full layoutsFor API or full compiler-program acceptance"
    execution = VerificationExecution(ROOT, output, result, stable, sha)
    error, started = None, time.monotonic()

    def run(command, label):
        remaining = 180 - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("LAYOUT_SOURCE_CASE_BUDGET_EXHAUSTED")
        return execution.run(list(map(str, command)), output / label, timeout=remaining)

    try:
        target = output / "layout.exe"
        command = [compiler, "build", source, *providers, "-o", target, "--target", "windows-x64",
                   "--llvm", llvm, "--jobs", "1", "-O0", "--keep-temps"]
        if args.native_build:
            command += ["--stdlib", ROOT / "stdlib"]
        done = run(command, "build")
        assert done.returncode == 0 and done.stderr == "", "LAYOUT_SOURCE_BUILD_FAILED"
        for index, reference in enumerate(api_cases):
            done = run([target] + ["extra"] * index, f"run{index}")
            match = re.fullmatch(r"capacity=(-?\d+) status=(-?\d+) size=(-?\d+) align=(-?\d+)\s*", done.stdout)
            observed = dict(zip(("capacity", "status", "size", "align"), map(int, match.groups()))) if match else None
            passed = done.returncode == 0 and done.stderr == "" and matches_layout(reference, observed)
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
