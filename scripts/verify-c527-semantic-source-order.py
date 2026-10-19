#!/usr/bin/env python3
"""Verify the current C# and selfhost interpolation decision order."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
    "selfhost/semantic/context.slg",
    "selfhost/semantic/expression_type_ids.slg",
    "selfhost/semantic/interpolation_inference.slg",
    "selfhost/llvm/text/context_prepare.slg",
    "selfhost/llvm/emitter/diagnostics.slg",
    "selfhost/ir/interpolation.slg",
)
OUTPUT = ROOT / "artifacts/scratch/c527-semantic-source-order-20260929-01.json"


def locate(lines: list[str], needle: str) -> int:
    matches = [i + 1 for i, line in enumerate(lines) if needle in line]
    if len(matches) != 1:
        raise ValueError(f"expected one occurrence of {needle!r}, got {matches}")
    return matches[0]


def locate_between(lines: list[str], needle: str, start: int, end: int) -> int:
    matches = [i + 1 for i in range(start, end - 1) if needle in lines[i]]
    if len(matches) != 1:
        raise ValueError(f"expected one occurrence of {needle!r} between {start} and {end}, got {matches}")
    return matches[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    output = args.output.resolve()
    sources = {}
    for name in SOURCES:
        data = (ROOT / name).read_bytes()
        sources[name] = {
            "sha256": hashlib.sha256(data).hexdigest().upper(),
            "lines": data.decode("utf-8-sig").splitlines(),
        }

    managed = sources[SOURCES[0]]["lines"]
    selfhost = sources[SOURCES[4]]["lines"]
    managed_order = {
        "inferString": locate(managed, "private BoundType InferStringExpression("),
        "inferFragment": locate(managed, "var interpolationType = InferExpression("),
        "checkDisplay": locate(managed, "EnsureDisplayable(interpolationType, expression.Line"),
    }
    selfhost_order = {
        "resolveTypes": locate(selfhost, "initialPrepared -> expressionTypeIds.resolveCallContext"),
        "resolveCallTargets": locate(selfhost, "prepared -> interpolationInference.preIrFlowCallTargets"),
        "checkDirectLexicalDisplay": locate(selfhost, "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode"),
        "checkOperands": locate(selfhost, "prepared.package -> semanticDiagnostics.firstExpressionOperandDiagnostic"),
        "lowerTypedIr": locate(selfhost, "prepared -> lowerPreparedIr(recursiveTypes!"),
        "repairDirectAsync": locate(selfhost, "ir! -> typedIr.repairDirectAsyncAwaitConsumers(prepared)"),
        "sealLateCallNumeric": locate(selfhost, "ir! -> typedIr.sealLateResolvedCallNumericArguments(prepared)"),
        "collectNumericWarnings": locate(selfhost, "prepared.package -> semanticDiagnostics.redundantNumericConversions(recursiveTypes!)"),
        "checkNumericCallArguments": locate(selfhost, "prepared.package -> semanticDiagnostics.firstNumericCallArgumentDiagnostic(recursiveTypes!)"),
        "checkSemanticResultPropagation": locate(selfhost, "prepared -> interpolationInference.preIrResultPropagationDecisionByNode(recursiveTypes!, semanticPropagationTraits)"),
        "classifyFlow": locate(selfhost, "prepared -> interpolationInference.classifyIntrinsicFlowReceivers"),
        "checkDisplay": locate(selfhost, "prepared -> interpolationInference.invalidDisplayTypeByNode"),
        "checkResultPropagation": locate(selfhost, "prepared -> interpolationInference.resultPropagationDecisionByNode"),
    }
    if not (managed_order["inferString"] < managed_order["inferFragment"] < managed_order["checkDisplay"]):
        raise ValueError("C# interpolation semantic order changed")
    if not (
        selfhost_order["resolveTypes"]
        < selfhost_order["resolveCallTargets"]
        < selfhost_order["checkDirectLexicalDisplay"]
        < selfhost_order["collectNumericWarnings"]
        < selfhost_order["checkNumericCallArguments"]
        < selfhost_order["checkSemanticResultPropagation"]
        < selfhost_order["lowerTypedIr"]
        < selfhost_order["repairDirectAsync"]
        < selfhost_order["sealLateCallNumeric"]
        < selfhost_order["checkOperands"]
        < selfhost_order["classifyFlow"]
        < selfhost_order["checkResultPropagation"]
        < selfhost_order["checkDisplay"]
    ):
        raise ValueError("selfhost interpolation decision order changed")
    expression_source = sources[SOURCES[2]]["lines"]
    call_closure_order = {
        "inferInitialTypes": locate(expression_source, "initialPrepared -> resolveContext => initialTypes"),
        "resolveTypedReceivers": locate(expression_source, "calls.resolveModulesTypedWithReceiverTypes("),
        "inferFinalTypes": locate(expression_source, "finalPrepared -> resolveContext => finalTypes"),
    }
    if not (
        call_closure_order["inferInitialTypes"]
        < call_closure_order["resolveTypedReceivers"]
        < call_closure_order["inferFinalTypes"]
    ):
        raise ValueError("selfhost call receiver semantic closure order changed")
    inference = sources[SOURCES[3]]["lines"]
    pre_ir_direct_type = locate(inference, "preIrDirectTypeId prepared:")
    pre_ir_composed_operand = locate(inference, "preIrComposedOperandTypeId prepared:")
    pre_ir_binary_type = locate(inference, "preIrDirectBinaryTypeId prepared:")
    pre_ir_conversion_type = locate(inference, "preIrDirectConversionTypeId prepared:")
    pre_ir_unary_type = locate(inference, "preIrDirectUnaryTypeId prepared:")
    pre_ir_function = locate(inference, "public preIrInvalidDirectDisplayTypeByNode prepared:")
    post_ir_function = locate(inference, "public invalidDisplayTypeByNode prepared:")
    pre_ir_float = locate_between(inference, "node.kind == 0 -> if {", pre_ir_direct_type, pre_ir_binary_type)
    pre_ir_unary = locate_between(inference, "node.kind == 2 and nodeIndex < (bindingFacts.interpolationUnaryTypeByNode -> len)", pre_ir_direct_type, pre_ir_binary_type)
    pre_ir_nominal = locate_between(inference, "node.kind == 14 and nodeIndex < (bindingFacts.interpolationContextualStructTypeByNode -> len)", pre_ir_direct_type, pre_ir_binary_type)
    pre_ir_nested_binary = locate_between(inference, "preIrComposedOperandTypeId(bindingFacts, memberTypes, computedTypes, nodeIndex, binary.operand0)", pre_ir_binary_type, pre_ir_conversion_type)
    pre_ir_nested_conversion = locate_between(inference, "preIrComposedOperandTypeId(bindingFacts, memberTypes, computedTypes, nodeIndex, conversion.operand0)", pre_ir_conversion_type, pre_ir_function)
    pre_ir_nested_unary = locate_between(inference, "preIrComposedOperandTypeId(bindingFacts, memberTypes, computedTypes, nodeIndex, unary.operand0)", pre_ir_unary_type, pre_ir_function)
    pre_ir_reverse_pass = locate_between(inference, "composedIndex! - 1 => composedIndex!", pre_ir_function, post_ir_function)
    pre_ir_unary_consumer = locate_between(inference, "prepared -> preIrDirectUnaryTypeId(bindingFacts, memberTypes, computedTypes!", pre_ir_function, post_ir_function)
    pre_ir_binary_consumer = locate_between(inference, "prepared -> preIrDirectBinaryTypeId(bindingFacts, memberTypes, computedTypes!", pre_ir_function, post_ir_function)
    pre_ir_conversion_consumer = locate_between(inference, "prepared -> preIrDirectConversionTypeId(bindingFacts, memberTypes, computedTypes!", pre_ir_function, post_ir_function)
    pre_ir_root_binary = locate_between(inference, "computedTypes![nodeIndex!] => typeId!", pre_ir_function, post_ir_function)
    pre_ir_consumer = locate(inference, "preIrInvalid[nodeIndex!] => invalidTypeId!")
    if not (pre_ir_direct_type < pre_ir_float < pre_ir_unary < pre_ir_nominal
            < pre_ir_composed_operand < pre_ir_binary_type < pre_ir_nested_binary
            < pre_ir_conversion_type < pre_ir_nested_conversion
            < pre_ir_unary_type < pre_ir_nested_unary < pre_ir_function
            < pre_ir_unary_consumer < pre_ir_binary_consumer < pre_ir_conversion_consumer < pre_ir_reverse_pass
            < pre_ir_root_binary
            < post_ir_function < pre_ir_consumer):
        raise ValueError("pre-IR displayability result is not consumed by the post-IR path")

    result = {
        "schemaVersion": 1,
        "unit": "C527-current-source-comparison",
        "status": "passed",
        "scope": "source decision order only; full pre-IR ownership and structural phase closure remain open",
        "managedDecision": "Each interpolation fragment is inferred and checked for displayability in C# semantic analysis.",
        "selfhostDecision": "Type facts, call targets, direct interpolation displayability, S001 numeric warnings, call-argument diagnostics and resolved direct/member Result propagation decisions precede Typed IR. Expression operand diagnostics and unresolved computed/flow propagation families still follow Typed IR and precede post-IR displayability. The C# versus SLG semantic phase structure remains open.",
        "managedOrder": managed_order,
        "selfhostOrder": selfhost_order,
        "selfhostCallClosureOrder": call_closure_order,
        "preIrDirectType": pre_ir_direct_type,
        "preIrBinaryType": pre_ir_binary_type,
        "preIrConversionType": pre_ir_conversion_type,
        "preIrUnaryType": pre_ir_unary_type,
        "preIrComposedOperand": pre_ir_composed_operand,
        "preIrDisplayProducer": pre_ir_function,
        "preIrFloatDecision": pre_ir_float,
        "preIrUnaryDecision": pre_ir_unary,
        "preIrNominalDecision": pre_ir_nominal,
        "preIrNestedBinaryRead": pre_ir_nested_binary,
        "preIrNestedConversionRead": pre_ir_nested_conversion,
        "preIrNestedUnaryRead": pre_ir_nested_unary,
        "preIrReverseBinaryPass": pre_ir_reverse_pass,
        "preIrUnaryConsumer": pre_ir_unary_consumer,
        "preIrBinaryConsumer": pre_ir_binary_consumer,
        "preIrConversionConsumer": pre_ir_conversion_consumer,
        "preIrRootBinaryType": pre_ir_root_binary,
        "postIrDisplayConsumer": pre_ir_consumer,
        "sourceSha256": {name: sources[name]["sha256"] for name in SOURCES},
        "semanticDecisionOwnerKinds": {"completed": 12, "total": 12},
        "fullPreIrExpressionClosure": False,
        "structuralPhasesClosed": {"completed": 0, "total": 7},
        "nextImplementationBoundary": "Move one post-IR interpolation decision to pre-IR semantic facts after focused current C# behavior verification; then prove paired behavior.",
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PASS {output.relative_to(ROOT)}: C# semantic order and SLG pre/post-IR split verified")


if __name__ == "__main__":
    main()
