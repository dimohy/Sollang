"""Run the focused C488 build/format diagnostic comparison."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalize(data: bytes) -> str:
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
        parser.error("managed and selfhost compilers must be separate artifacts")
    llvm = ROOT / ".tools/llvm-22.1.8"
    stdlib = ROOT / "stdlib"
    emoji = ROOT / "scripts/probes/interpolation/c487-emoji-binding-name.slg"
    symbol = ROOT / "scripts/probes/interpolation/c487-symbol-binding-name.slg"
    duplicate_label = ROOT / "scripts/probes/type-delimiters/duplicate-product-label.slg"
    empty_label = ROOT / "scripts/probes/type-delimiters/empty-product-label.slg"
    inputs = [managed, selfhost, emoji, symbol, duplicate_label, empty_label, Path(__file__).resolve()]
    inputs += sorted(stdlib.rglob("*.slg"))
    inputs += [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    inputs += [llvm / "bin/clang.exe"]
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    before = {str(path): sha256(path) for path in inputs}
    output.mkdir(parents=True)
    cases = (
        ("emoji-build", "build", emoji, None),
        ("symbol-build", "build", symbol, None),
        ("duplicate-label-build", "build", duplicate_label, None),
        ("empty-label-build", "build", empty_label, None),
        ("ascii-format", "format", None, b"main { 1 => @ }\n"),
        ("emoji-format", "format", None, emoji.read_bytes()),
    )
    rows = []
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": rows}
    result_path = output / "result.json"
    try:
        for case_id, kind, source, stdin in cases:
            row = {"id": case_id, "kind": kind}
            if source is not None:
                row["source"] = str(source.relative_to(ROOT)).replace("\\", "/")
            if stdin is not None:
                row["stdinSha256"] = hashlib.sha256(stdin).hexdigest().upper()
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                if kind == "build":
                    product = output / f"{case_id}-{label}.exe"
                    command = [str(compiler), "build", str(source), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                else:
                    command = [str(compiler), "format", "--stdin"]
                completed = subprocess.run(command, input=stdin, capture_output=True, timeout=120, cwd=ROOT)
                (output / f"{case_id}-{label}.stdout").write_bytes(completed.stdout)
                (output / f"{case_id}-{label}.stderr").write_bytes(completed.stderr)
                row[label] = {
                    "exitCode": completed.returncode,
                    "stdout": normalize(completed.stdout),
                    "stderr": normalize(completed.stderr),
                    "productExists": product.exists() if kind == "build" else False,
                }
            left, right = row["managed"], row["selfhost"]
            row["passed"] = (
                left["exitCode"] == right["exitCode"] == 1
                and left["stdout"] == right["stdout"] == ""
                and left["stderr"] == right["stderr"]
                and not left["productExists"]
                and not right["productExists"]
            )
            rows.append(row)
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = "passed" if "error" not in result and before == after and len(rows) == len(cases) and all(row["passed"] for row in rows) else "failed"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[C488 diagnostic parity] {result['status']} {sum(row['passed'] for row in rows)}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
