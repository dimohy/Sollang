#!/usr/bin/env python3
"""Verify nested field access after a method result with pinned compilers."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/probes/interpolation/c527-kind10-nested-member-negative.slg"
EXPECTED = (
    "sollang: semantic error at 19:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


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
    result = json.loads(args.build_result.read_text(encoding="utf-8"))
    if result["status"] != "passed" or not result["inputsStable"] or result["compilerSha256"] != sha(selfhost):
        raise ValueError("selfhost build result is invalid")
    inputs = [managed, selfhost, SOURCE, args.build_result.resolve(), Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for compiler_name, compiler in (("managed", managed), ("selfhost", selfhost)):
        executable = output / f"{compiler_name}.exe"
        command = [str(compiler), "build", str(SOURCE), "-o", str(executable),
                   "--target", "windows-x64"]
        if compiler_name == "selfhost":
            command.extend(["--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                            "--stdlib", str(ROOT / "stdlib"), "-O1"])
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
        (output / f"{compiler_name}.stdout.txt").write_bytes(completed.stdout)
        (output / f"{compiler_name}.stderr.txt").write_bytes(completed.stderr)
        runs[compiler_name] = {
            "exitCode": completed.returncode,
            "stdout": completed.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
            "stderr": completed.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n"),
            "executableExists": executable.is_file(),
        }
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and all(value == {
        "exitCode": 1, "stdout": "", "stderr": EXPECTED, "executableExists": False}
        for value in runs.values())
    record = {
        "schemaVersion": 1,
        "unit": "C527 kind-10 nested method-result field control",
        "status": "passed" if passed else "failed",
        "completed": int(passed),
        "total": 1,
        "inputStable": stable,
        "inputSha256": start,
        "runs": runs,
        "selfhostBuildResult": str(args.build_result.resolve()),
    }
    (output / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if not passed:
        raise ValueError(f"nested method result control failed: {output / 'result.json'}")
    print(f"PASS {output / 'result.json'}: exact paired nested field diagnostic")


if __name__ == "__main__":
    main()
