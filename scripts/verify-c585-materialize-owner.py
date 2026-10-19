"""Verify the current-source C585 owner diagnostics and retained positives."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c585-materialize-owner-unit-20260928-01.json"


def read(value: str) -> dict:
    path = Path(value)
    return json.loads((path if path.is_absolute() else ROOT / path).read_text(encoding="utf-8-sig"))


unit = read(str(RECEIPT))
comparison = read(unit["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert comparison["managedSourceSha256"] == unit["sourceHashes"][comparison["managedSource"]]
for source, expected in unit["sourceHashes"].items():
    assert hashlib.sha256((ROOT / source).read_bytes()).hexdigest().upper() == expected, source

build = read(unit["selfhostBuild"])
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
positive = read(unit["positivePair"])
assert positive["status"] == "passed" and positive["inputStable"]
assert positive["completed"] == positive["total"] == 12
assert {
    "2024-materialized-if-result-interpolation",
    "2027-materialized-direct-result-interpolation",
}.issubset({row["fixture"] for row in positive["runs"]})
assert {row["compilerSha256"] for row in positive["runs"] if row["compiler"] == "selfhost"} == {
    unit["selfhostCompilerSha256"]
}
assert len(unit["negativePairs"]) == 2
for value in unit["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"]
    assert negative["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
    assert negative["managed"]["noEmittedProducts"]
    assert negative["selfhost"]["noEmittedProducts"]
    managed = Path(negative["logs"]["managedStderr"]).read_text(encoding="utf-8-sig").strip()
    selfhost = Path(negative["logs"]["selfhostStderr"]).read_text(encoding="utf-8-sig").strip()
    assert managed == selfhost, value

assert unit["status"] == "passed"
assert unit["focusedCompleted"] == unit["focusedTotal"] == 4
print("[C585 materialize owner] PASS paired positives 2/2, exact negatives 2/2, stable current inputs")
