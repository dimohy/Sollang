#!/usr/bin/env python3
"""Verify the C# and SLG unknown nominal type diagnostic before LLVM."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/probes/interpolation/c527-struct-literal-unknown-type.slg"
COMPARISON = ROOT / "artifacts/scratch/c527-struct-literal-unknown-type-source-comparison-20260929-01.json"
FIRST = ROOT / "artifacts/scratch/c527-struct-literal-unknown-type-managed-first-20260929-01.json"
EXPECTED = "sollang: semantic error at 1:2: [module '<main>'] unknown struct type 'MissingPoint'\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], output: Path, label: str) -> dict:
    process = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(process.stdout)
    (output / f"{label}.stderr.txt").write_bytes(process.stderr)
    return {"exitCode": process.returncode,
            "stdout": process.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
            "stderr": process.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n")}


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ("managed", "selfhost", "build-result", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    build_path = args.build_result.resolve(strict=True)
    build = json.loads(build_path.read_text(encoding="utf-8"))
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    if (build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(selfhost)
            or comparison["status"] != "passed" or first["status"] != "passed"
            or first["expected"] != EXPECTED):
        raise ValueError("build or C# first comparison evidence is invalid")
    inputs = [managed, selfhost, build_path, COMPARISON, FIRST, SOURCE,
              ROOT / "selfhost/semantic/expression_type_ids.slg",
              ROOT / "selfhost/llvm/emitter/diagnostics.slg", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        executable = output / f"{name}.exe"
        command = [str(compiler), "build", str(SOURCE), "-o", str(executable), "--target", "windows-x64"]
        if name == "selfhost":
            command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                        "--stdlib", str(ROOT / "stdlib"), "-O1"]
        runs[name] = run(command, output, name)
        runs[name]["executableExists"] = executable.exists()
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and all(run["stderr"] == EXPECTED and run["exitCode"] != 0
                            and not run["executableExists"] for run in runs.values())
    record = {"schemaVersion": 1, "unit": "C527 unknown nominal receiver paired diagnostic",
              "status": "passed" if passed else "failed", "completed": 1 if passed else 0,
              "total": 1, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
