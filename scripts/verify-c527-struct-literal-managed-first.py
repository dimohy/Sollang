#!/usr/bin/env python3
"""Pin C# field access after a direct nominal struct literal."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-field-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-managed-first-20260929-01.json"
EXPECTED_FLOAT = "sollang: semantic error at 6:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    paths = [ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
             ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
             ROOT / "scripts/probes/interpolation/c527-struct-literal-field-positive.slg",
             ROOT / "scripts/probes/interpolation/c527-struct-literal-field-float.slg",
             RUN / "positive.exe", RUN / "positive.build.stdout.txt",
             RUN / "positive.build.stderr.txt", RUN / "positive.native.stdout.txt",
             RUN / "positive.native.stderr.txt", RUN / "float.build.stdout.txt",
             RUN / "float.build.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in paths}
    if (contents(RUN / "positive.build.stderr.txt") != ""
            or contents(RUN / "positive.native.stdout.txt") != "value=5\n"
            or contents(RUN / "positive.native.stderr.txt") != ""
            or contents(RUN / "float.build.stderr.txt") != EXPECTED_FLOAT):
        raise ValueError("C# struct-literal receiver behavior changed")
    if start != {str(path): sha(path) for path in paths}:
        raise ValueError("C# proof inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 direct struct-literal field receiver C# proof",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "positiveStdout": "value=5\n", "floatStderr": EXPECTED_FLOAT}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# positive run and Float diagnostic")


if __name__ == "__main__":
    main()
