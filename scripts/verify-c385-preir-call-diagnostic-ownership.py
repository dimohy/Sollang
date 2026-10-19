"""Check the source boundary of committed call argument diagnostics."""

import argparse
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def function(source, name):
    match = re.search(rf"^(?:public )?{re.escape(name)}\b[^\n]*", source, re.M)
    if not match:
        raise ValueError(f"missing function: {name}")
    next_declaration = re.search(r"^\S", source[match.end():], re.M)
    end = match.end() + next_declaration.start() if next_declaration else len(source)
    return source[match.start():end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    paths = [ROOT / p for p in (
        "selfhost/semantic/diagnostics.slg",
        "selfhost/llvm/text/context_prepare.slg",
        "selfhost/llvm/emitter/diagnostics.slg",
    )] + [Path(__file__).resolve()]
    paths.extend([ROOT / "selfhost/semantic/expression_type_ids.slg",
                  ROOT / "selfhost/semantic/expression_type_ids_resolution_phases.slg",
                  ROOT / "selfhost/semantic/interpolation_inference.slg",
                  ROOT / "selfhost/semantic/context.slg",
                  ROOT / "selfhost/llvm/text/foundation.slg",
                  ROOT / "selfhost/ir/interpolation.slg",
                  ROOT / "selfhost/semantic/type_ids.slg",
                  ROOT / "selfhost/llvm/text/containers.slg"])
    sources = [p.read_text(encoding="utf-8-sig") for p in paths]
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in paths}
    checked = []
    for name in ("firstNumericCallLiteralDiagnostic", "numericCallArgumentMismatch", "firstNumericCallArgumentDiagnostic",
                 "appendCallArgumentNumericWarning", "redundantNumericConversions",
                 "initializerValueAst", "firstNominalFieldMismatch",
                 "signatureTypeReferencesGeneric", "signatureFirstGenericIsValue",
                 "signatureRootIsArray", "firstGenericInputUsageDiagnostic", "signatureDeclarationDiagnosticFirst",
                 "firstSignatureTypeDiagnostic"):
        body = function(sources[0], name)
        if re.search(r"\bir\b|typedIr\.|functionIr|parameterIr", body):
            raise ValueError(f"Typed IR decision dependency: {name}")
        checked.append(name)
    compatibility = function(sources[10], "functionArgumentCompatible")
    if re.search(r"\bir\b|typedIr\.|functionIr|parameterIr", compatibility):
        raise ValueError("function argument compatibility must use semantic type identity")
    checked.append("functionArgumentCompatible")
    signature_lengths = function(sources[0], "firstSignatureTypeDiagnostic")
    if "package.nodes[range.astStart + symbol.astNode].kind == 60" not in signature_lengths:
        raise ValueError("additional signature location must exclude synthesized primary parameter symbols")
    if "nameToken: nameTokenByTypeAst![range.astStart + typeAst!]" not in signature_lengths:
        raise ValueError("signature diagnostic must commit the declaration role's source token")
    committed_arguments = function(sources[6], "callArgumentDiagnosticsByNode")
    if "typeIds.functionArgumentCompatible(argument.actualTypeId, argument.expectedTypeId)" not in committed_arguments:
        raise ValueError("committed argument diagnostics must share semantic compatibility")
    if "resolved.types[literalTypeId!].kind == 1 and resolved.types[literalTypeId!].origin == 1" not in committed_arguments:
        raise ValueError("numeric range checks must not interpret nominal declaration slots as builtins")
    prepare = function(sources[1], "prepareSnapshot")
    lowering = prepare.index("-> lowerPreparedIr(")
    fixed_length = prepare.index("semanticDiagnostics.firstSignatureTypeDiagnostic")
    if prepare.count("semanticDiagnostics.firstSignatureTypeDiagnostic") != 1 or fixed_length >= prepare.index("expressionTypeIds.resolveCallContext"):
        raise ValueError("signature length decision must be committed once before expression inference")
    length_renderer = function(sources[2], "emitSignatureTypeDiagnostic")
    if "context.signatureTypeDiagnostic" not in length_renderer or re.search(r"context\.ir|typedIr\.|firstSignatureTypeDiagnostic", length_renderer):
        raise ValueError("signature length renderer must consume only the committed decision")
    for name in ("blockingDiagnosticCount", "emitBlockingDiagnostics"):
        if "context.signatureTypeDiagnostic.sourceModule >= 0" not in function(sources[2], name):
            raise ValueError("signature rejection must block code generation: " + name)
    for name in ("redundantNumericConversions", "firstNumericCallArgumentDiagnostic", "firstNominalFieldMismatch"):
        occurrences = list(re.finditer(rf"semanticDiagnostics\.{name}\(", prepare))
        if len(occurrences) != 1 or occurrences[0].start() >= lowering:
            raise ValueError(f"decision must precede IR lowering exactly once: {name}")
    for name in ("callArgumentDiagnosticsByNode", "firstCallArgumentDiagnostic", "firstCallNumericDiagnostic", "callNumericWarningByNode"):
        body = function(sources[6], name)
        if re.search(r"\bir\b|typedIr\.|functionIr|parameterIr", body):
            raise ValueError(f"Typed IR interpolation call dependency: {name}")
        checked.append(name)
    for name in ("callArgumentDiagnosticsByNode", "callNumericWarningByNode"):
        occurrences = list(re.finditer(rf"interpolationInference\.{name}\(", prepare))
        if len(occurrences) != 1 or occurrences[0].start() >= lowering:
            raise ValueError(f"interpolation call decision must be committed once before IR lowering: {name}")
    warnings = function(sources[6], "callNumericWarningByNode")
    if "not argument.inputFromFlow" not in warnings:
        raise ValueError("call-context warnings must exclude the flowing input")
    interpolation_emitter = function(sources[2], "emitInterpolationCallArgumentDiagnostic")
    if "context.interpolationCallArgumentDiagnosticByNode[nodeIndex]" not in interpolation_emitter:
        raise ValueError("interpolation renderer must consume the selected node decision")
    if re.search(r"context\.ir|functionIr|parameterIr", interpolation_emitter):
        raise ValueError("interpolation numeric renderer depends on Typed IR")
    if "diagnostic.parameterSymbol" not in interpolation_emitter or "diagnostic.parameterOrdinal" not in interpolation_emitter:
        raise ValueError("additional parameter rendering must consume committed declaration identity")
    argument_resolution = function(sources[4], "resolveInterpolationCallReturnType")
    if "parameterSymbol: parameterSymbols[ordinal!]" not in argument_resolution or "parameterOrdinal: ordinal!" not in argument_resolution:
        raise ValueError("interpolation argument resolution must commit parameter identity and order")
    if "semanticContext.functionParameterSymbolsInSourceOrder(" not in argument_resolution:
        raise ValueError("interpolation parameters must use semantic declaration order")
    ordered_parameters = function(sources[7], "functionParameterSymbolsInSourceOrder")
    if "package.nodes[candidateAst].start" not in ordered_parameters or "ordered! -> push(selected!)" not in ordered_parameters:
        raise ValueError("parameter declaration order must be derived from source AST positions")
    ordinary_bindings = function(sources[7], "resolveCallArgumentBindings")
    if "functionParameterSymbolsInSourceOrder(" not in ordinary_bindings:
        raise ValueError("ordinary and interpolation calls must share the parameter order inventory")
    if "callArgumentAsts(" not in ordinary_bindings:
        raise ValueError("argument bindings must use the shared source argument inventory")
    arity = function(sources[0], "firstCallArityDiagnostic")
    if any(name not in arity for name in ("prepared.calls", "callArgumentAsts(",
                                          "functionParameterSymbolsInSourceOrder(", "declarationBodyIsActive(")):
        raise ValueError("declared flow arity must consume active semantic call and argument identities")
    if re.search(r"typedIr|context\.ir|functionIr|parameterIr", arity):
        raise ValueError("declared flow arity must be decided before Typed IR")
    arity_emitter = function(sources[2], "emitCallArityDiagnostic")
    if re.search(r"context\.ir|functionIr|parameterIr", arity_emitter):
        raise ValueError("arity rendering must use committed declaration and calling module identities")
    numeric_mismatch = function(sources[0], "numericCallArgumentMismatch")
    if "typeIds.functionArgumentCompatible(" not in numeric_mismatch:
        raise ValueError("numeric destinations must use the shared function argument compatibility contract")
    for traversal in ("interpolationCallArgumentAt", "interpolationCallArgumentLimit", "emitInterpolationSubtree"):
        body = function(sources[8], traversal)
        if not re.search(r"kind == 8 or \w+\.kind == 10\) and \w+\.argumentCount > 3", body):
            raise ValueError("local and qualified calls must share complete argument traversal: " + traversal)
        checked.append(traversal)
    lowered_interpolation = function(sources[9], "lowerPrepared")
    for condition in (
        "or (loweredKind! == 10 and flowQualifiedTarget!)",
        "resolvedSymbol! => directReceiverSymbol!",
        "symbol: directReceiverSymbol!",
        "parent: loweredIndex",
        "nodes! -> push(receiver)",
        "loweredCallNameLength! - directReceiverLength! - 1",
        "2 => qualifiedReceiverStatus!",
        "qualifiedReceiverStatus: qualifiedReceiverStatus!",
        "qualifiedReceiverStatus: node.qualifiedReceiverStatus",
    ):
        if condition not in lowered_interpolation:
            raise ValueError("direct instance receiver must retain lexical identity before explicit arguments: " + condition)
    if lowered_interpolation.index("nodes! -> push(receiver)") < lowered_interpolation.index("nodes! -> push(lowered)"):
        raise ValueError("direct receiver must follow its owning call in the interpolation node table")
    for condition in (
        "referenceMutable! and not candidateMutable",
        "not referenceMutable! and candidateMutable",
        "visibleMutablePrefix!",
        "resolvedPrefixSymbol! < 0",
        "visibleMutablePrefix! and resolvedFlowSymbol! < 0",
    ):
        if condition not in lowered_interpolation:
            raise ValueError("interpolation must preserve exact binding key before receiver fallback: " + condition)
    if lowered_interpolation.index("referenceMutable! and not candidateMutable") > lowered_interpolation.index("nearestSymbol! >= 0"):
        raise ValueError("mutable marker matching must precede nearest declaration selection")
    if "qualifiedReceiverStatus: node.qualifiedReceiverStatus" not in sources[6]:
        raise ValueError("semantic interpolation classification must preserve qualified receiver status")
    if "interpolationNode.qualifiedReceiverStatus == 2" not in sources[2] or "unknown function or method '$name'" not in sources[2]:
        raise ValueError("direct mutable receiver renderer must consume the committed rejection status")
    for condition in ("transparentCall.parent == fragmentAstIndex!", "transparentCall.kind == 11", "transparentCall.start == fragmentNode.start", "transparentCall.length == fragmentNode.length"):
        if condition not in lowered_interpolation:
            raise ValueError("qualified call transparency must preserve actual member projection spans")
    selection = function(sources[2], "firstBlockingInterpolationNode")
    if "context.interpolationCallArgumentDiagnosticByNode[nodeIndex!].code > 0" not in selection:
        raise ValueError("interpolation call errors must share the existing first-error selection")
    display = function(sources[6], "invalidDisplayTypeByNode")
    if "callNumericDiagnostics[diagnosticNode!].code > 0" not in display:
        raise ValueError("a call error must suppress its dependent display error")
    emitter = function(sources[2], "emitNumericCallArgumentDiagnostic")
    if re.search(r"context\.ir|functionIr|parameterIr", emitter):
        raise ValueError("numeric diagnostic rendering depends on Typed IR")
    initializer_emitter = function(sources[2], "emitNominalInitializerDiagnostics")
    if re.search(r"context\.ir|functionIr|parameterIr", initializer_emitter):
        raise ValueError("initializer diagnostic rendering depends on Typed IR")
    if "context.nominalFieldMismatch" not in initializer_emitter:
        raise ValueError("nominal field diagnostic must render the committed semantic mismatch")
    blocking = function(sources[2], "emitBlockingDiagnostics")
    if re.search(r"context\.interpolationCall(?:Numeric|Argument)Diagnostic\b|-> emitInterpolationCall(?:Numeric|Argument)Diagnostic\b", blocking):
        raise ValueError("a global interpolation call error must not override an earlier root")
    consumer_diagnostics = blocking.index("-> emitInterpolationDiagnostics")
    for name in ("firstBindingDeclarationDiagnostic", "firstDeclarationRootDiagnostic",
                 "declarationScope", "declarationNameConsumes", "declarationOwnerConsumed"):
        body = function(sources[0], name)
        if re.search(r"\btypedIr\b|\bir\b|context\.ir|functionIr|parameterIr", body):
            raise ValueError("declaration decisions depend on Typed IR: " + name)
        checked.append(name)
    preparation = function(sources[1], "prepareSnapshot")
    for name in ("firstBindingDeclarationDiagnostic", "firstDeclarationRootDiagnostic"):
        if preparation.index("semanticDiagnostics." + name) >= preparation.index("-> lowerPreparedIr"):
            raise ValueError("declaration root must be committed before lowering: " + name)
    declaration_emitter = function(sources[2], "emitBindingDeclarationDiagnostic")
    if "context.bindingDeclarationDiagnostic" not in declaration_emitter or re.search(
            r"context\.ir|functionIr|parameterIr|declarationOwnerConsumed|declarationAncestor", declaration_emitter):
        raise ValueError("declaration renderer must consume the committed diagnostic only")
    if "context.firstDeclarationRootDiagnostic == 5" not in blocking:
        raise ValueError("binding diagnostics must use the committed first-root decision")
    declaration_decision = function(sources[0], "firstBindingDeclarationDiagnostic")
    intrinsic_consumption = function(sources[0], "declarationIntrinsicOwnerConsumed")
    if re.search(r"\bir\b|typedIr\.|functionIr|parameterIr", intrinsic_consumption):
        raise ValueError("intrinsic owner consumption must use semantic flow identity")
    for condition in ("firstFlow.start != name.start", "parent.start == name.start",
                      "prepared.directFlowTargetPathByAst[globalFlow]", "grammar.tokenIdDot()",
                      "prepared.callIndexByAst[globalFlow]", "prepared.calls[callIndex].functionSymbol >= 0"):
        if condition not in intrinsic_consumption:
            raise ValueError("intrinsic owner consumption lost exact source/final target/declared callee boundary: " + condition)
    name_consumption = function(sources[0], "declarationNameConsumes")
    if name_consumption.index("declarationIntrinsicOwnerConsumed") > name_consumption.index("ownerType! < 0"):
        raise ValueError("intrinsic owner identity must not depend on an inferred replacement binding type")
    mutable_root = function(sources[11], "mutableBindingRoot")
    if "binding.kind == 17 and binding.flags != 1" not in mutable_root:
        raise ValueError("immutable binding must preserve its own storage identity")
    if mutable_root.index("binding.kind == 17 and binding.flags != 1") > mutable_root.index("candidateIndex! < candidateEnd!"):
        raise ValueError("immutable identity must be protected before mutable storage search")
    if "candidate.kind == 35 and candidate.parent >= 0" not in declaration_decision:
        raise ValueError("parameter visibility must use its declaring function, not its shared AST parent")
    active_body = function(sources[0], "declarationBodyIsActive")
    if "prepared.package.symbols[range.symbolStart + symbol!].kind == 7" not in active_body:
        raise ValueError("generic activation must select a function symbol, not a parameter sharing its AST")
    if "diagnosticOriginBefore" not in function(sources[0], "firstDeclarationRootDiagnostic"):
        raise ValueError("root diagnostics must compare declaration and initializer origins")
    for name in ("emitNumericCallLiteralDiagnostic", "emitNumericCallArgumentDiagnostic"):
        occurrences = list(re.finditer(rf"-> {name}\b", blocking))
        if len(occurrences) != 1 or occurrences[0].start() >= consumer_diagnostics:
            raise ValueError(f"semantic call failure must precede dependent diagnostics exactly once: {name}")
    if "resolved.callArguments" not in function(sources[0], "firstNumericCallArgumentDiagnostic"):
        raise ValueError("numeric mismatch decisions must consume semantic argument facts")
    arguments = function(sources[4], "resolveSemanticCallArguments")
    returns = function(sources[5], "resolveFlowCallTypes")
    for body in (arguments, returns):
        if "seedExplicitFlowGenericArguments(" not in body:
            raise ValueError("argument and return inference must share explicit generic seeding")
    if "contextualizeNumericCallArgumentArena(" not in returns:
        raise ValueError("return inference must contextualize additional numeric arguments")
    contextual = function(sources[4], "contextualizeNumericCallArgument")
    if "contextualizeNumericCallArgumentArena(" not in contextual:
        raise ValueError("argument inference must use the shared numeric arena update")
    if returns.index("contextualizeNumericCallArgumentArena(") > returns.index(
            "expressionIndexByAst[callRange.astStart + binding.argumentAst] => actualExpression"):
        raise ValueError("numeric context must precede reading the return inference actual")
    if hashes != {str(p): hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in paths}:
        raise ValueError("source inputs changed during validation")
    result = {"schemaVersion": 1, "status": "passed", "scope": "source-boundary-only",
              "checkedFunctions": checked, "inputsStable": True, "sourceHashes": hashes,
              "behavioralParity": "requires focused compiled paired proofs"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as out:
        json.dump(result, out, indent=2)
        out.write("\n")
    print("C385 pre-IR call diagnostic source boundary: PASS")


if __name__ == "__main__":
    main()
