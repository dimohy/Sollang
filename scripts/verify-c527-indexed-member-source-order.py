#!/usr/bin/env python3
"""Record the C# indexed receiver decision and the current SLG pre-IR gap."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
POSITIVE = ROOT / "examples/regression/2055-indexed-struct-interpolation-type.slg"
NEGATIVE = ROOT / "scripts/probes/interpolation/c527-indexed-member-display-negative.slg"
PROBE = ROOT / "artifacts/scratch/c527-indexed-member-preir-probe-20260929-01.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-indexed-member-managed-first-20260929-01")
PROBE_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-indexed-member-preir-probe-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-indexed-member-source-comparison-20260929-01.json"
EXPECTED_PROBE = (
    "node=0 kind=5 parent=-1 indexed=-1 member=-1 invalid=-1\n"
    "node=1 kind=7 parent=0 indexed=26 member=-1 invalid=-1\n"
)
EXPECTED_ERROR = (
    "sollang: semantic error at 7:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def unique_line(lines: list[str], text: str) -> int:
    matches = [index + 1 for index, value in enumerate(lines) if text in value]
    if len(matches) != 1:
        raise ValueError(f"expected one occurrence of {text!r}: {matches}")
    return matches[0]


def first_line(lines: list[str], text: str) -> int:
    matches = [index + 1 for index, value in enumerate(lines) if text in value]
    if not matches:
        raise ValueError(f"missing source occurrence of {text!r}")
    return matches[0]


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, FACTS, INFERENCE, PREPARATION, POSITIVE, NEGATIVE, PROBE,
              MANAGED_OUTPUT / "positive.exe", MANAGED_OUTPUT / "positive.build.stderr.txt",
              MANAGED_OUTPUT / "positive.native.stdout.txt", MANAGED_OUTPUT / "positive.native.stderr.txt",
              MANAGED_OUTPUT / "build.stderr.txt", PROBE_OUTPUT / "probe.exe",
              PROBE_OUTPUT / "build.stderr.txt", PROBE_OUTPUT / "build.stdout.txt",
              PROBE_OUTPUT / "probe.stdout.txt", PROBE_OUTPUT / "probe.stderr.txt",
              Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    facts = FACTS.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    preparation = PREPARATION.read_text(encoding="utf-8-sig").splitlines()
    index_method = unique_line(managed, "private BoundType InferIndexExpression(")
    member_method = unique_line(managed, "private BoundType InferFieldAccessExpression(")
    index_body = managed[index_method - 1:index_method + 170]
    member_body = managed[member_method - 1:member_method + 190]
    managed_order = {
        "indexSource": index_method - 1 + unique_line(index_body, "var sourceType = InferExpression("),
        "indexType": index_method - 1 + unique_line(index_body, "var indexType = expression.Index is NumberExpression"),
        "indexElement": index_method - 1 + first_line(index_body, "return elementType;"),
        "memberReceiver": member_method - 1 + unique_line(member_body, "var sourceType = InferExpression("),
        "memberVisibility": member_method - 1 + unique_line(member_body, "EnsureStructFieldVisible("),
        "memberType": member_method - 1 + unique_line(member_body, "return field.Type;"),
        "display": unique_line(managed, "EnsureDisplayable(interpolationType, expression.Line"),
    }
    if not (managed_order["indexSource"] < managed_order["indexType"] < managed_order["indexElement"]
            < managed_order["memberReceiver"] < managed_order["memberVisibility"]
            < managed_order["memberType"]):
        raise ValueError("C# receiver-first indexed member order changed")
    selfhost_order = {
        "memberPass": unique_line(facts, "[Int; ~] => interpolationMemberTypeByNode!"),
        "indexPass": unique_line(facts, "[Int; ~] => interpolationIndexedTypeByNode!"),
        "indexResult": unique_line(facts, "ownerType.first => interpolationIndexedTypeByNode![indexedNodeIndex!]"),
        "rootPreIrDisplay": unique_line(inference, "bindingFacts.interpolationMemberTypeByNode[nodeIndex!] => typeId!"),
        "preIrBeforeTypedIr": unique_line(preparation, "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode"),
        "typedIr": unique_line(preparation, "prepared -> lowerPreparedIr(recursiveTypes!"),
    }
    member_pass = facts[selfhost_order["memberPass"] - 1:selfhost_order["indexPass"] - 1]
    if (not selfhost_order["memberPass"] < selfhost_order["indexPass"] < selfhost_order["indexResult"]
            or "interpolationIndexedTypeByNode!" in "\n".join(member_pass)
            or not selfhost_order["preIrBeforeTypedIr"] < selfhost_order["typedIr"]):
        raise ValueError("SLG pre-IR indexed member ordering changed")
    if normalized(MANAGED_OUTPUT / "positive.build.stderr.txt") != "":
        raise ValueError("C# positive build has diagnostics")
    if (normalized(MANAGED_OUTPUT / "positive.native.stdout.txt") != "value=5\n"
            or normalized(MANAGED_OUTPUT / "positive.native.stderr.txt") != ""):
        raise ValueError("C# indexed Int execution changed")
    if normalized(MANAGED_OUTPUT / "build.stderr.txt") != EXPECTED_ERROR:
        raise ValueError("C# indexed Float diagnostic changed")
    if normalized(PROBE_OUTPUT / "build.stderr.txt") != "":
        raise ValueError("pre-IR probe build has diagnostics")
    if normalized(PROBE_OUTPUT / "probe.stderr.txt") != "":
        raise ValueError("pre-IR probe execution has diagnostics")
    if normalized(PROBE_OUTPUT / "probe.stdout.txt") != EXPECTED_PROBE:
        raise ValueError("pre-IR indexed member shape changed")
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("source comparison inputs changed")
    record = {
        "schemaVersion": 1,
        "unit": "C527 indexed receiver member source comparison",
        "status": "passed",
        "completed": 1,
        "total": 1,
        "inputStable": True,
        "inputSha256": start,
        "managedOrder": managed_order,
        "selfhostOrder": selfhost_order,
        "preIrProbe": EXPECTED_PROBE,
        "finding": "C# infers the indexed receiver before its field and display type. SLG records member types before indexed result types, leaving the root member type unresolved before Typed IR.",
        "requiredStructure": "Resolve member and index nodes by AST dependency order; preserve index validation, field accessibility, and display error precedence for mixed paths.",
        "implementationComplete": False,
        "structuralPhasesClosed": "0/7",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# index-to-field order and SLG pre-IR gap compared")


if __name__ == "__main__":
    main()
