"""Check the scoped pre-IR Result propagation ownership contract."""

import argparse
import hashlib
import json
from pathlib import Path

from importlib.util import module_from_spec, spec_from_file_location


ROOT = Path(__file__).resolve().parents[1]
spec = spec_from_file_location("call_boundary", ROOT / "scripts/verify-c385-preir-call-diagnostic-ownership.py")
boundary = module_from_spec(spec)
spec.loader.exec_module(boundary)


def verify_borrowed_storage_blocking(ownership, diagnostics):
    blocking = boundary.function(ownership, "isBlockingDiagnostic")
    if "or diagnostic.code == 41" not in blocking:
        raise ValueError("borrowed collection storage diagnostic must stop compilation")
    if "code: 41" not in ownership:
        raise ValueError("borrowed collection storage diagnostic producer is missing")
    render = boundary.function(diagnostics, "emitOwnershipDiagnostics")
    if "diagnostic.code == 41" not in render:
        raise ValueError("borrowed collection storage diagnostic renderer is missing")
    count = boundary.function(diagnostics, "blockingDiagnosticCount")
    if "-> ownershipCheck.isBlockingDiagnostic(context.ownershipDiagnostics, context.ir)" not in count:
        raise ValueError("emitter must consume the authoritative ownership blocking decision")


def preparation_pipeline(prepare):
    for caller, callee in (("prepareSnapshot", "prepareSnapshotWithSignature"),
                           ("prepareSnapshotWithSignature", "prepareResolvedSnapshot")):
        body = boundary.function(prepare, caller)
        if body.count(f"request -> {callee}(") != 1:
            raise ValueError(f"semantic preparation delegation must be unique: {caller} -> {callee}")
    snapshot = boundary.function(prepare, "prepareResolvedSnapshot")
    publication = "-> interpolationInference.preIrResultPropagationDecisionByNode("
    if prepare.count(publication) != 1 or snapshot.count(publication) != 1:
        raise ValueError("semantic propagation decisions must be published exactly once")
    if snapshot.index(publication) > snapshot.index("-> lowerPreparedIr("):
        raise ValueError("semantic propagation decisions must precede IR lowering")
    return snapshot



def verify_display_commitment(inference, snapshot):
    producer = boundary.function(inference, "preIrDisplayTypeByNode")
    if any(token in producer for token in ("typedIr.", "streamIr.", "expressionTypeId(plan", "ir[")):
        raise ValueError("committed display types must not read lowered IR")
    if "typesByNode! -> push(typeId!)" not in producer or "displayableBuiltinSymbol" in producer:
        raise ValueError("display producer must preserve both valid and invalid resolved types")
    adapter = boundary.function(inference, "preIrInvalidDisplayTypeByNode")
    if "-> preIrDisplayTypeByNode(" not in adapter or "displayableBuiltinSymbol" not in adapter:
        raise ValueError("invalid-only display projection must consume the canonical type producer")
    early = "-> interpolationInference.preIrDisplayTypeByNode("
    if snapshot.count(early) != 1 or snapshot.index(early) > snapshot.index("-> lowerPreparedIr("):
        raise ValueError("display types must be committed once before IR lowering")
    if "invalidDisplayTypeByNode(streamPlan, recursiveTypes!, preIrDisplayTypeByNode," not in snapshot:
        raise ValueError("late display consumer must receive the full committed type table")
    late = boundary.function(inference, "invalidDisplayTypeByNode")
    if "preIrDisplayTypes[nodeIndex!] => committedTypeId" not in late:
        raise ValueError("late display consumer must read the committed semantic type")
    gate = "node.parent < 0 and committedTypeId < 0 and not rootHasPriorError![nodeIndex!]"
    if late.count(gate) != 1 or "node.parent < 0 and invalidTypeId! < 0" in late:
        raise ValueError("only unresolved display roots may use late type inference")
    if "node.parent < 0 and rootHasPriorError![nodeIndex!]" not in late:
        raise ValueError("prior diagnostics must suppress dependent display errors")



def verify_binary_receiver_commitment(inference, expressions):
    shared = boundary.function(expressions, "interpolationBinaryTypeId")
    if any(token in shared for token in ("typedIr.", "streamIr.", "expressionTypeId(plan", "ir[")):
        raise ValueError("binary receiver decisions must not depend on lowered IR")
    for name in ("interpolationArithmeticDecision", "interpolationComparisonDecision"):
        if f"-> {name}(operands)" not in shared:
            raise ValueError("binary result types must consume shared diagnostic decisions")
    receiver = boundary.function(expressions, "preIrInterpolationReceiverTypeId")
    if "owner.kind == 3" not in receiver or "types -> interpolationBinaryTypeId(owner.opcode," not in receiver:
        raise ValueError("computed binary receivers must resolve before method selection")
    for operand in ("operand0", "operand1"):
        if f"prepared.interpolations[owner.{operand}].parent == nodeIndex" not in receiver:
            raise ValueError("binary receiver traversal must preserve actual child ownership")
    composed = boundary.function(inference, "preIrDirectBinaryTypeId")
    if "-> expressionTypeIds.interpolationBinaryTypeId(binary.opcode," not in composed:
        raise ValueError("display composition must share the receiver binary decision")
    for adapter, shared_name in (("arithmeticDecisionForOperands", "interpolationArithmeticDecision"),
                                 ("comparisonDecisionForOperands", "interpolationComparisonDecision")):
        projection = boundary.function(inference, adapter)
        if f"-> expressionTypeIds.{shared_name}(semanticOperands)" not in projection or "code!" in projection:
            raise ValueError("binary diagnostics must only project shared semantic decisions")
    operands = boundary.function(inference, "interpolationBinaryOperands")
    if "-> expressionTypeIds.interpolationBinaryOperands(" not in operands:
        raise ValueError("late binary operands must share semantic contextual typing")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--inference-source", type=Path, default=ROOT / "selfhost/semantic/interpolation_inference.slg")
    parser.add_argument("--preparation-source", type=Path, default=ROOT / "selfhost/llvm/text/context_prepare.slg")
    parser.add_argument("--expression-types-source", type=Path, default=ROOT / "selfhost/semantic/expression_type_ids.slg")
    args = parser.parse_args()
    paths = [ROOT / path for path in (
        "selfhost/semantic/interpolation_inference.slg",
        "selfhost/semantic/expression_type_ids.slg",
        "selfhost/llvm/text/context_prepare.slg",
        "scripts/verify-c385-preir-call-diagnostic-ownership.py",
        "selfhost/ir/typed/function_lowering.slg",
        "selfhost/llvm/text/foundation.slg",
        "selfhost/llvm/emitter/diagnostics.slg",
        "selfhost/semantic/ownership_check.slg",
    )] + [Path(__file__).resolve()]
    paths[0] = args.inference_source.resolve()
    paths[1] = args.expression_types_source.resolve()
    paths[2] = args.preparation_source.resolve()
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest().upper() for path in paths}
    inference, expressions, prepare = [path.read_text(encoding="utf-8-sig") for path in paths[:3]]
    checked = []
    for name in ("resultPropagationDecision", "semanticInterpolationFunctionTypeId",
                 "preIrResultPropagationDecisionByNode"):
        body = boundary.function(inference, name)
        if any(token in body for token in ("typedIr.", "streamIr.", "expressionTypeId(plan", "ir[")):
            raise ValueError(f"pre-IR propagation decision reads lowered IR: {name}")
        checked.append(name)
    early = boundary.function(inference, "preIrResultPropagationDecisionByNode")
    if "resultPropagationDecision(" not in early:
        raise ValueError("the semantic producer must own Result propagation decisions")
    if ("public resultPropagationDecisionByNode prepared:" in inference
            or "interpolationFunctionTypeId prepared:" in inference):
        raise ValueError("Result propagation must not retry inference from lowered IR")
    receiver = boundary.function(expressions, "preIrInterpolationReceiverTypeId")
    if "owner.kind == 11" not in receiver or "operandType.first -> return" not in receiver:
        raise ValueError("semantic member receivers must read the Result Ok payload")
    call = boundary.function(expressions, "resolveInterpolationCallReturnType")
    if "specializeManyInto(parameterTypes!, actualTypes!, returnType)" not in call:
        raise ValueError("generic interpolation calls must specialize the whole return type")
    if "callTypes[nodeIndex] -> return" not in receiver:
        raise ValueError("pre-IR receivers must consume committed semantic call result types")
    value = boundary.function(inference, "expressionTypeId")
    committed = value.index("bindingFacts.interpolationCallTypeByNode[nodeIndex] -> return")
    lowered_call = value.index("node.kind == 8 and node.symbol >= 0")
    if committed >= lowered_call:
        raise ValueError("committed call result types must precede lowered declaration lookup")
    binary_commitment = "public interpolationBinaryTypeId types:" in expressions
    if binary_commitment:
        verify_binary_receiver_commitment(inference, expressions)
        checked.append("binaryReceiverSemanticCommitment")
    snapshot = preparation_pipeline(prepare)
    for name in ("uninvokedAssociatedMemberByNode", "localEnumMemberDecisionByNode"):
        semantic = boundary.function(inference, name)
        if any(token in semantic for token in ("typedIr.", "streamIr.", "ir[", "ir:")):
            raise ValueError(f"enum/member semantic decision reads lowered IR: {name}")
        invocation = f"interpolationInference.{name}("
        if snapshot.count(invocation) != 1 or snapshot.index(invocation) >= snapshot.index("-> lowerPreparedIr("):
            raise ValueError(f"enum/member decision must have one pre-IR producer: {name}")
    associated = boundary.function(inference, "uninvokedAssociatedMemberByNode")
    if "functionParameterSymbolsInSourceOrder(" not in associated or "(parameters -> len) == 0" not in associated:
        raise ValueError("zero-input member decisions must use declared semantic parameters")
    publication = "-> interpolationInference.commitLocalEnumMemberTypes("
    if snapshot.count(publication) != 1 or snapshot.index(publication) >= snapshot.index("-> interpolationInference.preIrDisplayTypeByNode("):
        raise ValueError("enum member types must be committed before semantic display inference")
    if snapshot.index(publication) >= snapshot.index("typeIds.enumPayloadEdges("):
        raise ValueError("enum member types must precede type-derived layout and ownership facts")
    commit = boundary.function(inference, "commitLocalEnumMemberTypes")
    if "decision.status == 3 and decision.typeId >= 0" not in commit or "=> memberTypes[nodeIndex!]" not in commit:
        raise ValueError("only resolved enum values may publish member types")
    checked.append("singleEnumAndAssociatedSemanticOwner")
    if ("interpolationInference.resultPropagationDecisionByNode(" in snapshot
            or "invalidCollectionIndexExpectedTypeByNode, preIrResultPropagationDecisions," not in snapshot
            or "interpolationResultPropagationByNode: preIrResultPropagationDecisions" not in snapshot):
        raise ValueError("display and emission must consume the original pre-IR Result decisions")
    checked.append("singleResultPropagationSemanticOwner")
    display_commitment = "public preIrDisplayTypeByNode prepared:" in inference
    if display_commitment:
        verify_display_commitment(inference, snapshot)
        checked.append("displaySemanticCommitment")
    lowering, foundation, diagnostics = [path.read_text(encoding="utf-8-sig") for path in paths[4:7]]
    verify_borrowed_storage_blocking(paths[7].read_text(encoding="utf-8-sig"), diagnostics)
    checked.append("borrowedStorageDiagnosticBlocking")
    closure = boundary.function(lowering, "materializeGenericClosure")
    indexed_templates = "-> functionTemplatesBySymbol(prepared) => functionsBySymbol"
    interpolation_calls = "-> appendInterpolationGenericCalls(prepared, resolved, plans!, functionsBySymbol)"
    if indexed_templates not in closure or interpolation_calls not in closure:
        raise ValueError("interpolation calls must join the canonical generic closure")
    if closure.index(indexed_templates) > closure.index(interpolation_calls):
        raise ValueError("interpolation generic calls must consume the current function template index")
    interpolation_plan = boundary.function(lowering, "appendInterpolationGenericCalls")
    generic_scope = interpolation_plan.index("generic! -> if {")
    if interpolation_plan.index("[Int; ~] => templates!") < generic_scope:
        raise ValueError("generic plan arrays must be owned inside the materialization branch")
    if "typeIds.specializeManyInto(templates!, actuals!, function.typeId)" not in interpolation_plan:
        raise ValueError("interpolation function ABI must use all argument substitutions")
    bindings = boundary.function(lowering, "bindGenericBodies")
    if "functionsByInterpolation: interpolationFunctions!" not in bindings:
        raise ValueError("concrete interpolation function identity must be published")
    if "concreteTarget => importedInterpolationCallTargetByNode![concreteInterpolationIndex!]" not in snapshot:
        raise ValueError("interpolation emission must consume the concrete function identity")
    if '"_g$(callTargetFunction)" -> print' not in foundation:
        raise ValueError("interpolation calls must use the specialized function linkage")
    reachable = boundary.function(diagnostics, "reachableFunctions")
    if "context.importedInterpolationCallTargetByNode[interpolationNodeIndex] => interpolationTarget" not in reachable:
        raise ValueError("interpolation reachability must select the committed concrete target")
    if "(instanceInterpolation.kind == 8 or instanceInterpolation.kind == 10)" in reachable:
        raise ValueError("ordinary interpolation calls must not rediscover generic templates by name")
    if hashes != {str(path): hashlib.sha256(path.read_bytes()).hexdigest().upper() for path in paths}:
        raise ValueError("INPUT_DRIFT")
    result = {"schemaVersion": 1, "status": "passed", "scope": "source-boundary-only",
        "checkedFunctions": checked, "inputsStable": True, "sourceHashes": hashes,
        "unresolvedFamilies": ["other late interpolation semantic/display routes require separate closure"],
        "resultPropagationSemanticCommitment": True,
        "fullSemanticPhaseClosure": False, "displaySemanticCommitment": display_commitment,
        "binaryReceiverSemanticCommitment": binary_commitment,
        "behavioralParity": "requires focused compiled paired proofs"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as output:
        json.dump(result, output, indent=2)
        output.write("\n")
    print("C527 pre-IR Result propagation source boundary: PASS")


if __name__ == "__main__":
    main()
