"""Replay C716/C717 frozen observations without executing another compiler."""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
from source_guard import verify

E = Path(__file__).resolve().parent
ROOT = E.parents[3]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def result(name, completed, total, status='passed'):
    data = read(E / 'records' / name / 'result.json')
    assert data['status'] == status and data['completed'] == completed and data['total'] == total, name
    assert data['inputsStable'] and data['processesStopped'], name
    return data


phase = sys.argv[1]
assert phase in ('baseline', 'candidate')
manifest = read(E / 'proof-inputs12976.json')
for path, digest in manifest['archiveHashes'].items():
    assert sha(E / path) == digest, path
for path, digest in manifest['languageInputHashes'].items():
    assert sha(ROOT / path) == digest, path

before = result('reference12929-admission', 1, 10, 'failed')
assert before['cases'][0]['id'] == 'field-named-read'
assert before['cases'][0]['native']['exit'] == 1
assert "defined with type 'ptr' but expected '%sollang.struct" in before['cases'][0]['native']['stderr']
assert ' = freeze ptr ' in (E / 'records/reference12929-admission/.l0.ll').read_text(encoding='utf-8-sig')
later = result('reference12940-native', 1, 5, 'failed')
assert later['cases'][0]['status'] == 'passed' and later['cases'][0]['stdout'] == 'true\n' * 4
assert later['cases'][1]['id'] == 'field-value-input'
assert "defined with type 'ptr' but expected '%sollang.struct" in later['cases'][1]['native']['stderr']
prefix = result('reference12948-source', 3, 5, 'failed')
assert prefix['failure'].startswith('ValueError: NEGATIVE_ADMISSION_FAILED field-value-input')
assert "function 'sys.directory.create' expects" in prefix['failure']

location = result('reference12961-source', 5, 7, 'failed')
assert 'direct-runtime-reference' in location['failure'] and '19:5' in location['failure']
if phase == 'candidate':
    q = read(E / 'qualification12976.json')
    assert q['focused'] == [21, 21] and not q['claimsGoalComplete']
    for path, digest in q['sourceHashes'].items():
        assert sha(ROOT / path) == digest == sha(E / 'qualified-source' / path), path
    verify(*[(ROOT / name).read_text(encoding='utf-8-sig') for name in [
        'selfhost/llvm/text/call_arguments.slg', 'selfhost/llvm/text/function_expressions.slg',
        'selfhost/semantic/diagnostics.slg', 'selfhost/llvm/emitter/diagnostics.slg']])
    managed = result('reference12930-managed', 5, 5)['cases']
    managed += result('reference12956-managed-controls', 2, 2)['cases']
    expected = {row['id']: row for row in managed}
    assert len(expected) == 7
    native = result('reference12975-native', 7, 7)
    assert set(expected) == {row['id'] for row in native['cases']}
    for row in native['cases']:
        oracle = expected[row['id']]
        assert row['status'] == 'passed'
        if oracle.get('expectedRejected'):
            assert row['native']['exit'] == 1
            assert row['native']['stderr'] == oracle['diagnostic']
        else:
            assert row['native']['exit'] == row['runExit'] == 0 and row['stdout'] == 'true\n' * 4
    source = result('reference12972-source', 7, 7)
    assert set(expected) == {row['id'] for row in source['cases']}
    for row in source['cases']:
        oracle = expected[row['id']]
        if oracle.get('expectedRejected'):
            assert row['admissionRejected'] and row['emissionExit'] == 1
            stdout = (E / 'records/reference12972-source' / row['id'] / 'emit.stdout').read_text(encoding='utf-8-sig')
            assert stdout == oracle['diagnostic'] and 'target triple =' not in stdout
        else:
            assert row['emissionExit'] == row['assemblyExit'] == 0
    runtime = result('reference12973-runtime', 3, 3)
    for row in runtime['cases']:
        assert row['nativeLinkExit'] == row['nativeRunExit'] == 0 and row['stdout'] == 'true\n' * 4
    build = read(E / 'records/v12974/compiler-build01/result.json')
    assert build['status'] == 'passed' and build['inputsStable']
    assert build['steps'] == {'semanticPreflight': 0, 'build': 0, 'llvmAs': 0, 'v004': 0, 'parallelCallbacks': 0}
    assert build['compilerSha256'] == q['nativeCompilerSha256']
    for path in ['selfhost/llvm/text/call_arguments.slg', 'selfhost/llvm/text/function_expressions.slg',
                 'selfhost/semantic/diagnostics.slg', 'selfhost/llvm/emitter/diagnostics.slg']:
        assert any(name.replace('\\', '/').endswith('/' + path) and digest == sha(ROOT / path)
                   for name, digest in build['inputHashesEnd'].items()), path
    result('reference12969-preflight', 4, 4)
    stdlib = result('reference12970-stdlib', 1, 1)
    assert stdlib['fullStdlibSourceCount'] == 144 and stdlib['checkedSemanticDiagnosticCount'] == 0
print('C716/C717 ' + phase + ' observations verified; final whole-goal gates remain pending.')
