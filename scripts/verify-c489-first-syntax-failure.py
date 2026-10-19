"""Compare ordered multi-file syntax failures and retained single-file diagnostics."""

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
        parser.error("compilers must be separate artifacts")
    duplicate = ROOT / "scripts/probes/type-delimiters/duplicate-product-label.slg"
    empty = ROOT / "scripts/probes/type-delimiters/empty-product-label.slg"
    stdlib = ROOT / "stdlib"
    llvm = ROOT / ".tools/llvm-22.1.8"
    inputs = [managed, selfhost, duplicate, empty, Path(__file__).resolve(), llvm / "bin/clang.exe"]
    inputs += [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    inputs += sorted(stdlib.rglob("*.slg"))
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    before = {str(path): sha256(path) for path in inputs}
    output.mkdir(parents=True)
    cases = (
        ("duplicate-then-empty", (duplicate, empty)),
        ("empty-then-duplicate", (empty, duplicate)),
        ("duplicate-single", (duplicate,)),
        ("empty-single", (empty,)),
    )
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case_id, sources in cases:
            row = {"id": case_id, "sources": [str(path.relative_to(ROOT)).replace("\\", "/") for path in sources]}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                product = output / f"{case_id}-{label}.exe"
                command = [str(compiler), "build", *(str(path) for path in sources), "-o", str(product), "--target", "windows-x64"]
                if label == "selfhost":
                    command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                run = subprocess.run(command, capture_output=True, timeout=120, cwd=ROOT)
                (output / f"{case_id}-{label}.stdout").write_bytes(run.stdout)
                (output / f"{case_id}-{label}.stderr").write_bytes(run.stderr)
                row[label] = {"exitCode": run.returncode, "stdout": normalize(run.stdout), "stderr": normalize(run.stderr), "productExists": product.exists()}
            left, right = row["managed"], row["selfhost"]
            row["passed"] = (
                left["exitCode"] == right["exitCode"] == 1
                and left["stdout"] == right["stdout"] == ""
                and left["stderr"] == right["stderr"]
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
    print(f"[C489 first syntax failure] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
