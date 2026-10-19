#!/usr/bin/env python3
"""Compare C# method-result field inference with SLG kind-10 pre-IR facts."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
LOWERING = ROOT / "selfhost/ir/interpolation.slg"
POSITIVE = ROOT / "artifacts/scratch/c527-kind10-call-receiver-positive-20260929-01.slg"
NEGATIVE = ROOT / "artifacts/scratch/c527-kind10-call-receiver-candidate-20260929-01.slg"
PROBE = ROOT / "artifacts/scratch/c527-kind10-call-receiver-shape-20260929-01.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-call-receiver-managed-20260929-01")
PROBE_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-call-receiver-shape-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-kind10-receiver-source-comparison-20260929-01.json"
EXPECTED_SHAPE = (
    "node=0 kind=5 parent=-1 operand0=1 member=-1 invalid=-1\n"
    "node=1 kind=10 parent=0 operand0=2 member=-1 invalid=-1\n"
    "node=2 kind=1 parent=1 operand0=-1 member=-1 invalid=-1\n"
)
EXPECTED_ERROR = (
    "sollang: semantic error at 15:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def unique(lines: list[str], term: str) -> int:
    result = [index + 1 for index, line in enumerate(lines) if term in line]
    if len(result) != 1:
        raise ValueError(f"expected one occurrence of {term!r}: {result}")
    return result[0]


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, FACTS, INFERENCE, LOWERING, POSITIVE, NEGATIVE, PROBE,
              MANAGED_OUTPUT / "positive.exe", MANAGED_OUTPUT / "positive.build.stderr.txt",
              MANAGED_OUTPUT / "positive.native.stdout.txt", MANAGED_OUTPUT / "positive.native.stderr.txt",
              MANAGED_OUTPUT / "build.stderr.txt", PROBE_OUTPUT / "probe.exe",
              PROBE_OUTPUT / "build.stderr.txt", PROBE_OUTPUT / "probe.stdout.txt",
              PROBE_OUTPUT / "probe.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    facts = FACTS.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    lowering = LOWERING.read_text(encoding="utf-8-sig").splitlines()
    flow_method = unique(managed, "private FlowResult InferFlowExpression(")
    flow_body = managed[flow_method - 1:flow_method + 90]
    member_method = unique(managed, "private BoundType InferFieldAccessExpression(")
    member_body = managed[member_method - 1:member_method + 190]
    managed_order = {
        "flowMethod": flow_method,
        "flowSource": flow_method - 1 + unique(flow_body, "var currentType = initialCollectionContext"),
        "methodLookup": flow_method - 1 + unique(flow_body, "TryResolveInstanceMethod(currentType, firstTargetPath"),
        "memberReceiver": member_method - 1 + unique(member_body, "var sourceType = InferExpression("),
        "memberVisibility": member_method - 1 + unique(member_body, "EnsureStructFieldVisible("),
        "memberType": member_method - 1 + unique(member_body, "return field.Type;"),
        "display": unique(managed, "EnsureDisplayable(interpolationType, expression.Line"),
    }
    if not (managed_order["flowSource"] < managed_order["methodLookup"]
            and managed_order["memberReceiver"] < managed_order["memberVisibility"]
            < managed_order["memberType"]):
        raise ValueError("C# method-result or field source order changed")
    helper_start = unique(facts, "public preIrInterpolationReceiverTypeId prepared:")
    helper_end = unique(facts, "public resolveContext prepared:")
    helper = "\n".join(facts[helper_start - 1:helper_end - 1])
    if ("owner.kind == 8 and owner.symbol >= 0" not in helper
            or "owner.kind == 10" in helper
            or "node.kind == 10 and node.operand0 >= 0" not in "\n".join(inference)
            or "flowFunctionTarget! and not flowQualifiedTarget!" not in "\n".join(lowering)):
        raise ValueError("SLG kind-10 receiver source route changed")
    if (normalized(MANAGED_OUTPUT / "positive.build.stderr.txt") != ""
            or normalized(MANAGED_OUTPUT / "positive.native.stdout.txt") != "value=5\n"
            or normalized(MANAGED_OUTPUT / "positive.native.stderr.txt") != ""
            or normalized(MANAGED_OUTPUT / "build.stderr.txt") != EXPECTED_ERROR):
        raise ValueError("C# kind-10 receiver behavior changed")
    if (normalized(PROBE_OUTPUT / "build.stderr.txt") != ""
            or normalized(PROBE_OUTPUT / "probe.stderr.txt") != ""
            or normalized(PROBE_OUTPUT / "probe.stdout.txt") != EXPECTED_SHAPE):
        raise ValueError("kind-10 interpolation shape changed")
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("source comparison inputs changed")
    record = {
        "schemaVersion": 1,
        "unit": "C527 kind-10 call receiver eligibility and source comparison",
        "status": "passed",
        "completed": 1,
        "total": 1,
        "inputStable": True,
        "inputSha256": start,
        "managedOrder": managed_order,
        "selfhostPreIrReceiverHelper": [helper_start, helper_end],
        "astShape": EXPECTED_SHAPE,
        "finding": "A valid instance method result is interpolation kind 10 and can own a field. C# resolves method result then field and display type. SLG post-IR resolves kind 10, but pre-IR receiver facts omit it, leaving the field and display type unknown before Typed IR.",
        "requiredStructure": "Resolve the instance method's declared result and argument validity before propagating it to field inference, preserving the C# method and field diagnostic order.",
        "implementationComplete": False,
        "structuralPhasesClosed": "0/7",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: valid kind-10 receiver and C#/SLG decision order compared")


if __name__ == "__main__":
    main()
