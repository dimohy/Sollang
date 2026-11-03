"""Verify bounded layout metadata boundaries and real CSharp CLI decisions."""

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
from verification_fingerprints import managed_compilation_inputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    kind = parser.add_mutually_exclusive_group()
    kind.add_argument("--dictionary", action="store_true")
    kind.add_argument("--bitset", action="store_true")
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    probe, llvm = Path(__file__).resolve().parent, ROOT / ".tools/llvm-22.1.8"
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    prefix = "dictionary-" if args.dictionary else "bitset-" if args.bitset else ""
    boundary = "boundary" if args.bitset else "overflow"
    sources = [probe / name for name in ("Program.cs", "LayoutBoundary.csproj", prefix + "normal.slg", prefix + boundary + ".slg")]
    providers = [Path(__file__), *sources, *managed_compilation_inputs(compiler, ROOT / "stdlib"),
                 *list((ROOT / "scripts").glob("verification_*.py")), ROOT / "scripts/completed_artifact_plan.py",
                 *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-lib.exe")]]
    pins = {str(path.resolve()): digest(path) for path in providers}
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    stable = lambda: all(Path(path).is_file() and digest(path) == value for path, value in pins.items())
    metadata_count = 16 if args.dictionary or args.bitset else 7
    result = dict(schemaVersion=1, status="running", completed=0, total=metadata_count + 2, inputHashes=pins,
                  cases=[], maximumCaseSeconds=180, claimsGoalComplete=False,
                  scope=f"CSharp{metadata_count} tiny metadata boundaries plus overflow CLI rejection and valid bounded-value runtime")
    execution = VerificationExecution(ROOT, output, result, stable, digest)
    started, error = time.monotonic(), None

    def run(command, label):
        remaining = 180 - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("MANAGED_LAYOUT_CASE_BUDGET_EXHAUSTED")
        return execution.run(list(map(str, command)), output / label, timeout=remaining)

    try:
        done = run(["dotnet", "build", sources[1], "-c", "Release", "-o", output / "probe",
                    "--artifacts-path", output / "dotnet-artifacts", "--disable-build-servers",
                    "-p:UseSharedCompilation=false", "-nodeReuse:false", "--nologo"], "probe-build")
        assert done.returncode == 0 and done.stderr == "", "MANAGED_LAYOUT_PROBE_BUILD"
        done = run(["dotnet", output / "probe/LayoutBoundary.dll", compiler.with_suffix(".dll"),
                    *(["dictionary"] if args.dictionary else ["bitset"] if args.bitset else [])], "api")
        assert done.returncode == 0 and done.stderr == "", "MANAGED_LAYOUT_API_EXECUTION"
        rows = [json.loads(line) for line in done.stdout.splitlines()]
        capacities = ([1, 14, 15, 117440512, 117440513, 939524097, 1879048192, 2147483647] * 2 if args.dictionary else
                      [1, 63, 64, 65, 2147483584, 2147483585, 2147483646, 2147483647] * 2 if args.bitset else
                      [1, 536870907, 536870908, 536870909, 536870910, 536870912, 2147483647])
        assert [row["capacity"] for row in rows] == capacities
        if args.dictionary or args.bitset:
            assert [row["restored"] for row in rows] == [False] * 8 + [True] * 8
        for row in rows:
            if args.dictionary:
                expected = ({"status": "known", "size": 168, "buckets": 16} if row["capacity"] in (1, 14) else
                            {"status": "known", "size": 312, "buckets": 32} if row["capacity"] == 15 else
                            {"status": "known", "size": 1207959576, "buckets": 134217728} if row["capacity"] == 117440512 else
                            {"status": "overflow"})
            elif args.bitset:
                words = 1 if row["capacity"] <= 64 else 2 if row["capacity"] == 65 else 33554431 if row["capacity"] == 2147483584 else 33554432
                expected = {"status": "known", "size": words * 8, "words": words}
            else:
                expected = ({"status": "known", "size": 16} if row["capacity"] == 1 else
                            {"status": "known", "size": 2147483640} if row["capacity"] == 536870907 else {"status": "overflow"})
            passed = all(row.get(key) == value for key, value in expected.items())
            # Keep domain layout status separate from execution completion status.
            recorded = dict(row)
            recorded["layoutStatus"] = recorded.pop("status")
            result["cases"].append(dict(**recorded, expected=expected, passed=passed))
            result["completed"] += int(passed)
        assert result["completed"] == metadata_count, "MANAGED_LAYOUT_API_BOUNDARY"
        for name in (boundary, "normal"):
            target = output / (name + ".exe")
            done = run([compiler, "build", probe / (prefix + name + ".slg"), "-o", target,
                        "--target", "windows-x64", "--llvm", llvm, "--jobs", "1", "-O0"], name + "-build")
            if name == "overflow":
                container = "dictionary" if args.dictionary else "array"
                passed = done.returncode == 1 and done.stdout == "" and done.stderr == f"sollang: bounded {container} storage layout exceeds the Int32 size limit\n" and not target.exists()
            else:
                passed = done.returncode == 0 and done.stderr == ""
                if passed:
                    done = run([target], name + "-run")
                    expected_stdout = "ready\n" if name == "boundary" else "count=3\n" if args.bitset else "4\n15\n" if args.dictionary else "2\n"
                    passed = done.returncode == 0 and done.stdout == expected_stdout and done.stderr == ""
            result["cases"].append(dict(id=name, passed=passed))
            result["completed"] += int(passed)
            execution.save()
            assert passed, "MANAGED_LAYOUT_CLI_CONTROL:" + name
        result["status"] = "passed"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in ("status", "completed", "total", "failure", "inputsStable", "processesStopped")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
