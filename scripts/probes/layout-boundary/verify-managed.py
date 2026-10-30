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
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    probe, llvm = Path(__file__).resolve().parent, ROOT / ".tools/llvm-22.1.8"
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    sources = [probe / name for name in ("Program.cs", "LayoutBoundary.csproj", "normal.slg", "overflow.slg")]
    providers = [Path(__file__), *sources, *managed_compilation_inputs(compiler, ROOT / "stdlib"),
                 *list((ROOT / "scripts").glob("verification_*.py")), ROOT / "scripts/completed_artifact_plan.py",
                 *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-lib.exe")]]
    pins = {str(path.resolve()): digest(path) for path in providers}
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    stable = lambda: all(Path(path).is_file() and digest(path) == value for path, value in pins.items())
    result = dict(schemaVersion=1, status="running", completed=0, total=9, inputHashes=pins,
                  cases=[], maximumCaseSeconds=180, claimsGoalComplete=False,
                  scope="CSharp7 tiny metadata boundaries plus overflow CLI rejection and valid bounded-value runtime")
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
        done = run(["dotnet", output / "probe/LayoutBoundary.dll", compiler.with_suffix(".dll")], "api")
        assert done.returncode == 0 and done.stderr == "", "MANAGED_LAYOUT_API_EXECUTION"
        rows = [json.loads(line) for line in done.stdout.splitlines()]
        assert [row["capacity"] for row in rows] == [1, 536870907, 536870908, 536870909, 536870910, 536870912, 2147483647]
        for row in rows:
            expected = ({"status": "known", "size": 16} if row["capacity"] == 1 else
                        {"status": "known", "size": 2147483640} if row["capacity"] == 536870907 else {"status": "overflow"})
            passed = all(row.get(key) == value for key, value in expected.items())
            result["cases"].append(dict(**row, expected=expected, passed=passed))
            result["completed"] += int(passed)
        assert result["completed"] == 7, "MANAGED_LAYOUT_API_BOUNDARY"
        for name in ("overflow", "normal"):
            target = output / (name + ".exe")
            done = run([compiler, "build", probe / (name + ".slg"), "-o", target,
                        "--target", "windows-x64", "--llvm", llvm, "--jobs", "1", "-O0"], name + "-build")
            if name == "overflow":
                passed = done.returncode == 1 and done.stdout == "" and done.stderr == "sollang: bounded array storage layout exceeds the Int32 size limit\n" and not target.exists()
            else:
                passed = done.returncode == 0 and done.stderr == ""
                if passed:
                    done = run([target], "normal-run")
                    passed = done.returncode == 0 and done.stdout == "2\n" and done.stderr == ""
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
