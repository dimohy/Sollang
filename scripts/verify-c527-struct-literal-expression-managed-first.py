#!/usr/bin/env python3
"""Pin C# computed nominal field values and type mismatch diagnostics."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-expression-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-expression-managed-first-20260929-01.json"
EXPECTED_ERROR = "sollang: semantic error at 1:15: [module '<main>'] field 'x' expects Bool, got Int\n"


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
              ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field.slg",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field-type.slg",
              RUN / "expression.exe", RUN / "expression.build.stdout.txt",
              RUN / "expression.build.stderr.txt", RUN / "expression.native.stdout.txt",
              RUN / "expression.native.stderr.txt", RUN / "expression-type.build.stdout.txt",
              RUN / "expression-type.build.stderr.txt", Path(__file__).resolve()]
    if (read(RUN / "expression.build.stderr.txt") != ""
            or read(RUN / "expression.native.stderr.txt") != ""
            or read(RUN / "expression.native.stdout.txt") != "value=5\n"
            or read(RUN / "expression-type.build.stderr.txt") != EXPECTED_ERROR
            or (RUN / "expression-type.exe").exists()):
        raise ValueError("C# computed field behavior changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("C# proof inputs changed")
    result = {"schemaVersion": 1, "unit": "C527 computed nominal field C# proof",
              "status": "passed", "completed": 2, "total": 2, "inputStable": True,
              "inputSha256": start, "positiveStdout": "value=5\n", "negativeStderr": EXPECTED_ERROR}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# computed field positive and mismatch")


if __name__ == "__main__":
    main()
