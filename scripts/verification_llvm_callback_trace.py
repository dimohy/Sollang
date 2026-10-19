"""Bounded concurrent item tracing for one proven compute callback."""
from __future__ import annotations

import re

from verification_llvm_call_trace import FUNCTION

CALLEE = 'sollang_fn_sollang_compiler_llvm_text_emitFunction'
SYMBOL = 'sollang_observe_callback_item'


def instrument(source: str, callback: str, maximum_records: int = 8192):
    if not 2 <= maximum_records <= 65536:
        raise ValueError('CALLBACK_TRACE_RECORD_LIMIT')
    if SYMBOL in source:
        raise ValueError('CALLBACK_TRACE_ALREADY_INSTRUMENTED')
    matches = [m for m in FUNCTION.finditer(source) if m.group(1) == callback]
    if len(matches) != 1:
        raise ValueError('CALLBACK_TRACE_EXACT_OWNER_REQUIRED')
    match = matches[0]
    body = match.group(0)
    expected = re.compile(r'^  %mapped = call i32 @' + CALLEE +
                          r'\([^\n]*i32 %item, ptr %capture_value_0, ptr %capture_value_1\)$', re.M)
    calls = list(expected.finditer(body))
    if len(calls) != 1 or 'i64 %index' not in body.splitlines()[0]:
        raise ValueError('CALLBACK_TRACE_EXACT_CALL_REQUIRED')
    for external in ('GetStdHandle', 'WriteFile'):
        if not re.search(r'^declare [^\n]*@' + external + r'\(', source, re.M):
            raise ValueError('CALLBACK_TRACE_WINDOWS_ABI_REQUIRED')
    call = calls[0]
    wrapped = ('  call void @' + SYMBOL + '(i8 66, i32 %item, i64 %index)\n' +
               call.group(0) + '\n  call void @' + SYMBOL + '(i8 65, i32 %item, i64 %index)')
    changed = body[:call.start()] + wrapped + body[call.end():]
    source = source[:match.start()] + changed + source[match.end():]
    runtime = [f'@sollang_observe_callback_count = internal global i64 0',
               f'define internal void @{SYMBOL}(i8 %kind, i32 %item, i64 %ordinal) {{',
               'entry:',
               '  %record = atomicrmw add ptr @sollang_observe_callback_count, i64 1 monotonic',
               f'  %allowed = icmp ult i64 %record, {maximum_records}',
               '  br i1 %allowed, label %write, label %done',
               'write:', '  %buffer = alloca [28 x i8], align 1',
               '  store i8 %kind, ptr %buffer, align 1']
    for position, value in ((1, 58), (10, 58), (27, 10)):
        runtime += [f'  %fixed_{position} = getelementptr i8, ptr %buffer, i64 {position}',
                    f'  store i8 {value}, ptr %fixed_{position}, align 1']
    for name, width, offset in (('item', 8, 2), ('ordinal', 16, 11)):
        bits = width * 4
        for digit in range(width):
            key = f'{name}_{digit}'
            runtime += [f'  %{key}_shift = lshr i{bits} %{name}, {(width-digit-1)*4}',
                        f'  %{key}_nibble = and i{bits} %{key}_shift, 15',
                        f'  %{key}_byte = trunc i{bits} %{key}_nibble to i8',
                        f'  %{key}_decimal = icmp ult i8 %{key}_byte, 10',
                        f'  %{key}_number = add i8 %{key}_byte, 48',
                        f'  %{key}_letter = add i8 %{key}_byte, 87',
                        f'  %{key}_character = select i1 %{key}_decimal, i8 %{key}_number, i8 %{key}_letter',
                        f'  %{key}_address = getelementptr i8, ptr %buffer, i64 {offset+digit}',
                        f'  store i8 %{key}_character, ptr %{key}_address, align 1']
    runtime += ['  %stderr = call ptr @GetStdHandle(i32 -12)',
                '  %written = alloca i32, align 4',
                '  %success = call i32 @WriteFile(ptr %stderr, ptr %buffer, i32 28, ptr %written, ptr null)',
                '  br label %done', 'done:', '  ret void', '}']
    plan = dict(scope='diagnostic-only-not-acceptance', callback=callback,
                root=callback, depth=0, owners=[callback], markers=[],
                callee=CALLEE, maximumRecords=maximum_records,
                recordFormat='kind:item-hex32:ordinal-hex64', concurrent=True)
    return source + '\n' + '\n'.join(runtime) + '\n', plan


def summarize(plan: dict, trace: str):
    pending, completed = {}, {}
    lines = trace.splitlines(keepends=True)
    records = [line.rstrip('\r\n') for line in lines if line.endswith('\n')]
    if len(records) > plan['maximumRecords']:
        raise ValueError('CALLBACK_TRACE_BUDGET_EXCEEDED')
    for line in records:
        match = re.fullmatch(r'([BA]):([0-9a-f]{8}):([0-9a-f]{16})', line)
        if not match:
            raise ValueError('CALLBACK_TRACE_INVALID_RECORD')
        kind, item, ordinal = match.groups()
        item, ordinal = int(item, 16), int(ordinal, 16)
        if kind == 'B':
            if ordinal in pending or ordinal in completed:
                raise ValueError('CALLBACK_TRACE_DUPLICATE_ITEM')
            pending[ordinal] = item
        else:
            if pending.get(ordinal) != item:
                raise ValueError('CALLBACK_TRACE_UNMATCHED_RETURN')
            completed[ordinal] = pending.pop(ordinal)
    exhausted = len(records) == plan['maximumRecords']
    return dict(scope=plan['scope'], records=len(records),
                completedItems=completed, pendingItems=pending,
                traceBudgetExhausted=exhausted,
                pendingItemsConclusive=not exhausted,
                ignoredPartialLine=bool(lines and not lines[-1].endswith('\n')))
