"""Observe COM query status and ownership, managed first, with a shared fixture."""

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
from verification_source_proof import current_build_inputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--managed-compiler", type=Path, required=True)
    parser.add_argument("--native-build", type=Path)
    parser.add_argument("--managed-evidence", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    managed, output = args.managed_compiler.resolve(), args.output.resolve()
    probe, llvm = Path(__file__).resolve().parent, ROOT / ".tools/llvm-22.1.8"
    fixture = ROOT / "artifacts/com-query-response/query_fixture.dll"
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    compiler = managed
    providers = [Path(__file__), probe / "query_fixture.c", probe / "query-response.slg",
                 ROOT / "tests/com-interop/com_fixture.c", ROOT / "scripts/completed_artifact_plan.py",
                 *list((ROOT / "scripts").glob("verification_*.py")),
                 *managed_compilation_inputs(managed, ROOT / "stdlib"),
                 *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-as.exe")]]
    if args.native_build:
        assert args.managed_evidence, "COM_QUERY_MANAGED_PROOF_REQUIRED"
        reference = args.managed_evidence.resolve()
        old = json.loads(reference.read_text(encoding="utf-8-sig"))
        assert old["inputHashes"].get(str(managed)) == digest(managed), "COM_QUERY_MANAGED_COMPILER_IDENTITY_MISMATCH"
        assert old["inputHashes"].get(str(managed.with_suffix(".dll"))) == digest(managed.with_suffix(".dll")), "COM_QUERY_MANAGED_COMPILER_IDENTITY_MISMATCH"
        assert old["status"] == "passed" and old["completed"] == old["total"] == 3
        assert old["inputsStable"] and old["processesStopped"]
        for name, expected in old["inputHashes"].items():
            assert digest(name) == expected, "COM_QUERY_MANAGED_INPUT_CHANGED:" + name
        for index, expected in enumerate(("query=0\ninside=1\nafter=0\n", "query=-2147467262\ninside=1\nafter=0\n", "query=ok\ninside=1\nafter=0\n")):
            assert (reference.parent / f"run{index}.stdout").read_text(encoding="utf-8") == expected
            assert (reference.parent / f"run{index}.stderr").read_bytes() == b""
        build = json.loads((args.native_build / "result.json").read_text(encoding="utf-8-sig"))
        compiler = args.native_build.resolve() / "compiler.exe"
        assert build["status"] == "passed" and build["inputsStable"]
        assert digest(compiler) == build["compilerSha256"]
        providers += [compiler, args.native_build / "result.json", reference, fixture,
                      *current_build_inputs(ROOT, build)]
    elif fixture.exists():
        fixture_record = fixture.parent / "result.json"
        previous = json.loads(fixture_record.read_text(encoding="utf-8-sig"))
        assert previous["processesStopped"] and previous["inputsStable"]
        for path in (probe / "query_fixture.c", ROOT / "tests/com-interop/com_fixture.c", llvm / "bin/clang.exe", llvm / "bin/lld-link.exe", fixture):
            assert digest(path) == previous["inputHashes"][str(path.resolve())], "COM_QUERY_FIXTURE_COMPONENT_CHANGED"
        assert [row["exit"] for row in previous["processes"][:2]] == [0, 0]
        assert all(row["shutdownConfirmed"] for row in previous["processes"][:2])
        assert (fixture.parent / "fixture-compile.stderr").read_bytes() == b""
        assert (fixture.parent / "fixture-link.stderr").read_bytes() == b""
        providers += [fixture_record, fixture]
    else:
        assert output == fixture.parent, "COM_QUERY_FIXTURE_OUTPUT_MUST_BE_NEW"
    pins = {str(path.resolve()): digest(path) for path in providers}
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    stable = lambda: all(Path(path).is_file() and digest(path) == value for path, value in pins.items())
    result = dict(schemaVersion=1, status="running", completed=0, total=3, cases=[],
                  inputHashes=pins, maximumCaseSeconds=180, claimsGoalComplete=False,
                  scope="COM QueryInterface status/ownership; intentionally malformed responses and valid control")
    execution = VerificationExecution(ROOT, output, result, stable, digest)
    error = None
    started = time.monotonic()

    def run(command, label):
        remaining = 180 - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("COM_QUERY_CASE_BUDGET_EXHAUSTED")
        return execution.run(list(map(str, command)), output / label, timeout=remaining)

    try:
        if not args.native_build and not fixture.exists():
            obj = output / "query_fixture.obj"
            done = run([llvm / "bin/clang.exe", "--target=x86_64-pc-windows-msvc", "-O3", "-fno-addrsig", "-ffreestanding", "-c", probe / "query_fixture.c", "-o", obj], "fixture-compile")
            assert done.returncode == 0 and done.stderr == "", "COM_QUERY_FIXTURE_COMPILE_FAILED"
            done = run([llvm / "bin/lld-link.exe", "/nologo", "/dll", "/noentry", "/machine:x64", "/nodefaultlib", "/opt:ref", "/opt:icf", "/export:DllGetClassObject", "/export:com_fixture_live_references", "/export:query_fixture_set_mode", "/out:" + str(fixture), obj], "fixture-link")
            assert done.returncode == 0 and done.stderr == "", "COM_QUERY_FIXTURE_LINK_FAILED"
            pins[str(fixture)] = digest(fixture)
            execution.save()
        target = output / "query.exe"
        command = [compiler, "build", probe / "query-response.slg", "-o", target,
                   "--target", "windows-x64", "--llvm", llvm, "--jobs", "1", "-O0", "--keep-temps"]
        if args.native_build:
            command += ["--stdlib", ROOT / "stdlib"]
        done = run(command, "build")
        assert done.returncode == 0 and done.stderr == "", "COM_QUERY_BUILD_FAILED"
        ir = Path(str(target) + ".ll")
        assert run([llvm / "bin/llvm-as.exe", ir, "-o", output / "query.bc"], "assemble").returncode == 0
        result["llvmSha256"] = digest(ir)
        expectations = ["query=0\ninside=1\nafter=0\n", "query=-2147467262\ninside=1\nafter=0\n", "query=ok\ninside=1\nafter=0\n"]
        for index, expected in enumerate(expectations):
            done = run([target] + ["extra"] * index, f"run{index}")
            actual = (output / f"run{index}.stdout").read_text(encoding="utf-8")
            passed = done.returncode == 0 and actual == expected and done.stderr == ""
            result["cases"].append(dict(id=["success-null", "failure-borrowed", "valid"][index], passed=passed, expected=expected, actual=actual))
            result["completed"] += int(passed)
            execution.save()
        assert result["completed"] == result["total"], "COM_QUERY_RESPONSE_MISMATCH"
        result["status"] = "passed"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in ("status", "completed", "total", "failure", "cases", "inputsStable", "processesStopped")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
