"""Run exact emitted lifecycle bodies with deterministic OS/worker boundaries.

This is a focused ownership-order test, not a terminal or OS scheduler test.
The input modules and successful public build record are mandatory and pinned.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

from completed_artifact_plan import initialize_output
from verification_execution import VerificationExecution


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def function(module, name):
    matches = re.findall(r'^define[^\n]*@' + re.escape(name) + r'\([^\n]*\{\n.*?^}', module, re.M | re.S)
    if len(matches) != 1:
        raise ValueError('EXACT_EMITTED_FUNCTION_REQUIRED: ' + name)
    return matches[0].replace(' #0', '')


COUNTERS = '''
@freed = internal global i32 0
@bad = internal global i32 0
@joined = internal global i32 0
@signals = internal global i32 0
@closed = internal global i32 0
define internal void @increment(ptr %counter) {
  %n = load i32, ptr %counter
  %next = add i32 %n, 1
  store i32 %next, ptr %counter
  ret void
}
define internal void @require(i1 %ok) {
  %failed = xor i1 %ok, true
  %n = zext i1 %failed to i32
  %old = load i32, ptr @bad
  %sum = add i32 %old, %n
  store i32 %sum, ptr @bad
  ret void
}
define internal void @sollang_free(ptr %allocation) {
  call void @increment(ptr @freed)
  ret void
}
define internal void @free(ptr %allocation) {
  call void @sollang_free(ptr %allocation)
  ret void
}
declare void @llvm.trap()
'''


def mouse_module(module, platform, closed, retirement):
    next_body = function(module, 'sollang_mouse_event_next_raw')
    drop_body = function(module, 'sollang_mouse_event_stream_drop')
    two_phase = ', i1 ' in drop_body.splitlines()[0]
    def drop(context, destroy):
        mode = ', i1 ' + ('true' if destroy else 'false') if two_phase else ''
        return f'  call void @sollang_mouse_event_stream_drop(ptr {context}{mode})\n'
    if retirement:
        if two_phase:
            # Cancel at the last instruction boundary before returning. The
            # caller's worker borrow still exists until the callback returns.
            next_body, n = re.subn(r'(?m)^(  ret i1 (?:true|false))$', lambda m: drop('%context', False) + m[0], next_body)
        else:
            # Same retiring boundary in the previous active-reader design.
            next_body, n = re.subn(r'(?m)^(  %active_before_(?:value|closed)_return = atomicrmw sub[^\n]*\n)', lambda m: m[0] + drop('%context', False), next_body)
        if n != 2:
            raise ValueError('RETIREMENT_BOUNDARY_NOT_UNIQUE')
    windows = platform == 'windows'
    count_offset, cancel_offset = (28, 32) if windows else (16, 20)
    buffer_offset = 56 if windows else 40
    capacity_offset = 12 if windows else 0
    stubs = COUNTERS + '''
@ctx = internal global [80 x i8] zeroinitializer, align 8
@buffer = internal global [40 x i8] zeroinitializer, align 8
@original = internal global [128 x i8] zeroinitializer, align 8
'''
    if windows:
        stubs += '''
@cancel_calls = internal global i32 0
@worker_waits = internal global i32 0
define internal i32 @SetEvent(ptr %event) {
  %n = load i32, ptr @closed
  %live = icmp eq i32 %n, 0
  call void @require(i1 %live)
  call void @increment(ptr @signals)
  ret i32 1
}
define internal i32 @CancelSynchronousIo(ptr %thread) {
  call void @increment(ptr @cancel_calls)
  ret i32 1
}
define internal i32 @WaitForSingleObject(ptr %handle, i32 %timeout) {
  %thread = icmp eq ptr %handle, inttoptr(i64 3 to ptr)
  br i1 %thread, label %worker, label %event
worker:
  %infinite = icmp eq i32 %timeout, -1
  br i1 %infinite, label %legacy_worker_finished, label %timed_worker_wait
legacy_worker_finished:
  call void @increment(ptr @joined)
  ret i32 0
timed_worker_wait:
  call void @increment(ptr @worker_waits)
  %waits = load i32, ptr @worker_waits
  %first = icmp eq i32 %waits, 1
  br i1 %first, label %entered_io_after_cancel, label %finish
entered_io_after_cancel:
  ret i32 258
finish:
  %cancels = load i32, ptr @cancel_calls
  %retried = icmp uge i32 %cancels, 3
  call void @require(i1 %retried)
  call void @increment(ptr @joined)
  ret i32 0
event:
  ret i32 0
}
define internal i32 @CloseHandle(ptr %handle) {
  %event = icmp eq ptr %handle, inttoptr(i64 4 to ptr)
  br i1 %event, label %close_event, label %done
close_event:
  call void @increment(ptr @closed)
  br label %done
done:
  ret i32 1
}
define internal i32 @SetConsoleMode(ptr %input, i32 %mode) { ret i32 1 }
'''
        setup = '''
  %thread = getelementptr i8, ptr @ctx, i64 40
  store ptr inttoptr(i64 3 to ptr), ptr %thread
  %event = getelementptr i8, ptr @ctx, i64 48
  store ptr inttoptr(i64 4 to ptr), ptr %event
'''
        free_count = 2
        signal_body = ''
    else:
        signal_body = function(module, 'sollang_linux_mouse_signal')
        stubs += '''
@sollang_mouse_disable = internal global [16 x i8] zeroinitializer
define internal i64 @write(i32 %fd, ptr %bytes, i64 %length) {
  call void @increment(ptr @signals)
  ret i64 %length
}
define internal i64 @read(i32 %fd, ptr %bytes, i64 %length) { ret i64 %length }
define internal i32 @pthread_join(i64 %thread, ptr %result) {
  call void @increment(ptr @joined)
  ret i32 0
}
define internal i32 @tcsetattr(i32 %fd, i32 %mode, ptr %state) { ret i32 0 }
define internal i32 @close(i32 %fd) {
  call void @increment(ptr @closed)
  ret i32 0
}
'''
        setup = '''
  %thread = getelementptr i8, ptr @ctx, i64 32
  store i64 3, ptr %thread
  %event = getelementptr i8, ptr @ctx, i64 28
  store i32 4, ptr %event
  %original = getelementptr i8, ptr @ctx, i64 48
  store ptr @original, ptr %original
'''
        free_count = 3
    # Cancel-only must neither join nor free. Final destruction follows return.
    after_next = '''
  %early_frees = load i32, ptr @freed
  %not_freed = icmp eq i32 %early_frees, 0
  call void @require(i1 %not_freed)
  %early_joins = load i32, ptr @joined
  %not_joined = icmp eq i32 %early_joins, 0
  call void @require(i1 %not_joined)
'''
    stubs += f'''
define i32 @main() {{
  %capacity = getelementptr i8, ptr @ctx, i64 {capacity_offset}
  store i32 2, ptr %capacity
  %count = getelementptr i8, ptr @ctx, i64 {count_offset}
  store i32 {0 if closed else 1}, ptr %count
  %cancel = getelementptr i8, ptr @ctx, i64 {cancel_offset}
  store atomic i32 {1 if closed else 0}, ptr %cancel release, align 4
  %buffer = getelementptr i8, ptr @ctx, i64 {buffer_offset}
  store ptr @buffer, ptr %buffer
{setup}
  %values = alloca [5 x i32], align 4
  %y = getelementptr i8, ptr %values, i64 4
  %delta = getelementptr i8, ptr %values, i64 8
  %button = getelementptr i8, ptr %values, i64 12
  %kind = getelementptr i8, ptr %values, i64 16
  %value = call i1 @sollang_mouse_event_next_raw(ptr @ctx, ptr %values, ptr %y, ptr %delta, ptr %button, ptr %kind)
  %value_ok = icmp eq i1 %value, {'false' if closed else 'true'}
  call void @require(i1 %value_ok)
{after_next}
{drop('@ctx', True)}
  %frees = load i32, ptr @freed
  %exact_free = icmp eq i32 %frees, {free_count}
  call void @require(i1 %exact_free)
  %joins = load i32, ptr @joined
  %exact_join = icmp eq i32 %joins, 1
  call void @require(i1 %exact_join)
  %closes = load i32, ptr @closed
  %exact_close = icmp eq i32 %closes, 1
  call void @require(i1 %exact_close)
  %bad = load i32, ptr @bad
  %ok = icmp eq i32 %bad, 0
  %exit = select i1 %ok, i32 0, i32 17
  ret i32 %exit
}}
'''
    return '\n'.join([next_body, drop_body, signal_body, stubs])


def join_module(module, cancel_only):
    names = re.findall(r'^define[^\n]*@(sollang_(?:stream_join_\d+|join_\d+)_drop)\(', module, re.M)
    if len(names) != 1:
        raise ValueError('EXACT_SINGLE_MOUSE_JOIN_REQUIRED')
    name = names[0]
    body = function(module, name)
    context_types = re.findall(r'^%sollang\.join\.\d+ = type \{[^\n]+\}', module, re.M)
    if len(context_types) > 1:
        raise ValueError('EXACT_SINGLE_MOUSE_JOIN_CONTEXT_REQUIRED')
    two_phase = ', i1 ' in body.splitlines()[0]
    mode = ', i1 ' + ('false' if cancel_only else 'true') if two_phase else ''
    signature = ', i1 %destroy' if two_phase else ''
    branch = 'br i1 %destroy, label %destroy_input, label %cancel_input' if two_phase else 'br label %destroy_input'
    return '%sollang.event_stream = type { ptr, ptr, ptr }\n' + '\n'.join(context_types) + '\n' + body + '\n' + COUNTERS + f'''
@ctx = internal global {{ %sollang.event_stream, %sollang.event_stream, ptr }} {{
  %sollang.event_stream {{ ptr inttoptr(i64 1 to ptr), ptr null, ptr @input_lifecycle }},
  %sollang.event_stream {{ ptr inttoptr(i64 2 to ptr), ptr null, ptr @input_lifecycle }},
  ptr null
}}
@cancelled_inputs = internal global i32 0
@destroyed_inputs = internal global i32 0
define internal void @sollang_stream_join_runtime_cancel(ptr %runtime) {{ ret void }}
define internal void @sollang_stream_join_runtime_join_destroy(ptr %runtime) {{
  %destroyed = load i32, ptr @destroyed_inputs
  %still_live = icmp eq i32 %destroyed, 0
  call void @require(i1 %still_live)
  %cancelled = load i32, ptr @cancelled_inputs
  %all_cancelled = icmp eq i32 %cancelled, 2
  call void @require(i1 %all_cancelled)
  call void @increment(ptr @joined)
  ret void
}}
define internal void @input_lifecycle(ptr %input{signature}) {{
  {branch}
cancel_input:
  call void @increment(ptr @cancelled_inputs)
  ret void
destroy_input:
  %joins = load i32, ptr @joined
  %quiescent = icmp eq i32 %joins, 1
  call void @require(i1 %quiescent)
  call void @increment(ptr @destroyed_inputs)
  ret void
}}
define i32 @main() {{
  call void @{name}(ptr @ctx{mode})
  %cancelled = load i32, ptr @cancelled_inputs
  %cancel_ok = icmp eq i32 %cancelled, 2
  call void @require(i1 %cancel_ok)
  %frees = load i32, ptr @freed
  %free_ok = icmp eq i32 %frees, {0 if cancel_only else 1}
  call void @require(i1 %free_ok)
  %joins = load i32, ptr @joined
  %join_ok = icmp eq i32 %joins, {0 if cancel_only else 1}
  call void @require(i1 %join_ok)
  %drops = load i32, ptr @destroyed_inputs
  %drop_ok = icmp eq i32 %drops, {0 if cancel_only else 2}
  call void @require(i1 %drop_ok)
  %bad = load i32, ptr @bad
  %ok = icmp eq i32 %bad, 0
  %exit = select i1 %ok, i32 0, i32 17
  ret i32 %exit
}}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--proof', type=Path, required=True)
    parser.add_argument('--windows-module', type=Path, required=True)
    parser.add_argument('--linux-module', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expect', choices=['pass', 'reproduce'], required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    modules = {platform: path.resolve() for platform, path in [('windows', args.windows_module), ('linux', args.linux_module)]}
    proof = json.loads(args.proof.read_text(encoding='utf-8-sig'))
    if proof.get('status') != 'passed' or not proof.get('inputsStable') or not proof.get('processesStopped'):
        raise ValueError('SUCCESSFUL_STABLE_PUBLIC_BUILD_REQUIRED')
    for path in modules.values():
        if proof['generatedOutputHashes'].get(str(path)) != sha(path):
            raise ValueError('PUBLIC_MODULE_HASH_MISMATCH: ' + str(path))
    clang = repo / '.tools/llvm-22.1.8/bin/clang.exe'
    inputs = [args.proof.resolve(), *modules.values(), Path(__file__).resolve(), clang]
    pins = {str(path): sha(path) for path in inputs}
    # Construct every case before any process starts: unsupported emitted shapes
    # fail before compilation or runtime cost.
    cases = []
    for platform, path in modules.items():
        module = path.read_text(encoding='utf-8-sig')
        for closed in [False, True]:
            for retirement in [False, True]:
                name = platform + '-' + ('closed' if closed else 'value') + ('-cancel-at-return' if retirement else '-normal')
                cases.append((name, mouse_module(module, platform, closed, retirement)))
        for cancel_only in [False, True]:
            cases.append((platform + '-join-' + ('cancel' if cancel_only else 'destroy'), join_module(module, cancel_only)))
    initialize_output(repo, args.output)
    args.output.mkdir(exist_ok=False)
    result = dict(schemaVersion=1, status='running', inputHashes=pins, completed=0, total=len(cases), cases=[], scope=__doc__.strip())
    execution = VerificationExecution(repo, args.output, result, lambda: all(sha(path) == expected for path, expected in pins.items()), sha)
    error = None
    try:
        for name, llvm in cases:
            source = args.output / (name + '.ll')
            source.write_text(llvm, encoding='utf-8', newline='\n')
            exe = args.output / (name + '.exe')
            linked = execution.run([str(clang), '-Werror', '-Wno-override-module', str(source), '-O1', '-o', str(exe)], args.output / (name + '-link'), timeout=30)
            row = dict(id=name, buildExit=linked.returncode)
            result['cases'].append(row)
            if linked.returncode != 0 or linked.stderr.strip():
                raise ValueError(linked.stderr)
            run = execution.run([str(exe)], args.output / (name + '-run'), timeout=5)
            row.update(runExit=run.returncode, passed=run.returncode == 0, expectedRuntimeExit=0)
            if run.returncode not in (0, 17):
                raise ValueError('UNEXPECTED_RUNTIME_FAILURE: ' + str(row))
            result['completed'] += 1
            execution.save()
        failures = [row['id'] for row in result['cases'] if not row['passed']]
        result['runtimeContractSatisfied'] = not failures
        if args.expect == 'pass' and failures:
            raise ValueError('LIFECYCLE_CONTRACT_FAILED: ' + str(failures))
        if args.expect == 'reproduce' and not failures:
            raise ValueError('BASELINE_FAILED_TO_REPRODUCE')
        result['status'] = 'passed' if not failures else 'reproduced'
    except Exception as ex:
        error = ex
        raise
    finally:
        execution.finalize(error=error)
    print(json.dumps({key: result[key] for key in ['status', 'completed', 'total', 'runtimeContractSatisfied', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
