#!/usr/bin/env python3
"""Freeze C# nested field behavior and compare its current SLG decision order."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
TYPE_FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
POSITIVE = ROOT / "scripts/probes/interpolation/c527-nested-member-display-positive.slg"
NEGATIVE = ROOT / "scripts/probes/interpolation/c527-nested-member-display-negative.slg"
PRIVATE = ROOT / "scripts/probes/interpolation/c527-nested-private-intermediate.slg"
PRIVATE_DEPENDENCY = ROOT / "scripts/probes/interpolation/sample/nested_private.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-nested-member-managed-first-20260929-01")
SHAPE_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-nested-member-shape-probe-20260929-01")
PRIVATE_BASELINE = ROOT / "artifacts/scratch/c527-nested-member-baseline-20260929-01.json"
OUTPUT = ROOT / "artifacts/scratch/c527-nested-member-source-comparison-20260929-01.json"
EXPECTED_SHAPE = (
    "node=0 kind=5 parent=-1 operand0=1 lexical=-1 member=-1\n"
    "node=1 kind=5 parent=0 operand0=2 lexical=-1 member=26\n"
    "node=2 kind=1 parent=1 operand0=-1 lexical=27 member=-1\n"
)
EXPECTED_FLOAT = (
    "sollang: semantic error at 12:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def line(lines: list[str], phrase: str) -> int:
    indices = [index + 1 for index, value in enumerate(lines) if phrase in value]
    if len(indices) != 1:
        raise ValueError(f"expected one source occurrence of {phrase!r}, got {indices}")
    return indices[0]


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"source comparison output already exists: {OUTPUT}")
    inputs = [MANAGED, TYPE_FACTS, INFERENCE, PREPARATION, POSITIVE, NEGATIVE,
              PRIVATE, PRIVATE_DEPENDENCY, PRIVATE_BASELINE,
              SHAPE_OUTPUT / "probe.exe", SHAPE_OUTPUT / "probe.stdout.txt",
              SHAPE_OUTPUT / "build.stderr.txt", Path(__file__).resolve()]
    start_hashes = {str(path): sha(path) for path in inputs}
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    facts = TYPE_FACTS.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    preparation = PREPARATION.read_text(encoding="utf-8-sig").splitlines()

    method = line(managed, "private BoundType InferFieldAccessExpression(")
    body = managed[method - 1:method + 190]
    managed_order = {
        "fieldMethod": method,
        "inferReceiver": method - 1 + line(body, "var sourceType = InferExpression("),
        "checkVisibility": method - 1 + line(body, "EnsureStructFieldVisible("),
        "returnFieldType": method - 1 + line(body, "return field.Type;"),
        "checkInterpolationDisplay": line(managed, "EnsureDisplayable(interpolationType, expression.Line"),
    }
    if not (managed_order["fieldMethod"] < managed_order["inferReceiver"]
            < managed_order["checkVisibility"] < managed_order["returnFieldType"]):
        raise ValueError("C# receiver-first field decision order changed")

    member_start = line(facts, "[Int; ~] => interpolationMemberTypeByNode!")
    member_end = line(facts, "# Commit the C# owner check before considering the index operand.")
    member_body = facts[member_start - 1:member_end - 1]
    selfhost_order = {
        "memberFactStart": member_start,
        "lexicalReceiverOnly": member_start - 1 + line(member_body, "interpolationLexicalTypeByNode![member.operand0] => ownerTypeId"),
        "forwardIteration": member_start - 1 + line(member_body, "memberNodeIndex! + 1 => memberNodeIndex!"),
        "preIrDisplay": line(preparation, "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode"),
        "lowerTypedIr": line(preparation, "prepared -> lowerPreparedIr(recursiveTypes!"),
        "postIrPrivateField": line(preparation, "prepared -> interpolationInference.privateMemberFieldByNode"),
        "postIrDisplay": line(preparation, "prepared -> interpolationInference.invalidDisplayTypeByNode"),
        "privateDecision": line(inference, "public privateMemberFieldByNode prepared:"),
    }
    if not (selfhost_order["memberFactStart"] < selfhost_order["lexicalReceiverOnly"]
            < selfhost_order["forwardIteration"]
            and selfhost_order["preIrDisplay"] < selfhost_order["lowerTypedIr"]
            < selfhost_order["postIrPrivateField"] < selfhost_order["postIrDisplay"]):
        raise ValueError("SLG pre/post-IR member decision order changed")

    if normalized(SHAPE_OUTPUT / "probe.stdout.txt") != EXPECTED_SHAPE:
        raise ValueError("nested member AST shape changed")
    if (SHAPE_OUTPUT / "build.stderr.txt").stat().st_size != 0:
        raise ValueError("nested member shape probe had build diagnostics")
    if normalized(MANAGED_OUTPUT / "positive.native.stdout.txt") != "value=true\n":
        raise ValueError("C# nested Bool execution changed")
    if normalized(MANAGED_OUTPUT / "negative.build.stderr.txt") != EXPECTED_FLOAT:
        raise ValueError("C# nested Float diagnostic changed")
    private_diagnostic = normalized(MANAGED_OUTPUT / "private.build.stderr.txt")
    baseline = json.loads(PRIVATE_BASELINE.read_text(encoding="utf-8"))
    if (not baseline["exactDiagnosticMatch"] or baseline["diagnostic"] != private_diagnostic
            or baseline["sourceComparisonComplete"]):
        raise ValueError("nested private-field baseline changed")
    for source in (MANAGED, TYPE_FACTS, INFERENCE, PREPARATION, PRIVATE, PRIVATE_DEPENDENCY):
        if baseline["sourceSha256"][str(source.relative_to(ROOT)).replace("\\", "/")] != sha(source):
            raise ValueError(f"private-field baseline source drifted: {source}")

    stable = start_hashes == {str(path): sha(path) for path in inputs}
    if not stable:
        raise ValueError("source comparison inputs changed during verification")
    result = {
        "schemaVersion": 1,
        "unit": "C527 nested member expression source comparison",
        "status": "passed",
        "completed": 1,
        "total": 1,
        "inputStable": stable,
        "inputSha256": start_hashes,
        "managedDecision": "C# recursively infers the immediate receiver, checks field visibility, returns field type, then checks interpolation displayability.",
        "selfhostCurrentDecision": "Nested member AST nodes are parent-before-child; current pre-IR field facts consume lexical receivers in forward order, so only the inner field type is known before Typed IR. Post-IR semantic facts preserve the intermediate private-field diagnostic.",
        "requiredStructure": "Resolve member nodes child-before-parent, preserving each field visibility and receiver decision before propagating its type to the parent; check a root's displayability only after its accessible path is known.",
        "managedOrder": managed_order,
        "selfhostOrder": selfhost_order,
        "astShape": EXPECTED_SHAPE,
        "managedFirstOutput": str(MANAGED_OUTPUT),
        "privateBaseline": str(PRIVATE_BASELINE),
        "implementationComplete": False,
        "fullPreIrExpressionClosure": False,
        "structuralPhasesClosed": "0/7",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# receiver-first behavior and SLG nested source order compared")


if __name__ == "__main__":
    main()
