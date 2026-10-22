from pathlib import Path
import hashlib, json, re

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / 'artifacts/scratch/resume-20261006-owner-continuation22'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def verify():
    contract = read(ROOT / 'scripts/contracts/parallel-ownership-closure-controls.json')
    records = [read(BASE / p / 'result.json') for p in [
        'ownership12479-managed', 'ownership12482-source', 'ownership12483-runtime']]
    for record in records:
        assert record['status'] == 'passed'
        assert record['completed'] == record['total'] == 20
        assert record['inputsStable'] and record['processesStopped']
        for path, expected in record['inputHashes'].items():
            assert sha(Path(path)) == expected, path
    assert sha(BASE / 'managed12478/compiler/Sollang.Compiler.dll') == contract['expectedManagedDllSha256']
    assert sha(BASE / 'ownership12482-source/producer.exe') == records[1]['producerSha256']
    assert len(contract['cases']) == 20
    for expected, managed, source, runtime in zip(contract['cases'], *(r['cases'] for r in records)):
        assert expected['id'] == managed['id'] == source['id'] == runtime['id']
        for actual in [managed, runtime]:
            assert actual['passed'] and actual['runExit'] == expected['exit']
            for stream in ['stdout', 'stderr']:
                assert actual[stream].replace('\r\n', '\n') == expected[stream]
        assert source['status'] == 'passed' and source['emissionExit'] == source['assemblyExit'] == 0
        path = BASE / 'ownership12482-source' / source['id'] / 'emitted.ll'
        assert sha(path) == source['emittedLlvmSha256']
        llvm = path.read_text(encoding='utf-8-sig')
        if expected['id'].startswith('compound-'):
            assert re.search(r'^tryparallel[0-9]+_sequential_header:', llvm, re.M)
            assert not re.search(r'^  call void @sollang_compute_execute', llvm, re.M)
    # Inspect the complete callback block, including selected value, store,
    # retained-field extraction, typed drop, and loop continuation.
    observations = {}
    for case in ['callback-field', 'callback-nested-field', 'callback-retained']:
        llvm = (BASE / 'ownership12482-source' / case / 'emitted.ll').read_text(encoding='utf-8-sig')
        block = re.search(r'^parallel[0-9]+_body:\n(.*?)(?=^parallel[0-9]+_exit:)', llvm, re.M | re.S).group(1)
        after_store = block[block.index('  store %sollang.array.i32 %v'):]
        drops = re.findall(r'call void @sollang_drop_t[0-9]+\(%sollang.array.i32 (%[A-Za-z0-9_]+)\)', after_store)
        assert len(drops) == 1, (case, drops)
        assert '_mapped' not in drops[0]
        if case != 'callback-retained':
            retained = drops[0]
            assert re.search(re.escape(retained) + r' = extractvalue .*?, 1\n', after_store)
            selected = re.findall(r'(%dropg[0-9]+_p[0-9]+) = extractvalue .*?, 0\n', after_store)
            assert selected and all(value not in drops for value in selected)
        observations[case] = block
    return records, observations

if __name__ == '__main__':
    verify()
    print('Current CSharp20, SLG source assembly20 and runtime20 passed; retained local/direct-field/nested-field cleanup paths checked. Fresh native and runtime allocation accounting remain unverified.')
