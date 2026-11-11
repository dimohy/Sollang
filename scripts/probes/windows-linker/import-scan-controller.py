"""Exercise the existing managed/native import probes; never build a compiler."""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from verification_execution import VerificationExecution


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "native"), required=True)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--compiler", type=Path)
    parser.add_argument("--actual-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    contract_path = Path(__file__).with_name("import-scan-contract.json")
    contract = read(contract_path)
    manifest_path = args.actual_manifest.resolve(strict=True)
    manifest = read(manifest_path)
    probe = args.probe.resolve(strict=True)
    compiler = args.compiler.resolve(strict=True) if args.compiler else None
    dotnet = shutil.which("dotnet") if args.mode == "managed" else None
    if args.mode == "managed" and dotnet is None:
        raise ValueError("IMPORT_PROBE_DOTNET_MISSING")
    output = args.output.resolve()
    if (output.exists() or not output.is_relative_to(ROOT / "artifacts")
            or (args.mode == "managed") != (compiler is not None)
            or contract["schemaVersion"] != 1):
        raise ValueError("IMPORT_PROBE_INPUT_CONTRACT")
    actual = manifest["cases"]
    if ([row["id"] for row in actual]
            != [row["id"] for row in contract["actualCases"]]):
        raise ValueError("IMPORT_PROBE_ACTUAL_CASE_SCOPE")
    markers = contract["markers"]
    definitions_path = ROOT / contract["definitions"]
    definitions = read(definitions_path)
    rows = []
    inputs = [Path(__file__), contract_path, manifest_path, probe, definitions_path,
              ROOT / "scripts/verification_execution.py",
              ROOT / "scripts/verification-process.ps1",
              ROOT / "src/Sollang.Compiler/Shared/Policies/WindowsLinkPolicy.cs"]
    if args.mode == "managed":
        inputs.extend((ROOT / "scripts/probes/windows-linker/reference-harness.cs",
                       ROOT / "src/Sollang.Compiler/Tooling/WindowsLinker.cs"))
        for product in (probe, compiler):
            inputs.extend(product.with_suffix(suffix) for suffix in
                          (".dll", ".deps.json", ".runtimeconfig.json"))
    else:
        inputs.extend(ROOT / name for name in (
            "scripts/probes/windows-linker/imports.slg",
            "scripts/probes/windows-linker/imports.sources.txt",
            "selfhost/windows_imports.slg", "selfhost/windows_linker.slg",
            "selfhost/runtime/windows_poll.slg", "selfhost/generated/windows_link_policy.slg"))
    llvm_lib = ROOT / ".tools/llvm-22.1.8/bin/llvm-lib.exe"
    inputs.append(llvm_lib)
    for reference, case in zip(actual, contract["actualCases"]):
        path = Path(reference["path"]).resolve(strict=True)
        if not path.is_relative_to(ROOT) or sha(path) != reference["sha256"]:
            raise ValueError("IMPORT_PROBE_ACTUAL_INPUT_CHANGED")
        inputs.append(path)
        rows.append({**case, "path": path})
    if any(not path.is_file() for path in inputs):
        raise ValueError("IMPORT_PROBE_DEPENDENCY_MISSING")
    output.mkdir(parents=True)
    for case in contract["cases"]:
        path = output / (case["id"] + ".scan.txt")
        if not case.get("missing", False):
            offset = case["offset"]
            payload = "\n".join(markers[name] for name in case["markers"])
            payload += case.get("suffix", "")
            if not case.get("noFinalNewline", False):
                payload += "\n"
            if not isinstance(offset, int) or (offset != 0 and offset < 2):
                raise ValueError("IMPORT_PROBE_PADDING_INVALID")
            size = offset + len(payload.encode("ascii"))
            if size > contract["maximumSyntheticBytes"]:
                raise ValueError("IMPORT_PROBE_FIXTURE_BUDGET")
            padding = b"" if offset == 0 else b";" + b" " * (offset - 2) + b"\n"
            path.write_bytes(padding + payload.encode("ascii"))
            inputs.append(path)
        rows.append({**case, "path": path})
    pins = {str(path): sha(path) for path in dict.fromkeys(inputs)}
    stable = lambda: all(Path(path).is_file() and sha(path) == value
                         for path, value in pins.items())
    result = dict(schemaVersion=1, status="running", completed=0, total=len(rows),
                  inputHashes=pins, cases=[], claimsGoalComplete=False,
                  scope="Import selection only; no compiler build or whole-program acceptance")
    execution = VerificationExecution(ROOT, output, result, stable, sha)
    execution.save()
    error = None
    try:
        for case in rows:
            work = output / (case["id"] + ".imports")
            if args.mode == "managed":
                command = [dotnet, str(probe), str(compiler), "--imports",
                           str(llvm_lib.parent.parent), str(case["path"]), str(work)]
            else:
                work.mkdir()
                command = [str(probe), str(llvm_lib), str(case["path"]), str(work)]
            run = execution.run(command, output / case["id"],
                                timeout=contract["caseBudgetSeconds"])
            failure_case = case.get("expectedReadFailure", False)
            expected_exit = 1 if failure_case and args.mode == "managed" else 0
            found = {p.name: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
                     for p in work.glob("*.def")}
            wanted = set(contract["defaultImports"]) | set(case.get("expectedOptional", []))
            passed = run.returncode == expected_exit
            if failure_case:
                passed &= bool(run.stderr) and (not run.stdout if args.mode == "managed"
                          else run.stdout.replace("\r\n", "\n") == "result=1\n")
            else:
                passed &= not run.stderr and found == {key: definitions[key] for key in wanted}
                if args.mode == "managed":
                    passed &= json.loads(run.stdout)["definitions"] == found
                else:
                    lines = run.stdout.splitlines()
                    passed &= bool(lines) and lines[-1] == "result=0"
                    if passed:
                        passed &= {Path(line).resolve() for line in lines[:-1]} == {
                            (work / name.replace(".def", ".lib")).resolve() for name in wanted}
                        passed &= len(lines) == len(wanted) + 1
            result["cases"].append(dict(id=case["id"], passed=bool(passed),
                expectedExit=expected_exit, actualExit=run.returncode,
                expectedReadFailure=failure_case, expectedImports=sorted(wanted),
                actualImports=sorted(found)))
            result["completed"] += int(passed)
            execution.save()
            print(case["id"] + (" passed" if passed else " FAILED"), flush=True)
        result["status"] = "passed" if result["completed"] == result["total"] else "failed"
        if result["status"] == "failed":
            result["failure"] = "IMPORT_LIBRARY_SELECTION_MISMATCH"
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
