"""Run a small declarative lexer contract against managed and self-host CLIs."""

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
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--managed", type=Path, required=True)
    parser.add_argument("--selfhost", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    contract_path = args.contract.resolve(strict=True)
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    cases = contract.get("cases")
    if contract.get("schemaVersion") != 1 or not isinstance(cases, list) or not cases:
        parser.error("contract must have schemaVersion 1 and a nonempty cases list")
    if len({case.get("id") for case in cases}) != len(cases):
        parser.error("case IDs must be unique")
    for case in cases:
        if (not isinstance(case.get("id"), str) or not case["id"].replace("-", "").isalnum()
                or case.get("mode") not in ("format-stdin", "build")
                or not isinstance(case.get("source"), str)
                or not isinstance(case.get("expected"), dict)
                or set(case["expected"]) != {"exitCode", "stdout", "stderr"}):
            parser.error(f"invalid case contract: {case!r}")
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
    inputs = [managed, selfhost, contract_path, Path(__file__).resolve(), llvm / "bin/clang.exe", *runtime]
    inputs += sorted(stdlib.rglob("*.slg"))
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    paths = {}
    for case in cases:
        path = output / f"{case['id']}.slg"
        path.write_bytes(case["source"].encode("utf-8"))
        paths[case["id"]] = path
    inputs += list(paths.values())
    before = {str(path): sha256(path) for path in inputs}
    result = {"schemaVersion": 1, "contract": str(contract_path), "status": "running", "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case in cases:
            row = {"id": case["id"], "sourceSha256": before[str(paths[case["id"]])]}
            for label, compiler in (("managed", managed), ("selfhost", selfhost)):
                if case["mode"] == "format-stdin":
                    observed = run([str(compiler), "format", "--stdin"], paths[case["id"]].read_bytes())
                else:
                    product = output / f"{case['id']}-{label}.exe"
                    command = [str(compiler), "build", str(paths[case["id"]]), "-o", str(product), "--target", "windows-x64"]
                    if label == "selfhost":
                        command += ["--stdlib", str(stdlib), "--llvm", str(llvm)]
                    observed = run(command)
                    observed["productExists"] = product.is_file()
                row[label] = observed
            expected = case["expected"]
            row["passed"] = all(
                all(observed[key] == value for key, value in expected.items())
                and (case["mode"] != "build" or not observed["productExists"])
                for observed in (row["managed"], row["selfhost"])
            ) and row["managed"] == row["selfhost"]
            result["cases"].append(row)
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = "passed" if "error" not in result and before == after and len(result["cases"]) == len(cases) and all(row["passed"] for row in result["cases"]) else "failed"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[lexer paired cases] {result['status']} {sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
