#!/usr/bin/env python3
"""Pin the unknown nominal type fixture to the paired diagnostic."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-unknown-type-focused-20260929-01\result.json")
SOURCE = ROOT / "scripts/probes/interpolation/c527-struct-literal-unknown-type.slg"
RETAINED = ROOT / "examples/regression/diagnostics/2106-struct-literal-unknown-type.slg"
EXPECTED = ROOT / "examples/regression/diagnostics/2106-struct-literal-unknown-type.stderr.contains.txt"
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-unknown-type-regression-contract-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    proof = json.loads(FOCUSED.read_text(encoding="utf-8"))
    value = EXPECTED.read_text(encoding="utf-8").replace("\r\n", "\n")
    if (proof["status"] != "passed" or not proof["inputsStable"]
            or proof["inputSha256"][str(SOURCE)] != sha(SOURCE)
            or sha(SOURCE) != sha(RETAINED)
            or any(proof["runs"][name]["stderr"] != value for name in ("managed", "selfhost"))):
        raise ValueError("retained unknown nominal type fixture differs from paired behavior")
    inputs = [FOCUSED, SOURCE, RETAINED, EXPECTED, Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression inputs changed")
    result = {"schemaVersion": 1, "unit": "C527 unknown nominal type retained diagnostic",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "focusedResult": str(FOCUSED), "fixture": str(RETAINED)}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: unknown nominal type fixture")


if __name__ == "__main__":
    main()
