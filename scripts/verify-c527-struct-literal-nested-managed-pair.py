#!/usr/bin/env python3
"""Pin C# nested nominal receiver output and inner field diagnostic."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-nested-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-nested-managed-pair-20260929-01.json"
EXPECTED = "sollang: semantic error at 1:28: [module '<main>'] field 'x' expects Bool, got Int\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
              ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-nested-field.slg",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-nested-field-type.slg",
              RUN / "nested.exe", RUN / "nested.build.stdout.txt", RUN / "nested.build.stderr.txt",
              RUN / "nested.native.stdout.txt", RUN / "nested.native.stderr.txt",
              RUN / "nested-type.build.stdout.txt", RUN / "nested-type.build.stderr.txt", Path(__file__).resolve()]
    if (read(RUN / "nested.build.stderr.txt") != ""
            or read(RUN / "nested.native.stderr.txt") != ""
            or read(RUN / "nested.native.stdout.txt") != "value=5\n"
            or read(RUN / "nested-type.build.stderr.txt") != EXPECTED
            or (RUN / "nested-type.exe").exists()):
        raise ValueError("C# nested nominal positive or diagnostic changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("C# nested proof inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nested nominal initializer C# pair",
              "status": "passed", "completed": 2, "total": 2, "inputStable": True,
              "inputSha256": start, "positiveStdout": "value=5\n", "negativeStderr": EXPECTED}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# nested nominal positive and inner field error")


if __name__ == "__main__":
    main()
