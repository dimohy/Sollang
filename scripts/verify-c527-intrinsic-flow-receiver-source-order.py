#!/usr/bin/env python3
"""Compare nested Text slice/len interpolation decisions before paired execution."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
LOWERING = ROOT / "selfhost/ir/interpolation.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
POSITIVE = ROOT / "scripts/probes/interpolation/c527-intrinsic-flow-result-receiver-positive.slg"
ARITY = ROOT / "scripts/probes/interpolation/c527-intrinsic-flow-result-receiver-arity.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-intrinsic-flow-receiver-managed-first-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-intrinsic-flow-receiver-source-comparison-20260929-01.json"
EXPECTED_ARITY = "sollang: semantic error at 1:46: [module '<main>'] len does not accept arguments\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def first(lines: list[str], value: str) -> int:
    for number, line in enumerate(lines, 1):
        if value in line:
            return number
    raise ValueError(f"source decision missing: {value}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, LOWERING, INFERENCE, PREPARATION, POSITIVE, ARITY,
              MANAGED_OUTPUT / "positive.exe", MANAGED_OUTPUT / "positive.build.stderr.txt",
              MANAGED_OUTPUT / "positive.native.stdout.txt", MANAGED_OUTPUT / "positive.native.stderr.txt",
              MANAGED_OUTPUT / "arity.build.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    lowering = LOWERING.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    preparation = PREPARATION.read_text(encoding="utf-8-sig").splitlines()
    managed_order = {
        "receiverInference": first(managed, "private FlowResult InferFlowExpression("),
        "targetSequence": first(managed, "for (var i = 0; i < expression.Targets.Count; i++)"),
        "lenDecision": first(managed, 'case "len":'),
        "sliceDecision": first(managed, 'case "slice" when currentType is BoundType.Text or BoundType.SourceText:'),
    }
    selfhost_order = {
        "lenOpcode": first(lowering, "-101 => intrinsicFlowOpcode!"),
        "sliceOpcode": first(lowering, "-203 => intrinsicFlowOpcode!"),
        "sliceResult": first(lowering, "intrinsicFlowOpcode! == -203 -> if { 1 => loweredTypeSymbol! }"),
        "receiverDependentResult": first(inference, "intrinsicFlowResultBuiltinSymbol prepared:"),
        "sliceArity": first(inference, "node.kind == 6 and node.opcode == -203 and node.argumentCount != 2"),
        "lenArity": first(inference, "node.opcode == -101 or node.opcode == -236"),
        "typePreparation": first(preparation, "prepared -> interpolationInference.flowResultTypeByNode("),
        "arityPreparation": first(preparation, "analysisInterpolations -> interpolationInference.invalidIntrinsicFlowArityByNode"),
    }
    if (managed_order["receiverInference"] >= managed_order["targetSequence"]
            or selfhost_order["lenOpcode"] >= selfhost_order["sliceResult"]
            or selfhost_order["typePreparation"] >= selfhost_order["arityPreparation"]
            or normalized(MANAGED_OUTPUT / "positive.build.stderr.txt") != ""
            or normalized(MANAGED_OUTPUT / "positive.native.stdout.txt") != "length=2\n"
            or normalized(MANAGED_OUTPUT / "positive.native.stderr.txt") != ""
            or normalized(MANAGED_OUTPUT / "arity.build.stderr.txt") != EXPECTED_ARITY):
        raise ValueError("C# first or nested intrinsic source decisions changed")
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("source-comparison inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 intrinsic-flow result receiver source comparison",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "managedOrder": managed_order,
              "selfhostOrder": selfhost_order,
              "finding": "C# advances from Text slice result to len receiver and rejects len arity before display. SLG encodes both flow nodes, their result types, and arity decisions; paired execution remains necessary.",
              "pairedExecutionComplete": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: slice result and len receiver source decisions compared")


if __name__ == "__main__":
    main()
