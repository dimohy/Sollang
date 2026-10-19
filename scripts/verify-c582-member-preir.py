"""Validate the current C582 member type fact and focused paired evidence."""

import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = "artifacts/scratch/c582-member-field-preir-unit-20260928-01.json"


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


proof = read(RECEIPT)
source = read(proof["sourceComparison"])
managed = read(proof["managedFirst"])
managed_negative = read(proof["managedFirstNegative"])
prior = read(proof["priorUnaryProof"])
build = read(proof["selfhostBuild"])
positive = read(proof["positivePair"])
negative = read(proof["negativePair"])

assert proof["status"] == "passed" and proof["focusedCompleted"] == proof["focusedTotal"] == 4
assert [step["status"] for step in proof["focusedSteps"]] == ["complete"] * 4
assert source["status"] == "source-reviewed-before-selfhost-change"
assert source["managedFirst"] == proof["managedFirst"]
assert source["managedFirstNegative"] == proof["managedFirstNegative"]
assert sha(source["managedSource"].split(":")[0]) == source["managedSourceSha256"]
assert prior["status"] == "passed" and prior["semanticOwnedKindsUnchanged"] == "4/12"
assert managed["status"] == "passed" and managed["inputsStable"]
assert managed["sourceSha256"] == sha("examples/regression/2020-interpolation-direct-struct-field.slg")
assert managed_negative["status"] == "passed"
assert managed_negative["inputHashesStart"] == managed_negative["inputHashesEnd"]
assert managed_negative["inputHashesStart"]["source"] == sha(
    "examples/regression/diagnostics/2021-interpolation-member-unsigned-negate.slg"
)
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == proof["selfhostCompilerSha256"]
compiler = str(path(proof["selfhostBuild"]).parent / "compiler.exe")
assert sha(compiler) == proof["selfhostCompilerSha256"]

probe = proof["preIrProbe"]
assert sha(probe["source"]) == probe["sourceSha256"]
assert sha(probe["executable"]) == probe["executableSha256"]
run = subprocess.run([probe["executable"]], cwd=ROOT, capture_output=True, text=True, check=True)
assert not run.stderr and all(line in run.stdout.splitlines() for line in probe["requiredLines"])

assert positive["status"] == "passed" and positive["inputStable"]
assert (positive["completed"], positive["total"]) == (4, 4)
assert positive["inputHashesStart"][compiler] == proof["selfhostCompilerSha256"]
assert positive["inputHashesEnd"][compiler] == proof["selfhostCompilerSha256"]
assert negative["state"] == "passed" and negative["inputsStable"]
assert negative["selfhostCompilerSha256"] == proof["selfhostCompilerSha256"]
directory = path(proof["negativePair"]).parent
managed_stderr = (directory / "managed.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
selfhost_stderr = (directory / "selfhost.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
assert proof["negativeNormalizedExact"] and managed_stderr == selfhost_stderr
assert managed_stderr.startswith("sollang: semantic error at ")

for value, expected in proof["currentSourceHashes"].items():
    assert sha(value) == expected, value
producer = path("selfhost/semantic/expression_type_ids.slg").read_text(encoding="utf-8-sig")
consumer = path("selfhost/semantic/interpolation_inference.slg").read_text(encoding="utf-8-sig")
prepare = path("selfhost/llvm/text/context_prepare.slg").read_text(encoding="utf-8-sig")
assert producer.index("interpolationLexicalTypeByNode!") < producer.index("interpolationMemberTypeByNode!")
assert producer.index("interpolationMemberTypeByNode!") < producer.index("interpolationUnaryTypeByNode!")
assert "public memberFieldIndex prepared:" in producer
assert "bindingFacts.interpolationMemberTypeByNode[nodeIndex] -> return" in consumer
assert "prepared -> expressionTypeIds.memberFieldIndex(" in consumer
assert prepare.index("prepared -> expressionTypeIds.resolveContext") < prepare.index("prepared -> lowerPreparedIr(")
assert proof["semanticOwnedKindsUnchanged"] == "4/12"
assert proof["structuralPhasesClosed"] == "0/7"
print("[C582 member pre-IR] PASS probe 3/3, build 1/1, paired positives 4/4, exact negative 1/1")
