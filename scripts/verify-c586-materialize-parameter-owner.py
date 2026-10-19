"""Verify current-source C586 parameter owner and retained materialize behavior."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c586-materialize-parameter-owner-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


unit = read(str(RECEIPT))
assert unit["status"] == "passed"
assert (unit["focusedCompleted"], unit["focusedTotal"]) == (8, 8)
for comparison_name in ("sourceComparison", "modifierComparison"):
    comparison = read(unit[comparison_name])
    assert comparison["status"] == "source-compared-before-slg-edit"
    assert comparison["managedSourceSha256"] == unit["sourceHashes"][comparison["managedSource"]]
for source, expected in unit["sourceHashes"].items():
    assert sha(source) == expected, source

build = read(unit["selfhostBuild"])
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
compiler = str(path(unit["selfhostBuild"]).parent / "compiler.exe")
assert sha(compiler) == unit["selfhostCompilerSha256"]
positive = read(unit["positivePair"])
assert positive["status"] == "passed" and positive["inputStable"]
assert (positive["completed"], positive["total"]) == (12, 12)
assert {
    "2024-materialized-if-result-interpolation",
    "2027-materialized-direct-result-interpolation",
    "581-materialized-text-arena",
}.issubset({row["fixture"] for row in positive["runs"]})
assert {row["compilerSha256"] for row in positive["runs"] if row["compiler"] == "selfhost"} == {
    unit["selfhostCompilerSha256"]
}

assert len(unit["negativePairs"]) == 5
for value in unit["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"], value
    assert negative["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
    assert negative["managed"]["noEmittedProducts"] and negative["selfhost"]["noEmittedProducts"]
    directory = path(value).parent
    managed = (directory / "managed.stderr.txt").read_text(encoding="utf-8-sig").strip()
    selfhost = (directory / "selfhost.stderr.txt").read_text(encoding="utf-8-sig").strip()
    assert managed == selfhost and managed.startswith("sollang: semantic error at "), value
    expected = path(negative["expected"]).read_text(encoding="utf-8-sig").strip()
    if expected.startswith("sollang: "):
        assert managed == expected, value

print("[C586 materialize parameter owner] PASS paired positives 3/3, exact negatives 5/5, stable current inputs")
