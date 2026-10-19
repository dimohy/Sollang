"""Record a small C# compiler native/diagnostic gate before SLG source edits."""

import argparse
import hashlib
import json
import subprocess
from completed_artifact_plan import initialize_output, cleanup_output
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LLVM = ROOT / ".tools/llvm-22.1.8"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def text(data: bytes) -> str:
    return data.decode("utf-8", "replace").replace("\r\n", "\n")


def repository_file(relative: str) -> Path:
    path = (ROOT / relative).resolve(strict=True)
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError(f"input must be a repository file: {relative}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--managed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    contract = args.contract.resolve(strict=True)
    compiler = args.managed.resolve(strict=True)
    output = args.output.resolve()
    if output.exists() or args.timeout < 1:
        parser.error("output must be fresh and timeout positive")
    plan = json.loads(contract.read_text(encoding="utf-8"))
    cases = plan.get("cases")
    if plan.get("schemaVersion") != 1 or not isinstance(cases, list) or not cases:
        parser.error("contract requires schemaVersion 1 and nonempty cases")
    if len({case.get("id") for case in cases}) != len(cases):
        parser.error("case IDs must be unique")
    inputs = [contract, compiler, Path(__file__).resolve(), LLVM / "bin/llvm-as.exe", LLVM / "bin/clang.exe"]
    inputs.extend(compiler.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json"))
    resolved = []
    for case in cases:
        if case.get("mode") not in ("positive", "negative") or not isinstance(case.get("id"), str):
            parser.error(f"invalid case: {case!r}")
        if case["mode"] == "negative" and case.get("expectedBuildExit") != 1:
            parser.error(f"negative case requires expectedBuildExit 1: {case['id']}")
        source = repository_file(case["source"])
        expected = repository_file(case["expected"])
        resolved.append((case, source, expected))
        inputs.extend((source, expected))
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    before = {str(path): digest(path) for path in inputs}
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    rows = []
    failure = None
    try:
        for case, source, expected in resolved:
            product = output / f"{case['id']}.exe"
            build = subprocess.run(
                [str(compiler), "build", str(source), "-o", str(product),
                 "--target", "windows-x64", "--llvm", str(LLVM), "-O1", "--keep-temps"],
                cwd=ROOT, capture_output=True, timeout=args.timeout, check=False,
            )
            (output / f"{case['id']}.build.stdout.txt").write_bytes(build.stdout)
            (output / f"{case['id']}.build.stderr.txt").write_bytes(build.stderr)
            native = None
            unexpected_build_diagnostics = (
                case["mode"] == "positive" and build.returncode == 0 and bool(build.stderr)
            )
            if case["mode"] == "positive" and build.returncode == 0 and not unexpected_build_diagnostics:
                native = subprocess.run([str(product)], cwd=ROOT, capture_output=True,
                                        timeout=args.timeout, check=False)
                (output / f"{case['id']}.native.stdout.txt").write_bytes(native.stdout)
                (output / f"{case['id']}.native.stderr.txt").write_bytes(native.stderr)
            expected_text = text(expected.read_bytes())
            passed = (
                build.returncode == 0 and native is not None and native.returncode == 0
                and text(native.stdout) == expected_text and not native.stderr
                if case["mode"] == "positive" else
                build.returncode == 1 and expected_text.strip() in text(build.stderr)
                and not product.exists()
            )
            rows.append({"id": case["id"], "mode": case["mode"], "passed": passed,
                         "expectedBuildExit": 0 if case["mode"] == "positive" else 1,
                         "buildExit": build.returncode,
                         "unexpectedBuildDiagnostics": unexpected_build_diagnostics,
                         "nativeExit": None if native is None else native.returncode})
            if not passed:
                failure = (f"MANAGED_POSITIVE_BUILD_DIAGNOSTICS: {case['id']}"
                           if unexpected_build_diagnostics else f"case failed: {case['id']}")
                break
    except Exception as error:
        failure = repr(error)
    after = {str(path): digest(path) for path in inputs}
    result = {"schemaVersion": 1, "gate": plan.get("gate"),
              "status": "passed" if failure is None and before == after and len(rows) == len(cases) else "failed",
              "completed": sum(row["passed"] for row in rows), "total": len(cases),
              "inputHashes": before,
              "inputHashesStart": before, "inputHashesEnd": after, "inputsStable": before == after,
              "cases": rows, "failure": failure}
    result_path = output / "result.json"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[managed compiler focused] {result['status']} {result['completed']}/{result['total']}; result={result_path}")
    if result["status"] == "passed":
        cleanup_output(ROOT, output)
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
