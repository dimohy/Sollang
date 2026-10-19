#!/usr/bin/env python3
"""Require C527 positive fixtures to appear in the native regression catalog."""

from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REGRESSION = ROOT / "examples/regression"
CONTRACT = ROOT / "scripts/contracts/c527-regression-fixture-layout.json"
RUNNER = ROOT / "tests/Sollang.ExampleTests/Program.cs"


def validate_layout(regression: Path, names: list[str], warnings: dict[str, str] | None = None) -> None:
    expected_dir = regression / "expected"
    misplaced = sorted(path.name for path in regression.glob("*.stdout.txt"))
    if misplaced:
        raise ValueError(f"stdout expectations outside runner catalog: {misplaced}")
    for name in names:
        source = regression / f"{name}.slg"
        expected = expected_dir / f"{name}.stdout.txt"
        if not source.is_file() or not expected.is_file() or expected.stat().st_size == 0:
            raise ValueError(f"missing catalog source or expected output: {name}")
    for name, warning in (warnings or {}).items():
        if name not in names or not warning:
            raise ValueError(f"warning fixture is not a positive catalog case: {name}")
        expected_warning = expected_dir / f"{name}.compiler.stderr.contains.txt"
        if not expected_warning.is_file() or warning not in expected_warning.read_text(encoding="utf-8-sig"):
            raise ValueError(f"missing expected compiler warning: {name}")


def self_test() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        regression = Path(temporary)
        (regression / "expected").mkdir()
        (regression / "example.slg").write_text("main {}\n", encoding="utf-8")
        expected = regression / "expected/example.stdout.txt"
        expected.write_text("ok\n", encoding="utf-8")
        warning = regression / "expected/example.compiler.stderr.contains.txt"
        warning.write_text("warning S001\n", encoding="utf-8")
        validate_layout(regression, ["example"], {"example": "warning S001"})
        misplaced = regression / "example.stdout.txt"
        misplaced.write_text("ok\n", encoding="utf-8")
        try:
            validate_layout(regression, ["example"])
        except ValueError as error:
            assert "outside runner catalog" in str(error)
        else:
            raise AssertionError("misplaced expectation was accepted")
        misplaced.unlink()
        warning.unlink()
        try:
            validate_layout(regression, ["example"], {"example": "warning S001"})
        except ValueError as error:
            assert "missing expected compiler warning" in str(error)
        else:
            raise AssertionError("missing compiler warning expectation was accepted")
        expected.unlink()
        try:
            validate_layout(regression, ["example"])
        except ValueError as error:
            assert "missing catalog" in str(error)
        else:
            raise AssertionError("missing expectation was accepted")
    print("PASS fixture layout self-test: valid, misplaced, missing warning, missing output")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    names = contract["positiveFixtures"]
    warnings = contract.get("warningFixtures", {})
    assert contract["schemaVersion"] == 1
    assert contract["runnerCatalog"] == "examples/regression/expected"
    assert len(names) == len(set(names)) and names
    runner = RUNNER.read_text(encoding="utf-8-sig")
    assert 'EnumerateFiles(expectedDir, "*.stdout.txt")' in runner
    assert 'Path.Combine(repoRoot, "examples", "regression", "expected")' in runner
    assert 'EnumerateFiles(regressionDir, "*.stdout.txt")' in runner
    assert 'misplacedExpectations.Length > 0' in runner
    assert isinstance(warnings, dict)
    validate_layout(REGRESSION, names, warnings)
    print(f"PASS C527 positive fixtures {len(names)}/{len(names)} in regression runner catalog")


if __name__ == "__main__":
    main()
