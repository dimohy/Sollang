from pathlib import Path
import importlib.util, re

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('source_proof', HERE / 'verify-source12517.py')
source_proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_proof)
BASE = source_proof.BASE

def verify():
    source_proof.verify()
    read, sha = source_proof.read, source_proof.sha
    native = read(BASE / 'native12518-qualification/result.json')
    assert native['status'] == 'passed' and native['completed'] == native['total'] == 29
    source_proof.stable(native)
    compiler = BASE / 'v12515/compiler-build01/compiler.exe'
    build = read(compiler.parent / 'result.json')
    assert build['status'] == 'passed' and build['inputsStable']
    assert build['inputHashesStart'] == build['inputHashesEnd']
    assert sha(compiler) == build['compilerSha256'] == native['compilerSha256']
    assert native['compilerSha256'] == 'A923B33CEB78B59C2C796D7D847BCF9F6CB26EB9B615CC458E18BA89EC172A98'
    controls = read(BASE / 'source12511-contract.json')['cases']
    managed_admission = read(BASE / 'sourceboundary12501/result.json')['cases']
    assert {row['id'] for row in native['cases']} == {row['id'] for row in controls}
    llvm_by_id = {}
    for row in native['cases']:
        expected = next(case for case in controls if case['id'] == row['id'])
        assert row['status'] == 'passed' and row['passed']
        record = read(BASE / 'native12518-qualification' / (row['id'] + '.exe.compiler-build.json'))
        source_proof.stable(record)
        assert row['buildExit'] == row['expectedBuildExit']
        if expected.get('admitted') is False:
            assert row['admissionRejected'] and row['buildExit'] == 1
            managed = next(case for case in managed_admission if 'source-text-' + case['id'] == row['id'])
            assert (row['stdout'] + row['stderr']).strip() == managed['stderr'].strip()
        else:
            assert row['buildExit'] == row['runExit'] == row['expectedRuntimeExit'] == 0
            for stream in ['stdout', 'stderr']:
                assert row[stream].replace('\r\n', '\n') == expected[stream]
            path = BASE / 'native12518-qualification' / (row['id'] + '.exe.ll')
            assert sha(path) == record['llvmSha256']
            llvm_by_id[row['id']] = path.read_text(encoding='utf-8-sig')
    blocks = {}
    for case in ['callback-field', 'callback-nested-field', 'callback-retained']:
        block = re.search(r'^parallel[0-9]+_body:\n(.*?)(?=^parallel[0-9]+_exit:)', llvm_by_id[case], re.M | re.S).group(1)
        tail = block[block.index('  store %sollang.array.i32 %v'):]
        drops = re.findall(r'call void @sollang_drop_t[0-9]+\(%sollang.array.i32 (%[A-Za-z0-9_]+)\)', tail)
        assert len(drops) == 1 and '_mapped' not in drops[0]
        if case != 'callback-retained':
            assert re.search(re.escape(drops[0]) + r' = extractvalue .*?, 1\n', tail)
            selected = re.findall(r'(%dropg[0-9]+_p[0-9]+) = extractvalue .*?, 0\n', tail)
            assert selected and all(value not in drops for value in selected)
        blocks[case] = block
    block = re.search(r'^tryparallel[0-9]+_sequential_body:\n(.*?)(?=^tryparallel[0-9]+_sequential_next:)', llvm_by_id['callback-try-local'], re.M | re.S).group(1)
    assert '_mapped = freeze %sollang.enum.' in block and 'store %sollang.enum.' in block
    assert 'call void @sollang_drop_' not in block
    blocks['callback-try-local'] = block
    for case, llvm in llvm_by_id.items():
        if case.startswith('compound-'):
            assert re.search(r'^tryparallel[0-9]+_sequential_header:', llvm, re.M)
            assert not re.search(r'^  call void @sollang_compute_execute', llvm, re.M)
        if case in ['recursive-original', 'success', 'first-error', 'empty', 'ordered', 'function', 'region', 'source-text-direct-result', 'source-text-direct-error']:
            assert re.search(r'^  call void @sollang_compute_execute', llvm, re.M)
    llvm = llvm_by_id['recursive-original']
    cleanup = re.search(r'^tryparallel[0-9]+_cleanup_ok:\n(.*?)(?=^[A-Za-z0-9_]+:)', llvm, re.M | re.S).group(1)
    array_type = re.search(r'call void @sollang_drop_t([0-9]+)\(', cleanup).group(1)
    def drop_body(type_id):
        return re.search(r'^define internal void @sollang_drop_t' + type_id + r'\([^\n]*\) \{\n.*?^\}', llvm, re.M | re.S).group(0)
    array = drop_body(array_type)
    box_type = re.search(r'call void @sollang_drop_t([0-9]+)\(ptr %element\)', array).group(1)
    box = drop_body(box_type)
    assert 'call void @free(ptr %data)' in array and 'call void @free(ptr %value)' in box
    blocks['discarded-array-to-box'] = cleanup + array + box
    return native, blocks

if __name__ == '__main__':
    verify()
    print('Fresh canonical native29 matches CSharp29 and current source29, including exact six diagnostics and23 normal outputs. Actual LLVM preserves returned ownership, drops retained siblings and recursively drops discarded array/box payloads. Final gates and runtime allocation accounting are not claimed.')
