"""Verify pre-IR owned index decisions, borrow allowance and exact diagnostics."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = "artifacts/scratch/c589-owned-index-preir-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


unit = read(RECEIPT)
assert unit["status"] == "passed"
assert (unit["focusedCompleted"], unit["focusedTotal"]) == (3, 3)
comparison = read(unit["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert sha(comparison["managedSource"]) == comparison["managedSourceSha256"]
for value, expected in unit["currentSourceHashes"].items():
    assert sha(value) == expected, value

build = read(unit["selfhostBuild"])
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
assert sha(str(path(unit["selfhostBuild"]).parent / "compiler.exe")) == unit["selfhostCompilerSha256"]

probe = unit["preIrProbe"]
assert sha(probe["source"]) == probe["sourceSha256"]
assert sha(probe["executable"]) == probe["executableSha256"]
assert path(probe["output"]).read_text(encoding="utf-8-sig").splitlines() == [
    "index=0 owned=26 container=1",
    "index=3 owned=26 container=2",
]

positive = read(unit["positivePair"])
assert positive["status"] == "passed" and positive["inputStable"]
assert positive["completed"] == positive["total"] == 15
assert {row["compilerSha256"] for row in positive["runs"] if row["compiler"] == "selfhost"} == {unit["selfhostCompilerSha256"]}
assert "2037-interpolated-owned-index-readonly-call" in {row["fixture"] for row in positive["runs"]}

assert len(unit["negativePairs"]) == 12
for value in unit["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"], value
    assert negative["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
    left = path(negative["logs"]["managedStderr"]).read_text(encoding="utf-8-sig").strip()
    right = path(negative["logs"]["selfhostStderr"]).read_text(encoding="utf-8-sig").strip()
    assert left == right and left.startswith("sollang: semantic error at "), value

print("[C589 owned index pre-IR] PASS facts 2/2, positives 15/15, exact negatives 12/12")
