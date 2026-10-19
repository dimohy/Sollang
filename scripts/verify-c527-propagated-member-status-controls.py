#!/usr/bin/env python3
"""Check non-Result and outside-Result propagation before member display."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-status-managed-first-20260929-01")
CASES = {
    "outside-result": (ROOT / "scripts/probes/interpolation/c527-propagated-member-outside-result.slg",
                       "sollang: semantic error at 1:13: [module '<main>'] '?' can only be used inside a function returning Result<T, E>\n"),
    "non-result": (ROOT / "scripts/probes/interpolation/c527-propagated-member-non-result.slg",
                   "sollang: semantic error at 1:13: [module '<main>'] '?' expects Result<T, E> but received Point\n"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ("managed", "selfhost", "build-result", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    build_path = args.build_result.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    build = json.loads(build_path.read_text(encoding="utf-8"))
    if build["status"] != "passed" or not build["inputsStable"] or build["compilerSha256"] != sha(selfhost):
        raise ValueError("selfhost compiler build is invalid")
    inputs = [managed, selfhost, build_path,
              ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
              ROOT / "selfhost/semantic/interpolation_inference.slg",
              ROOT / "selfhost/llvm/text/context_prepare.slg", Path(__file__).resolve()]
    for case, (source, expected) in CASES.items():
        managed_error = MANAGED_OUTPUT / f"{case}.build.stderr.txt"
        inputs += [source, managed_error, MANAGED_OUTPUT / f"{case}.build.stdout.txt"]
        if managed_error.read_text(encoding="utf-8").replace("\r\n", "\n") != expected:
            raise ValueError(f"C# first {case} diagnostic changed")
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for case, (source, expected) in CASES.items():
        executable = output / f"{case}.exe"
        command = [str(selfhost), "build", str(source), "-o", str(executable),
                   "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                   "--stdlib", str(ROOT / "stdlib"), "-O1"]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
        (output / f"{case}.build.stdout.txt").write_bytes(result.stdout)
        (output / f"{case}.build.stderr.txt").write_bytes(result.stderr)
        actual = result.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n")
        runs[case] = {"exitCode": result.returncode, "stderr": actual,
                      "expected": expected, "executableExists": executable.is_file(),
                      "passed": result.returncode != 0 and actual == expected and not executable.is_file()}
    stable = start == {str(path): sha(path) for path in inputs}
    complete = sum(int(item["passed"]) for item in runs.values()) if stable else 0
    record = {"schemaVersion": 1, "unit": "C527 propagated Result failure status controls",
              "status": "passed" if complete == len(CASES) else "failed",
              "completed": complete, "total": len(CASES), "inputsStable": stable,
              "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {complete}/{len(CASES)} {output / 'result.json'}")
    if complete != len(CASES):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
