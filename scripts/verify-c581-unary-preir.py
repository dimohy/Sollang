"""Validate the C581 direct-operand unary decision against live evidence."""

import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = ROOT / "artifacts/scratch/c581-unary-direct-operand-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


proof = read(str(RECEIPT))
prior = read(proof["priorLexicalProof"])
source = read(proof["sourceComparison"])
build = read(proof["selfhostBuild"])
positive = read(proof["positivePair"])
assert proof["status"] == "passed" and source["status"] == "source-reviewed-before-selfhost-change"
assert prior["status"] == "passed" and prior["semanticOwnedKinds"] == "4/12"
assert read(prior["selfhostBuild"])["status"] == "passed"
assert read(prior["positivePair"])["status"] == "passed"
assert read(prior["positivePair"])["completed"] == 4
assert read(source["managedFirstPositive"])["status"] == "passed"
assert read(source["managedFirstPositive"])["completed"] == 2
for key in ("managedFirstNotNegative", "managedFirstNegateNegative"):
    assert read(source[key])["state"] == "passed"
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == proof["selfhostCompilerSha256"]
compiler = str(path(proof["selfhostBuild"]).parent / "compiler.exe")
assert sha(compiler) == proof["selfhostCompilerSha256"]

for probe in proof["preIrProbes"]:
    assert sha(probe["source"]) == probe["sourceSha256"]
    assert sha(probe["executable"]) == probe["executableSha256"]
    run = subprocess.run([probe["executable"]], cwd=ROOT, capture_output=True, text=True, check=True)
    assert not run.stderr and all(line in run.stdout.splitlines() for line in probe["requiredLines"])

assert positive["status"] == "passed" and positive["inputStable"]
assert (positive["completed"], positive["total"]) == (5, 5)
assert positive["inputHashesStart"][compiler] == proof["selfhostCompilerSha256"]
assert positive["inputHashesEnd"][compiler] == proof["selfhostCompilerSha256"]
for value in proof["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"]
    assert negative["selfhostCompilerSha256"] == proof["selfhostCompilerSha256"]
    directory = path(value).parent
    managed = (directory / "managed.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    selfhost = (directory / "selfhost.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    assert managed == selfhost and managed.startswith("sollang: semantic error at ")

for value, expected in proof["currentSourceHashes"].items():
    assert sha(value) == expected, value
producer = path("selfhost/semantic/expression_type_ids.slg").read_text(encoding="utf-8-sig")
consumer = path("selfhost/semantic/interpolation_inference.slg").read_text(encoding="utf-8-sig")
prepare = path("selfhost/llvm/text/context_prepare.slg").read_text(encoding="utf-8-sig")
assert producer.index("interpolationLexicalTypeByNode!") < producer.index("interpolationUnaryTypeByNode!")
assert "interpolationLexicalTypeByNode: [Int; ~]" in producer
assert "bindingFacts.interpolationLexicalTypeByNode[nodeIndex] -> return" in consumer
assert producer.index("interpolationUnaryTypeByNode!") < producer.index("ExpressionTypeIdSet {\n        types: types!")
assert prepare.index("prepared -> expressionTypeIds.resolveContext") < prepare.index("prepared -> lowerPreparedIr(")
assert "bindingFacts.interpolationUnaryTypeByNode[nodeIndex] -> return" in consumer
assert consumer.count("bindingFacts.interpolationUnaryStatusByNode[nodeIndex!] == 1") == 2
assert proof["semanticOwnedKindsUnchanged"] == "4/12" and proof["structuralPhasesClosed"] == "0/7"
assert proof["focusedCompleted"] == proof["focusedTotal"] == 4
print("[C581 unary pre-IR] PASS positive probes 2/2, invalid probes 2/2, build 1/1, paired positives 5/5, exact negatives 4/4")
