#!/usr/bin/env python3
"""Verify a field after an indexed field of an instance-method result."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POSITIVE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-chained-field-positive.slg"
NEGATIVE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-chained-field-negative.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-indexed-chain-managed-first-20260929-01")
EXPECTED_ERROR = "sollang: semantic error at 19:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def run(command: list[str], output: Path, label: str) -> dict:
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(completed.stdout)
    (output / f"{label}.stderr.txt").write_bytes(completed.stderr)
    return {"exitCode": completed.returncode,
            "stdout": completed.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
            "stderr": completed.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n")}


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ("managed", "selfhost", "build-result", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    build_result_path = args.build_result.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    build_result = json.loads(build_result_path.read_text(encoding="utf-8"))
    if (build_result["status"] != "passed" or not build_result["inputsStable"]
            or build_result["compilerSha256"] != sha(selfhost)
            or contents(MANAGED_OUTPUT / "positive.build.stderr.txt") != ""
            or contents(MANAGED_OUTPUT / "positive.native.stdout.txt") != "value=5\n"
            or contents(MANAGED_OUTPUT / "positive.native.stderr.txt") != ""
            or contents(MANAGED_OUTPUT / "negative.build.stderr.txt") != EXPECTED_ERROR):
        raise ValueError("managed-first or selfhost build evidence changed")
    inputs = [managed, selfhost, build_result_path, POSITIVE, NEGATIVE,
              MANAGED_OUTPUT / "positive.exe", MANAGED_OUTPUT / "positive.native.stdout.txt",
              MANAGED_OUTPUT / "positive.native.stderr.txt", MANAGED_OUTPUT / "positive.build.stderr.txt",
              MANAGED_OUTPUT / "negative.build.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for case, source in (("positive", POSITIVE), ("negative", NEGATIVE)):
        executable = output / f"{case}.exe"
        runs[case] = run([str(selfhost), "build", str(source), "-o", str(executable),
                          "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                          "--stdlib", str(ROOT / "stdlib"), "-O1"], output, f"{case}-build")
        runs[case]["executableExists"] = executable.is_file()
        if case == "positive" and executable.is_file():
            runs["native"] = run([str(executable)], output, "positive-native")
    stable = start == {str(path): sha(path) for path in inputs}
    passed = (stable and runs["positive"]["exitCode"] == 0
              and runs["positive"]["executableExists"]
              and runs["native"] == {"exitCode": 0, "stdout": "value=5\n", "stderr": ""}
              and runs["negative"]["exitCode"] != 0
              and not runs["negative"]["executableExists"]
              and runs["negative"]["stderr"] == EXPECTED_ERROR)
    record = {"schemaVersion": 1, "unit": "C527 method-result indexed chained field",
              "status": "passed" if passed else "failed", "completed": 1 if passed else 0,
              "total": 1, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
