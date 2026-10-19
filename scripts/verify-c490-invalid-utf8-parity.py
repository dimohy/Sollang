"""Compare strict source-byte diagnostics in managed and self-host CLIs."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(data: bytes) -> str:
    return data.decode("utf-8", "replace").replace("\r\n", "\n")


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
    managed_runtime = [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    inputs = [managed, selfhost, Path(__file__).resolve(), llvm / "bin/clang.exe", *managed_runtime]
    inputs += sorted(stdlib.rglob("*.slg"))
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    invalid_ff = output / "invalid-ff.slg"
    truncated_e2 = output / "truncated-e2.slg"
    after_emoji = output / "invalid-after-emoji.slg"
    next_line = output / "invalid-next-line.slg"
    invalid_ff.write_bytes(b"main { \xff }\n")
    truncated_e2.write_bytes(b"main { \xe2\x82 }\n")
    after_emoji.write_bytes(b'main { "' + "🙂".encode("utf-8") + b'" \xff }\n')
    next_line.write_bytes(b"main {\n \xff\n}\n")
    inputs += [invalid_ff, truncated_e2, after_emoji, next_line]
    before = {str(path): sha256(path) for path in inputs}
    cases = (
        ("build-invalid-ff", "build", invalid_ff),
        ("build-truncated-e2", "build", truncated_e2),
        ("build-invalid-after-emoji", "build", after_emoji),
        ("build-invalid-next-line", "build", next_line),
        ("format-stdin-invalid-ff", "format-stdin", invalid_ff),
        ("format-file-invalid-ff", "format-file", invalid_ff),
    )
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id, kind, source in cases:
            row = {"id": case_id, "kind": kind, "sourceSha256": before[str(source)]}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                product = output / f"{case_id}-{label}.exe"
                if kind == "build":
                    command = [str(compiler), "build", str(source), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                    stdin = None
                elif kind == "format-stdin":
                    command = [str(compiler), "format", "--stdin"]
                    stdin = source.read_bytes()
                else:
                    command = [str(compiler), "format", "--check", str(source)]
                    stdin = None
                run = subprocess.run(command, input=stdin, capture_output=True, timeout=120, cwd=ROOT)
                (output / f"{case_id}-{label}.stdout").write_bytes(run.stdout)
                (output / f"{case_id}-{label}.stderr").write_bytes(run.stderr)
                row[label] = {
                    "exitCode": run.returncode,
                    "stdout": normalized(run.stdout),
                    "stderr": normalized(run.stderr),
                    "productExists": product.exists(),
                }
            left, right = row["managed"], row["selfhost"]
            row["passed"] = (
                left["exitCode"] == right["exitCode"] == 1
                and left["stdout"] == right["stdout"] == ""
                and left["stderr"] == right["stderr"]
                and left["stderr"].startswith("sollang: lex error at ")
                and not left["productExists"]
                and not right["productExists"]
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
    print(f"[C490 invalid UTF-8] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
