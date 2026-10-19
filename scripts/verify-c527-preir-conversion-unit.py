#!/usr/bin/env python3
"""Validate the direct numeric conversion pre-IR interpolation unit."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-conversion-compiler-o1-20260929-02")
INTERNAL = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-conversion-facts-managed-20260929-01")
MANAGED = ROOT / "artifacts/scratch/c527-preir-conversion-managed-first-20260929-01/result.json"
PAIRED = ROOT / "artifacts/scratch/c527-preir-conversion-paired-20260929-02/result.json"
CONTROLS = ROOT / "artifacts/scratch/c527-preir-conversion-retained-controls-20260929-01/result.json"
SOURCE_ORDER = ROOT / "artifacts/scratch/c527-semantic-source-order-20260929-08.json"
OUTPUT = ROOT / "artifacts/scratch/c527-preir-conversion-unit-20260929-01.json"
FIXTURES = {
    "float": ("diagnostics/2143-interpolation-preir-conversion-float", ".stderr.contains.txt"),
    "valid": ("2144-interpolation-preir-conversion-valid", ".stdout.txt"),
    "bool": ("diagnostics/2145-interpolation-preir-conversion-bool", ".stderr.contains.txt"),
}


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    managed, paired, controls, order, build = map(read, (MANAGED, PAIRED, CONTROLS, SOURCE_ORDER, BUILD / "result.json"))
    assert managed["status"] == paired["status"] == controls["status"] == order["status"] == build["status"] == "passed"
    assert paired["inputStable"] and build["inputsStable"]
    assert managed["completed"] == managed["total"] == paired["completed"] == paired["total"] == 4
    assert controls["completed"] == controls["total"] == 4
    assert build["compilerSha256"] == paired["compilerSha256"] == controls["selfhostCompilerSha256"] == sha(BUILD / "compiler.exe")
    for name, expected in order["sourceSha256"].items():
        assert sha(ROOT / name) == expected, name
    assert (INTERNAL / "build.stderr.txt").read_bytes() == (INTERNAL / "run.stderr.txt").read_bytes() == b""
    assert (INTERNAL / "run.stdout.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n") == "float=19\ninvalid=-1\n"
    for case, (stem, suffix) in FIXTURES.items():
        fixture = ROOT / "examples/regression" / f"{stem}.slg"
        source = ROOT / managed["cases"][case]["source"]
        assert fixture.read_bytes() == source.read_bytes(), case
        output_base = ROOT / "examples/regression" / ("diagnostics" if suffix.startswith(".stderr") else "expected")
        expected = (output_base / f"{Path(stem).name}{suffix}").read_text(encoding="utf-8-sig").strip()
        actual = managed["cases"][case]["buildStderr"] if suffix.startswith(".stderr") else managed["cases"][case]["runStdout"]
        assert expected in actual, case
    result = {
        "schemaVersion": 1,
        "unit": "C527 numeric conversion pre-IR display",
        "status": "passed",
        "completed": 8,
        "total": 8,
        "managedFirst": {"completed": 4, "total": 4},
        "paired": {"completed": 4, "total": 4},
        "retainedControls": {"completed": 4, "total": 4},
        "retainedFixtures": {"completed": 3, "total": 3},
        "internalPreIrFacts": {"floatSymbol": 19, "invalidTypeId": -1},
        "compilerSha256": build["compilerSha256"],
        "evidenceSha256": {str(path.relative_to(ROOT)): sha(path) for path in (MANAGED, PAIRED, CONTROLS, SOURCE_ORDER)},
        "structuralPhasesClosed": {"completed": 0, "total": 7},
        "stage2Stage3": {"completed": 0, "total": 2},
    }
    if OUTPUT.exists():
        raise ValueError(f"closure record exists: {OUTPUT}")
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: paired 4/4, controls 4/4, fixtures 3/3")


if __name__ == "__main__":
    main()
