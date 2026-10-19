#!/usr/bin/env python3
"""Refresh interpolation receiver routes without treating syntax counts as parity."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREVIOUS = ROOT / "artifacts/scratch/c527-preir-receiver-inventory-20260929-01.json"
LOWERING = ROOT / "selfhost/ir/interpolation.slg"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
COMPILER = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-compiler-o1-20260929-01\compiler.exe")
PROOFS = {
    "instanceMethodResult": Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-kind10-retained-20260929-01\result.json"),
    "intrinsicFlowResult": Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-intrinsic-retained-20260929-01\result.json"),
    "resultPropagation": Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-focused-20260929-01\result.json"),
}
OUTPUT = ROOT / "artifacts/scratch/c527-receiver-phase-inventory-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def require(text: str, fragment: str) -> None:
    if fragment not in text:
        raise ValueError(f"receiver route changed: {fragment}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [PREVIOUS, LOWERING, FACTS, INFERENCE, PREPARATION, MANAGED,
              COMPILER, *PROOFS.values(), Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    previous = json.loads(PREVIOUS.read_text(encoding="utf-8"))
    if (previous["status"] != "passed" or previous["mappedKinds"] != 14
            or previous["inputSha256"][str(LOWERING)] != sha(LOWERING)):
        raise ValueError("lowering syntax inventory changed")
    facts = FACTS.read_text(encoding="utf-8")
    inference = INFERENCE.read_text(encoding="utf-8")
    preparation = PREPARATION.read_text(encoding="utf-8")
    managed = MANAGED.read_text(encoding="utf-8")
    first_start = facts.index("public preIrInterpolationReceiverTypeId prepared:")
    first_end = facts.index("public resolveContext prepared:", first_start)
    first_pass = facts[first_start:first_end]
    for fragment in ("owner.kind == 1", "owner.kind == 5", "owner.kind == 7", "owner.kind == 8"):
        require(first_pass, fragment)
    for fragment in ("public preIrCallMemberTypeByNode prepared:",
                     "receiver.kind == 10 and member.operand0 < (callTargets -> len)",
                     "expressionTypeIds.preIrIndexedResultTypeId(",
                     "public resultPropagationDecisionByNode prepared:",
                     "intrinsicFlowResultBuiltinSymbol prepared:"):
        require(inference, fragment)
    for fragment in ("interpolationInference.preIrFlowCallTargets(recursiveTypes!)",
                     "interpolationInference.resultPropagationDecisionByNode(",
                     "interpolationInference.invalidDisplayTypeByNode("):
        require(preparation, fragment)
    for fragment in ("StructLiteralExpression literal => InferStructLiteralExpression(",
                     "FieldAccessExpression field => InferFieldAccessExpression("):
        require(managed, fragment)
    compiler_hash = sha(COMPILER)
    proof_status = {}
    for name, path in PROOFS.items():
        proof = json.loads(path.read_text(encoding="utf-8"))
        if (proof["status"] != "passed" or not proof["inputsStable"]
                or proof["inputSha256"][str(COMPILER)] != compiler_hash
                or proof["inputSha256"][str(INFERENCE)] != sha(INFERENCE)
                or proof["inputSha256"][str(PREPARATION)] != sha(PREPARATION)):
            raise ValueError(f"{name} focused proof is stale or incomplete")
        proof_status[name] = {"status": "current-source-focused", "result": str(path),
                              "compilerSha256": compiler_hash}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("inventory inputs changed")
    record = {"schemaVersion": 2, "unit": "C527 pre-IR receiver coverage inventory refresh",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "mappedSyntaxKinds": 14,
              "firstPassReceiverKinds": [1, 5, 7, 8],
              "laterCallDerivedReceiverKinds": [5, 7, 10],
              "postIrFocusedReceiverKinds": [6, 11],
              "focusedScenarios": proof_status,
              "nextComparisonCandidate": {"kind": 12, "name": "structLiteral",
                                          "question": "Can a direct nominal struct literal be a field receiver inside interpolation, and where does each compiler commit its type?"},
              "countsAreSyntaxAndRouteInventoryOnly": True,
              "structuralPhasesClosed": "0/7"}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 14 syntax kinds; 3 current-source focused scenarios")


if __name__ == "__main__":
    main()
