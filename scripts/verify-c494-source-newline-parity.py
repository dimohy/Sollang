"""Compare CR, CRLF, comment, and LF source boundaries in both compilers."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LF = bytes([10])
CR = bytes([13])


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], stdin: bytes | None = None) -> dict:
    completed = subprocess.run(command, input=stdin, capture_output=True, timeout=120, cwd=ROOT)
    return {
        "exitCode": completed.returncode,
        "stdout": completed.stdout.decode("utf-8", "replace").replace("\r\n", "\n"),
        "stderr": completed.stderr.decode("utf-8", "replace").replace("\r\n", "\n"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--managed", type=Path, required=True)
    parser.add_argument("--selfhost", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    if managed == selfhost:
        parser.error("compilers must be separate artifacts")
    runtime = [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    llvm = ROOT / ".tools/llvm-22.1.8"
    stdlib = ROOT / "stdlib"
    inputs = [managed, selfhost, Path(__file__).resolve(), llvm / "bin/clang.exe", *runtime]
    inputs += sorted(stdlib.rglob("*.slg"))
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    lines = (b"main {", b"1 -> println", b"2 -> println", b"}")
    raw_cases = (
        ("cr-statements", CR.join(lines) + CR, "format"),
        ("crlf-statements", (CR + LF).join(lines) + CR + LF, "format"),
        ("cr-comment", CR.join((b"main {", b"# note", b"1 -> println", b"}")) + CR, "format"),
        ("lf-control", LF.join(lines) + LF, "format"),
        ("cr-native", CR.join(lines) + CR, "build"),
    )
    for case_id, source, _ in raw_cases:
        (output / f"{case_id}.slg").write_bytes(source)
    inputs += [output / f"{case_id}.slg" for case_id, _, _ in raw_cases]
    before = {str(path): sha256(path) for path in inputs}
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id, source, kind in raw_cases:
            row = {"id": case_id, "sourceSha256": before[str(output / f"{case_id}.slg")]}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                if kind == "format":
                    observed = run([str(compiler), "format", "--stdin"], source)
                else:
                    product = output / f"{case_id}-{label}.exe"
                    command = [str(compiler), "build", str(output / f"{case_id}.slg"), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                    observed = run(command)
                    observed["productExists"] = product.is_file()
                    if product.is_file():
                        observed["native"] = run([str(product)])
                row[label] = observed
            left, right = row["managed"], row["selfhost"]
            row["passed"] = (
                left == right and left == {"exitCode": 0, "stdout": "main {\n    1 -> println\n    2 -> println\n}\n", "stderr": ""}
                if kind == "format" and case_id != "cr-comment"
                else left == right and left["exitCode"] == 0 and left["stdout"] == "main {\n    # note\n    1 -> println\n}\n" and left["stderr"] == ""
                if kind == "format"
                else left["exitCode"] == right["exitCode"] == 0
                and left["productExists"] and right["productExists"]
                and left["native"] == right["native"] == {"exitCode": 0, "stdout": "1\n2\n", "stderr": ""}
                and not left["stderr"] and not right["stderr"]
            )
            result["cases"].append(row)
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = "passed" if "error" not in result and before == after and len(result["cases"]) == len(raw_cases) and all(row["passed"] for row in result["cases"]) else "failed"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[C494 source newline] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(raw_cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
