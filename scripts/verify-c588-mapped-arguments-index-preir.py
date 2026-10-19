"""Verify C588 pre-IR mapped/Arguments index decisions and exact paired diagnostics."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = "artifacts/scratch/c588-mapped-arguments-index-preir-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


unit = read(RECEIPT)
assert unit["status"] == "passed"
assert (unit["focusedCompleted"], unit["focusedTotal"]) == (4, 4)
assert sha("selfhost/semantic/expression_type_ids.slg") == unit["sourceHashes"]["selfhost/semantic/expression_type_ids.slg"]
assert sha("selfhost/llvm/emitter/diagnostics.slg") == unit["sourceHashes"]["selfhost/llvm/emitter/diagnostics.slg"]
assert sha("src/Sollang.Compiler/Semantics/SemanticCompiler.cs") == unit["sourceHashes"]["src/Sollang.Compiler/Semantics/SemanticCompiler.cs"]

managed = read(unit["managedFirst"])
assert managed["status"] == "passed" and len(managed["cases"]) == 4
for case in managed["cases"]:
    assert sha(case["source"]) == case["sourceSha256"]
for value in unit["sourceComparisons"]:
    comparison = read(value)
    assert comparison["status"] == "source-compared-before-slg-edit"
    assert sha(comparison["managedSource"]) == comparison["managedSourceSha256"]

build = read(unit["selfhostBuild"])
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == unit["selfhostCompilerSha256"]
assert sha(str(path(unit["selfhostBuild"]).parent / "compiler.exe")) == unit["selfhostCompilerSha256"]

probe = unit["preIrProbe"]
assert sha(probe["source"]) == probe["sourceSha256"]
assert sha(probe["executable"]) == probe["executableSha256"]
assert path(probe["output"]).read_text(encoding="utf-8-sig").splitlines() == [
    "index=0 type=8 expected=-1",
    "index=3 type=-1 expected=13",
    "index=6 type=1 expected=-1",
    "index=9 type=-1 expected=13",
]

positive = read(unit["positivePair"])
assert positive["status"] == "passed" and positive["inputStable"]
assert positive["completed"] == positive["total"] == 15
assert {row["compilerSha256"] for row in positive["runs"] if row["compiler"] == "selfhost"} == {unit["selfhostCompilerSha256"]}
assert {
    "2031-interpolated-mapped-index-preir",
    "2032-interpolated-arguments-index-preir",
    "1426-dictionary-index-interpolation",
    "2022-interpolation-indexed-signed-unary",
}.issubset({row["fixture"] for row in positive["runs"]})

assert len(unit["negativePairs"]) == 10
for value in unit["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"], value
    assert negative["selfhostCompilerSha256"] == unit["selfhostCompilerSha256"]
    left = path(negative["logs"]["managedStderr"]).read_text(encoding="utf-8-sig").strip()
    right = path(negative["logs"]["selfhostStderr"]).read_text(encoding="utf-8-sig").strip()
    assert left == right and left.startswith("sollang: semantic error at "), value

print("[C588 mapped/Arguments pre-IR] PASS facts 4/4, paired positives 15/15, exact negatives 10/10")
