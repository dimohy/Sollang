"""Bind local reference name classification to the shared value load."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]


def verify(arguments, expressions, diagnostics, emitter):
    classifier = arguments.split('isLocalReadonlyReferenceName valueIndex:', 1)[1].split('referenceParameterValueIsMaterialized valueIndex:', 1)[0]
    assert 'value.kind != 5 or (value -> referenceValueTypeId(context, state)) < 0' in classifier
    assert 'binding.kind == 17 and binding.flags != 1' in classifier
    assert '(value.operand0 -> asyncFrameBindingRoot(ownerIndex, context, state)) < 0' in classifier
    materialized = arguments.split('referenceParameterValueIsMaterialized valueIndex:', 1)[1].split('writeReferencePlaceValue functionIndex:', 1)[0]
    assert 'valueIndex -> isLocalReadonlyReferenceName(ownerIndex, context, state)' in materialized
    named = expressions.split('emitNamedPlaceRead expressionIndex:', 1)[1].split('expression.operand0 -> asyncFrameBindingRoot', 1)[0]
    assert 'expressionIndex -> isLocalReadonlyReferenceName(functionIndex, context, state)' in named
    assert 'localValueTypeId -> writeAggregateFieldTypeId(context, state)' in named
    assert 'functionIndex -> writeForwardedReferenceValue(expressionIndex, context, state)' in named
    assert '"  %v$(expressionIndex) = load " -> print' in named
    mismatch = diagnostics.split('numericCallArgumentMismatch package:', 1)[1]
    fallback = mismatch.split('resolved.types[argument.actualTypeId] => actualType', 1)[1].split('# Console facades', 1)[0]
    assert 'package.nodes[package.ranges[argument.sourceModule].astStart + argument.argumentAst].kind == 15' in fallback
    assert 'argument.targetSourceModule >= libraryStart' in mismatch
    assert 'argument.targetSourceModule < libraryStart + libraryCount' in mismatch
    assert 'grammar.ruleIdNativeFunctionDeclaration()' in mismatch
    assert 'mismatchCode! == 8 -> if { argument.argumentAst => diagnosticAst! }' in mismatch
    rendered = emitter.split('emitNumericCallArgumentDiagnostic context:', 1)[1].split('emitMemberFieldCollision context:', 1)[0]
    assert 'diagnostic.code != 8 -> if { "function \'" -> print }' in rendered
    assert 'diagnostic.code == 8 -> if { " " -> print } else { "\' " -> print }' in rendered


if __name__ == '__main__':
    arguments = (ROOT / 'selfhost/llvm/text/call_arguments.slg').read_text(encoding='utf-8-sig')
    expressions = (ROOT / 'selfhost/llvm/text/function_expressions.slg').read_text(encoding='utf-8-sig')
    diagnostics = (ROOT / 'selfhost/semantic/diagnostics.slg').read_text(encoding='utf-8-sig')
    emitter = (ROOT / 'selfhost/llvm/emitter/diagnostics.slg').read_text(encoding='utf-8-sig')
    verify(arguments, expressions, diagnostics, emitter)
    stale = expressions.replace('"  %v$(expressionIndex) = load " -> print', '"  %v$(expressionIndex) = freeze " -> print', 1)
    try:
        verify(arguments, stale, diagnostics, emitter)
    except AssertionError:
        print('Shared local reference read passed; pointer-freeze mutation rejected.')
    else:
        raise AssertionError('POINTER_FREEZE_MUTATION_ACCEPTED')
    broad = diagnostics.replace('and package.nodes[package.ranges[argument.sourceModule].astStart + argument.argumentAst].kind == 15', 'and true', 1)
    try:
        verify(arguments, expressions, broad, emitter)
    except AssertionError:
        print('Name-only readonly input rule passed; broad reference fallback rejected.')
    else:
        raise AssertionError('BROAD_REFERENCE_FALLBACK_ACCEPTED')
    wrong = emitter.replace('diagnostic.code != 8 -> if { "function \'" -> print }', '"function \'" -> print', 1)
    try:
        verify(arguments, expressions, diagnostics, wrong)
    except AssertionError:
        print('Runtime/ordinary diagnostic styles passed; quoted runtime mutation rejected.')
    else:
        raise AssertionError('QUOTED_RUNTIME_DIAGNOSTIC_ACCEPTED')
    wrong_location = diagnostics.replace('mismatchCode! == 8 -> if { argument.argumentAst => diagnosticAst! }', '', 1)
    try:
        verify(arguments, expressions, wrong_location, emitter)
    except AssertionError:
        print('Runtime argument location passed; whole-call location mutation rejected.')
    else:
        raise AssertionError('RUNTIME_CALL_LOCATION_ACCEPTED')
