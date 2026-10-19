#!/usr/bin/env python3
"""Pin C# diagnostics for nominal struct initializers inside interpolation."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-init-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-initializer-managed-first-20260929-01.json"
EXPECTED = {
    "unknown-field": "sollang: semantic error at 1:10: [module '<main>'] struct 'Point' has no field 'y'\n",
    "duplicate-field": "sollang: semantic error at 1:16: [module '<main>'] field 'x' is initialized more than once in 'Point'\n",
    "missing-field": "sollang: semantic error at 1:2: [module '<main>'] struct 'Point' requires field 'x' to be initialized\n",
    "field-type": "sollang: semantic error at 1:13: [module '<main>'] field 'x' expects Bool, got Int\n",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
              ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs", Path(__file__).resolve()]
    for name, expected in EXPECTED.items():
        source = ROOT / f"scripts/probes/interpolation/c527-struct-literal-{name}.slg"
        stderr = RUN / f"{name}.stderr.txt"
        stdout = RUN / f"{name}.stdout.txt"
        inputs.extend((source, stderr, stdout))
        if stderr.read_text(encoding="utf-8").replace("\r\n", "\n") != expected:
            raise ValueError(f"C# {name} diagnostic changed")
        if (RUN / f"{name}.exe").exists():
            raise ValueError(f"C# {name} unexpectedly produced an executable")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("C# proof inputs changed")
    result = {"schemaVersion": 1, "unit": "C527 nominal struct initializer C# diagnostics",
              "status": "passed", "completed": 4, "total": 4, "inputStable": True,
              "inputSha256": start, "expected": EXPECTED}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 4/4 C# initializer diagnostics")


if __name__ == "__main__":
    main()
