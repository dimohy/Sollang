"""Compare the numeric lexer boundary for ASCII and Unicode decimal digits."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


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
    llvm = ROOT / ".tools/llvm-22.1.8"
    stdlib = ROOT / "stdlib"
    runtime = [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    inputs = [managed, selfhost, Path(__file__).resolve(), llvm / "bin/clang.exe", *runtime]
    inputs += sorted(stdlib.rglob("*.slg"))
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    cases = (
        ("arabic-indic", "١", "format"),
        ("devanagari", "१", "format"),
        ("fullwidth", "１", "format"),
        ("ascii-control", "1", "format"),
        ("separator-control", "1_000", "format"),
        ("fraction-control", "1.25", "format"),
        ("exponent-control", "1e2", "format"),
        ("fraction-exponent-control", "1_000.25e+2", "format"),
        ("arabic-indic-build", "١", "build"),
    )
    paths = {case_id: output / f"{case_id}.slg" for case_id, _, _ in cases}
    for case_id, digit, _ in cases:
        paths[case_id].write_text(f"main {{ {digit} -> println }}\n", encoding="utf-8")
    inputs += list(paths.values())
    before = {str(path): sha256(path) for path in inputs}
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id, digit, kind in cases:
            row = {"id": case_id, "sourceSha256": before[str(paths[case_id])]}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                if kind == "format":
                    observed = run([str(compiler), "format", "--stdin"], paths[case_id].read_bytes())
                else:
                    product = output / f"{case_id}-{label}.exe"
                    command = [str(compiler), "build", str(paths[case_id]), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                    observed = run(command)
                    observed["productExists"] = product.exists()
                row[label] = observed
            left, right = row["managed"], row["selfhost"]
            if digit.isascii():
                row["passed"] = left == right == {"exitCode": 0, "stdout": f"main {{ {digit} -> println }}\n", "stderr": ""}
            else:
                row["passed"] = (
                    left == right
                    and left["exitCode"] == 1
                    and left["stdout"] == ""
                    and left["stderr"] == f"sollang: lex error at 1:8: unexpected character '{digit}'\n"
                    and (kind != "build" or not left["productExists"])
                )
            result["cases"].append(row)
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = "passed" if "error" not in result and before == after and len(result["cases"]) == len(cases) and all(row["passed"] for row in result["cases"]) else "failed"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[C495 decimal boundary] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
