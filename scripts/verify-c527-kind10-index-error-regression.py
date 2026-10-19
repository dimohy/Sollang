#!/usr/bin/env python3
"""Bind the invalid-index diagnostic fixture to the paired focused result."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-invalid-index-focused-20260929-01\result.json")
SOURCE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-invalid-bool.slg"
RETAINED = ROOT / "examples/regression/diagnostics/2092-instance-method-result-index-invalid-bool.slg"
EXPECTED = ROOT / "examples/regression/diagnostics/2092-instance-method-result-index-invalid-bool.stderr.contains.txt"
OUTPUT = ROOT / "artifacts/scratch/c527-kind10-index-error-regression-contract-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    focused = json.loads(FOCUSED.read_text(encoding="utf-8"))
    expected = EXPECTED.read_text(encoding="utf-8").replace("\r\n", "\n")
    if (focused["status"] != "passed" or not focused["inputsStable"]
            or focused["inputSha256"][str(SOURCE)] != sha(SOURCE)
            or sha(SOURCE) != sha(RETAINED)
            or expected != focused["managedStderr"]
            or expected != focused["selfhostStderr"]):
        raise ValueError("retained invalid-index diagnostic differs from paired result")
    inputs = [FOCUSED, SOURCE, RETAINED, EXPECTED, Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 invalid-index retained diagnostic",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "focusedResult": str(FOCUSED), "fixture": str(RETAINED)}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: retained exact index error")


if __name__ == "__main__":
    main()
