#!/usr/bin/env python3
"""Pin C# nested nominal constructor and chained field output."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-nested-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-nested-managed-first-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
              ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
              ROOT / "src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-nested-field.slg",
              RUN / "nested.exe", RUN / "nested.build.stdout.txt", RUN / "nested.build.stderr.txt",
              RUN / "nested.native.stdout.txt", RUN / "nested.native.stderr.txt", Path(__file__).resolve()]
    if (read(RUN / "nested.build.stderr.txt") != ""
            or read(RUN / "nested.native.stderr.txt") != ""
            or read(RUN / "nested.native.stdout.txt") != "value=5\n"):
        raise ValueError("C# nested nominal field result changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("C# proof inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nested nominal receiver C# proof",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "nativeStdout": "value=5\n"}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# nested nominal receiver")


if __name__ == "__main__":
    main()
