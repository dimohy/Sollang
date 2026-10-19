#!/usr/bin/env python3
"""Bind computed nominal field fixtures to the paired compiler result."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-expression-focused-20260929-01\result.json")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-expression-regression-contract-20260929-01.json"
CASES = (
    ("positive", ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field.slg",
     ROOT / "examples/regression/2108-struct-literal-expression-field.slg",
     ROOT / "examples/regression/expected/2108-struct-literal-expression-field.stdout.txt", "value=5\n"),
    ("fieldType", ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field-type.slg",
     ROOT / "examples/regression/diagnostics/2109-struct-literal-expression-field-type.slg",
     ROOT / "examples/regression/diagnostics/2109-struct-literal-expression-field-type.stderr.contains.txt",
     "sollang: semantic error at 1:15: [module '<main>'] field 'x' expects Bool, got Int\n"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    proof = json.loads(FOCUSED.read_text(encoding="utf-8"))
    if proof["status"] != "passed" or not proof["inputsStable"]:
        raise ValueError("paired compiler result is invalid")
    inputs = [FOCUSED, Path(__file__).resolve()]
    for label, source, retained, expected, value in CASES:
        inputs.extend((source, retained, expected))
        if (proof["inputSha256"][str(source)] != sha(source)
                or sha(source) != sha(retained)
                or expected.read_text(encoding="utf-8").replace("\r\n", "\n") != value):
            raise ValueError(f"retained {label} input differs from paired proof")
        for compiler in ("managed", "selfhost"):
            actual = proof["runs"][compiler]["native"]["stdout"] if label == "positive" else proof["runs"][compiler][label]["stderr"]
            if actual != value:
                raise ValueError(f"retained {label} output differs: {compiler}")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 computed nominal field retained fixtures",
              "status": "passed", "completed": 2, "total": 2, "inputStable": True,
              "inputSha256": start, "focusedResult": str(FOCUSED),
              "fixtures": [str(case[2]) for case in CASES]}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 2/2 computed initializer fixtures")


if __name__ == "__main__":
    main()
