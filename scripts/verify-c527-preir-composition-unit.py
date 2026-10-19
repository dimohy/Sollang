#!/usr/bin/env python3
"""Close the nested conversion/binary pre-IR unit from current evidence."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-composition-compiler-o1-20260929-01")
BEFORE = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-composition-facts-baseline-20260929-01")
AFTER = Path("C:/Users/dimohy/AppData/Local/Sollang/c527-preir-composition-facts-after-20260929-01")
EVIDENCE = {
    "managed": ROOT / "artifacts/scratch/c527-preir-composition-managed-first-20260929-01/result.json",
    "sourceComparison": ROOT / "artifacts/scratch/c527-preir-composition-source-comparison-20260929-01.json",
    "paired": ROOT / "artifacts/scratch/c527-preir-composition-paired-20260929-01/result.json",
    "nestedControls": ROOT / "artifacts/scratch/c527-preir-composition-nested-controls-20260929-01/result.json",
    "conversionControls": ROOT / "artifacts/scratch/c527-preir-composition-conversion-controls-20260929-01/result.json",
    "sourceOrder": ROOT / "artifacts/scratch/c527-semantic-source-order-20260929-09.json",
}
OUTPUT = ROOT / "artifacts/scratch/c527-preir-composition-unit-20260929-02.json"
CATALOG_POSITIVE = ROOT / "artifacts/scratch/c527-regression-catalog-integrated-20260929-01"
CATALOG_NEGATIVE = ROOT / "artifacts/scratch/c527-regression-catalog-negative-control-20260929-02"
FIXTURE_LAYOUT = ROOT / "scripts/contracts/c527-regression-fixture-layout.json"
FIXTURE_VALIDATOR = ROOT / "scripts/verify-regression-fixture-layout.py"
RUNNER = ROOT / "tests/Sollang.ExampleTests/bin/Release/net11.0/Sollang.ExampleTests.dll"
FIXTURES = {
    "floatBinary": ("diagnostics/2146-interpolation-composed-float-binary", ".stderr.contains.txt"),
    "floatConversion": ("diagnostics/2147-interpolation-composed-float-conversion", ".stderr.contains.txt"),
    "intBinary": ("2148-interpolation-composed-int-binary", ".stdout.txt"),
    "nestedWidth": ("2149-interpolation-composed-nested-width", ".stdout.txt"),
    "invalidConversionBinary": ("diagnostics/2150-interpolation-composed-invalid-conversion-binary", ".stderr.contains.txt"),
    "invalidInnerBinary": ("diagnostics/2151-interpolation-composed-invalid-inner-binary", ".stderr.contains.txt"),
    "invalidNestedConversion": ("diagnostics/2152-interpolation-composed-invalid-nested-conversion", ".stderr.contains.txt"),
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
    for name in ("managed", "paired", "nestedControls", "conversionControls"):
        record = records[name]
        assert record["status"] == "passed" and record["inputStable"], name
        assert record["completed"] == record["total"], name
    assert records["managed"]["total"] == records["paired"]["total"] == records["nestedControls"]["total"] == 7
    assert records["conversionControls"]["total"] == 4
    for name in ("paired", "nestedControls", "conversionControls"):
        assert records[name]["compilerSha256"] == build["compilerSha256"], name
    assert records["sourceComparison"]["status"] == "compared-before-slg-edit"
    assert records["sourceOrder"]["status"] == "passed"
    for name, expected in records["sourceOrder"]["sourceSha256"].items():
        assert sha(ROOT / name) == expected, name
    assert (BEFORE / "build.stderr.txt").read_bytes() == (BEFORE / "run.stderr.txt").read_bytes() == b""
    assert (AFTER / "build.stderr.txt").read_bytes() == (AFTER / "run.stderr.txt").read_bytes() == b""
    assert normalized(BEFORE / "run.stdout.txt") == "binary=-1\nconversion=-1\n"
    assert normalized(AFTER / "run.stdout.txt") == "binary=19\nconversion=19\n"
    managed_cases = records["managed"]["cases"]
    for case, (stem, suffix) in FIXTURES.items():
        fixture = ROOT / "examples/regression" / f"{stem}.slg"
        source = ROOT / managed_cases[case]["source"]
        assert fixture.read_bytes() == source.read_bytes(), case
        output_base = ROOT / "examples/regression" / ("diagnostics" if suffix.startswith(".stderr") else "expected")
        expected = (output_base / f"{Path(stem).name}{suffix}").read_text(encoding="utf-8-sig").strip()
        actual = managed_cases[case]["buildStderr"] if suffix.startswith(".stderr") else managed_cases[case]["runStdout"]
        assert expected in actual, case
    layout = subprocess.run([sys.executable, str(FIXTURE_VALIDATOR)], cwd=ROOT,
                            text=True, capture_output=True, check=False)
    assert layout.returncode == 0 and "positive fixtures 10/10" in layout.stdout
    positive_record = read(CATALOG_POSITIVE / "result.json")
    positive_stdout = normalized(CATALOG_POSITIVE / "stdout.txt")
    assert positive_record["status"] == "passed" and positive_record["exitCode"] == 0
    assert positive_record["runnerSha256"] == sha(RUNNER)
    assert positive_record["stdoutSha256"] == sha(CATALOG_POSITIVE / "stdout.txt")
    assert positive_record["stderrSha256"] == sha(CATALOG_POSITIVE / "stderr.txt")
    assert (CATALOG_POSITIVE / "stderr.txt").read_bytes() == b""
    assert "All 23 example tests passed." in positive_stdout
    assert len(re.findall(r"^\[\d+/23\] PASS ", positive_stdout, re.MULTILINE)) == 23
    negative_record = read(CATALOG_NEGATIVE / "result.json")
    assert negative_record["status"] == "passed" and negative_record["observedExitCode"] == 1
    assert negative_record["misplacedFileReported"] and negative_record["stdoutEmpty"] and negative_record["fixtureRemoved"]
    assert negative_record["stdoutSha256"] == sha(CATALOG_NEGATIVE / "stdout.txt")
    assert negative_record["stderrSha256"] == sha(CATALOG_NEGATIVE / "stderr.txt")
    assert not (ROOT / "examples/regression/__fixture-layout-negative.stdout.txt").exists()
    result = {
        "schemaVersion": 1,
        "unit": "C527 nested numeric conversion and binary pre-IR composition",
        "status": "passed",
        "completed": 18,
        "total": 18,
        "managedFirst": {"completed": 7, "total": 7},
        "paired": {"completed": 7, "total": 7},
        "nestedControls": {"completed": 7, "total": 7},
        "conversionControls": {"completed": 4, "total": 4},
        "retainedFixtures": {"completed": 7, "total": 7},
        "regressionCatalog": {"completed": 23, "total": 23},
        "fixtureLayout": {"completed": 10, "total": 10},
        "misplacedExpectationRejection": {"completed": 1, "total": 1},
        "preIrFacts": {"before": [-1, -1], "after": [19, 19]},
        "compilerSha256": build["compilerSha256"],
        "evidenceSha256": {name: sha(path) for name, path in EVIDENCE.items()},
        "fixtureLayoutSha256": sha(FIXTURE_LAYOUT),
        "regressionRunnerSha256": sha(RUNNER),
        "structuralPhasesClosed": {"completed": 0, "total": 7},
        "stage2Stage3": {"completed": 0, "total": 2},
    }
    if OUTPUT.exists():
        raise ValueError(f"closure record exists: {OUTPUT}")
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: paired 7/7, controls 11/11, fixtures 7/7")


if __name__ == "__main__":
    main()
