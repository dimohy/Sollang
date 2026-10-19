#!/usr/bin/env python3
"""Inventory prepared interpolation receiver kinds without claiming parity."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOWERING = ROOT / "selfhost/ir/interpolation.slg"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
OUTPUT = ROOT / "artifacts/scratch/c527-preir-receiver-inventory-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [LOWERING, FACTS, INFERENCE, Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    lowering = LOWERING.read_text(encoding="utf-8")
    facts = FACTS.read_text(encoding="utf-8")
    inference = INFERENCE.read_text(encoding="utf-8")
    required = {
        "literal": "fragmentNode.kind == 14 -> if { 0 => loweredKind! }",
        "name": "fragmentNode.kind == 15 -> if { 1 => loweredKind! }",
        "unary": "fragmentNode.kind == 22 -> if { 2 => loweredKind! }",
        "binary": "-> if { 3 => loweredKind! }",
        "boolLiteral": "fragmentNode.kind == 83 -> if { 4 => loweredKind! }",
        "member": "fragmentNode.kind == 36 -> if { 5 => loweredKind! }",
        "intrinsicFlow": "intrinsicFlowOpcode! < -1 -> if { 6 => loweredKind! }",
        "index": "fragmentNode.kind == 41 -> if { 7 => loweredKind! }",
        "resolvedCall": "resolvedFlowSymbol! >= 0 -> if { 8 => loweredKind! }",
        "conversion": "flowConversionSymbol! >= 0 -> if { 9 => loweredKind! }",
        "unresolvedCall": "-> if { 10 => loweredKind! }",
        "propagation": "fragmentNode.kind == 82 -> if { 11 => loweredKind! }",
        "structLiteral": "fragmentNode.kind == 38 -> if { 12 => loweredKind! }",
        "fieldLabel": "fieldChildOrdinal! % 2 == 0 -> if { 13 => loweredKind! }",
    }
    for name, fragment in required.items():
        if fragment not in lowering:
            raise ValueError(f"interpolation kind mapping changed: {name}")
    helper_start = facts.index("public preIrInterpolationReceiverTypeId prepared:")
    helper_end = facts.index("public resolveContext prepared:", helper_start)
    helper = facts[helper_start:helper_end]
    supported = {
        1: "owner.kind == 1 and nodeIndex < (lexicalTypes -> len)",
        5: "owner.kind == 5 and nodeIndex < (memberTypes -> len)",
        7: "owner.kind == 7 and nodeIndex < (indexedTypes -> len)",
        8: "owner.kind == 8 and owner.symbol >= 0",
    }
    for kind, fragment in supported.items():
        if fragment not in helper:
            raise ValueError(f"pre-IR receiver kind {kind} changed")
    if ("node.kind == 10 and node.operand0 >= 0" not in inference
            or "node.kind == 9 and node.typeSymbol >= 0" not in inference
            or "bindingFacts.interpolationMemberTypeByNode[nodeIndex!] => typeId!" not in inference):
        raise ValueError("post-IR comparison reference changed")
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("inventory inputs changed")
    entries = [
        {"kind": kind, "name": name, "preIrReceiver": "resolved" if kind in supported else "not-handled",
         "defectConfirmed": False}
        for kind, name in enumerate(required)
    ]
    record = {
        "schemaVersion": 1,
        "unit": "C527 remaining pre-IR receiver expression inventory",
        "status": "passed",
        "completed": 1,
        "total": 1,
        "inputStable": True,
        "inputSha256": start,
        "mappedKinds": 14,
        "preIrReceiverHandledKinds": 4,
        "unhandledKinds": 10,
        "countsAreStaticSyntaxInventoryOnly": True,
        "entries": entries,
        "nextComparisonCandidate": {
            "kind": 10,
            "name": "unresolvedCall",
            "reason": "Post-IR inference handles kind 10 call targets; pre-IR receiver resolution does not. Confirm whether a valid nominal result can be a field receiver before implementation.",
        },
        "structuralPhasesClosed": "0/7",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 14 syntax kinds, 4 handled pre-IR receivers; eligibility remains unconfirmed")


if __name__ == "__main__":
    main()
