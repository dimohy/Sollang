#!/usr/bin/env python3
"""Bind propagated Result member fixtures to paired compiler behavior."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FOCUSED = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-focused-20260929-01\result.json")
STATUS = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-status-focused-20260929-01\result.json")
OUTPUT = ROOT / "artifacts/scratch/c527-propagated-member-regression-contract-20260929-01.json"
CASES = (
    ("positive", ROOT / "scripts/probes/interpolation/c527-propagated-result-member-positive.slg",
     ROOT / "examples/regression/2095-propagated-result-member.slg",
     ROOT / "examples/regression/expected/2095-propagated-result-member.stdout.txt", "value=5\n"),
    ("float", ROOT / "scripts/probes/interpolation/c527-propagated-result-member-float.slg",
     ROOT / "examples/regression/diagnostics/2096-propagated-result-member-float.slg",
     ROOT / "examples/regression/diagnostics/2096-propagated-result-member-float.stderr.contains.txt",
     "sollang: semantic error at 8:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
    ("mismatch", ROOT / "scripts/probes/interpolation/c527-propagated-result-member-error-mismatch.slg",
     ROOT / "examples/regression/diagnostics/2097-propagated-result-member-error-mismatch.slg",
     ROOT / "examples/regression/diagnostics/2097-propagated-result-member-error-mismatch.stderr.contains.txt",
     "sollang: semantic error at 1:13: [module '<main>'] '?' error type Text does not match function error type Int\n"),
    ("outside-result", ROOT / "scripts/probes/interpolation/c527-propagated-member-outside-result.slg",
     ROOT / "examples/regression/diagnostics/2098-propagated-member-outside-result.slg",
     ROOT / "examples/regression/diagnostics/2098-propagated-member-outside-result.stderr.contains.txt",
     "sollang: semantic error at 1:13: [module '<main>'] '?' can only be used inside a function returning Result<T, E>\n"),
    ("non-result", ROOT / "scripts/probes/interpolation/c527-propagated-member-non-result.slg",
     ROOT / "examples/regression/diagnostics/2099-propagated-member-non-result.slg",
     ROOT / "examples/regression/diagnostics/2099-propagated-member-non-result.stderr.contains.txt",
     "sollang: semantic error at 1:13: [module '<main>'] '?' expects Result<T, E> but received Point\n"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    focused = json.loads(FOCUSED.read_text(encoding="utf-8"))
    status = json.loads(STATUS.read_text(encoding="utf-8"))
    if (focused["status"] != "passed" or not focused["inputsStable"]
            or status["status"] != "passed" or not status["inputsStable"]):
        raise ValueError("paired compiler result is invalid")
    inputs = [FOCUSED, STATUS, Path(__file__).resolve()]
    for label, source, retained, expected, value in CASES:
        inputs.extend((source, retained, expected))
        proof = status if label in ("outside-result", "non-result") else focused
        if (proof["inputSha256"][str(source)] != sha(source)
                or sha(source) != sha(retained)
                or expected.read_text(encoding="utf-8").replace("\r\n", "\n") != value):
            raise ValueError(f"retained {label} case differs from paired input")
        if label in ("outside-result", "non-result"):
            if status["runs"][label]["stderr"] != value:
                raise ValueError(f"selfhost {label} output differs from expected")
        else:
            for compiler in ("managed", "selfhost"):
                result = focused["runs"][compiler]
                actual = result["native"]["stdout"] if label == "positive" else result[label]["stderr"]
                if actual != value:
                    raise ValueError(f"{compiler} {label} output differs from expected")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("regression inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 propagated Result member retained fixtures",
              "status": "passed", "completed": 3, "total": 3, "inputStable": True,
              "inputSha256": start, "focusedResult": str(FOCUSED), "statusResult": str(STATUS),
              "fixtures": [str(case[2]) for case in CASES]}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: {len(CASES)}/{len(CASES)} retained fixtures")


if __name__ == "__main__":
    main()
