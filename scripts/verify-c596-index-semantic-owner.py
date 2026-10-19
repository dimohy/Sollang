"""Verify the current-source kind-7 semantic result owner and focused evidence."""

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECEIPT = ROOT / "artifacts/scratch/c596-index-result-semantic-unit-20260928-01.json"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


receipt = read_json(RECEIPT)
assert receipt["unit"] == "C596-index-result-semantic-owner"
assert receipt["completed"] == receipt["total"] == 3
assert len(receipt["steps"]) == 3
assert all(step["status"] == "complete" for step in receipt["steps"])
parity = read_json(ROOT / "scripts/contracts/interpolation-semantic-parity.json")
branch_contract = read_json(ROOT / "scripts/contracts/interpolation-index-branch-progress.json")
assert 7 in parity["semanticOwnedKinds"] and 7 not in parity["emitterOwnedKinds"]
assert branch_contract["finalSemanticOwnerPromotion"] == "complete"
assert branch_contract["finalSemanticOwnerProof"] == RECEIPT.relative_to(ROOT).as_posix()
assert sha(ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs") == receipt["managedSourceSha256"]
for source, expected in receipt["slgSourceHashes"].items():
    assert sha(ROOT / source) == expected, source

comparison = read_json(ROOT / receipt["sourceComparison"])
assert comparison["status"] == "source-compared-before-slg-edit"
assert comparison["managedSourceSha256"] == receipt["managedSourceSha256"]

semantic = (ROOT / "selfhost/semantic/interpolation_inference.slg").read_text(encoding="utf-8")
prepare = (ROOT / "selfhost/llvm/text/context_prepare.slg").read_text(encoding="utf-8")
emitter = (ROOT / "selfhost/llvm/text/foundation.slg").read_text(encoding="utf-8")
assert "public indexedResultTypeByNode" in semantic
assert "prepared -> expressionTypeId(plan, bindingFacts, ir, types, fields, sourceModule, nodeIndex!) => resultTypeId!" in semantic
assert "interpolationInference.indexedResultTypeByNode(streamPlan, recursiveTypes!" in prepare
assert "interpolationIndexedTypeByNode: indexedResultTypeByNode" in prepare
type_function = emitter.split("interpolationNodeTypeId nodeIndex:", 1)[1]
index_branch = type_function.split("node.kind == 7 and node.operand0 >= 0 -> if {", 1)[1].split(
    "node.kind == 5 and node.operand0 >= 0 -> if {", 1
)[0]
assert "context.interpolationIndexedTypeByNode[semanticIndex]" in index_branch
assert "containerTypeId" not in index_branch

build = read_json(Path(receipt["buildResult"]))
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == receipt["compilerSha256"]
paired = read_json(Path(receipt["pairedResult"]))
assert paired["status"] == "passed" and paired["inputStable"]
assert paired["completed"] == paired["total"] == 8
assert len(paired["runs"]) == 16
retained = read_json(Path(receipt["retainedPairedResult"]))
assert retained["status"] == "passed" and retained["inputStable"]
assert retained["completed"] == retained["total"] == 6
assert len(retained["runs"]) == 12
for result in (paired, retained):
    assert {run["compiler"] for run in result["runs"]} == {"managed", "selfhost"}
    assert len({run["fixture"] for run in result["runs"]}) == result["total"]
    for run in result["runs"]:
        assert run["buildExit"] == run["llvmAsExit"] == run["directCallExit"] == run["nativeExit"] == 0
        if run["compiler"] == "selfhost":
            assert run["compilerSha256"] == receipt["compilerSha256"]

assert len(receipt["negativeCases"]) == 13
for case in receipt["negativeCases"]:
    result = read_json(Path(case["result"]))
    assert result["state"] == "passed" and result["inputsStable"], case["name"]
    assert result["selfhostCompilerSha256"] == receipt["compilerSha256"], case["name"]
    assert result["managed"]["exitCode"] == result["selfhost"]["exitCode"] == 1
    assert result["managed"]["noEmittedProducts"] and result["selfhost"]["noEmittedProducts"]
    managed_error = Path(result["managed"]["stderrPath"]).read_text(encoding="utf-8").strip()
    selfhost_error = Path(result["selfhost"]["stderrPath"]).read_text(encoding="utf-8").strip()
    assert managed_error == selfhost_error == case["exactStderr"], case["name"]

print("[C596 semantic index owner] VERIFIED source bridge, positive 14/14, exact negative 13/13")
