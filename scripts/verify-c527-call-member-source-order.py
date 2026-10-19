#!/usr/bin/env python3
"""Freeze C# call-result member behavior and compare the SLG pre-IR owner path."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
POSITIVE = ROOT / "scripts/probes/interpolation/c527-call-result-member-display-positive.slg"
NEGATIVE = ROOT / "scripts/probes/interpolation/c527-call-result-member-display-negative.slg"
PROBE = ROOT / "artifacts/scratch/c527-call-member-preir-probe-20260929-01.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-call-member-managed-first-20260929-01")
PROBE_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-call-member-preir-probe-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-call-member-source-comparison-20260929-01.json"
EXPECTED_ERROR = (
    "sollang: semantic error at 8:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)
EXPECTED_PROBE = (
    "node=0 kind=5 parent=-1 member=-1 invalid=-1\n"
    "node=1 kind=8 parent=0 member=-1 invalid=-1\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def unique_line(lines: list[str], term: str) -> int:
    matches = [index + 1 for index, line in enumerate(lines) if term in line]
    if len(matches) != 1:
        raise ValueError(f"expected one occurrence of {term!r}: {matches}")
    return matches[0]


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, FACTS, INFERENCE, POSITIVE, NEGATIVE, PROBE,
              MANAGED_OUTPUT / "positive.exe", MANAGED_OUTPUT / "positive.build.stderr.txt",
              MANAGED_OUTPUT / "negative.build.stderr.txt", PROBE_OUTPUT / "probe.exe",
              PROBE_OUTPUT / "build.stderr.txt", PROBE_OUTPUT / "probe.stdout.txt",
              PROBE_OUTPUT / "probe.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    facts = FACTS.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    method = unique_line(managed, "private BoundType InferFieldAccessExpression(")
    body = managed[method - 1:method + 190]
    managed_order = {
        "inferCallReceiver": method - 1 + unique_line(body, "var sourceType = InferExpression("),
        "checkFieldVisibility": method - 1 + unique_line(body, "EnsureStructFieldVisible("),
        "returnFieldType": method - 1 + unique_line(body, "return field.Type;"),
        "checkDisplay": unique_line(managed, "EnsureDisplayable(interpolationType, expression.Line"),
    }
    if not (managed_order["inferCallReceiver"] < managed_order["checkFieldVisibility"]
            < managed_order["returnFieldType"]):
        raise ValueError("C# call-result member order changed")
    owner_helper = unique_line(facts, "public preIrInterpolationIndexOwnerTypeId prepared:")
    member_start = unique_line(facts, "[Int; ~] => interpolationMemberTypeByNode!")
    member_end = unique_line(facts, "prepared.interpolations[memberNodeIndex!] => indexed")
    member_pass = "\n".join(facts[member_start - 1:member_end - 1])
    if ("owner.kind == 8 and owner.symbol >= 0" not in "\n".join(facts[owner_helper - 1:owner_helper + 50])
            or "preIrInterpolationIndexOwnerTypeId(" in member_pass
            or "prepared.interpolations[member.operand0].kind == 8" in member_pass
            or "bindingFacts.interpolationMemberTypeByNode[nodeIndex!] => typeId!" not in "\n".join(inference)):
        raise ValueError("SLG call-result member source decision changed")
    if (normalized(MANAGED_OUTPUT / "positive.build.stderr.txt") != ""
            or normalized(MANAGED_OUTPUT / "negative.build.stderr.txt") != EXPECTED_ERROR):
        raise ValueError("C# call-result member behavior changed")
    if normalized(PROBE_OUTPUT / "build.stderr.txt") != "":
        raise ValueError("SLG pre-IR probe build has diagnostics")
    if (normalized(PROBE_OUTPUT / "probe.stdout.txt") != EXPECTED_PROBE
            or normalized(PROBE_OUTPUT / "probe.stderr.txt") != ""):
        raise ValueError("SLG call-result member pre-IR shape changed")
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("source comparison inputs changed")
    record = {
        "schemaVersion": 1,
        "unit": "C527 call-result member display source comparison",
        "status": "passed",
        "completed": 1,
        "total": 1,
        "inputStable": True,
        "inputSha256": start,
        "managedOrder": managed_order,
        "selfhostMemberPass": [member_start, member_end],
        "selfhostCallResultHelper": owner_helper,
        "preIrProbe": EXPECTED_PROBE,
        "finding": "C# infers the call result before field visibility and display checks; SLG has a pre-IR call-result type resolver for indexes but the member owner path does not consume it.",
        "requiredStructure": "Use the existing semantic call-result type resolver for the member receiver, then apply the shared field and visibility decisions before display validation.",
        "implementationComplete": False,
        "structuralPhasesClosed": "0/7",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: C# call-result field behavior and SLG source path compared")


if __name__ == "__main__":
    main()
