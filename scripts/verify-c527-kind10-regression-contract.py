#!/usr/bin/env python3
"""Check retained method-result fixtures against pinned focused behavior."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-preir-focused-20260929-01\result.json")
NESTED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-nested-focused-20260929-01\result.json")
OUTPUT = ROOT / "artifacts/scratch/c527-kind10-regression-contract-20260929-01.json"
MAPPINGS = [
    (ROOT / "artifacts/scratch/c527-kind10-call-receiver-positive-20260929-01.slg",
     ROOT / "examples/regression/2086-instance-method-result-member-interpolation.slg",
     ROOT / "examples/regression/expected/2086-instance-method-result-member-interpolation.stdout.txt",
     "value=5\n"),
    (ROOT / "artifacts/scratch/c527-kind10-call-receiver-candidate-20260929-01.slg",
     ROOT / "examples/regression/diagnostics/2087-instance-method-result-member-float.slg",
     ROOT / "examples/regression/diagnostics/2087-instance-method-result-member-float.stderr.contains.txt",
     "sollang: semantic error at 15:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
    (ROOT / "scripts/probes/interpolation/c527-kind10-method-arity-negative.slg",
     ROOT / "examples/regression/diagnostics/2088-instance-method-result-arity.slg",
     ROOT / "examples/regression/diagnostics/2088-instance-method-result-arity.stderr.contains.txt",
     "sollang: semantic error at 10:5: [module '<main>'] function 'make' expects 1 additional argument(s)\n"),
    (ROOT / "scripts/probes/interpolation/c527-kind10-nested-member-negative.slg",
     ROOT / "examples/regression/diagnostics/2089-instance-method-result-nested-field-float.slg",
     ROOT / "examples/regression/diagnostics/2089-instance-method-result-nested-field-float.stderr.contains.txt",
     "sollang: semantic error at 19:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    focused = json.loads(FOCUSED.read_text(encoding="utf-8"))
    nested = json.loads(NESTED.read_text(encoding="utf-8"))
    if (focused["status"] != "passed" or not focused["inputStable"]
            or nested["status"] != "passed" or not nested["inputStable"]):
        raise ValueError("focused evidence is invalid")
    for compiler in ("managed", "selfhost"):
        if focused["runs"][compiler]["methodIntNative"]["stdout"] != MAPPINGS[0][3]:
            raise ValueError("focused positive output changed")
        if (focused["runs"][compiler]["methodFloat"]["stderr"] != MAPPINGS[1][3]
                or focused["runs"][compiler]["methodArity"]["stderr"] != MAPPINGS[2][3]
                or nested["runs"][compiler]["stderr"] != MAPPINGS[3][3]):
            raise ValueError("focused diagnostic changed")
    inputs = [FOCUSED, NESTED, Path(__file__).resolve()]
    for source, retained, expected, value in MAPPINGS:
        inputs.extend((source, retained, expected))
        proof = nested if source == MAPPINGS[3][0] else focused
        if proof["inputSha256"][str(source)] != sha(source):
            raise ValueError(f"focused source drifted: {source}")
        if sha(source) != sha(retained):
            raise ValueError(f"retained source differs from focused source: {retained}")
        if expected.read_text(encoding="utf-8").replace("\r\n", "\n") != value:
            raise ValueError(f"retained expectation differs from paired behavior: {expected}")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression contract inputs changed")
    record = {
        "schemaVersion": 1,
        "unit": "C527 retained kind-10 method-result fixtures",
        "status": "passed",
        "completed": len(MAPPINGS),
        "total": len(MAPPINGS),
        "inputStable": True,
        "inputSha256": start,
        "fixtures": [str(item[1]) for item in MAPPINGS],
        "focusedResult": str(FOCUSED),
        "nestedResult": str(NESTED),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: four retained fixtures match paired inputs")


if __name__ == "__main__":
    main()
