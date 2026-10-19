#!/usr/bin/env python3
"""Match C# single index error after an instance-method result."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-invalid-bool.slg"
COMPARISON = ROOT / "artifacts/scratch/c527-kind10-index-error-source-comparison-20260929-01.json"
MANAGED_ERROR = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-invalid-index-managed-first-20260929-01\build.stderr.txt")
EXPECTED = "sollang: semantic error at 1:24: [module '<main>'] index must be Int\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


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
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    build_result = json.loads(build_result_path.read_text(encoding="utf-8"))
    if (comparison["status"] != "passed" or comparison["inputSha256"][str(SOURCE)] != sha(SOURCE)
            or comparison["inputSha256"][str(MANAGED_ERROR)] != sha(MANAGED_ERROR)
            or MANAGED_ERROR.read_text(encoding="utf-8").replace("\r\n", "\n") != EXPECTED
            or build_result["status"] != "passed" or not build_result["inputsStable"]
            or build_result["compilerSha256"] != sha(selfhost)):
        raise ValueError("C# first, comparison, or build result changed")
    inputs = [managed, selfhost, build_result_path, SOURCE, COMPARISON, MANAGED_ERROR,
              ROOT / "selfhost/semantic/interpolation_inference.slg",
              ROOT / "selfhost/llvm/text/context_prepare.slg", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    executable = output / "case.exe"
    completed = subprocess.run([str(selfhost), "build", str(SOURCE), "-o", str(executable),
                                "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                                "--stdlib", str(ROOT / "stdlib"), "-O1"],
                               cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / "build.stdout.txt").write_bytes(completed.stdout)
    (output / "build.stderr.txt").write_bytes(completed.stderr)
    actual = completed.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n")
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and completed.returncode != 0 and not executable.exists() and actual == EXPECTED
    record = {"schemaVersion": 1, "unit": "C527 method-result indexed invalid-index precedence",
              "status": "passed" if passed else "failed", "completed": 1 if passed else 0,
              "total": 1, "inputsStable": stable, "inputSha256": start,
              "selfhostExitCode": completed.returncode, "selfhostStderr": actual,
              "managedStderr": EXPECTED}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
