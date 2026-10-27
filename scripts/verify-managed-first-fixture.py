"""Prove a focused C# compiler contract before a corresponding SLG edit."""

import argparse
import hashlib
import json
import subprocess
from completed_artifact_plan import initialize_output, cleanup_output
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--managed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append")
    args = parser.parse_args()
    contract = args.contract.resolve(strict=True)
    managed = args.managed.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    fixture = json.loads(contract.read_text(encoding="utf-8"))
    cases = fixture.get("cases")
    if fixture.get("schemaVersion") != 1 or not isinstance(cases, list) or not cases:
        parser.error("contract requires schemaVersion 1 and nonempty cases")
    if len({case.get("id") for case in cases}) != len(cases):
        parser.error("case IDs must be unique")
    for case in cases:
        if (not isinstance(case.get("id"), str) or not case["id"].replace("-", "").isalnum()
                or case.get("mode") != "format-stdin" or not isinstance(case.get("source"), str)
                or set(case.get("expected", {})) != {"exitCode", "stdout", "stderr"}):
            parser.error(f"invalid focused case: {case!r}")
    runtime = [managed.with_suffix(suffix) for suffix in (".dll", ".deps.json", ".runtimeconfig.json")]
    inputs = [contract, managed, *runtime, Path(__file__).resolve()]
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    reusable = (None if args.reusable_compiler_directory is None
                else [path.resolve(strict=True) for path in args.reusable_compiler_directory])
    initialize_output(ROOT, output, reusable_directories=reusable)
    output.mkdir(parents=True)
    source_paths = {}
    for case in cases:
        path = output / f"{case['id']}.slg"
        path.write_bytes(case["source"].encode("utf-8"))
        source_paths[case["id"]] = path
    inputs += list(source_paths.values())
    before = {str(path): sha256(path) for path in inputs}
    result = {"schemaVersion": 1, "phase": "managed-first", "status": "running",
              "contract": str(contract), "inputHashesStart": before, "cases": []}
    result_path = output / "result.json"
    try:
        for case in cases:
            process = subprocess.run([str(managed), "format", "--stdin"],
                                     input=source_paths[case["id"]].read_bytes(),
                                     capture_output=True, timeout=120, cwd=ROOT)
            observed = {"exitCode": process.returncode,
                        "stdout": process.stdout.decode("utf-8", "replace").replace("\r\n", "\n"),
                        "stderr": process.stderr.decode("utf-8", "replace").replace("\r\n", "\n")}
            result["cases"].append({"id": case["id"], "sourceSha256": before[str(source_paths[case["id"]])],
                                    "passed": observed == case["expected"], "observed": observed})
            result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = ("passed" if "error" not in result and before == after
                        and len(result["cases"]) == len(cases)
                        and all(row["passed"] for row in result["cases"]) else "failed")
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[managed first] {result['status']} "
          f"{sum(row['passed'] for row in result['cases'])}/{len(cases)}; result={result_path}")
    if result["status"] == "passed":
        cleanup_output(ROOT, output, reusable_directories=reusable)
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
