"""Verify current-source member result facts and retained index ownership."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECEIPT = ROOT / "artifacts/scratch/c597-member-result-unit-20260928-01.json"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


receipt = read_json(RECEIPT)
assert receipt["status"] == "focused-complete-kind5-open"
assert receipt["completed"] == receipt["total"] == 3
assert len(receipt["steps"]) == 3
assert all(step["status"] == "complete" for step in receipt["steps"])
parity = read_json(ROOT / "scripts/contracts/interpolation-semantic-parity.json")
index_contract = read_json(ROOT / "scripts/contracts/interpolation-index-branch-progress.json")
assert 7 in parity["semanticOwnedKinds"] and 7 not in parity["emitterOwnedKinds"]
assert 5 in parity["emitterOwnedKinds"] and 5 not in parity["semanticOwnedKinds"]
assert index_contract["finalSemanticOwnerPromotion"] == "complete"
assert index_contract["finalSemanticOwnerProof"] == RECEIPT.relative_to(ROOT).as_posix()
assert sha(ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs") == receipt["managedSourceSha256"]
for source, expected in receipt["slgSourceHashes"].items():
    assert sha(ROOT / source) == expected, source
comparison = read_json(ROOT / receipt["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert comparison["managedSourceSha256"] == receipt["managedSourceSha256"]

inference = (ROOT / "selfhost/semantic/interpolation_inference.slg").read_text(encoding="utf-8")
prepare = (ROOT / "selfhost/llvm/text/context_prepare.slg").read_text(encoding="utf-8")
emitter = (ROOT / "selfhost/llvm/text/foundation.slg").read_text(encoding="utf-8")
assert "public memberResultTypeByNode" in inference
assert "public indexedResultTypeByNode" in inference
assert "interpolationInference.memberResultTypeByNode(streamPlan, recursiveTypes!" in prepare
assert "interpolationMemberTypeByNode: memberResultTypeByNode" in prepare
type_function = emitter.split("interpolationNodeTypeId nodeIndex:", 1)[1]
index_branch = type_function.split("node.kind == 7 and node.operand0 >= 0 -> if {", 1)[1].split(
    "node.kind == 5 and node.operand0 >= 0 -> if {", 1
)[0]
member_branch = type_function.split("node.kind == 5 and node.operand0 >= 0 -> if {", 1)[1].split(
    "node.kind == 3 -> if {", 1
)[0]
assert "context.interpolationIndexedTypeByNode[semanticIndex]" in index_branch
assert "containerTypeId" not in index_branch
assert "context.interpolationMemberTypeByNode[semanticIndex]" in member_branch
assert "interpolationMemberFieldIndex" not in member_branch

build = read_json(Path(receipt["buildResult"]))
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == receipt["compilerSha256"]
prefix = read_json(Path(receipt["prefixPairedResult"]))
assert prefix["status"] == "failed" and prefix["inputStable"]
assert prefix["completed"] == 6 and prefix["total"] == 10
assert receipt["excludedFixture"] in prefix["failure"]
assert len(prefix["runs"]) == 12
retained = read_json(Path(receipt["retainedPairedResult"]))
assert retained["status"] == "passed" and retained["inputStable"]
assert retained["completed"] == retained["total"] == 3
assert len(retained["runs"]) == 6
for result in (prefix, retained):
    for run in result["runs"]:
        assert run["buildExit"] == run["llvmAsExit"] == run["directCallExit"] == run["nativeExit"] == 0
        if run["compiler"] == "selfhost":
            assert run["compilerSha256"] == receipt["compilerSha256"]
assert len({run["fixture"] for result in (prefix, retained) for run in result["runs"]}) == 9
assert receipt["validPositiveCompleted"] == receipt["validPositiveTotal"] == 9

assert len(receipt["negativeCases"]) == 4
for case in receipt["negativeCases"]:
    result = read_json(Path(case["result"]))
    assert result["state"] == "passed" and result["inputsStable"], case["name"]
    assert result["selfhostCompilerSha256"] == receipt["compilerSha256"], case["name"]
    assert result["managed"]["exitCode"] == result["selfhost"]["exitCode"] == 1
    managed = Path(result["managed"]["stderrPath"]).read_text(encoding="utf-8").strip()
    selfhost = Path(result["selfhost"]["stderrPath"]).read_text(encoding="utf-8").strip()
    assert managed == selfhost == case["exactStderr"], case["name"]

print("[C597 member result] VERIFIED current source, valid positives 9/9, exact negatives 4/4; kind 5 open")
