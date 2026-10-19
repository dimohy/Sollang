#!/usr/bin/env python3
"""Pin four nominal initializer diagnostics to the paired compiler result."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-init-focused-20260929-01\result.json")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-initializer-regression-contract-20260929-01.json"
CASES = {
    "unknown-field": "2102",
    "duplicate-field": "2103",
    "missing-field": "2104",
    "field-type": "2105",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    proof = json.loads(FOCUSED.read_text(encoding="utf-8"))
    if proof["status"] != "passed" or not proof["inputsStable"]:
        raise ValueError("paired compiler result is invalid")
    inputs = [FOCUSED, Path(__file__).resolve()]
    fixtures = []
    for name, number in CASES.items():
        source = ROOT / f"scripts/probes/interpolation/c527-struct-literal-{name}.slg"
        retained = ROOT / f"examples/regression/diagnostics/{number}-struct-literal-{name}.slg"
        expected = ROOT / f"examples/regression/diagnostics/{number}-struct-literal-{name}.stderr.contains.txt"
        fixtures.append(str(retained))
        inputs.extend((source, retained, expected))
        value = expected.read_text(encoding="utf-8").replace("\r\n", "\n")
        if (sha(source) != sha(retained)
                or proof["inputSha256"][str(source)] != sha(source)
                or any(proof["runs"][compiler][name]["stderr"] != value for compiler in ("managed", "selfhost"))):
            raise ValueError(f"retained {name} differs from paired behavior")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nominal initializer retained diagnostics",
              "status": "passed", "completed": 4, "total": 4, "inputStable": True,
              "inputSha256": start, "focusedResult": str(FOCUSED), "fixtures": fixtures}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 4/4 retained initializer diagnostics")


if __name__ == "__main__":
    main()
