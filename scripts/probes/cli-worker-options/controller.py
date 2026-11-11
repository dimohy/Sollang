"""Exercise existing CLI products without building or modifying a compiler."""
import argparse
import hashlib
import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from verification_execution import VerificationExecution


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def worker_count(stdout):
    lines = stdout.splitlines()
    match = re.fullmatch(r"; sollang workers = ([1-9][0-9]*)", lines[0]) if lines else None
    return int(match[1]) if match else None


def validate_library_fixture(source, policy):
    """Check this small probe's ABI spellings against the canonical binding list."""
    binding = re.search(r'public static string LibraryAbiTypeBindings\(\) =>\s*"([^"\n]+)";',
                        policy.read_text(encoding="utf-8-sig"))
    if binding is None:
        raise ValueError("WORKER_LIBRARY_ABI_POLICY_SHAPE_CHANGED")
    allowed = {row.split(":", 1)[1] for row in binding[1].split("|")}
    declarations = [line for line in source.read_text(encoding="utf-8-sig").splitlines()
                    if line.startswith("public ")]
    signature = re.fullmatch(r"public increment value: (\w+) -> (\w+) => value \+ 1",
                             declarations[0]) if len(declarations) == 1 else None
    if signature is None or any(name not in allowed for name in signature.groups()):
        raise ValueError("WORKER_LIBRARY_FIXTURE_NOT_ABI_SAFE")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "native"), required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(strict=True), args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / "artifacts"):
        raise ValueError("WORKER_OPTIONS_OUTPUT_INVALID")
    contract_path = Path(__file__).with_name("contract.json")
    source = Path(__file__).with_name("library.slg")
    policy = ROOT / "src/Sollang.Compiler/Shared/Policies/TypeNamePolicy.cs"
    validate_library_fixture(source, policy)
    contract = json.loads(contract_path.read_text(encoding="utf-8-sig"))
    llvm = ROOT / ".tools/llvm-22.1.8"
    inputs = [Path(__file__), contract_path, source, policy, compiler,
              ROOT / "scripts/verification_execution.py", ROOT / "scripts/verification-process.ps1",
              *sorted((ROOT / "stdlib").rglob("*.slg")),
              *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-lib.exe", "llvm-split.exe")]]
    if args.mode == "managed":
        inputs += [compiler.with_suffix(ext) for ext in (".dll", ".deps.json", ".runtimeconfig.json")]
        inputs += [ROOT / "src/Sollang.Compiler" / name for name in
                   ("Cli/CliOptions.cs", "Cli/CompilerApp.cs", "Tooling/WindowsLinker.cs")]
    else:
        inputs.append(ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.slg")
    if any(not path.is_file() for path in inputs) or contract["schemaVersion"] != 1:
        raise ValueError("WORKER_OPTIONS_INPUT_INVALID")
    pins = {str(path): sha(path) for path in inputs}
    stable = lambda: all(Path(path).is_file() and sha(path) == digest for path, digest in pins.items())
    output.mkdir(parents=True)
    empty_root = output / "empty-stdlib"
    empty_root.mkdir()
    total = len(contract["cases"]) if args.mode == "managed" else len(contract["cases"]) * len(contract["nativeModes"]) + 1
    result = dict(schemaVersion=1, status="running", completed=0, total=total,
                  inputHashes=pins, cases=[], scope=contract["scope"], claimsGoalComplete=False)
    execution = VerificationExecution(ROOT, output, result, stable, sha)
    started = time.monotonic()
    error = None

    def run(command, name):
        remaining = contract["maximumTotalSeconds"] - (time.monotonic() - started)
        if remaining <= 0:
            raise ValueError("WORKER_OPTIONS_TOTAL_BUDGET_EXHAUSTED")
        return execution.run(command, output / name,
                             timeout=min(contract["maximumCommandSeconds"], remaining))

    def record(name, observed, passed, applied_workers=None):
        result["cases"].append(dict(id=name, passed=bool(passed), actualExit=observed.returncode,
                                    appliedWorkerLimit=applied_workers))
        result["completed"] += int(passed)
        execution.save()
        print(name + (" passed" if passed else " FAILED"), flush=True)

    def library_command(folder, value, keep_temps=False):
        command = [str(compiler), "build", str(source), "--library", "--target", "windows-x64",
                   "--llvm", str(llvm), "-o", str(folder / "library.dll"), "-O0"]
        if args.mode == "native":
            command += ["--stdlib", str(ROOT / "stdlib")]
        if keep_temps:
            command.append("--keep-temps")
        command.append("--jobs")
        if value is not None:
            command.append(value)
        return command

    try:
        if args.mode == "managed":
            for case in contract["cases"]:
                folder = output / case["id"]
                folder.mkdir()
                observed = run(library_command(folder, case["value"]), case["id"])
                if case["accepted"]:
                    product = folder / "library.dll"
                    passed = observed.returncode == 0 and not observed.stderr
                    passed &= product.is_file() and product.read_bytes()[:2] == b"MZ"
                    passed &= len(list(folder.glob("*.slglib.json"))) == 1
                else:
                    passed = observed.returncode == 1 and "--jobs" in observed.stderr
                    passed &= not observed.stdout and not list(folder.iterdir())
                record(case["id"], observed, passed)
        else:
            for mode in contract["nativeModes"]:
                for case in contract["cases"]:
                    name = mode["id"] + "-" + case["id"]
                    folder = output / name
                    folder.mkdir()
                    command = [str(compiler), mode["id"], str(folder / "cache.semantic"),
                               str(folder / "stage.semantic"), "-O0"]
                    if mode["library"]:
                        command += ["library.dll", str(folder / "interface.slglib.json")]
                    command += [str(empty_root), "--jobs"]
                    if case["value"] is not None:
                        command.append(case["value"])
                    observed = run(command, name)
                    applied = worker_count(observed.stdout)
                    passed = observed.returncode == 1 and not observed.stderr and not list(folder.iterdir())
                    if case["accepted"]:
                        passed &= applied is not None and 0 < applied <= int(case["value"])
                        passed &= "source root contains no readable .slg files" in observed.stdout
                    else:
                        passed &= observed.stdout == "; sollang error: --jobs expects a positive integer\n"
                    record(name, observed, passed, applied)
            folder = output / "public-library-one"
            folder.mkdir()
            observed = run(library_command(folder, "1", keep_temps=True), "public-library-one")
            product = folder / "library.dll"
            llvm_output = folder / "library.dll.ll"
            passed = observed.returncode == 0 and not observed.stderr
            passed &= product.is_file() and product.read_bytes()[:2] == b"MZ"
            passed &= len(list(folder.glob("*.slglib.json"))) == 1
            applied = worker_count(llvm_output.read_text(encoding="utf-8-sig")) if llvm_output.is_file() else None
            passed &= applied == 1
            record("public-library-one", observed, passed, applied)
        result["status"] = "passed" if result["completed"] == total else "failed"
        if result["status"] == "failed":
            result["failure"] = "CLI_WORKER_DISPATCH_MISMATCH"
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
