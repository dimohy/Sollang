from pathlib import Path
import hashlib, json, re

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def stable(record):
    assert record['inputsStable'] and record['processesStopped']
    for path, expected in record['inputHashes'].items():
        assert sha(Path(path)) == expected, path

def check_boundary_llvm(llvm_by_id):
    assert re.search(r'_last, label %stream[0-9]+_exit, label %stream[0-9]+_header', llvm_by_id['range-maximum-map'])
    assert re.search(r'_inner_last, label %stream[0-9]+_inner_exit, label %stream[0-9]+_inner_header', llvm_by_id['range-flatmap-maximum'])
    assert re.search(r'_inner_last, label %stream[0-9]+_after_each, label %stream[0-9]+_inner_header', llvm_by_id['range-flatmap-phases'])
    assert re.search(r'_taken_done, label %stream[0-9]+_exit, label %stream[0-9]+_range_continue', llvm_by_id['range-flatmap-phases'])
    for case in ['uint32-display','uint32-function','uint32-region','uint32-reference','integer-display-controls']:
        llvm=llvm_by_id[case]
        assert re.search(r'%v[0-9]+_runtime_integer = zext i32 .*? to i64',llvm),case
        assert re.search(r'call void @sollang_runtime_print_i64\(i64 %v[0-9]+_runtime_integer, i1 false, i1 true\)',llvm),case
    assert re.search(r'_runtime_reference_value = load i32',llvm_by_id['uint32-reference'])

def verify_boundaries(controls, source, runtime):
    extra=read(ROOT/'scripts/contracts/evidence/C2026-10-23-694/csharp12530.json')
    assert extra['status']=='passed' and extra['completed']==extra['total']==11 and extra['processesStopped']
    assert extra['compilerSha256']=='3C5518BB1763BDB5D4B046B57376FF07E4F5056EA08B0CF9A63AB633EF88B1D5'
    for case in extra['cases']:
        assert sha(ROOT/case['source'])==case['sourceSha256']
        expected=next(c for c in controls if c['id']==case['id'])
        assert expected['stdout']==case['stdout'] and expected['stderr']==case['stderr'] and expected['exit']==case['exit']==0
        folder=ROOT/'scripts/contracts/evidence/C2026-10-23-694/csharp12530'/case['id']
        stable(read(folder/(case['id']+'.exe.compiler-build.json')))
        execution=read(folder/(case['id']+'.execution.json'))
        assert execution['status']=='passed' and execution['exit']==0 and execution['processesStopped']
    comparison=read(ROOT/'scripts/contracts/evidence/C2026-10-23-694/source-comparison12534.json')
    for row in comparison['sources']:assert sha(ROOT/row['path'])==row['currentSha256']
    check_boundary_llvm({case['id']:(BASE/'source12530-source'/case['id']/'emitted.ll').read_text(encoding='utf-8-sig') for case in extra['cases']})

def verify():
    controls = read(BASE / 'source12530-contract.json')['cases']
    source = read(BASE / 'source12530-source/result.json')
    runtime = read(BASE / 'source12531-runtime/result.json')
    managed = read(BASE / 'ownership12500-managed/result.json')
    admission = read(BASE / 'sourceboundary12501/result.json')
    for record, count in [(source, 40), (runtime, 34), (managed, 21)]:
        assert record['status'] == 'passed' and record['completed'] == record['total'] == count
        stable(record)
    assert admission['status'] == 'passed' and admission['completed'] == admission['total'] == 8
    dll = BASE / 'managed12499/compiler/Sollang.Compiler.dll'
    assert sha(dll) == admission['compilerDllSha256'] == '3C5518BB1763BDB5D4B046B57376FF07E4F5056EA08B0CF9A63AB633EF88B1D5'
    assert sha(BASE / 'source12530-source/producer.exe') == source['producerSha256']
    assert len(controls) == len(source['cases']) == 40
    assert len({row['id'] for row in controls}) == 40
    for expected, actual in zip(controls, source['cases']):
        assert expected['id'] == actual['id'] and actual['status'] == 'passed'
        folder = BASE / 'source12530-source' / actual['id']
        if expected.get('admitted') is False:
            assert actual['emissionExit'] == 1 and actual['admissionRejected']
            text = (folder / 'emit.stdout').read_text(encoding='utf-8-sig')
            assert text.count('parallel callback SourceText is supported only as a direct top-level tryParallel Result payload') == 1
            assert 'target triple =' not in text and not (folder / 'emitted.ll').exists()
        else:
            assert actual['emissionExit'] == actual['assemblyExit'] == 0
            assert sha(folder / 'emitted.ll') == actual['emittedLlvmSha256']
            executed = next(row for row in runtime['cases'] if row['id'] == actual['id'])
            assert executed['passed'] and executed['runExit'] == expected['exit']
            for stream in ['stdout', 'stderr']:
                assert executed[stream].replace('\r\n', '\n') == expected[stream]
    for row in admission['cases']:
        assert row['passed'] and sha(Path(row['source'])) == row['sourceSha256']
        build = read(BASE / 'sourceboundary12501' / (row['id'] + '.exe.compiler-build.json'))
        stable(build)
        expected = next(case for case in controls if case['id'] == 'source-text-' + row['id'])
        if expected['admitted']:
            assert row['exit'] == row['runExit'] == 0
            assert row['runStdout'].replace('\r\n', '\n') == expected['stdout'] and not row['runStderr']
        else:
            assert row['exit'] == 1 and row['stderr'].count('parallel callback SourceText is supported only as a direct top-level tryParallel Result payload') == 1
            diagnostic = (BASE / 'source12530-source' / expected['id'] / 'emit.stdout').read_text(encoding='utf-8-sig')
            assert diagnostic.strip() == row['stderr'].strip()
    for row in managed['cases']:
        expected = next(case for case in controls if case['id'] == row['id'])
        assert row['passed'] and row['runExit'] == expected['exit']
        for stream in ['stdout', 'stderr']:
            assert row[stream].replace('\r\n', '\n') == expected[stream]
    blocks = {}
    for case in ['callback-field', 'callback-nested-field', 'callback-retained']:
        llvm = (BASE / 'source12530-source' / case / 'emitted.ll').read_text(encoding='utf-8-sig')
        block = re.search(r'^parallel[0-9]+_body:\n(.*?)(?=^parallel[0-9]+_exit:)', llvm, re.M | re.S).group(1)
        tail = block[block.index('  store %sollang.array.i32 %v'):]
        drops = re.findall(r'call void @sollang_drop_t[0-9]+\(%sollang.array.i32 (%[A-Za-z0-9_]+)\)', tail)
        assert len(drops) == 1 and '_mapped' not in drops[0]
        if case != 'callback-retained':
            assert re.search(re.escape(drops[0]) + r' = extractvalue .*?, 1\n', tail)
            selected = re.findall(r'(%dropg[0-9]+_p[0-9]+) = extractvalue .*?, 0\n', tail)
            assert selected and all(value not in drops for value in selected)
        blocks[case] = block
    llvm = (BASE / 'source12530-source/callback-try-local/emitted.ll').read_text(encoding='utf-8-sig')
    block = re.search(r'^tryparallel[0-9]+_sequential_body:\n(.*?)(?=^tryparallel[0-9]+_sequential_next:)', llvm, re.M | re.S).group(1)
    assert '_mapped = freeze %sollang.enum.' in block and 'store %sollang.enum.' in block
    assert 'call void @sollang_drop_' not in block
    blocks['callback-try-local'] = block
    verify_boundaries(controls, source, runtime)
    return source, runtime, blocks

if __name__ == '__main__':
    verify()
    print('CSharp ownership21/admission8 and current SLG source40/runtime34 and CSharp11 boundary controls pass with full input closures; retained-only direct/nested/local cleanup and named Result transfer checked in actual LLVM. Fresh native/final gates remain pending.')
