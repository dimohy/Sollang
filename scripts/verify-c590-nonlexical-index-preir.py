"""Verify C590 source comparison, semantic facts, and paired behavior."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c590-nonlexical-index-preir-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


unit = read(str(RECEIPT))
assert unit["status"] == "passed"
assert (unit["focusedCompleted"], unit["focusedTotal"]) == (4, 4)
comparison = read(unit["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert sha(comparison["managedSource"]) == comparison["managedSourceSha256"]
for value, expected in comparison["managedEmitterSources"].items():
    assert sha(value) == expected, value
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
    "function kind=7 returnAst=-1 astCount=35",
    "index=0 ownerKind=5 ownerSymbol=-1 type=8 expected=-1",
    "index=4 ownerKind=5 ownerSymbol=-1 type=-1 expected=2",
    "index=8 ownerKind=8 ownerSymbol=2 type=8 expected=-1",
    "index=11 ownerKind=8 ownerSymbol=2 type=-1 expected=2",
]

for value, expected_count in (("focusedPositivePair", 2), ("retainedPositivePair", 15)):
    positive = read(unit[value])
    assert positive["status"] == "passed" and positive["inputStable"]
    assert positive["completed"] == positive["total"] == expected_count
    assert {row["compilerSha256"] for row in positive["runs"] if row["compiler"] == "selfhost"} == {unit["selfhostCompilerSha256"]}

assert len(unit["negativePairs"]) == 14
for value in unit["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"], value
    assert negative["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
    left = path(negative["logs"]["managedStderr"]).read_text(encoding="utf-8-sig").strip()
    right = path(negative["logs"]["selfhostStderr"]).read_text(encoding="utf-8-sig").strip()
    assert left == right and left.startswith("sollang: semantic error at "), value

print("[C590 nonlexical index pre-IR] PASS facts 4/4, focused 4/4, retained positives 15/15, exact negatives 14/14")
