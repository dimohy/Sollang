"""Verify C591's pre-IR owner decision and retained paired cases."""

import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c591-owner-index-preir-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


unit = read(str(RECEIPT))
assert unit["status"] == "passed"
assert (unit["focusedCompleted"], unit["focusedTotal"]) == (2, 2)
assert (unit["overallFocusedCompleted"], unit["overallFocusedTotal"]) == (2, 3)
comparison = read(unit["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert sha(comparison["managedSource"]) == comparison["managedSourceSha256"]
for value, expected in unit["currentSourceHashes"].items():
    assert sha(value) == expected, value

managed = read(unit["managedFirst"])
assert managed["status"] == "passed" and managed["completed"] == managed["total"] == 3
assert sha(managed["managedCompiler"]) == managed["managedCompilerSha256"]
for row in managed["cases"]:
    assert sha(row["source"]) == row["sourceSha256"]

build = read(unit["selfhostBuild"])
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
assert sha(str(path(unit["selfhostBuild"]).parent / "compiler.exe")) == unit["selfhostCompilerSha256"]

probe = unit["preIrProbe"]
assert sha(probe["source"]) == probe["sourceSha256"]
assert sha(probe["executable"]) == probe["executableSha256"]
assert path(probe["output"]).read_text(encoding="utf-8-sig").splitlines() == [
    "index=0 ownerType=26 kind=7 origin=4 symbol=7 unsupported=26",
    "index=3 ownerType=2 kind=1 origin=1 symbol=2 unsupported=2",
]

for value, expected_count in (("namedKeyControl", 1), ("retainedPositivePair", 15)):
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

assert read(unit["contextualBoundary"])["status"] == "unresolved"
subprocess.run([sys.executable, str(ROOT / "scripts/verify-c591-contextual-key-boundary.py")], cwd=ROOT, check=True)
print("[C591 owner pre-IR] PASS facts 2/2, owner exact negatives 2/2, retained positives 15/15, retained exact negatives 12/12; contextual key pending")
