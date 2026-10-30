"""Compare the actual C# COM import detector with the production SLG helper."""

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
    parser.add_argument("--managed-compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    parser.add_argument("--managed-evidence", type=Path,
                        help="Reuse exact completed managed controls; execute only the SLG side")
    args = parser.parse_args()
    compiler, output = args.managed_compiler.resolve(), args.output.resolve()
    probe = Path(__file__).resolve().parent
    llvm = ROOT / ".tools/llvm-22.1.8"
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    providers = managed_compilation_inputs(compiler, ROOT / "stdlib") + [
        ROOT / "selfhost/toolchain.slg", *probe.glob("*.cs"), *probe.glob("*.csproj"),
        probe / "import-scan.slg", Path(__file__),
        *list((ROOT / "scripts").glob("verification_*.py")),
        ROOT / "scripts/completed_artifact_plan.py",
        *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-lib.exe")]]
    pins = {str(path.resolve()): digest(path) for path in providers}
    managed_reference = None
    if args.managed_evidence:
        reference = args.managed_evidence.resolve()
        previous = json.loads(reference.read_text(encoding="utf-8-sig"))
        assert previous["inputsStable"] and previous["processesStopped"], "COM_REFERENCE_NOT_TERMINAL"
        expected_ids = ["managed-" + name for name in ("absent", "present", "split", "end", "beyond", "partial", "missing")]
        expected_values = ["false", "true", "true", "true", "false", "false", "error"]
        assert [case["id"] for case in previous["cases"]] == expected_ids, "COM_REFERENCE_CASES_DIFFER"
        assert all(case["passed"] for case in previous["cases"]), "COM_REFERENCE_FAILED"
        assert [case["expected"] for case in previous["cases"]] == expected_values, "COM_REFERENCE_EXPECTATIONS_DIFFER"
        source_only = {str((ROOT / "selfhost/toolchain.slg").resolve()), str(Path(__file__).resolve())}
        for name, expected in previous["inputHashes"].items():
            if name not in source_only:
                assert digest(name) == expected, "COM_REFERENCE_INPUT_CHANGED:" + name
                pins[name] = expected
        for name, expected in zip(expected_ids, expected_values):
            for extension in ("stdout", "stderr"):
                path = reference.parent / (name + "." + extension)
                observed = path.read_text(encoding="utf-8-sig")
                assert (observed.strip() == expected if extension == "stdout" else observed == ""), "COM_REFERENCE_STREAM_DIFFERS"
                pins[str(path)] = digest(path)
        managed_reference = dict(path=str(reference), sha256=digest(reference), completed=7, total=7)
        pins[str(reference)] = digest(reference)
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    (output / "inputs").mkdir()
    marker = b"declare dllimport i32 @CoInitializeEx"
    cases = [("absent", b"no imports\n", "false"), ("present", marker, "true"),
             ("split", b" " * (4096 - 17) + marker, "true"),
             ("end", b" " * (1048576 - len(marker)) + marker, "true"),
             ("beyond", b" " * 1048576 + marker, "false"),
             ("partial", b" " * (1048576 - len(marker) + 1) + marker, "false"),
             ("missing", None, "error")]
    for name, content, expected in cases:
        if content is not None:
            path = output / "inputs" / name
            path.write_bytes(content)
            pins[str(path)] = digest(path)
    stable = lambda: all(Path(path).is_file() and digest(path) == value for path, value in pins.items())
    result = dict(schemaVersion=1, status="running", completed=0, total=7 if managed_reference else 14, inputHashes=pins,
                  scope="Actual CSharp reflection and managed-seeded production SLG source helper; no current Native CLI acceptance",
                  cases=[], maximumCaseSeconds=180, aggregateMaximumSeconds=180, claimsGoalComplete=False)
    if managed_reference:
        result["managedReference"] = managed_reference
    execution = VerificationExecution(ROOT, output, result, stable, digest)
    error = None
    started = time.monotonic()

    def run(command, label):
        remaining = 180 - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("COM_IMPORT_SCAN_BUDGET_EXHAUSTED")
        return execution.run(list(map(str, command)), output / label, timeout=remaining)

    try:
        assert stable(), "COM_IMPORT_SCAN_INPUT_DRIFT"
        if not managed_reference:
            build = run(["dotnet", "build", probe / "ImportScan.csproj", "-c", "Release",
                         "-o", output / "managed-helper", "--artifacts-path", output / "dotnet-artifacts",
                         "--disable-build-servers", "-p:UseSharedCompilation=false", "-nodeReuse:false", "--nologo"],
                        "managed-helper-build")
            assert build.returncode == 0, "COM_IMPORT_SCAN_MANAGED_HELPER_BUILD"
        for side in (("slg-source",) if managed_reference else ("managed", "slg-source")):
            if side == "slg-source":
                build = run([compiler, "build", probe / "import-scan.slg", ROOT / "selfhost/toolchain.slg",
                             "-o", output / "slg-scan.exe", "--target", "windows-x64", "--llvm", llvm,
                             "-O0", "--keep-temps"], "slg-helper-build")
                assert build.returncode == 0 and build.stderr == "", "COM_IMPORT_SCAN_SLG_HELPER_BUILD"
            for name, content, expected in cases:
                command = (["dotnet", output / "managed-helper/ImportScan.dll", compiler.with_suffix(".dll")]
                           if side == "managed" else [output / "slg-scan.exe"])
                observed = run(command + [output / "inputs" / name], side + "-" + name)
                passed = observed.returncode == 0 and observed.stdout.strip() == expected and observed.stderr == ""
                result["cases"].append(dict(id=side + "-" + name, expected=expected, passed=passed))
                result["completed"] += int(passed)
                execution.save()
                assert passed, "COM_IMPORT_SCAN_MISMATCH:" + side + ":" + name
        result["status"] = "passed"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in
                      ("status", "completed", "total", "failure", "inputsStable", "processesStopped")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
