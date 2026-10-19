"""Add bounded compute-dispatch boundaries to an emitCore diagnostic trace."""
from copy import deepcopy
from verification_llvm_call_trace import FUNCTION, CALL

ROOT = 'sollang_fn_sollang_compiler_llvm_text_emitCore'
CALLEE = 'sollang_compute_execute'


def instrument_compute(source: str, plan: dict) -> tuple[str, dict]:
    if (plan['root'] != ROOT or plan['depth'] != 0 or plan['owners'] != [ROOT]
            or plan['abi'] != 'managed-windows'):
        raise ValueError('COMPUTE_TRACE_CORE_SCOPE_REQUIRED')
    if any(CALLEE in row['label'] for row in plan['markers']):
        raise ValueError('COMPUTE_TRACE_ALREADY_INSTRUMENTED')
    matches = [m for m in FUNCTION.finditer(source) if m.group(1) == ROOT]
    if len(matches) != 1:
        raise ValueError('COMPUTE_TRACE_SINGLE_ROOT_REQUIRED')
    match = matches[0]
    calls = [line for line in match.group(0).splitlines()
             if (call := CALL.search(line)) and call.group(1) == CALLEE]
    if len(calls) != 2:
        raise ValueError('COMPUTE_TRACE_TWO_DISPATCHES_REQUIRED')
    if len(plan['markers']) + 4 > plan['maximumRecords']:
        raise ValueError('COMPUTE_TRACE_STATIC_BUDGET_REQUIRED')
    result = deepcopy(plan)
    constants = []

    def marker(kind):
        index = len(result['markers'])
        label = kind + ':' + ROOT + '->' + CALLEE
        result['markers'].append(dict(id=index, label=label))
        constants.append(f'@sollang_observation_label_{index} = private constant '
                         f'[{len(label)} x i8] c"{label}"')
        return ('  call void @sollang_observation_emit('
                f'ptr @sollang_observation_label_{index}, i64 {len(label)})')

    lines = []
    for line in match.group(0).splitlines():
        call = CALL.search(line)
        if call and call.group(1) == CALLEE:
            lines.extend([marker('before'), line, marker('after')])
        else:
            lines.append(line)
    transformed = source[:match.start()] + '\n'.join(lines) + source[match.end():]
    result['runtimeBoundaryCallees'] = [CALLEE]
    return transformed + '\n' + '\n'.join(constants) + '\n', result
