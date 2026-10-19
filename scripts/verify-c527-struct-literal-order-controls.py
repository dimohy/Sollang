#!/usr/bin/env python3
"""Check source ordered nominal initialization and retained contextual errors."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ORDER = ROOT / "scripts/probes/interpolation/c527-struct-literal-initializer-source-order.slg"
MANAGED_RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-order-managed-first-20260929-01\order.stderr.txt")
CASES = {
    "order": (ORDER, "sollang: semantic error at 1:12: [module '<main>'] field 'b' expects Bool, got Int\n"),
    "contextualMissing": (ROOT / "examples/regression/diagnostics/2047-interpolated-contextual-struct-key-missing-field.slg",
                          "contextual SymbolKey literal is missing field 'id'"),
    "contextualDuplicate": (ROOT / "examples/regression/diagnostics/2048-interpolated-contextual-struct-key-duplicate-field.slg",
                            "field 'scope' is initialized more than once"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--selfhost", type=Path, required=True)
    parser.add_argument("--build-result", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    compiler = args.selfhost.resolve(strict=True)
    build_path = args.build_result.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    build = json.loads(build_path.read_text(encoding="utf-8"))
    if build["status"] != "passed" or not build["inputsStable"] or build["compilerSha256"] != sha(compiler):
        raise ValueError("self-host compiler build evidence is invalid")
    if MANAGED_RUN.read_text(encoding="utf-8").replace("\r\n", "\n") != CASES["order"][1]:
        raise ValueError("C# initializer order proof changed")
    inputs = [compiler, build_path, MANAGED_RUN, Path(__file__).resolve()]
    inputs += [source for source, _ in CASES.values()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for name, (source, expected) in CASES.items():
        executable = output / f"{name}.exe"
        command = [str(compiler), "build", str(source), "-o", str(executable),
                   "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                   "--stdlib", str(ROOT / "stdlib"), "-O1"]
        process = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
        (output / f"{name}.stdout.txt").write_bytes(process.stdout)
        (output / f"{name}.stderr.txt").write_bytes(process.stderr)
        stderr = process.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n")
        runs[name] = {"exitCode": process.returncode, "stderr": stderr,
                      "executableExists": executable.exists(),
                      "passed": process.returncode != 0 and not executable.exists()
                      and (stderr == expected if name == "order" else expected in stderr)}
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and all(run["passed"] for run in runs.values())
    record = {"schemaVersion": 1, "unit": "C527 nominal initializer order and contextual controls",
              "status": "passed" if passed else "failed", "completed": 3 if passed else 0,
              "total": 3, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
