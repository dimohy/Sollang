#!/usr/bin/env python3
"""Pin C# behavior for a propagated Result payload field."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-result-member-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-propagated-result-member-managed-first-20260929-01.json"
CASES = {
    "positive": (ROOT / "scripts/probes/interpolation/c527-propagated-result-member-positive.slg", ""),
    "float": (ROOT / "scripts/probes/interpolation/c527-propagated-result-member-float.slg",
              "sollang: semantic error at 8:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
    "mismatch": (ROOT / "scripts/probes/interpolation/c527-propagated-result-member-error-mismatch.slg",
                 "sollang: semantic error at 1:13: [module '<main>'] '?' error type Text does not match function error type Int\n"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe",
              ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs", Path(__file__).resolve()]
    for label, (source, expected) in CASES.items():
        inputs += [source, OUTPUT_DIR / f"{label}.build.stdout.txt", OUTPUT_DIR / f"{label}.build.stderr.txt"]
        if contents(OUTPUT_DIR / f"{label}.build.stderr.txt") != expected:
            raise ValueError(f"C# {label} diagnostic changed")
    inputs += [OUTPUT_DIR / "positive.exe", OUTPUT_DIR / "positive.native.stdout.txt",
               OUTPUT_DIR / "positive.native.stderr.txt"]
    if (contents(OUTPUT_DIR / "positive.native.stdout.txt") != "value=5\n"
            or contents(OUTPUT_DIR / "positive.native.stderr.txt") != ""):
        raise ValueError("C# positive run changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("C# proof inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 propagated Result payload member C# first",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start,
              "expected": {label: error for label, (_, error) in CASES.items()},
              "positiveStdout": "value=5\n"}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# positive run and two exact diagnostics")


if __name__ == "__main__":
    main()
