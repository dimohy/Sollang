"""Validate the current C583 indexed type and mismatch facts."""

import hashlib
import argparse
import json
import subprocess
from pathlib import Path

from interpolation_current_source import historical_compiler_hash, validate_sources


ROOT = Path(__file__).resolve().parent.parent
RECEIPT = "artifacts/scratch/c583-index-preir-unit-20260928-01.json"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--contract', type=Path, default=ROOT / 'scripts/contracts/interpolation-semantic-parity.json')
args = parser.parse_args()


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
prior = read(proof["priorMemberProof"])
build = read(proof["selfhostBuild"])
positive = read(proof["positivePair"])

assert proof["status"] == "passed" and proof["focusedCompleted"] == proof["focusedTotal"] == 4
assert [step["status"] for step in proof["focusedSteps"]] == ["complete"] * 4
assert source["status"] == "source-reviewed-before-selfhost-change"
assert source["managedFirstPositive"] == proof["managedFirst"]
assert source["managedFirstNegative"] == proof["managedFirstNegative"]
validate_sources([source["managedSource"].split(":")[0]], contract_path=args.contract)
assert prior["status"] == "passed" and prior["semanticOwnedKindsUnchanged"] == "4/12"
assert managed["status"] == "passed" and managed["inputsStable"]
assert managed["sourceSha256"] == sha("examples/regression/2022-interpolation-indexed-signed-unary.slg")
assert managed_negative["status"] == "passed"
assert managed_negative["inputHashesStart"] == managed_negative["inputHashesEnd"]
assert managed_negative["inputHashesStart"]["source"] == sha(
    "examples/regression/diagnostics/2023-interpolation-array-index-type.slg"
)
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == proof["selfhostCompilerSha256"]
compiler = str(path(proof["selfhostBuild"]).parent / "compiler.exe")
assert historical_compiler_hash(compiler, build_record=proof['selfhostBuild'], contract_path=args.contract) == proof["selfhostCompilerSha256"]

probe = proof["preIrProbe"]
assert sha(probe["source"]) == probe["sourceSha256"]
assert sha(probe["executable"]) == probe["executableSha256"]
run = subprocess.run([probe["executable"]], cwd=ROOT, capture_output=True, text=True, check=True)
assert not run.stderr and all(line in run.stdout.splitlines() for line in probe["requiredLines"])

assert positive["status"] == "passed" and positive["inputStable"]
assert (positive["completed"], positive["total"]) == (15, 15)
assert {
    "2022-interpolation-indexed-signed-unary",
    "2009-interpolated-index-binding-instance-method",
    "2015-interpolated-compound-index-instance-method",
    "2020-interpolation-direct-struct-field",
}.issubset({row["fixture"] for row in positive["runs"]})
assert positive["inputHashesStart"][compiler] == proof["selfhostCompilerSha256"]
assert positive["inputHashesEnd"][compiler] == proof["selfhostCompilerSha256"]
assert proof["negativeNormalizedExact"] == "2/2"
for value in proof["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"]
    assert negative["selfhostCompilerSha256"] == proof["selfhostCompilerSha256"]
    directory = path(value).parent
    managed_stderr = (directory / "managed.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    selfhost_stderr = (directory / "selfhost.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    assert managed_stderr == selfhost_stderr and managed_stderr.startswith("sollang: semantic error at ")

validate_sources(list(proof["currentSourceHashes"]), contract_path=args.contract)
producer = path("selfhost/semantic/expression_type_ids.slg").read_text(encoding="utf-8-sig")
consumer = path("selfhost/semantic/interpolation_inference.slg").read_text(encoding="utf-8-sig")
prepare = path("selfhost/llvm/text/context_prepare.slg").read_text(encoding="utf-8-sig")
assert "public preIrIntIndexExpression prepared:" in producer
assert "prepared -> expressionTypeIds.preIrIntIndexExpression(" in consumer
assert producer.index("interpolationLexicalTypeByNode!") < producer.index("interpolationIndexedTypeByNode!")
assert producer.index("interpolationIndexedTypeByNode!") < producer.index("interpolationUnaryTypeByNode!")
assert "bindingFacts.interpolationIndexedTypeByNode[nodeIndex] -> return" in consumer
assert "bindingFacts.interpolationIndexExpectedTypeByNode[nodeIndex!] => invalidExpected!" in consumer
assert prepare.index("initialPrepared -> expressionTypeIds.resolveCallContextWithExternalResults(externalResults) => resolvedCallContext") < prepare.index("prepared -> lowerPreparedIr(")
assert "resolvedCallContext.types => recursiveTypes!" in prepare
assert "initialPrepared.package -> libraryImports.callResultTypes(initialPrepared.semantic.types, libraries, libraryCalls) => externalResults" in prepare
assert "request -> prepareResolvedSnapshot(resolvedCallContext, libraries, libraryCalls, unresolvedMutableNames, signatureTypeDiagnostic)" in prepare
external_context = producer.split('public resolveCallContextWithExternalResults ', 1)[1].split('\n}', 1)[0]
assert 'initialPrepared -> resolveContextCoreSeeded(seeds, externalResults) => initialTypes' in external_context
assert 'initialPrepared -> completeResolvedCallContextSeeded(initialTypes, seeds, externalResults)' in external_context
resolve_call_context = producer.split('public resolveCallContext ', 1)[1].split('\n}', 1)[0]
assert 'initialPrepared -> resolveContextCore => initialTypes' in resolve_call_context
assert 'initialPrepared -> completeResolvedCallContext(initialTypes)' in resolve_call_context
assert proof["semanticOwnedKindsUnchanged"] == "4/12"
assert proof["structuralPhasesClosed"] == "0/7"
print("[C583 index pre-IR] PASS retained historical probe/paired/diagnostic facts and current source identity; fresh whole parity remains separate")
