"""Verify current-source C593 pre-IR facts and focused C# pairs."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c593-unary-index-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


unit = read(str(RECEIPT))
assert unit["status"] == "passed"
assert (unit["completed"], unit["total"]) == (3, 3)
assert (unit["focusedCompleted"], unit["focusedTotal"]) == (3, 3)
assert [step["status"] for step in unit["steps"]] == ["complete"] * 3
comparison = read(unit["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert sha(comparison["managedSource"]) == comparison["managedSourceSha256"]
for source, expected in unit["currentSourceHashes"].items():
    assert sha(source) == expected, source

probe = unit["preIrProbe"]
assert sha(probe["source"]) == probe["sourceSha256"]
assert sha(probe["executable"]) == probe["executableSha256"]
assert path(probe["output"]).read_text(encoding="utf-8-sig").splitlines() == [
    "index=0 result=2 expected=-1 owner=-1",
    "index=5 result=-1 expected=2 owner=-1",
]

build = read(unit["selfhostBuild"])
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
assert sha(str(path(unit["selfhostBuild"]).parent / "compiler.exe")) == unit["selfhostCompilerSha256"]

pair = read(unit["positivePair"])
assert pair["status"] == "passed" and pair["inputStable"]
assert (pair["completed"], pair["total"]) == (7, 7)
assert len(pair["runs"]) == 14
expected_fixtures = {
    "2042-interpolated-contextual-struct-dictionary-key",
    "2046-interpolated-contextual-struct-dictionary-key-value",
    "2051-interpolated-nested-unary",
    "2022-interpolation-indexed-signed-unary",
    "2053-interpolated-nested-unary-index",
    "2038-interpolated-member-array-index-preir",
    "2031-interpolated-mapped-index-preir",
}
assert {run["fixture"] for run in pair["runs"]} == expected_fixtures
for run in pair["runs"]:
    assert (run["buildExit"], run["llvmAsExit"], run["directCallExit"], run["nativeExit"]) == (0, 0, 0, 0)
    if run["compiler"] == "selfhost":
        assert run["compilerSha256"] == unit["selfhostCompilerSha256"]

assert len(unit["negativePairs"]) == 8
for receipt in unit["negativePairs"]:
    negative = read(receipt)
    assert negative["state"] == "passed" and negative["inputsStable"]
    assert negative["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
    for compiler in ("managed", "selfhost"):
        assert negative[compiler]["exitCode"] == 1
        assert negative[compiler]["expectedInStderr"] and negative[compiler]["noEmittedProducts"]
    managed = path(negative["managed"]["stderrPath"]).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    selfhost = path(negative["selfhost"]["stderrPath"]).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    assert managed == selfhost and managed.startswith("sollang: semantic error at "), receipt

print("[C593 unary index pre-IR] VERIFIED 3/3; probe 2/2, positives 7/7, exact negatives 8/8")
