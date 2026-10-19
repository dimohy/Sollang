#!/usr/bin/env python3
"""Compare C# method-result field indexing with current SLG pre-IR order."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
POSITIVE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-positive.slg"
NEGATIVE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-negative.slg"
PROBE = ROOT / "artifacts/scratch/c527-kind10-indexed-shape-probe-20260929-01.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-indexed-managed-first-20260929-01")
PROBE_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-indexed-shape-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-kind10-indexed-source-comparison-20260929-01.json"
EXPECTED_SHAPE = (
    "node=0 kind=7 parent=-1 operand0=1 indexed=-1 member=-1 callMember=-1 target=-1 invalid=-1\n"
    "node=1 kind=5 parent=0 operand0=2 indexed=-1 member=-1 callMember=28 target=-1 invalid=-1\n"
    "node=2 kind=10 parent=1 operand0=3 indexed=-1 member=-1 callMember=-1 target=0 invalid=-1\n"
    "node=3 kind=1 parent=2 operand0=-1 indexed=-1 member=-1 callMember=-1 target=-1 invalid=-1\n"
    "node=4 kind=0 parent=0 operand0=-1 indexed=-1 member=-1 callMember=-1 target=-1 invalid=-1\n"
)
EXPECTED_ERROR = (
    "sollang: semantic error at 15:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def unique(lines: list[str], needle: str) -> int:
    found = [index + 1 for index, line in enumerate(lines) if needle in line]
    if len(found) != 1:
        raise ValueError(f"expected one occurrence of {needle!r}: {found}")
    return found[0]


def first(lines: list[str], needle: str) -> int:
    found = [index + 1 for index, line in enumerate(lines) if needle in line]
    if not found:
        raise ValueError(f"expected occurrence of {needle!r}")
    return found[0]


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, FACTS, INFERENCE, PREPARATION, POSITIVE, NEGATIVE, PROBE,
              MANAGED_OUTPUT / "positive.exe", MANAGED_OUTPUT / "positive.build.stderr.txt",
              MANAGED_OUTPUT / "positive.native.stdout.txt", MANAGED_OUTPUT / "positive.native.stderr.txt",
              MANAGED_OUTPUT / "negative.build.stderr.txt", PROBE_OUTPUT / "probe.exe",
              PROBE_OUTPUT / "build.stderr.txt", PROBE_OUTPUT / "probe.stdout.txt",
              PROBE_OUTPUT / "probe.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    facts = FACTS.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    preparation = PREPARATION.read_text(encoding="utf-8-sig").splitlines()
    field_start = unique(managed, "private BoundType InferFieldAccessExpression(")
    index_start = unique(managed, "private BoundType InferIndexExpression(")
    field_body = managed[field_start - 1:field_start + 190]
    index_body = managed[index_start - 1:index_start + 130]
    managed_order = {
        "fieldReceiver": field_start - 1 + unique(field_body, "var sourceType = InferExpression("),
        "fieldVisibility": field_start - 1 + unique(field_body, "EnsureStructFieldVisible("),
        "fieldType": field_start - 1 + unique(field_body, "return field.Type;"),
        "indexReceiver": index_start - 1 + unique(index_body, "var sourceType = InferExpression("),
        "indexValidation": index_start - 1 + unique(index_body, "if (indexType != expectedIndexType)"),
        "display": unique(managed, "EnsureDisplayable(interpolationType, expression.Line"),
    }
    if not (managed_order["fieldReceiver"] < managed_order["fieldVisibility"]
            < managed_order["fieldType"]
            and managed_order["indexReceiver"] < managed_order["indexValidation"]):
        raise ValueError("C# field/index receiver order changed")
    inference_text = "\n".join(inference)
    preparation_text = "\n".join(preparation)
    selfhost_order = {
        "initialIndexFacts": unique(facts, "[Int; ~] => interpolationIndexedTypeByNode!"),
        "initialIndexOwner": first(facts, "preIrInterpolationReceiverTypeId(references!, referenceIndexByTypeAst!, interpolationLexicalTypeByNode!, interpolationMemberTypeByNode!, interpolationIndexedTypeByNode!, interpolationRange.sourceModule, indexed.operand0)"),
        "callMemberFacts": unique(inference, "public preIrCallMemberTypeByNode prepared:"),
        "rootDisplay": unique(inference, "public preIrInvalidDirectDisplayTypeByNode prepared:"),
    }
    phase_order = [
        "prepared -> expressionTypeIds.resolveContext => recursiveTypes!",
        "prepared -> interpolationInference.preIrFlowCallTargets(recursiveTypes!)",
        "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode(recursiveTypes!, semanticInterpolationCallTargets)",
        "prepared -> lowerPreparedIr(recursiveTypes!, supportsComputePool)",
    ]
    positions = [preparation_text.find(part) for part in phase_order]
    if (selfhost_order["initialIndexFacts"] >= selfhost_order["initialIndexOwner"]
            or selfhost_order["callMemberFacts"] >= selfhost_order["rootDisplay"]
            or any(position < 0 for position in positions) or positions != sorted(positions)
            or "node.kind == 5 and nodeIndex! < (memberTypes -> len)" not in inference_text
            or "node.kind == 7 and nodeIndex!" in inference_text[inference_text.index("public preIrInvalidDirectDisplayTypeByNode prepared:"):inference_text.index("public invalidDisplayTypeByNode prepared:")]):
        raise ValueError("SLG pre-IR index/member source route changed")
    if (normalized(MANAGED_OUTPUT / "positive.build.stderr.txt") != ""
            or normalized(MANAGED_OUTPUT / "positive.native.stdout.txt") != "value=5\n"
            or normalized(MANAGED_OUTPUT / "positive.native.stderr.txt") != ""
            or normalized(MANAGED_OUTPUT / "negative.build.stderr.txt") != EXPECTED_ERROR):
        raise ValueError("C# method-result indexed behavior changed")
    if (normalized(PROBE_OUTPUT / "build.stderr.txt") != ""
            or normalized(PROBE_OUTPUT / "probe.stderr.txt") != ""
            or normalized(PROBE_OUTPUT / "probe.stdout.txt") != EXPECTED_SHAPE):
        raise ValueError("SLG method-result indexed shape changed")
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("source comparison inputs changed")
    record = {
        "schemaVersion": 1,
        "unit": "C527 method-result indexed projection source comparison",
        "status": "passed",
        "completed": 1,
        "total": 1,
        "inputStable": True,
        "inputSha256": start,
        "managedOrder": managed_order,
        "selfhostOrder": selfhost_order,
        "phaseOrder": phase_order,
        "preIrProbe": EXPECTED_SHAPE,
        "finding": "C# infers the method result, field, index element, and display type in receiver order. SLG computes initial index facts before kind-10 call targets, then call-derived member facts, but does not recompute the index result or validate a root index display before Typed IR.",
        "requiredStructure": "Move reusable index-result decisions to a semantic pre-IR step after call-derived member facts, preserving owner and index validation before final displayability.",
        "implementationComplete": False,
        "structuralPhasesClosed": "0/7",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# receiver order and SLG index-after-call gap compared")


if __name__ == "__main__":
    main()
