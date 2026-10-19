"""Check UTF-8 BOM source decoding in the managed and self-host CLIs."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE = b"main { 1 -> println }\n"


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
    bom = output / "utf8-bom.slg"
    plain = output / "plain.slg"
    bom.write_bytes(b"\xef\xbb\xbf" + SOURCE)
    plain.write_bytes(SOURCE)
    inputs += [bom, plain]
    before = {str(path): sha256(path) for path in inputs}
    cases = ("format-stdin-utf8-bom", "format-check-utf8-bom", "build-utf8-bom", "format-stdin-plain-control")
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id in cases:
            row = {"id": case_id}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                product = output / f"{case_id}-{label}.exe"
                if case_id.startswith("format-stdin"):
                    source = bom if "bom" in case_id else plain
                    observed = run([str(compiler), "format", "--stdin"], source.read_bytes())
                elif case_id.startswith("format-check"):
                    observed = run([str(compiler), "format", "--check", str(bom)])
                else:
                    command = [str(compiler), "build", str(bom), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                    observed = run(command)
                    observed["productExists"] = product.is_file()
                    if product.is_file():
                        observed["productSha256"] = sha256(product)
                        observed["native"] = run([str(product)])
                row[label] = observed
            left, right = row["managed"], row["selfhost"]
            if case_id == "build-utf8-bom":
                row["passed"] = (
                    left["exitCode"] == right["exitCode"] == 0
                    and left["productExists"] and right["productExists"]
                    and left["native"] == right["native"] == {"exitCode": 0, "stdout": "1\n", "stderr": ""}
                    and not left["stderr"] and not right["stderr"]
                )
            else:
                expected = SOURCE.decode() if case_id.startswith("format-stdin") else ""
                row["passed"] = left == right == {"exitCode": 0, "stdout": expected, "stderr": ""}
            result["cases"].append(row)
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = "passed" if "error" not in result and before == after and len(result["cases"]) == len(cases) and all(row["passed"] for row in result["cases"]) else "failed"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[C491 UTF-8 BOM] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
