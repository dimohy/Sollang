#!/usr/bin/env python3
"""Close the unary composition pre-IR unit from exact paired evidence."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-s001-contextual-float-compiler-o1-20260929-01")
BEFORE = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-unary-composed-facts-baseline-20260929-01")
AFTER = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-unary-composed-facts-after-20260929-03")
EVIDENCE = {
    "managed": ROOT / "artifacts/scratch/c527-preir-unary-composed-managed-first-20260929-01/result.json",
    "sourceComparison": ROOT / "artifacts/scratch/c527-preir-unary-composed-source-comparison-20260929-01.json",
    "paired": ROOT / "artifacts/scratch/c527-preir-unary-composed-paired-20260929-03/result.json",
    "unaryControls": ROOT / "artifacts/scratch/c527-preir-unary-composed-unary-controls-20260929-02/result.json",
    "binaryControls": ROOT / "artifacts/scratch/c527-preir-unary-composed-binary-controls-20260929-03/result.json",
    "conversionControls": ROOT / "artifacts/scratch/c527-preir-unary-composed-conversion-controls-20260929-02/result.json",
    "sourceOrder": ROOT / "artifacts/scratch/c527-semantic-source-order-20260929-12.json",
    "s001Managed": ROOT / "artifacts/scratch/c527-s001-managed-controls-20260929-01/result.json",
    "s001Comparison": ROOT / "artifacts/scratch/c527-s001-source-comparison-20260929-01.json",
    "s001Paired": ROOT / "artifacts/scratch/c527-s001-paired-controls-20260929-02/result.json",
    "floatManaged": ROOT / "artifacts/scratch/c527-contextual-float-arithmetic-managed-first-20260929-02/result.json",
    "floatComparison": ROOT / "artifacts/scratch/c527-contextual-float-llvm-source-comparison-20260929-01.json",
    "floatPaired": ROOT / "artifacts/scratch/c527-contextual-float-arithmetic-paired-20260929-01/result.json",
}
CATALOG = ROOT / "artifacts/scratch/c527-preir-unary-composed-regression-catalog-20260929-03"
LAYOUT = ROOT / "scripts/verify-regression-fixture-layout.py"
OUTPUT = ROOT / "artifacts/scratch/c527-preir-unary-composed-unit-20260929-02.json"
FIXTURES = {
    "floatConversion": ("diagnostics/2153-interpolation-unary-composed-float-conversion", ".stderr.contains.txt"),
    "floatBinary": ("diagnostics/2154-interpolation-unary-composed-float-binary", ".stderr.contains.txt"),
    "intConversion": ("2155-interpolation-unary-composed-int-conversion", ".stdout.txt"),
    "notCompare": ("2156-interpolation-unary-composed-not-compare", ".stdout.txt"),
    "notFloatCompare": ("2157-interpolation-unary-composed-not-float-compare", ".stdout.txt"),
    "invalidNotFloat": ("diagnostics/2158-interpolation-unary-composed-invalid-not-float", ".stderr.contains.txt"),
    "invalidNegateCompare": ("diagnostics/2159-interpolation-unary-composed-invalid-negate-compare", ".stderr.contains.txt"),
    "invalidChildConversion": ("diagnostics/2160-interpolation-unary-composed-invalid-child-conversion", ".stderr.contains.txt"),
}


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    records = {name: read(path) for name, path in EVIDENCE.items()}
    build = read(BUILD / "result.json")
    assert build["status"] == "passed" and build["inputsStable"]
    assert sha(BUILD / "compiler.exe") == build["compilerSha256"]
    for name in ("managed", "paired", "unaryControls", "binaryControls", "conversionControls",
                 "s001Managed", "s001Paired", "floatManaged", "floatPaired"):
        record = records[name]
        assert record["status"] == "passed" and record["inputStable"], name
        assert record["completed"] == record["total"], name
    assert records["managed"]["total"] == records["paired"]["total"] == 8
    assert records["unaryControls"]["total"] == 4
    assert records["binaryControls"]["total"] == 7
    assert records["conversionControls"]["total"] == 4
    assert records["s001Managed"]["total"] == records["s001Paired"]["total"] == 5
    assert records["floatManaged"]["total"] == records["floatPaired"]["total"] == 2
    for name in ("paired", "unaryControls", "binaryControls", "conversionControls", "s001Paired", "floatPaired"):
        assert records[name]["compilerSha256"] == build["compilerSha256"], name
    assert records["sourceComparison"]["status"] == "compared-before-slg-edit"
    assert records["s001Comparison"]["status"] == "compared-before-slg-edit"
    assert records["floatComparison"]["status"] == "compared-before-slg-edit"
    assert records["sourceOrder"]["status"] == "passed"
    for name, expected in records["sourceOrder"]["sourceSha256"].items():
        assert sha(ROOT / name) == expected, name
    assert (BEFORE / "build.stderr.txt").read_bytes() == (BEFORE / "run.stderr.txt").read_bytes() == b""
    assert (AFTER / "build.stderr.txt").read_bytes() == (AFTER / "run.stderr.txt").read_bytes() == b""
    assert normalized(BEFORE / "run.stdout.txt") == "conversion=-1\nbinary=-1\n"
    assert normalized(AFTER / "run.stdout.txt") == "conversion=19\nbinary=19\n"
    managed_cases = records["managed"]["cases"]
    for case, (stem, suffix) in FIXTURES.items():
        fixture = ROOT / "examples/regression" / f"{stem}.slg"
        source = ROOT / managed_cases[case]["source"]
        assert fixture.read_bytes() == source.read_bytes(), case
        output_base = ROOT / "examples/regression" / ("diagnostics" if suffix.startswith(".stderr") else "expected")
        expected = (output_base / f"{Path(stem).name}{suffix}").read_text(encoding="utf-8-sig").strip()
        actual = managed_cases[case]["buildStderr"] if suffix.startswith(".stderr") else managed_cases[case]["runStdout"]
        assert expected in actual, case
    expected_s001 = ROOT / "examples/regression/expected/2157-interpolation-unary-composed-not-float-compare.compiler.stderr.contains.txt"
    assert expected_s001.read_text(encoding="utf-8-sig").strip() == managed_cases["notFloatCompare"]["buildStderr"].strip()
    layout = subprocess.run([sys.executable, str(LAYOUT)], cwd=ROOT,
                            text=True, capture_output=True, check=False)
    assert layout.returncode == 0 and "positive fixtures 13/13" in layout.stdout
    catalog_record = read(CATALOG / "result.json")
    catalog_stdout = normalized(CATALOG / "stdout.txt")
    assert catalog_record["status"] == "passed" and catalog_record["exitCode"] == 0
    assert catalog_record["stdoutSha256"] == sha(CATALOG / "stdout.txt")
    assert catalog_record["stderrSha256"] == sha(CATALOG / "stderr.txt")
    assert (CATALOG / "stderr.txt").read_bytes() == b""
    assert "All 8 example tests passed." in catalog_stdout
    assert len(re.findall(r"^\[\d+/8\] PASS ", catalog_stdout, re.MULTILINE)) == 8
    result = {
        "schemaVersion": 1,
        "unit": "C527 unary composition pre-IR type",
        "status": "passed",
        "completed": 30,
        "total": 30,
        "managedFirst": {"completed": 8, "total": 8},
        "paired": {"completed": 8, "total": 8},
        "relatedControls": {"completed": 15, "total": 15},
        "s001Controls": {"completed": 5, "total": 5},
        "contextualFloatArithmetic": {"completed": 2, "total": 2},
        "retainedFixtures": {"completed": 8, "total": 8},
        "regressionCatalog": {"completed": 8, "total": 8},
        "fixtureLayout": {"completed": 13, "total": 13},
        "preIrFacts": {"before": [-1, -1], "after": [19, 19]},
        "compilerSha256": build["compilerSha256"],
        "evidenceSha256": {name: sha(path) for name, path in EVIDENCE.items()},
        "structuralPhasesClosed": {"completed": 0, "total": 7},
        "stage2Stage3": {"completed": 0, "total": 2},
    }
    if OUTPUT.exists():
        raise ValueError(f"closure record exists: {OUTPUT}")
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: paired 8/8, controls 22/22, fixtures 8/8")


if __name__ == "__main__":
    main()
