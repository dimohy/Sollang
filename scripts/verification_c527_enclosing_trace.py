"""Reject enclosing C527 traces that spend their budget in nested/hot loops."""

ROOT = 'sollang_fn_sollang_compiler_llvm_text_prepareNative'
SNAPSHOT = 'sollang_fn_sollang_compiler_llvm_text_prepareSnapshot'
LAYOUT = 'sollang_fn_sollang_compiler_llvm_text_aggregateFieldLayout'
REQUIRED = ('lowerPreparedIr', 'materializeGenericClosure',
            'analyzeResolvedLoweredContext', 'layoutsFor', 'valueLayoutCycles',
            'resultPropagationDecisionByNode', 'invalidDisplayTypeByNode',
            'analyzeNominalInitializers')


def validate(plan):
    if plan.get('root') != ROOT or set(plan.get('owners', [])) != {ROOT, SNAPSHOT}:
        raise ValueError('C527_ENCLOSING_PHASE_OWNERS_REQUIRED')
    if LAYOUT not in plan.get('excludedCallees', []):
        raise ValueError('C527_ENCLOSING_LAYOUT_LOOP_MUST_NOT_SPEND_TRACE_BUDGET')
    labels = [row['label'] for row in plan['markers']]
    if any(label.endswith('->' + LAYOUT) for label in labels):
        raise ValueError('C527_ENCLOSING_EXCLUDED_LAYOUT_STILL_TRACED')
    for name in REQUIRED:
        for direction in ('before:', 'after:'):
            if not any(label.startswith(direction + SNAPSHOT + '->')
                       and label.endswith('_' + name) for label in labels):
                raise ValueError('C527_ENCLOSING_REQUIRED_BOUNDARY_MISSING: ' + name)
    if not len(labels) <= plan.get('maximumRecords', 0) <= 1024:
        raise ValueError('C527_ENCLOSING_STATIC_PHASE_BUDGET_INSUFFICIENT')
    return {'status': 'passed', 'owners': 2, 'requiredBoundaries': len(REQUIRED),
            'staticMarkers': len(labels), 'maximumRecords': plan['maximumRecords'],
            'scope': 'trace-contract-only-not-original-acceptance'}
