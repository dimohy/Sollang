"""Observe selected function IR indices without tracing expression hot loops."""
import re

from verification_llvm_call_trace import FUNCTION
from verification_llvm_callback_trace import instrument as callback_instrument, SYMBOL

OWNER = 'sollang_fn_sollang_compiler_llvm_text_emitFunctionNamed'
PREFIX = 'sollang_fn_sollang_compiler_llvm_text_'
WRAPPER = 'sollang_observe_selected_function_phase'
PHASES = ('staticReadonlyNumericArrayReturn', 'functionCaptures',
          'emitHoistedControlAllocas', 'emitHoistedReferenceArgumentAllocas',
          'prepareFunctionExpressionOrder', 'emitScheduledFunctionBody',
          'emitFunctionReturn')


def instrument(source, callback, selected):
    if not selected or len(selected) > 4 or len(set(selected)) != len(selected) or any(
            type(i) is not int or not 0 <= i < 2**31 for i in selected):
        raise ValueError('FUNCTION_PHASE_EXACT_INDICES_REQUIRED')
    transformed, _ = callback_instrument(source, callback, 256)
    # Reuse the numeric record runtime, not the all-item callback observations.
    for kind in (66, 65):
        line = f'  call void @{SYMBOL}(i8 {kind}, i32 %item, i64 %index)\n'
        if transformed.count(line) != 1:
            raise ValueError('FUNCTION_PHASE_CALLBACK_BOUNDARY_REQUIRED')
        transformed = transformed.replace(line, '', 1)
    matches = [m for m in FUNCTION.finditer(transformed) if m.group(1) == OWNER]
    if len(matches) != 1 or 'i32 %it,' not in matches[0].group(0).splitlines()[0]:
        raise ValueError('FUNCTION_PHASE_OWNER_ABI_REQUIRED')
    owner = matches[0]
    body = owner.group(0)
    decimal = re.search(r'^  call void @' + PREFIX + r'writeDecimal\([^\n]*i32 (%[\w.]+)\)$', body, re.M)
    if not decimal:
        raise ValueError('FUNCTION_PHASE_DECLARATION_IDENTITY_REQUIRED')
    identity = re.search(r'^  ' + re.escape(decimal.group(1)) +
                         r' = extractvalue (%[\w.]+) (%[\w.]+), 2$', body, re.M)
    if not identity or not re.search(r' = extractvalue ' + re.escape(identity.group(1)) +
                                     ' ' + re.escape(identity.group(2)) + r', 4$', body, re.M):
        raise ValueError('FUNCTION_PHASE_TYPED_IR_IDENTITY_REQUIRED')
    node_type, node_value = identity.group(1), identity.group(2)
    load = re.search(r'^  ' + re.escape(node_value) + r' = load ' + re.escape(node_type) + r',[^\n]+$', body, re.M)
    slot = re.search(r'^  store i32 %[\w.]+, ptr (%[\w.]+), align 4$', body[load.end():] if load else '', re.M)
    if not load or not slot:
        raise ValueError('FUNCTION_PHASE_SPAN_STORAGE_REQUIRED')
    span_slot = slot.group(1)
    lines = body.splitlines()
    result, seen, phases = [], set(), {}
    for line in lines:
        call = re.search(r'call [^\n]*@' + PREFIX + r'([A-Za-z0-9_]+)\(', line)
        name = call.group(1) if call else None
        trace = name in PHASES and (name not in seen or name == 'emitFunctionReturn')
        if trace:
            phase = len(phases) + 1
            phases[phase] = name
            seen.add(name)
            if name == PHASES[0]:
                result.extend([f'  %observe_function_end = load i32, ptr {span_slot}, align 4',
                               '  %observe_function_end64 = zext i32 %observe_function_end to i64',
                               f'  call void @{WRAPPER}(i8 69, i32 %it, i64 %observe_function_end64)'])
            if name == 'emitFunctionReturn':
                result.append(f'  call void @{WRAPPER}(i8 65, i32 %it, i64 8)')
            result.append(f'  call void @{WRAPPER}(i8 66, i32 %it, i64 {phase})')
        result.append(line)
        if line == 'entry:':
            result.append(f'  call void @{WRAPPER}(i8 73, i32 %it, i64 0)')
        if line == load.group(0):
            for field, kind in ((2, 77), (4, 83)):
                result.extend([f'  %observe_identity_{field} = extractvalue {node_type} {node_value}, {field}',
                               f'  %observe_identity64_{field} = zext i32 %observe_identity_{field} to i64',
                               f'  call void @{WRAPPER}(i8 {kind}, i32 %it, i64 %observe_identity64_{field})'])
        if trace:
            result.append(f'  call void @{WRAPPER}(i8 65, i32 %it, i64 {phase})')
            if name == 'prepareFunctionExpressionOrder':
                result.append(f'  call void @{WRAPPER}(i8 66, i32 %it, i64 8)')
    if seen != set(PHASES):
        raise ValueError('FUNCTION_PHASE_REQUIRED_CALL_MISSING')
    phases[8] = 'ordinary-expression-emission'
    transformed = transformed[:owner.start()] + '\n'.join(result) + transformed[owner.end():]
    runtime = [f'define internal void @{WRAPPER}(i8 %kind, i32 %item, i64 %phase) {{', 'entry:']
    for index, item in enumerate(selected):
        runtime.append(f'  %selected_{index} = icmp eq i32 %item, {item}')
        if index:
            previous = '%selected_0' if index == 1 else f'%combined_{index-1}'
            runtime.append(f'  %combined_{index} = or i1 {previous}, %selected_{index}')
    condition = '%selected_0' if len(selected) == 1 else f'%combined_{len(selected)-1}'
    runtime.extend([f'  br i1 {condition}, label %record, label %done', 'record:',
                    f'  call void @{SYMBOL}(i8 %kind, i32 %item, i64 %phase)',
                    '  br label %done', 'done:', '  ret void', '}'])
    plan = dict(root=OWNER, owners=[OWNER], depth=0, markers=[], maximumRecords=256,
                selectedFunctionIrIndices=selected, phases=phases,
                scope='diagnostic-only-not-acceptance', metadataKinds=dict(I='entered', M='sourceModule', S='symbol', E='functionEnd'))
    return transformed + '\n' + '\n'.join(runtime) + '\n', plan


def summarize(plan, trace):
    functions = {}
    lines = trace.splitlines(keepends=True)
    records = [line.rstrip('\r\n') for line in lines if line.endswith('\n')]
    if len(records) > plan['maximumRecords']:
        raise ValueError('FUNCTION_PHASE_BUDGET_EXCEEDED')
    phases = {int(k): v for k, v in plan['phases'].items()}
    for line in records:
        match = re.fullmatch(r'([IBAMSE]):([0-9a-f]{8}):([0-9a-f]{16})', line)
        if not match:
            raise ValueError('FUNCTION_PHASE_INVALID_RECORD')
        kind, item, value = match.groups(); item, value = int(item, 16), int(value, 16)
        if item not in plan['selectedFunctionIrIndices']:
            raise ValueError('FUNCTION_PHASE_UNSELECTED_ITEM')
        f = functions.setdefault(item, dict(returnedPhases=[], pendingPhase=None, metadata={}))
        if kind != 'I' and 'entered' not in f['metadata']:
            raise ValueError('FUNCTION_PHASE_ENTRY_REQUIRED')
        if kind in plan['metadataKinds']:
            key = plan['metadataKinds'][kind]
            if key in f['metadata']:
                raise ValueError('FUNCTION_PHASE_REENTRY_OR_DUPLICATE_METADATA')
            f['metadata'][key] = value
        elif value not in phases:
            raise ValueError('FUNCTION_PHASE_UNKNOWN_PHASE')
        elif kind == 'B' and f['pendingPhase'] is None:
            f['pendingPhase'] = value
        elif kind == 'A' and f['pendingPhase'] == value:
            f['returnedPhases'].append(value); f['pendingPhase'] = None
        else:
            raise ValueError('FUNCTION_PHASE_UNMATCHED_BOUNDARY')
    exhausted = len(records) == plan['maximumRecords']
    return dict(scope=plan['scope'], records=len(records), functions=functions,
                traceBudgetExhausted=exhausted, pendingPhasesConclusive=not exhausted,
                ignoredPartialLine=bool(lines and not lines[-1].endswith('\n')))
