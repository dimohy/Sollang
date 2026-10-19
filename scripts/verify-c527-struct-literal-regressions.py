#!/usr/bin/env python3
"""Pin retained direct nominal struct receiver cases to the paired result."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-field-focused-20260929-01\result.json")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-regression-contract-20260929-01.json"
CASES = (
    ("positive", ROOT / "scripts/probes/interpolation/c527-struct-literal-field-positive.slg",
     ROOT / "examples/regression/2100-struct-literal-field-interpolation.slg",
     ROOT / "examples/regression/expected/2100-struct-literal-field-interpolation.stdout.txt", "value=5\n"),
    ("float", ROOT / "scripts/probes/interpolation/c527-struct-literal-field-float.slg",
     ROOT / "examples/regression/diagnostics/2101-struct-literal-field-interpolation-float.slg",
     ROOT / "examples/regression/diagnostics/2101-struct-literal-field-interpolation-float.stderr.contains.txt",
     "sollang: semantic error at 6:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    result = json.loads(FOCUSED.read_text(encoding="utf-8"))
    if result["status"] != "passed" or not result["inputsStable"]:
        raise ValueError("paired compiler result is invalid")
    inputs = [FOCUSED, Path(__file__).resolve()]
    for label, probe, retained, expected, value in CASES:
        inputs.extend((probe, retained, expected))
        if (result["inputSha256"][str(probe)] != sha(probe)
                or sha(probe) != sha(retained)
                or expected.read_text(encoding="utf-8").replace("\r\n", "\n") != value):
            raise ValueError(f"retained {label} case differs from paired input")
        for compiler in ("managed", "selfhost"):
            actual = result["runs"][compiler]["native"]["stdout"] if label == "positive" else result["runs"][compiler][label]["stderr"]
            if actual != value:
                raise ValueError(f"{compiler} {label} output differs from expected")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 direct nominal struct receiver retained fixtures",
              "status": "passed", "completed": 2, "total": 2, "inputStable": True,
              "inputSha256": start, "focusedResult": str(FOCUSED),
              "fixtures": [str(case[2]) for case in CASES]}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 2/2 retained fixtures")


if __name__ == "__main__":
    main()
