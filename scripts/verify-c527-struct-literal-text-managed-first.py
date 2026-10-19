#!/usr/bin/env python3
"""Pin C# Text field initialization in an interpolated nominal receiver."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-text-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-text-managed-first-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
              ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
              ROOT / "src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-text-field.slg",
              RUN / "text.exe", RUN / "text.build.stdout.txt", RUN / "text.build.stderr.txt",
              RUN / "text.native.stdout.txt", RUN / "text.native.stderr.txt", Path(__file__).resolve()]
    if ((RUN / "text.build.stderr.txt").read_text(encoding="utf-8") != ""
            or (RUN / "text.native.stderr.txt").read_text(encoding="utf-8") != ""
            or (RUN / "text.native.stdout.txt").read_text(encoding="utf-8").replace("\r\n", "\n") != "value=hello\n"):
        raise ValueError("C# Text field receiver behavior changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("C# proof inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nominal Text field receiver C# proof",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "nativeStdout": "value=hello\n"}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# Text field receiver")


if __name__ == "__main__":
    main()
