#!/usr/bin/env python3
"""Pin C# unknown nominal struct type diagnostic inside interpolation."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-unknown-type-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-unknown-type-managed-first-20260929-01.json"
EXPECTED = "sollang: semantic error at 1:2: [module '<main>'] unknown struct type 'MissingPoint'\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
              ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-unknown-type.slg",
              RUN / "unknown.stdout.txt", RUN / "unknown.stderr.txt", Path(__file__).resolve()]
    if (RUN / "unknown.exe").exists() or (RUN / "unknown.stderr.txt").read_text(encoding="utf-8").replace("\r\n", "\n") != EXPECTED:
        raise ValueError("C# unknown type behavior changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("C# proof inputs changed")
    result = {"schemaVersion": 1, "unit": "C527 unknown nominal struct receiver C# diagnostic",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "expected": EXPECTED}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# unknown nominal type diagnostic")


if __name__ == "__main__":
    main()
