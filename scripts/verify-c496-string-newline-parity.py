"""Compare ordinary and raw string newline boundaries in both compilers."""

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
    stdlib = ROOT / "stdlib"
    llvm = ROOT / ".tools/llvm-22.1.8"
    runtime = [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    inputs = [managed, selfhost, Path(__file__).resolve(), llvm / "bin/clang.exe", *runtime]
    inputs += sorted(stdlib.rglob("*.slg"))
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    cases = (
        ("lf", b'main { "a\nb" -> println }\n', "format"),
        ("cr", b'main { "a\rb" -> println }\n', "format"),
        ("crlf", b'main { "a\r\nb" -> println }\n', "format"),
        ("quoted-control", b'main { "ab" -> println }\n', "format"),
        ("raw-control", b'main { """a\nb""" -> println }\n', "format"),
        ("lf-build", b'main { "a\nb" -> println }\n', "build"),
    )
    paths = {case_id: output / f"{case_id}.slg" for case_id, _, _ in cases}
    for case_id, source, _ in cases:
        paths[case_id].write_bytes(source)
    inputs += list(paths.values())
    before = {str(path): sha256(path) for path in inputs}
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id, source, kind in cases:
            row = {"id": case_id, "sourceSha256": before[str(paths[case_id])]}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                if kind == "format":
                    observed = run([str(compiler), "format", "--stdin"], source)
                else:
                    product = output / f"{case_id}-{label}.exe"
                    command = [str(compiler), "build", str(paths[case_id]), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                    observed = run(command)
                    observed["productExists"] = product.exists()
                row[label] = observed
            left, right = row["managed"], row["selfhost"]
            if case_id in ("quoted-control", "raw-control"):
                row["passed"] = left == right and left["exitCode"] == 0 and not left["stderr"] and bool(left["stdout"])
            else:
                row["passed"] = (
                    left == right
                    and left["exitCode"] == 1
                    and left["stdout"] == ""
                    and left["stderr"] == "sollang: lex error at 1:8: unterminated string literal\n"
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
    print(f"[C496 string newline] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
