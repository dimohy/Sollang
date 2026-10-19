"""Validate the C580 semantic type receipt against live sources and runs."""

import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c580-lexical-name-preir-unit-20260928-01.json"


def read(path: str) -> dict:
    target = Path(path)
    return json.loads((target if target.is_absolute() else ROOT / target).read_text(encoding="utf-8-sig"))


def sha(path: str) -> str:
    target = Path(path)
    return hashlib.sha256((target if target.is_absolute() else ROOT / target).read_bytes()).hexdigest().upper()


proof = json.loads(RECEIPT.read_text(encoding="utf-8-sig"))
comparison = read(proof["sourceComparison"])
build = read(proof["selfhostBuild"])
positive = read(proof["positivePair"])
assert proof["status"] == "passed" and comparison["status"] == "source-reviewed-before-selfhost-change"
assert comparison["managedFirst"] == proof["managedFirst"]
assert read(proof["managedFirst"])["status"] == "passed"
assert build["status"] == "passed" and build["inputsStable"] and build["steps"] == {
    "build": 0, "llvmAs": 0, "v004": 0
}
assert build["compilerSha256"] == proof["selfhostCompilerSha256"]
compiler = str(Path(proof["selfhostBuild"]).parent / "compiler.exe")
assert sha(compiler) == proof["selfhostCompilerSha256"]
assert positive["status"] == "passed" and positive["inputStable"]
assert (positive["completed"], positive["total"]) == (4, 4)
assert positive["inputHashesStart"][compiler] == proof["selfhostCompilerSha256"]
assert positive["inputHashesEnd"][compiler] == proof["selfhostCompilerSha256"]
assert sha(proof["preIrProbeSource"]) == proof["preIrProbeSourceSha256"]
assert sha(proof["preIrProbeExecutable"]) == proof["preIrProbeExecutableSha256"]
probe = subprocess.run(
    [proof["preIrProbeExecutable"]], cwd=ROOT, capture_output=True, text=True, check=True
)
assert probe.stderr == "" and proof["preIrExpected"] in probe.stdout.splitlines()
assert "parameter=10 parent=6 type=26" in probe.stdout.splitlines()

for path, expected_hash in proof["currentSourceHashes"].items():
    assert sha(path) == expected_hash, path
producer = (ROOT / "selfhost/semantic/expression_type_ids.slg").read_text(encoding="utf-8-sig")
consumer = (ROOT / "selfhost/semantic/interpolation_inference.slg").read_text(encoding="utf-8-sig")
prepare = (ROOT / "selfhost/llvm/text/context_prepare.slg").read_text(encoding="utf-8-sig")
assert producer.index("[Int; ~] => interpolationLexicalTypeByNode!") < producer.index("ExpressionTypeIdSet {\n        types: types!")
assert prepare.index("prepared -> expressionTypeIds.resolveContext") < prepare.index("prepared -> lowerPreparedIr(")
assert "bindingFacts.interpolationLexicalTypeByNode[nodeIndex] -> return" in consumer
assert "streamRoleTypeId prepared:" not in consumer and "lexicalTypeId prepared:" not in consumer

for path in proof["negativePairs"]:
    receipt = read(path)
    assert receipt["state"] == "passed" and receipt["inputsStable"]
    assert receipt["selfhostCompilerSha256"] == proof["selfhostCompilerSha256"]
    directory = (ROOT / path).parent
    managed = (directory / "managed.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    selfhost = (directory / "selfhost.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    assert managed == selfhost and managed.startswith("sollang: semantic error at ")

assert (proof["focusedCompleted"], proof["focusedTotal"]) == (4, 4)
assert proof["negativeNormalizedExact"] == "2/2"
assert proof["semanticOwnedKinds"] == "4/12" and proof["structuralPhasesClosed"] == "0/7"
assert proof["preIrFullExpressionClosure"] is False
print("[C580 lexical pre-IR] PASS probe 1/1, build 1/1, positives 4/4, exact negatives 2/2")
