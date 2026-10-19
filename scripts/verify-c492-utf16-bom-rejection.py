"""Check strict UTF-8 input parity for UTF-16 BOM sources."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TEXT = "main { 1 -> println }\n"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], stdin: bytes | None = None) -> dict:
    process = subprocess.run(command, input=stdin, capture_output=True, timeout=120, cwd=ROOT)
    return {
        "exitCode": process.returncode,
        "stdout": process.stdout.decode("utf-8", "replace").replace("\r\n", "\n"),
        "stderr": process.stderr.decode("utf-8", "replace").replace("\r\n", "\n"),
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
    sources = {
        "utf16le": b"\xff\xfe" + TEXT.encode("utf-16-le"),
        "utf16be": b"\xfe\xff" + TEXT.encode("utf-16-be"),
        "utf8": b"\xef\xbb\xbf" + TEXT.encode("utf-8"),
    }
    paths = {name: output / f"{name}.slg" for name in sources}
    for name, path in paths.items():
        path.write_bytes(sources[name])
    inputs += list(paths.values())
    before = {str(path): sha256(path) for path in inputs}
    cases = tuple((f"{kind}-{encoding}", kind, encoding) for encoding in ("utf16le", "utf16be") for kind in ("format-stdin", "format-file", "build")) + (("format-stdin-utf8-control", "format-stdin", "utf8"),)
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id, kind, encoding in cases:
            row = {"id": case_id, "sourceSha256": before[str(paths[encoding])]}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                product = output / f"{case_id}-{label}.exe"
                if kind == "format-stdin":
                    observed = run([str(compiler), "format", "--stdin"], sources[encoding])
                elif kind == "format-file":
                    observed = run([str(compiler), "format", "--check", str(paths[encoding])])
                else:
                    command = [str(compiler), "build", str(paths[encoding]), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                    observed = run(command)
                    observed["productExists"] = product.exists()
                row[label] = observed
            left, right = row["managed"], row["selfhost"]
            if encoding == "utf8":
                row["passed"] = left == right == {"exitCode": 0, "stdout": TEXT, "stderr": ""}
            else:
                row["passed"] = (
                    left == right
                    and left["exitCode"] == 1
                    and left["stdout"] == ""
                    and left["stderr"] == "sollang: lex error at 1:1: unexpected character '�'\n"
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
    print(f"[C492 strict UTF-8] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
