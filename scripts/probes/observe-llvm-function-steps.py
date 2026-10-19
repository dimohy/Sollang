"""Observe an emitted function's propagation steps in a pinned LLVM copy."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from completed_artifact_plan import initialize_output
from verification_execution import VerificationExecution


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llvm', type=Path, required=True)
    parser.add_argument('--symbol', required=True)
    parser.add_argument('--expected-steps', type=int, required=True)
    parser.add_argument('--branch-label', action='append', default=[])
    parser.add_argument('--compare-slice', action='append', default=[],
                        help='Compare a 32-byte slice argument between calls; print equality only')
    parser.add_argument('--source-proof', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source, proof, output = args.llvm.resolve(), args.source_proof.resolve(), args.output.resolve()
    if not re.fullmatch(r'sollang_m\d+_s\d+', args.symbol):
        raise ValueError('LLVM_STEP_SYMBOL_INVALID')
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('LLVM_STEP_FRESH_OUTPUT_REQUIRED')
    text = source.read_text(encoding='utf-8')
    triples = re.findall(r'^target triple = "([^"]+)"$', text, re.M)
    if len(triples) != 1:
        raise ValueError('LLVM_STEP_TARGET_NOT_UNIQUE')
    if 'define internal void @sollang_runtime_print_i32(i32 %value, i1 %newline)' not in text:
        raise ValueError('LLVM_STEP_PRINT_ABI_MISSING')
    pattern = re.compile(r'^define [^\n]*@' + re.escape(args.symbol) + r'\([^\n]*\)[^\n]*\{\n(?P<body>.*?)^\}', re.M | re.S)
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise ValueError('LLVM_STEP_FUNCTION_NOT_UNIQUE')
    match = matches[0]
    body = match.group('body')
    helpers = []
    comparisons = []
    for index, argument in enumerate(args.compare_slice):
        if (not re.fullmatch(r'arg\d*', argument) or args.compare_slice.count(argument) != 1
                or not re.search(r'\{ ptr, i64 \} %' + re.escape(argument) + r'(?=,|\))', match[0].split('\n', 1)[0])):
            raise ValueError('LLVM_STEP_SLICE_ABI_INVALID')
        helper = 'sollang_observed_slice_' + str(index)
        comparisons.append(f'  %observed_slice_{index} = call i32 @{helper}({{ ptr, i64 }} %{argument})\n'
                           + f'  call void @sollang_runtime_print_i32(i32 {9200 + index}, i1 true)\n'
                           + f'  call void @sollang_runtime_print_i32(i32 %observed_slice_{index}, i1 true)\n')
        code = [f'@{helper}_seen = private global i1 false',
                f'@{helper}_capture = private global [32 x i8] zeroinitializer',
                f'define internal i32 @{helper}({{ ptr, i64 }} %slice) {{', 'entry:',
                '  %data = extractvalue { ptr, i64 } %slice, 0',
                '  %length = extractvalue { ptr, i64 } %slice, 1',
                '  %valid = icmp eq i64 %length, 32',
                '  br i1 %valid, label %ready, label %invalid', 'invalid:', '  ret i32 3', 'ready:',
                f'  %seen = load i1, ptr @{helper}_seen',
                '  br i1 %seen, label %compare, label %capture', 'capture:',
                f'  call void @llvm.memcpy.p0.p0.i64(ptr @{helper}_capture, ptr %data, i64 32, i1 false)',
                f'  store i1 true, ptr @{helper}_seen', '  ret i32 2', 'compare:']
        for byte in range(32):
            code += [f'  %left{byte} = getelementptr i8, ptr %data, i64 {byte}',
                     f'  %right{byte} = getelementptr i8, ptr @{helper}_capture, i64 {byte}',
                     f'  %a{byte} = load i8, ptr %left{byte}', f'  %b{byte} = load i8, ptr %right{byte}',
                     f'  %x{byte} = xor i8 %a{byte}, %b{byte}',
                     f'  %difference{byte} = or i8 ' + ('0' if byte == 0 else f'%difference{byte - 1}') + f', %x{byte}']
        code += ['  %same = icmp eq i8 %difference31, 0', '  %answer = zext i1 %same to i32',
                 '  ret i32 %answer', '}']
        helpers.append('\n'.join(code))
    if comparisons:
        body = body.replace('entry:\n', 'entry:\n' + ''.join(comparisons), 1)
    labels = re.findall(r'^(try\d+_ok):', body, re.M)
    if len(labels) != args.expected_steps or len(set(labels)) != len(labels):
        raise ValueError('LLVM_STEP_LABEL_CONTRACT_CHANGED')
    for label in args.branch_label:
        if not re.fullmatch(r'[A-Za-z0-9_]+', label) or body.count(label + ':\n') != 1 or label in labels:
            raise ValueError('LLVM_STEP_BRANCH_LABEL_INVALID')
    labels += args.branch_label
    entries = re.findall(r'^entry:', body, re.M)
    if len(entries) != 1:
        raise ValueError('LLVM_STEP_ENTRY_NOT_UNIQUE')
    plan = [dict(marker=9000, label='entry')]
    plan += [dict(marker=9001 + i, label=label) for i, label in enumerate(labels)]
    for step in plan:
        body = body.replace(step['label'] + ':\n', step['label'] + ':\n'
                            + f"  call void @sollang_runtime_print_i32(i32 {step['marker']}, i1 true)\n", 1)
    patched = text[:match.start('body')] + body + text[match.end('body'):]
    if helpers:
        patched += '\n' + '\n\n'.join(helpers) + '\n'
    tools = [ROOT / '.tools/llvm-22.1.8/bin' / name for name in ('llvm-as.exe', 'clang.exe')]
    inputs = [source, proof, Path(__file__).resolve(), ROOT / 'scripts/verification_execution.py', *tools]
    if any(not path.is_file() for path in inputs):
        raise ValueError('LLVM_STEP_INPUT_MISSING')
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    derived = output / 'observed.ll'
    derived.write_bytes(patched.encode('utf-8'))
    manifest = output / 'step-plan.json'
    manifest.write_text(json.dumps(dict(symbol=args.symbol, original=str(source), originalSha256=sha(source),
                                        steps=plan, sliceComparisons=args.compare_slice,
                                        comparisonCodes={'capture': 2, 'equal': 1, 'different': 0, 'wrongLength': 3}), indent=2) + '\n', encoding='utf-8')
    inputs += [derived, manifest]
    pins = {str(path): sha(path) for path in inputs}
    stable = lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in inputs)
    result = dict(schemaVersion=1, status='running', inputHashes=pins,
                  scope='Auxiliary instrumented LLVM observation; no production acceptance', symbol=args.symbol)
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        commands = [([str(tools[0]), str(derived), '-o', str(output / 'observed.bc')], 'assemble'),
                    # Match the canonical paired fixture runner's Windows LLVM link contract.
                    ([str(tools[1]), '-Wno-override-module', '-target', triples[0], '-O1', str(derived),
                      '-o', str(output / 'observed.exe'), '-lws2_32', '-lshell32', '-lbcrypt'], 'link'),
                    ([str(output / 'observed.exe')], 'run')]
        for command, name in commands:
            run = runner.run(command, output / name, 180)
            if run.returncode or run.stderr.strip():
                raise ValueError('LLVM_STEP_' + name.upper() + '_FAILED')
        observed = [int(line) for line in run.stdout.splitlines() if line.isdigit() and 9000 <= int(line) < 9000 + len(plan)]
        result.update(status='observed', stdout=run.stdout, observedMarkers=observed)
        print(json.dumps(dict(status=result['status'], observedMarkers=observed, stdout=run.stdout)))
    except BaseException as exc:
        error = exc
        raise
    finally:
        runner.finalize(error)


if __name__ == '__main__':
    main()
