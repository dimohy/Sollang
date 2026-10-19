#!/usr/bin/env python3
"""Close the focused nested binary interpolation unit from stable evidence."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = {
    "managedFirst": ROOT / "artifacts/scratch/c527-preir-nested-binary-managed-first-20260929-01/result.json",
    "managedControls": ROOT / "artifacts/scratch/c527-preir-nested-binary-managed-controls-20260929-01/result.json",
    "paired": ROOT / "artifacts/scratch/c527-preir-nested-binary-paired-20260929-03/result.json",
    "directControls": ROOT / "artifacts/scratch/c527-preir-binary-direct-controls-paired-20260929-01/result.json",
    "sourceOrder": ROOT / "artifacts/scratch/c527-semantic-source-order-20260929-07.json",
}
BUILD = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-nested-binary-compiler-o1-20260929-02")
INTERNAL = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-nested-binary-facts-managed-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-preir-nested-binary-unit-20260929-01.json"
FIXTURES = {
    "float": ("2138-interpolation-preir-nested-binary-float", True),
    "int": ("2139-interpolation-preir-nested-binary-int", False),
    "compare": ("2140-interpolation-preir-nested-binary-compare", False),
    "logical": ("2141-interpolation-preir-nested-binary-logical", False),
    "invalidInner": ("2142-interpolation-preir-nested-binary-invalid", True),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> None:
    records = {key: read(path) for key, path in EVIDENCE.items()}
    build = read(BUILD / "result.json")
    for key in ("managedFirst", "managedControls", "paired", "directControls"):
        record = records[key]
        assert record["status"] == "passed" and record["inputStable"], key
        assert record["completed"] == record["total"], key
    assert records["managedFirst"]["total"] == 5
    assert records["managedControls"]["total"] == records["paired"]["total"] == 7
    assert records["directControls"]["total"] == 6
    assert build["status"] == "passed" and build["inputsStable"]
    assert build["compilerSha256"] == sha(BUILD / "compiler.exe") == records["paired"]["compilerSha256"]
    assert records["directControls"]["compilerSha256"] == build["compilerSha256"]
    assert records["sourceOrder"]["status"] == "passed"
    for name, expected in records["sourceOrder"]["sourceSha256"].items():
        assert sha(ROOT / name) == expected, name
    assert (INTERNAL / "build.stderr.txt").read_bytes() == b""
    assert (INTERNAL / "run.stderr.txt").read_bytes() == b""
    assert (INTERNAL / "run.stdout.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n") == "float=20\ninvalid=-1\n"
    managed_cases = records["managedControls"]["cases"]
    paired_cases = records["paired"]["cases"]
    for case, (stem, negative) in FIXTURES.items():
        base = ROOT / "examples/regression" / ("diagnostics" if negative else "")
        assert (base / f"{stem}.slg").read_bytes() == (ROOT / paired_cases[case]["source"]).read_bytes(), case
        suffix = ".stderr.contains.txt" if negative else ".stdout.txt"
        output_base = base if negative else ROOT / "examples/regression/expected"
        expected = (output_base / f"{stem}{suffix}").read_text(encoding="utf-8-sig").strip()
        actual = managed_cases[case]["buildStderr"] if negative else managed_cases[case]["runStdout"]
        assert expected in actual, case
    result = {
        "schemaVersion": 1,
        "unit": "C527 nested binary pre-IR type and inner diagnostic order",
        "status": "passed",
        "completed": 13,
        "total": 13,
        "managedFirst": {"completed": 5, "total": 5},
        "managedControls": {"completed": 7, "total": 7},
        "paired": {"completed": 7, "total": 7},
        "directControls": {"completed": 6, "total": 6},
        "retainedFixtures": {"completed": 5, "total": 5},
        "internalPreIrFacts": {"floatSymbol": 20, "invalidTypeId": -1},
        "sourceOrder": str(EVIDENCE["sourceOrder"].relative_to(ROOT)),
        "compilerSha256": build["compilerSha256"],
        "evidenceSha256": {key: sha(path) for key, path in EVIDENCE.items()},
        "structuralPhasesClosed": {"completed": 0, "total": 7},
        "stage2Stage3": {"completed": 0, "total": 2},
    }
    if OUTPUT.exists():
        raise ValueError(f"closure record exists: {OUTPUT}")
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: nested 7/7, direct 6/6, fixtures 5/5")


if __name__ == "__main__":
    main()
