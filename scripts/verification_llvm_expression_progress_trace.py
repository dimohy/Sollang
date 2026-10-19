"""Sample exact ordinary-function emission boundaries without changing calls."""
import re
from verification_llvm_call_trace import FUNCTION
from verification_llvm_callback_trace import instrument as callback_instrument, SYMBOL

OWNER = 'sollang_fn_sollang_compiler_llvm_text_emitFunctionNamed'
PREFIX = 'sollang_fn_sollang_compiler_llvm_text_'
HANDLERS = ['emitFunctionIntrinsicExpressions', 'inline-expression-branches',
            'emitFunctionAggregateExpressions', 'emitFunctionLoopExpressions',
            'emitFunctionArrayExpressions', 'emitFunctionEnumExpressions',
            'emitFunctionMemberExpressions', 'emitFunctionOperatorExpressions',
            'emitFunctionCalls', 'emitFunctionTerminalExpressions']
WRAPPER = 'sollang_observe_expression_sample'


def instrument(source, callback, selected, stride=128, maximum_records=8192):
    if not 1 <= len(selected) <= 4 or len(set(selected)) != len(selected) or any(
            type(i) is not int or not 0 <= i < 2**31 for i in selected):
        raise ValueError('EXPRESSION_TRACE_EXACT_INDICES_REQUIRED')
    if type(stride) is not int or stride < 1 or stride > 4096 or stride & (stride-1):
        raise ValueError('EXPRESSION_TRACE_POWER_OF_TWO_STRIDE_REQUIRED')
    changed, _ = callback_instrument(source, callback, maximum_records)
    for kind in (66, 65):
        marker = f'  call void @{SYMBOL}(i8 {kind}, i32 %item, i64 %index)\n'
        if changed.count(marker) != 1:
            raise ValueError('EXPRESSION_TRACE_CALLBACK_BOUNDARY_REQUIRED')
        changed = changed.replace(marker, '', 1)
    owners = [m for m in FUNCTION.finditer(changed) if m.group(1) == OWNER]
    if len(owners) != 1 or 'i32 %it,' not in owners[0].group(0).splitlines()[0]:
        raise ValueError('EXPRESSION_TRACE_OWNER_REQUIRED')
    owner = owners[0]
    body = owner.group(0)
    calls = {}
    for handler in HANDLERS:
        if handler == 'inline-expression-branches':
            continue
        found = list(re.finditer(r'^  call void @' + PREFIX + handler +
                     r'\([^\n]*?i32 (%[\w.]+), i32 %it,[^\n]*\)$', body, re.M))
        if len(found) != 1:
            raise ValueError('EXPRESSION_TRACE_EXACT_HANDLER_REQUIRED:' + handler)
        calls[handler] = found[0]
    expression = calls[HANDLERS[0]].group(1)
    if any(m.group(1) != expression for m in calls.values()):
        raise ValueError('EXPRESSION_TRACE_SHARED_EXPRESSION_REQUIRED')
    if list(calls) != sorted(calls, key=lambda h: calls[h].start()):
        raise ValueError('EXPRESSION_TRACE_HANDLER_ORDER_REQUIRED')
    def record(kind, phase):
        return [f'  %observe_payload_{kind}_{phase} = or i64 %observe_payload, {phase}',
                f'  call void @{WRAPPER}(i1 %observe_sample, i8 {ord(kind)}, i32 %it, i64 %observe_payload_{kind}_{phase})']
    output = []
    seen = set()
    for line in body.splitlines():
        match = next((h for h,m in calls.items() if line == m.group(0)), None)
        if match == HANDLERS[0]:
            output += ['  %observe_ordinal = load i32, ptr %observe_counter, align 4',
                       '  %observe_next = add i32 %observe_ordinal, 1',
                       '  store i32 %observe_next, ptr %observe_counter, align 4',
                       f'  %observe_mod = and i32 %observe_ordinal, {stride-1}',
                       '  %observe_sample = icmp eq i32 %observe_mod, 0',
                       '  %observe_ordinal64 = zext i32 %observe_ordinal to i64',
                       '  %observe_ordinal_part = shl i64 %observe_ordinal64, 40',
                       f'  %observe_expression64 = zext i32 {expression} to i64',
                       '  %observe_expression_part = shl i64 %observe_expression64, 8',
                       '  %observe_payload = or i64 %observe_ordinal_part, %observe_expression_part']
        if match == HANDLERS[2]:
            output += record('A', 2)
        if match:
            phase = HANDLERS.index(match)+1
            output += record('B', phase)
        if '@' + PREFIX + 'emitFunctionReturn(' in line:
            output += ['  %observe_total = load i32, ptr %observe_counter, align 4',
                       '  %observe_total64 = zext i32 %observe_total to i64',
                       f'  call void @{WRAPPER}(i1 true, i8 82, i32 %it, i64 %observe_total64)']
            seen.add('return')
        output.append(line)
        if line == 'entry:':
            output += ['  %observe_counter = alloca i32, align 4',
                       '  store i32 0, ptr %observe_counter, align 4',
                       f'  call void @{WRAPPER}(i1 true, i8 73, i32 %it, i64 0)']
        if match:
            output += record('A', phase)
            if phase == 1:
                output += record('B', 2)
    if 'return' not in seen:
        raise ValueError('EXPRESSION_TRACE_RETURN_BOUNDARY_REQUIRED')
    changed = changed[:owner.start()] + '\n'.join(output) + changed[owner.end():]
    runtime = [f'define internal void @{WRAPPER}(i1 %sample, i8 %kind, i32 %item, i64 %payload) {{','entry:']
    for n,item in enumerate(selected):
        runtime.append(f'  %selected_{n} = icmp eq i32 %item, {item}')
        if n:
            previous = '%selected_0' if n == 1 else f'%combined_{n-1}'
            runtime.append(f'  %combined_{n} = or i1 {previous}, %selected_{n}')
    condition = '%selected_0' if len(selected) == 1 else f'%combined_{len(selected)-1}'
    runtime += [f'  %allowed = and i1 %sample, {condition}',
                '  br i1 %allowed, label %record, label %done','record:',
                f'  call void @{SYMBOL}(i8 %kind, i32 %item, i64 %payload)',
                '  br label %done','done:','  ret void','}']
    return changed+'\n'+'\n'.join(runtime)+'\n', dict(root=OWNER, owners=[OWNER], depth=0,
        markers=[], maximumRecords=maximum_records, selectedFunctionIrIndices=selected,
        stride=stride, handlers={i+1:h for i,h in enumerate(HANDLERS)},
        scope='diagnostic-only-not-acceptance', payload='ordinal24:expression32:handler8')


def summarize(plan, trace):
    lines = trace.splitlines(keepends=True)
    records = [l.rstrip('\r\n') for l in lines if l.endswith('\n')]
    if len(records) > plan['maximumRecords']:
        raise ValueError('EXPRESSION_TRACE_BUDGET_EXCEEDED')
    functions = {}
    for line in records:
        match = re.fullmatch(r'([IBAR]):([0-9a-f]{8}):([0-9a-f]{16})', line)
        if not match:
            raise ValueError('EXPRESSION_TRACE_INVALID_RECORD')
        kind,item,payload = match.groups();item,payload=int(item,16),int(payload,16)
        if item not in plan['selectedFunctionIrIndices']:
            raise ValueError('EXPRESSION_TRACE_UNSELECTED_FUNCTION')
        if kind == 'I':
            if item in functions or payload != 0:
                raise ValueError('EXPRESSION_TRACE_DUPLICATE_ENTRY')
            functions[item] = dict(lastCheckpoint=None, pending=None, completedCheckpoints=0,
                                   reachedReturn=False, iterationCount=None)
            continue
        if item not in functions or functions[item]['reachedReturn']:
            raise ValueError('EXPRESSION_TRACE_ENTRY_OR_ORDER_REQUIRED')
        f = functions[item]
        if kind == 'R':
            if f['pending']:
                raise ValueError('EXPRESSION_TRACE_RETURN_WITH_PENDING_HANDLER')
            f.update(reachedReturn=True,iterationCount=payload)
            continue
        ordinal,expression,handler = payload>>40,(payload>>8)&0xffffffff,payload&255
        if ordinal % plan['stride'] or handler not in range(1,11):
            raise ValueError('EXPRESSION_TRACE_INVALID_CHECKPOINT')
        checkpoint=dict(ordinal=ordinal,expression=expression,handler=handler)
        last=f['lastCheckpoint']
        if kind == 'B':
            if f['pending'] or (last and (ordinal < last['ordinal'] or
                (ordinal==last['ordinal'] and (expression!=last['expression'] or handler!=last['handler']+1)) or
                (ordinal>last['ordinal'] and (last['handler']!=10 or handler!=1)))) or (not last and (ordinal!=0 or handler!=1)):
                raise ValueError('EXPRESSION_TRACE_HANDLER_ORDER_REQUIRED')
            f['pending']=checkpoint
        elif f['pending'] != checkpoint:
            raise ValueError('EXPRESSION_TRACE_UNMATCHED_RETURN')
        else:
            f['pending']=None;f['lastCheckpoint']=checkpoint
            if handler==10:f['completedCheckpoints']+=1
    exhausted = len(records)==plan['maximumRecords']
    return dict(scope=plan['scope'],records=len(records),functions=functions,
        traceBudgetExhausted=exhausted,pendingBoundariesConclusive=not exhausted,
        ignoredPartialLine=bool(lines and not lines[-1].endswith('\n')))
