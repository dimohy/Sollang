#!/usr/bin/env python3
"""Compare C# Result propagation and field diagnostics with the SLG route."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
EMITTER = ROOT / "selfhost/llvm/emitter/diagnostics.slg"
SOURCE = ROOT / "scripts/probes/interpolation/c527-propagated-result-member-error-mismatch.slg"
MANAGED_PROOF = ROOT / "artifacts/scratch/c527-propagated-result-member-managed-first-20260929-01.json"
PROBE = ROOT / "artifacts/scratch/c527-propagated-member-decision-probe-20260929-01.slg"
PROBE_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-member-decision-probe-20260929-03")
SELFHOST_ERROR = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-propagated-result-member-selfhost-before-20260929-01\mismatch.build.stderr.txt")
OUTPUT = ROOT / "artifacts/scratch/c527-propagated-member-source-comparison-20260929-01.json"
EXPECTED_MANAGED = "sollang: semantic error at 1:13: [module '<main>'] '?' error type Text does not match function error type Int\n"
EXPECTED_SELFHOST = "sollang: semantic error at 8:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def first(lines: list[str], needle: str) -> int:
    for index, line in enumerate(lines, 1):
        if needle in line:
            return index
    raise ValueError(f"missing source decision: {needle}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    paths = [MANAGED, INFERENCE, PREPARATION, EMITTER, SOURCE, MANAGED_PROOF,
             PROBE, PROBE_OUTPUT / "probe.exe", PROBE_OUTPUT / "probe.stdout.txt",
             PROBE_OUTPUT / "probe.stderr.txt", SELFHOST_ERROR, Path(__file__).resolve()]
    start = {str(path): sha(path) for path in paths}
    proof = json.loads(MANAGED_PROOF.read_text(encoding="utf-8"))
    if proof["status"] != "passed" or proof["inputSha256"][str(SOURCE)] != sha(SOURCE):
        raise ValueError("C# first proof is invalid")
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    preparation = PREPARATION.read_text(encoding="utf-8-sig").splitlines()
    emitter = EMITTER.read_text(encoding="utf-8-sig").splitlines()
    field_start = first(managed, "private BoundType InferFieldAccessExpression(")
    managed_order = {
        "fieldReceiver": first(managed[field_start - 1:], "var sourceType = InferExpression(") + field_start - 1,
        "propagation": first(managed, "private BoundType InferTryExpression("),
        "resultCheck": first(managed, "if (!_types.TryGetResultTypes(operandType, out var operandResult))"),
        "errorCheck": first(managed, "if (operandResult.Error != outerResult.Error)"),
        "okResult": first(managed, "return operandResult.Ok;"),
    }
    selfhost_order = {
        "resultPayload": first(inference, "node.kind == 11 and node.operand0 >= 0 -> if {"),
        "propagationDecision": first(inference, "public resultPropagationDecisionByNode prepared:"),
        "displayDecision": first(inference, "public invalidDisplayTypeByNode prepared:"),
        "displayPreparation": first(preparation, "prepared -> interpolationInference.invalidDisplayTypeByNode("),
        "resultPreparation": first(preparation, "prepared -> interpolationInference.resultPropagationDecisionByNode("),
        "firstBlockingNode": first(emitter, "public emitInterpolationDiagnostics context:"),
    }
    probe_output = contents(PROBE_OUTPUT / "probe.stdout.txt")
    if (not managed_order["resultCheck"] < managed_order["errorCheck"] < managed_order["okResult"]
            or selfhost_order["displayPreparation"] >= selfhost_order["resultPreparation"]
            or "node=0 kind=5 parent=-1" not in probe_output
            or "propagation=-1" not in probe_output
            or "display=20" not in probe_output
            or "node=1 kind=11 parent=0" not in probe_output
            or "propagation=3" not in probe_output
            or contents(PROBE_OUTPUT / "probe.stderr.txt") != ""
            or contents(SELFHOST_ERROR) != EXPECTED_SELFHOST
            or proof["expected"]["mismatch"] != EXPECTED_MANAGED):
        raise ValueError("C# or SLG source decision changed")
    if start != {str(path): sha(path) for path in paths}:
        raise ValueError("source-comparison inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 propagated Result payload member source comparison",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "managedOrder": managed_order,
              "selfhostOrder": selfhost_order,
              "finding": "C# checks Result error compatibility before returning Ok for field access. SLG computes propagation status 3 at the child but marks the root Float display earlier; first-blocking-node selection reports only the root display error.",
              "requiredStructure": "Compute propagation decisions before root displayability and suppress root display when a descendant propagation decision is invalid.",
              "implementationComplete": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: propagation error precedes root member display")


if __name__ == "__main__":
    main()
