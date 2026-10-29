"""Observe an allocation's guarded, source-owned fatal branch.

Check a diagnostic in its allocation's actual failure block. A declared
semantic diagnostic code is independent of private backend block identities;
the default retains the older block-owned observation contract.
"""
import re


def allocation_failure_binding(text, byte_count, source_function, *, diagnostic_code=None):
    if type(byte_count) is not int or byte_count <= 0 or not source_function:
        raise ValueError('ALLOCATION_FAILURE_CONTRACT_INVALID')
    return allocation_failure_call_binding(
        text, f'call ptr @sollang_alloc(i64 {byte_count})', source_function,
        diagnostic_code=diagnostic_code)


def allocation_failure_call_binding(text, call_needle, source_function, *, diagnostic_code=None):
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
    identity = fail if diagnostic_code is None else diagnostic_code
    if len(payload) != int(length) or diagnostic != source_function + ':' + identity:
        raise ValueError('ALLOCATION_FAILURE_DIAGNOSTIC_OWNER_MISMATCH')
    return dict(allocationPointer=allocation[1], condition=condition, testedPointer=tested_pointer,
                readyBlock=branch[2], failureBlock=fail, diagnostic=diagnostic,
                encodedDiagnostic=encoded, diagnosticByteCount=int(length))


def main():
    """Reuse the guarded-allocation observer for exact shared failure cases."""
    import argparse
    import hashlib
    import json
    import time
    from pathlib import Path
    from completed_artifact_plan import initialize_output, cleanup_output
    from verification_execution import VerificationExecution
    from verification_contract_lease import VerificationContractLease

    parser = argparse.ArgumentParser(description=main.__doc__)
    parser.add_argument('--contract', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-result', type=Path, required=True)
    parser.add_argument('--managed-compiler', type=Path)
    parser.add_argument('--llvm-input', action='append', default=[], metavar='PROGRAM=PATH')
    parser.add_argument('--reusable-compiler-directory', type=Path, action='append')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    contract_path = args.contract.resolve(strict=True)
    contract = json.loads(contract_path.read_text(encoding='utf-8-sig'))
    cases = contract['cases']
    reference_path = args.reference_result.resolve(strict=True)
    reference = json.loads(reference_path.read_text(encoding='utf-8-sig'))
    if (contract['schemaVersion'] != 1 or not cases or
            len({case['id'] for case in cases}) != len(cases) or
            reference['status'] != 'passed' or not reference['inputsStable'] or
            not reference['processesStopped'] or
            bool(args.managed_compiler) == bool(args.llvm_input)):
        raise ValueError('ALLOCATION_FAILURE_EXECUTION_CONTRACT_INVALID')
    programs = {}
    for item in args.llvm_input:
        key, value = item.split('=', 1)
        if key in programs:
            raise ValueError('ALLOCATION_FAILURE_DUPLICATE_PROGRAM')
        programs[key] = Path(value).resolve(strict=True)
    source_paths = {}
    for case in cases:
        if (re.fullmatch(r'[a-z0-9-]+', case['id']) is None or
                re.fullmatch(r'[a-z0-9-]+', case['program']) is None or
                case['diagnosticCode'] != 'allocation_failed' or case['exit'] != 0 or
                case['expectedRuntimeExit'] != -1073741795 or
                case['runStderr'] != case['sourceFunction'] + ':allocation_failed' or
                type(case['allocationBytes']) is not int or case['allocationBytes'] <= 0):
            raise ValueError('ALLOCATION_FAILURE_CASE_INVALID')
        source = (root / case['source']).resolve(strict=True)
        if not source.is_relative_to(root) or not source.is_file():
            raise ValueError('ALLOCATION_FAILURE_SOURCE_INVALID')
        if case['program'] in source_paths and source_paths[case['program']] != source:
            raise ValueError('ALLOCATION_FAILURE_PROGRAM_SOURCE_CONFLICT')
        source_paths[case['program']] = source
    if not args.managed_compiler and set(programs) != set(source_paths):
        raise ValueError('ALLOCATION_FAILURE_PROGRAM_INPUT_MISMATCH')
    llvm_home = root / '.tools/llvm-22.1.8'
    clang = llvm_home / 'bin/clang.exe'
    inputs = [contract_path, reference_path, clang, Path(__file__).resolve(),
              root / 'scripts/verification_execution.py',
              root / 'scripts/verification_contract_lease.py',
              root / 'scripts/completed_artifact_plan.py', *source_paths.values(),
              *programs.values()]
    sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    pins = dict(reference['inputHashes'])
    if args.managed_compiler:
        compiler = args.managed_compiler.resolve(strict=True)
        inputs += [compiler, *(compiler.with_suffix(suffix) for suffix in
                              ('.dll', '.deps.json', '.runtimeconfig.json'))]
        if any(pins.get(str(path)) != sha(path) for path in inputs[-4:]):
            raise ValueError('ALLOCATION_FAILURE_REFERENCE_COMPILER_MISMATCH')
    pins.update({str(path): sha(path) for path in inputs})
    stable = lambda: all(Path(path).is_file() and sha(path) == value
                         for path, value in pins.items())
    if not stable():
        raise ValueError('ALLOCATION_FAILURE_REFERENCE_INPUT_DRIFT')
    output = args.output.resolve()
    initialize_output(root, output, reusable_directories=args.reusable_compiler_directory)
    output.mkdir(parents=True, exist_ok=False)
    result = dict(schemaVersion=1, status='running', inputHashes=pins,
                  completed=0, total=len(cases), cases=[], controls=[], claimsGoalComplete=False)
    execution = VerificationExecution(root, output, result, stable, sha)
    error = None
    with VerificationContractLease([Path(path) for path in pins]):
        try:
            if args.managed_compiler:
                for program, source in source_paths.items():
                    folder = output / program
                    folder.mkdir()
                    executable = folder / 'source.exe'
                    run = execution.run([str(compiler), 'build', str(source), '-o',
                        str(executable), '--target', 'windows-x64', '--llvm', str(llvm_home),
                        '-O0', '--keep-temps'], folder / 'build', timeout=180)
                    if run.returncode or run.stderr.strip():
                        raise ValueError('ALLOCATION_FAILURE_SOURCE_BUILD_FAILED: ' + run.stderr)
                    programs[program] = Path(str(executable) + '.ll')
            for case in cases:
                started = time.monotonic()
                text = programs[case['program']].read_text(encoding='utf-8-sig')
                observe = lambda value: allocation_failure_binding(value, case['allocationBytes'],
                    case['sourceFunction'], diagnostic_code=case['diagnosticCode'])
                binding = observe(text)
                # Backend label movement must not change the semantic diagnostic.
                moved = text.replace(binding['failureBlock'], binding['failureBlock'] + '_moved')
                observe(moved)
                bad_guard = binding['condition'] + ' = icmp ne ptr ' + binding['testedPointer']
                mutants = [text.replace(bad_guard, bad_guard.replace('icmp ne', 'icmp eq'), 1),
                           text.replace('call void @llvm.trap()', ''),
                           text.replace(binding['encodedDiagnostic'], 'X' + binding['encodedDiagnostic'], 1)]
                for mutant in mutants:
                    try:
                        observe(mutant)
                    except ValueError:
                        continue
                    raise ValueError('ALLOCATION_FAILURE_MUTATION_ACCEPTED')
                result['controls'].append(dict(id=case['id'], completed=4, total=4))
                needle = f"call ptr @sollang_alloc(i64 {case['allocationBytes']})"
                changed = text.replace(needle,
                    f"call ptr @sollang_test_fail_alloc(i64 {case['allocationBytes']})")
                changed += '\ndefine internal ptr @sollang_test_fail_alloc(i64 %bytes) {\nentry:\n  ret ptr null\n}\n'
                if 'define dso_local i32 @sollang_start()' in changed:
                    changed += '\ndefine i32 @main() {\nentry:\n  %value = call i32 @sollang_start()\n  ret i32 %value\n}\n'
                folder = output / ('failure-' + case['id'])
                folder.mkdir()
                llvm, executable = folder / 'failure.ll', folder / 'failure.exe'
                llvm.write_bytes(changed.encode('utf-8'))
                run = execution.run([str(clang), '-Wno-override-module', str(llvm), '-O1',
                    '-o', str(executable), '-lws2_32', '-lshell32', '-lbcrypt', '-lole32'],
                    folder / 'link', timeout=180)
                if run.returncode or run.stderr.strip():
                    raise ValueError('ALLOCATION_FAILURE_LINK_FAILED: ' + run.stderr)
                run = execution.run([str(executable)], folder / 'run', timeout=180)
                passed = ((run.returncode & 0xffffffff) == 0xc000001d and
                          run.stderr == case['runStderr'] and run.stdout == case['stdout'])
                row = dict(id=case['id'], status='passed' if passed else 'failed', passed=passed,
                    sourceBinding=binding, buildExit=0, runExit=run.returncode,
                    expectedRuntimeExit=case['expectedRuntimeExit'],
                    runStdout=run.stdout, runStderr=run.stderr,
                    llvmInputSha256=sha(programs[case['program']]),
                    instrumentedLlvmSha256=sha(llvm), wallSeconds=round(time.monotonic()-started, 3))
                result['cases'].append(row)
                result['completed'] += int(passed)
                execution.save()
                if not passed:
                    raise ValueError('ALLOCATION_FAILURE_EXACT_DIAGNOSTIC_MISMATCH: ' + repr(row))
            result['status'] = 'passed'
        except BaseException as caught:
            error = caught
        finally:
            execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in
                     ('status', 'completed', 'total', 'inputsStable', 'processesStopped', 'failure')}))
    if error:
        raise error
    cleanup_output(root, output, execute=True,
                   reusable_directories=args.reusable_compiler_directory)


if __name__ == '__main__':
    main()
