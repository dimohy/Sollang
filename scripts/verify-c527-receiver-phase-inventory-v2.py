#!/usr/bin/env python3
"""Pin current interpolation receiver routes after nominal literal lowering."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = Path(r"C:\Users\dimohy\AppData\Local\Sollang")
COMPILER = BASE / "c527-struct-literal-unknown-type-compiler-o1-20260929-01/compiler.exe"
BUILD = BASE / "c527-struct-literal-unknown-type-compiler-o1-20260929-01/result.json"
LOWERING = ROOT / "selfhost/ir/interpolation.slg"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
EMITTER = ROOT / "selfhost/llvm/text/foundation.slg"
DIAGNOSTICS = ROOT / "selfhost/llvm/emitter/diagnostics.slg"
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
PROOFS = {
    "retainedReceiverControls": ROOT / "artifacts/scratch/c527-struct-literal-current-source-controls-20260929-01.json",
    "unknownNominalType": BASE / "c527-struct-literal-unknown-type-focused-20260929-01/result.json",
    "textInitializer": ROOT / "artifacts/scratch/c527-struct-literal-text-reused-pair-20260929-01.json",
}
OUTPUT = ROOT / "artifacts/scratch/c527-receiver-phase-inventory-v2-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def require(path: Path, fragment: str) -> None:
    if fragment not in path.read_text(encoding="utf-8-sig"):
        raise ValueError(f"receiver route changed in {path}: {fragment}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    build = json.loads(BUILD.read_text(encoding="utf-8"))
    compiler_hash = sha(COMPILER)
    if build["status"] != "passed" or not build["inputsStable"] or build["compilerSha256"] != compiler_hash:
        raise ValueError("current compiler build is invalid")
    for fragment in ("# 12 contextual struct literal, 13 struct field name, 14 nominal struct literal.",
                     "fragmentNode.kind == 39 -> if { 14 => loweredKind! }",
                     "fragmentNode.kind == 40 and fragmentNode.parent >= 0"):
        require(LOWERING, fragment)
    first = FACTS.read_text(encoding="utf-8-sig").split("public preIrInterpolationReceiverTypeId prepared:", 1)[1].split("nominalInterpolationTypeId prepared:", 1)[0]
    for kind in (1, 5, 7, 8, 14):
        if f"owner.kind == {kind}" not in first:
            raise ValueError(f"pre-IR receiver kind {kind} is missing")
    for path, fragments in {
        FACTS: ("nominalInterpolationTypeId prepared:", "interpolationContextualStructTypeByNode![literalNodeIndex!]",
                "literal.kind == 14 -> if {", "code: 6"),
        INFERENCE: ("public resultPropagationDecisionByNode prepared:", "intrinsicFlowResultBuiltinSymbol prepared:"),
        EMITTER: ("emitInterpolationContextualStruct labelIndex:", "node.kind == 12 or node.kind == 14 -> if {"),
        DIAGNOSTICS: ("firstBlockingInterpolationNode context:", "unknown struct type '$typeName'"),
        MANAGED: ("StructLiteralExpression literal => InferStructLiteralExpression(",
                  "FieldAccessExpression field => InferFieldAccessExpression("),
    }.items():
        for fragment in fragments:
            require(path, fragment)
    for name, path in PROOFS.items():
        proof = json.loads(path.read_text(encoding="utf-8"))
        stable = proof.get("inputStable", proof.get("inputsStable"))
        if proof["status"] != "passed" or stable is not True:
            raise ValueError(f"focused receiver proof is invalid: {name}")
        if proof["inputSha256"].get(str(COMPILER)) != compiler_hash:
            raise ValueError(f"focused receiver proof uses another compiler: {name}")
    inputs = [COMPILER, BUILD, LOWERING, FACTS, INFERENCE, EMITTER, DIAGNOSTICS, MANAGED,
              *PROOFS.values(), Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("inventory inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 receiver phase inventory after nominal literal",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "compilerSha256": compiler_hash,
              "mappedInterpolationKinds": 15, "firstPassReceiverKinds": [1, 5, 7, 8, 14],
              "laterCallDerivedReceiverKinds": [5, 7, 10], "postIrReceiverKinds": [6, 11],
              "focusedProofGroups": {name: str(path) for name, path in PROOFS.items()},
              "scope": "Syntax and phase-route inventory only; no complete semantic coverage or structural parity claim."}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 15 syntax kinds, 5 first-pass receiver kinds")


if __name__ == "__main__":
    main()
