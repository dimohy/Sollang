"""Verify COM imports through standalone and project native build paths."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
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
    parser.add_argument("--native-build", type=Path, required=True)
    parser.add_argument("--rebuilt-fixture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--case", action="append", choices=["managed-project", "managed-plain", "managed-direct-factory", "native-registered", "native-guarded", "native-project", "native-plain", "native-direct-factory"])
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    assert not args.case or len(args.case) == len(set(args.case)), "COM_DUPLICATE_CASE_SELECTION"
    managed, build, output = args.managed_compiler.resolve(), args.native_build.resolve(), args.output.resolve()
    native = build / "compiler.exe"
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    record = json.loads((build / "result.json").read_text(encoding="utf-8-sig"))
    assert record["status"] == "passed" and record["inputsStable"], "COM_NATIVE_BUILD_NOT_QUALIFIED"
    assert digest(native) == record["compilerSha256"], "COM_NATIVE_PRODUCT_CHANGED"
    fixture = ROOT / "artifacts/com-interop/com_fixture.dll"
    original, rebuilt = bytearray(fixture.read_bytes()), bytearray(args.rebuilt_fixture.read_bytes())
    for data in (original, rebuilt):
        offset = struct.unpack_from("<I", data, 0x3c)[0]
        assert data[offset:offset + 4] == b"PE\0\0", "COM_FIXTURE_NOT_PE"
        data[offset + 8:offset + 12] = b"\0" * 4
    assert original == rebuilt, "COM_FIXTURE_DIFFERS_BEYOND_COFF_TIMESTAMP"
    probe, llvm = Path(__file__).resolve().parent, ROOT / ".tools/llvm-22.1.8"
    sources = [probe / name for name in ("registered.slg", "registered-guarded.slg", "non-com.slg")]
    direct = ROOT / "examples/regression/604-com-interface.slg"
    expected = ROOT / "examples/regression/expected/604-com-interface.stdout.txt"
    providers = [Path(__file__), native, build / "result.json", fixture, args.rebuilt_fixture,
                 ROOT / "tests/com-interop/com_fixture.c", direct, expected, *sources,
                 *list((ROOT / "scripts").glob("verification_*.py")),
                 ROOT / "scripts/completed_artifact_plan.py",
                 ROOT / "scripts/verify-llvm-direct-call-closure.ps1",
                 ROOT / "scripts/native-exact-fixture-receipt.ps1",
                 llvm / "bin/llvm-as.exe", *current_build_inputs(ROOT, record),
                 *managed_compilation_inputs(managed, ROOT / "stdlib")]
    providers += list(expected.parent.glob("604-com-interface*.txt"))
    pins = {str(path.resolve()): digest(path) for path in providers}
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    project = output / "project"
    (project / "src").mkdir(parents=True)
    shutil.copyfile(sources[1], project / "src/main.slg")
    manifest = project / "sollang.project"
    manifest.write_text('project {\n    name: "com-import-project"\n    version: "0.1.0"\n    root: "src/main.slg"\n}\n', encoding="utf-8")
    for path in (manifest, project / "src/main.slg"):
        pins[str(path)] = digest(path)
    stable = lambda: all(Path(path).is_file() and digest(path) == value for path, value in pins.items())
    result = dict(schemaVersion=1, status="running", completed=0, total=8, inputHashes=pins,
                  cases=[], maximumCaseSeconds=180, claimsGoalComplete=False,
                  scope="Managed-first project/non-COM/direct-factory controls; five fresh Native observations. Registered active input is compile/link only; guarded runs avoid COM registration.")
    execution = VerificationExecution(ROOT, output, result, stable, digest)
    specs = [("managed", "project", manifest, b"ready\n", ["23"]),
             ("managed", "plain", sources[2], b"plain\n", []),
             ("managed", "direct-factory", direct, expected.read_bytes().replace(b"\r\n", b"\n"), None),
             ("native", "registered", sources[0], None, ["23"]),
             ("native", "guarded", sources[1], b"ready\n", ["23"]),
             ("native", "project", manifest, b"ready\n", ["23"]),
             ("native", "plain", sources[2], b"plain\n", []),
             ("native", "direct-factory", direct, expected.read_bytes().replace(b"\r\n", b"\n"), None)]
    if args.case:
        specs = [spec for spec in specs if spec[0] + "-" + spec[1] in args.case]
        result["total"] = len(specs)
        result["scope"] = "Explicitly selected managed-first COM controls: " + ", ".join(args.case)
    error = None
    try:
        assert stable(), "COM_INPUT_DRIFT_BEFORE_EXECUTION"
        for side, name, source, stdout, contexts in specs:
            folder = output / (side + "-" + name)
            folder.mkdir()
            started = time.monotonic()

            def run(command, label):
                remaining = 180 - (time.monotonic() - started)
                if remaining <= 0:
                    raise TimeoutError("COM_CASE_BUDGET_EXHAUSTED")
                return execution.run(list(map(str, command)), folder / label, timeout=remaining)

            compiler = managed if side == "managed" else native
            target = folder / "program.exe"
            command = [compiler, "build", *(["--project", source] if name == "project" else [source]),
                       "-o", target, "--target", "windows-x64", "--llvm", llvm,
                       "--jobs", "1", "-O0", "--keep-temps"]
            if side == "native":
                command += ["--stdlib", ROOT / "stdlib"]
            row = dict(id=side + "-" + name, status="running", passed=False,
                       runtimeRequested=stdout is not None)
            result["cases"].append(row)
            execution.save()
            done = run(command, "build")
            assert done.returncode == 0 and done.stderr == "", "COM_BUILD_FAILED:" + row["id"]
            ir = Path(str(target) + ".ll")
            text = ir.read_text(encoding="utf-8-sig")
            observed = re.findall(r"call i32 @CoCreateInstance\(ptr [^,]+, ptr null, i32 (\d+),", text)
            row["registeredClassContexts"] = observed
            if contexts is not None:
                assert observed == contexts, "COM_CLASS_CONTEXT_MISMATCH:" + row["id"]
            assert run([llvm / "bin/llvm-as.exe", ir, "-o", folder / "program.bc"], "assemble").returncode == 0
            assert run(["pwsh", "-NoProfile", "-File", ROOT / "scripts/verify-llvm-direct-call-closure.ps1",
                        "-LlvmPath", ir], "closure").returncode == 0
            if name == "direct-factory":
                assert "'" not in str(ROOT) and "'" not in str(ir)
                code = ". './scripts/native-exact-fixture-receipt.ps1'; $c=Get-NativeExactLlvmContracts -ExpectedRoot './examples/regression/expected' -Fixture '604-com-interface' -CompilerIsManagedDll $" + ("true" if side == "managed" else "false") + "; Assert-NativeExactLlvmContracts -LlvmPath '" + str(ir) + "' -Contracts $c"
                assert run(["pwsh", "-NoProfile", "-Command", code], "original-llvm-contract").returncode == 0
            if stdout is not None:
                done = run([target], "run")
                assert done.returncode == 0 and (folder / "run.stdout").read_bytes().replace(b"\r\n", b"\n") == stdout and done.stderr == "", "COM_RUNTIME_MISMATCH:" + row["id"]
            row.update(status="passed", passed=True, durationMilliseconds=round((time.monotonic() - started) * 1000, 3))
            result["completed"] += 1
            execution.save()
            print(row["id"] + ": PASS", flush=True)
        result["status"] = "passed"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in ("status", "completed", "total", "failure", "inputsStable", "processesStopped")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
