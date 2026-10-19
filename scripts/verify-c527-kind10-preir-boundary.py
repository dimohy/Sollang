#!/usr/bin/env python3
"""Freeze method target and argument decisions before changing kind-10 type facts."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_COMPARISON = ROOT / "artifacts/scratch/c527-kind10-receiver-source-comparison-20260929-01.json"
MANAGED_SOURCE = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
FACTS_SOURCE = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE_SOURCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION_SOURCE = ROOT / "selfhost/llvm/text/context_prepare.slg"
ARITY_CASE = ROOT / "scripts/probes/interpolation/c527-kind10-method-arity-negative.slg"
TARGET_PROBE = ROOT / "artifacts/scratch/c527-kind10-target-probe-20260929-01.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-arity-managed-20260929-01")
SELFHOST_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-arity-selfhost-baseline-20260929-01")
PROBE_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-target-probe-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-kind10-preir-boundary-20260929-01.json"
EXPECTED_ARITY = (
    "sollang: semantic error at 10:5: [module '<main>'] "
    "function 'make' expects 1 additional argument(s)\n"
)
EXPECTED_TARGET = (
    "node=0 kind=5 parent=-1 member=-1 targetStatus=-1 targetSource=-1 targetSymbol=-1 receiverType=-1 args=-1\n"
    "node=1 kind=10 parent=0 member=-1 targetStatus=0 targetSource=0 targetSymbol=5 receiverType=27 args=0\n"
    "node=2 kind=1 parent=1 member=-1 targetStatus=-1 targetSource=-1 targetSymbol=-1 receiverType=-1 args=-1\n"
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [SOURCE_COMPARISON, MANAGED_SOURCE, FACTS_SOURCE, INFERENCE_SOURCE,
              PREPARATION_SOURCE, ARITY_CASE, TARGET_PROBE,
              MANAGED_OUTPUT / "build.stderr.txt", SELFHOST_OUTPUT / "build.stderr.txt",
              PROBE_OUTPUT / "probe.exe", PROBE_OUTPUT / "build.stderr.txt",
              PROBE_OUTPUT / "probe.stdout.txt", PROBE_OUTPUT / "probe.stderr.txt",
              Path(__file__).resolve()]
    start = {str(path): digest(path) for path in inputs}
    comparison = json.loads(SOURCE_COMPARISON.read_text(encoding="utf-8"))
    for source in (MANAGED_SOURCE, FACTS_SOURCE, INFERENCE_SOURCE):
        if comparison["inputSha256"][str(source)] != digest(source):
            raise ValueError(f"source comparison drifted: {source}")
    if normalized(MANAGED_OUTPUT / "build.stderr.txt") != EXPECTED_ARITY:
        raise ValueError("managed arity diagnostic changed")
    if normalized(SELFHOST_OUTPUT / "build.stderr.txt") != EXPECTED_ARITY:
        raise ValueError("selfhost arity diagnostic changed")
    if (normalized(PROBE_OUTPUT / "build.stderr.txt") != ""
            or normalized(PROBE_OUTPUT / "probe.stderr.txt") != ""
            or normalized(PROBE_OUTPUT / "probe.stdout.txt") != EXPECTED_TARGET):
        raise ValueError("pre-IR target probe changed")
    preparation = PREPARATION_SOURCE.read_text(encoding="utf-8")
    order = [
        "prepared -> expressionTypeIds.resolveContext => recursiveTypes!",
        "prepared -> interpolationInference.preIrFlowCallTargets(recursiveTypes!)",
        "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode(recursiveTypes!)",
        "prepared -> lowerPreparedIr(recursiveTypes!, supportsComputePool)",
    ]
    positions = [preparation.find(text) for text in order]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        raise ValueError("pre-IR semantic preparation order changed")
    if start != {str(path): digest(path) for path in inputs}:
        raise ValueError("boundary inputs changed during verification")
    record = {
        "schemaVersion": 1,
        "unit": "C527 kind-10 method target and arity baseline",
        "status": "passed",
        "completed": 1,
        "total": 1,
        "inputStable": True,
        "inputSha256": start,
        "managedAndSelfhostArity": EXPECTED_ARITY,
        "preIrTarget": EXPECTED_TARGET,
        "preparationOrder": order,
        "finding": "A visible zero-additional-argument instance method is resolved before Typed IR, but method target facts are produced after the ExpressionTypeIdSet member pass. Invalid arity already has exact paired diagnostics and must not yield a member type.",
        "implementationComplete": False,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: method target, arity precedence, and pre-IR order")


if __name__ == "__main__":
    main()
