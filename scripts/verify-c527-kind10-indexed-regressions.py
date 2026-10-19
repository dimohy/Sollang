#!/usr/bin/env python3
"""Bind retained indexed method-result cases to the paired focused result."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-indexed-focused-20260929-01\result.json")
OUTPUT = ROOT / "artifacts/scratch/c527-kind10-indexed-regression-contract-20260929-01.json"
CASES = (
    ("positive", ROOT / "scripts/probes/interpolation/c527-kind10-indexed-positive.slg",
     ROOT / "examples/regression/2090-instance-method-result-indexed-field.slg",
     ROOT / "examples/regression/expected/2090-instance-method-result-indexed-field.stdout.txt",
     "value=5\n"),
    ("negative", ROOT / "scripts/probes/interpolation/c527-kind10-indexed-negative.slg",
     ROOT / "examples/regression/diagnostics/2091-instance-method-result-indexed-field-float.slg",
     ROOT / "examples/regression/diagnostics/2091-instance-method-result-indexed-field-float.stderr.contains.txt",
     "sollang: semantic error at 15:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    focused = json.loads(FOCUSED.read_text(encoding="utf-8"))
    if focused["status"] != "passed" or not focused["inputsStable"]:
        raise ValueError("paired focused result is invalid")
    inputs = [FOCUSED, Path(__file__).resolve()]
    for label, source, retained, expected, value in CASES:
        inputs.extend((source, retained, expected))
        if (focused["inputSha256"][str(source)] != sha(source)
                or sha(source) != sha(retained)
                or expected.read_text(encoding="utf-8").replace("\r\n", "\n") != value):
            raise ValueError(f"retained {label} case differs from paired result")
        for compiler in ("managed", "selfhost"):
            actual = (focused["runs"][compiler]["native"]["stdout"]
                      if label == "positive" else focused["runs"][compiler]["negative"]["stderr"])
            if actual != value:
                raise ValueError(f"{compiler} {label} output changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression contract inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 indexed method-result retained cases",
              "status": "passed", "completed": 2, "total": 2, "inputsStable": True,
              "inputSha256": start, "focusedResult": str(FOCUSED),
              "fixtures": [str(case[2]) for case in CASES]}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 2/2 retained cases")


if __name__ == "__main__":
    main()
