"""Verify C592's current-source pre-IR decision and focused C# pair."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c592-nested-unary-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def sha256(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


def lines(value: str) -> list[str]:
    return path(value).read_text(encoding="utf-8-sig").splitlines()


unit = json.loads(RECEIPT.read_text(encoding="utf-8-sig"))
assert unit["status"] == "passed"
assert (unit["completed"], unit["total"]) == (2, 2)
assert [step["status"] for step in unit["steps"]] == ["complete", "complete"]
for source, expected in unit["currentSourceHashes"].items():
    assert sha256(source) == expected, source
build = json.loads(path(unit["selfhostBuild"]).read_text(encoding="utf-8-sig"))
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
assert sha256(str(path(unit["selfhostBuild"]).parent / "compiler.exe")) == unit["selfhostCompilerSha256"]
probe = unit["preIrProbe"]
assert sha256(probe["source"]) == probe["sourceSha256"]
assert sha256(probe["executable"]) == probe["executableSha256"]
assert lines(probe["output"]) == [
    "node=0 operand=1 type=2 status=0",
    "node=1 operand=2 type=2 status=0",
    "node=3 operand=4 type=23 status=0",
    "node=4 operand=5 type=23 status=0",
]
pair = json.loads(path(unit["positivePair"]).read_text(encoding="utf-8-sig"))
assert pair["status"] == "passed" and pair["inputStable"]
assert pair["completed"] == pair["total"] and pair["total"] >= 2
assert len(pair["runs"]) == 2 * pair["total"]
runs = [run for run in pair["runs"] if run["fixture"].startswith(("2051-", "2022-"))]
assert len(runs) == 4
for run in runs:
    assert (run["buildExit"], run["llvmAsExit"], run["directCallExit"], run["nativeExit"]) == (0, 0, 0, 0)
    if run["compiler"] == "selfhost":
        assert run["compilerSha256"] == unit["selfhostCompilerSha256"]
assert lines(unit["managedNegative"]) == lines(unit["selfhostNegative"]) == [
    "sollang: semantic error at 1:9: [module '<main>'] 'not' expects Bool"
]
print("[C592 nested unary] VERIFIED 2/2; pre-IR facts, 2 positive pairs, exact negative")
