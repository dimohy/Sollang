#!/usr/bin/env python3
"""Bind reused C# and SLG nested nominal positive and diagnostic runs."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = Path(r"C:\Users\dimohy\AppData\Local\Sollang")
FIRST = ROOT / "artifacts/scratch/c527-struct-literal-nested-managed-pair-20260929-01.json"
COMPARISON = ROOT / "artifacts/scratch/c527-struct-literal-nested-source-comparison-20260929-01.json"
RUN = BASE / "c527-struct-literal-nested-selfhost-before-20260929-01"
BUILD = BASE / "c527-struct-literal-expression-compiler-o1-20260929-01/result.json"
COMPILER = BASE / "c527-struct-literal-expression-compiler-o1-20260929-01/compiler.exe"
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-nested-paired-20260929-01.json"
EXPECTED = "sollang: semantic error at 1:28: [module '<main>'] field 'x' expects Bool, got Int\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    first = json.loads(read(FIRST))
    comparison = json.loads(read(COMPARISON))
    build = json.loads(read(BUILD))
    if (first["status"] != "passed" or first["negativeStderr"] != EXPECTED
            or comparison["status"] != "passed" or comparison["nativeStdout"] != "value=5\n"
            or build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(COMPILER)
            or read(RUN / "nested.build.stderr.txt") != ""
            or read(RUN / "nested.native.stdout.txt") != "value=5\n"
            or read(RUN / "nested.native.stderr.txt") != ""
            or read(RUN / "nested-type.build.stderr.txt") != EXPECTED
            or (RUN / "nested-type.exe").exists()):
        raise ValueError("nested nominal paired behavior changed")
    inputs = [FIRST, COMPARISON, BUILD, COMPILER,
              ROOT / "selfhost/semantic/interpolation_inference.slg",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-nested-field.slg",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-nested-field-type.slg",
              RUN / "nested.exe", RUN / "nested.build.stdout.txt", RUN / "nested.build.stderr.txt",
              RUN / "nested.native.stdout.txt", RUN / "nested.native.stderr.txt",
              RUN / "nested-type.build.stdout.txt", RUN / "nested-type.build.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("paired inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nested nominal initializer paired",
              "status": "passed", "completed": 2, "total": 2, "inputStable": True,
              "inputSha256": start, "positiveStdout": "value=5\n", "negativeStderr": EXPECTED}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: nested nominal positive and inner type error")


if __name__ == "__main__":
    main()
