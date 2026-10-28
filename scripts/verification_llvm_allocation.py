"""Observe an allocation's guarded, source-owned fatal branch.

This checks a diagnostic's relationship to its own generated failure block;
it does not establish byte-identical generated identifiers or full diagnostic
parity. Both emitters use the same rule without producer-specific strings.
"""
import re


def allocation_failure_binding(text, byte_count, source_function):
    if type(byte_count) is not int or byte_count <= 0 or not source_function:
        raise ValueError('ALLOCATION_FAILURE_CONTRACT_INVALID')
    return allocation_failure_call_binding(
        text, f'call ptr @sollang_alloc(i64 {byte_count})', source_function)


def allocation_failure_call_binding(text, call_needle, source_function):
    """Use one explicit, previously assembled allocation or resize call site."""
    if (not source_function or not isinstance(call_needle, str)
            or re.fullmatch(r'call ptr @sollang_(?:alloc|resize)\([^\n()]+\)', call_needle) is None):
        raise ValueError('ALLOCATION_FAILURE_CONTRACT_INVALID')
    text = text.replace('\r\n', '\n')
    matches = list(re.finditer(
        rf'^\s*(%[-\w.$]+) = {re.escape(call_needle)}\s*$', text, re.M))
    if len(matches) != 1:
        raise ValueError('ALLOCATION_FAILURE_CALL_NOT_UNIQUE')
    allocation = matches[0]
    owners = list(re.finditer(r'^define[^\n]*\{[ \t]*$', text[:allocation.start()], re.M))
    closing = re.search(r'^}', text[allocation.end():], re.M)
    if not owners or closing is None:
        raise ValueError('ALLOCATION_FAILURE_FUNCTION_MISSING')
    # LLVM block identifiers are local to a function. A same-named failure
    # block in a different function cannot supply this call site's evidence.
    function_end = allocation.end() + closing.end()
    function_text = text[owners[-1].start():function_end]
    pointers = {allocation[1]}
    condition = None
    tested_pointer = None
    branch = None
    for line in text[allocation.end():function_end].splitlines():
        if not line.strip():
            continue
        alias = re.fullmatch(r'\s*(%[-\w.$]+) = getelementptr i8, ptr (%[-\w.$]+), i64 0\s*', line)
        if alias and alias[2] in pointers:
            pointers.add(alias[1])
            continue
        comparison = re.fullmatch(r'\s*(%[-\w.$]+) = icmp ne ptr (%[-\w.$]+), null\s*', line)
        if comparison and comparison[2] in pointers and condition is None:
            condition = comparison[1]
            tested_pointer = comparison[2]
            continue
        branch = re.fullmatch(r'\s*br i1 (%[-\w.$]+), label %([-\w.$]+), label %([-\w.$]+)\s*', line)
        if branch and condition == branch[1]:
            break
        raise ValueError('ALLOCATION_FAILURE_GUARD_MISSING_BEFORE_USE')
    if branch is None or condition is None:
        raise ValueError('ALLOCATION_FAILURE_GUARD_MISSING_BEFORE_USE')
    fail = branch[3]
    block = re.search(rf'^{re.escape(fail)}:\s*\n(.*?)(?=^[-\w.$]+:|^}})', function_text, re.M | re.S)
    if block is None or not re.search(r'call void @llvm\.trap\(\)\s*\n\s*unreachable', block[1]):
        raise ValueError('ALLOCATION_FAILURE_FATAL_BRANCH_MISSING')
    literals = re.findall(r'\[(\d+) x i8\] c"((?:\\[0-9A-Fa-f]{2}|[^"\\])*)"', block[1])
    if not literals:
        symbols = re.findall(r'ptr (@[-\w.$]+)', block[1])
        for symbol in symbols:
            literals += re.findall(rf'^{re.escape(symbol)} = [^\n]*?\[(\d+) x i8\] c"((?:\\[0-9A-Fa-f]{{2}}|[^"\\])*)"', text, re.M)
    if len(literals) != 1:
        raise ValueError('ALLOCATION_FAILURE_DIAGNOSTIC_NOT_UNIQUE')
    length, encoded = literals[0]
    payload = bytearray()
    index = 0
    while index < len(encoded):
        if encoded[index] == '\\':
            payload.append(int(encoded[index + 1:index + 3], 16))
            index += 3
        else:
            payload.extend(encoded[index].encode('utf-8'))
            index += 1
    diagnostic = payload.decode('utf-8')
    if len(payload) != int(length) or diagnostic != source_function + ':' + fail:
        raise ValueError('ALLOCATION_FAILURE_DIAGNOSTIC_OWNER_MISMATCH')
    return dict(allocationPointer=allocation[1], condition=condition, testedPointer=tested_pointer,
                readyBlock=branch[2], failureBlock=fail, diagnostic=diagnostic,
                encodedDiagnostic=encoded, diagnosticByteCount=int(length))
