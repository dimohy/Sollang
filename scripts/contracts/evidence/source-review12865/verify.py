"""Replay frozen C714 helper, entry-witness and normal-program observations."""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
from source_guard import body, verify as verify_sources

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
manifest = read(E / 'proof-inputs12890.json')
for path, digest in manifest['archiveHashes'].items():
    assert sha(E / path) == digest, path
for path, digest in manifest['languageInputHashes'].items():
    assert sha(ROOT / path) == digest, path

for name in ('environment12872-before-helper', 'environment12875-native-before-helper'):
    data = result(name, 16, 24, 'failed')
    assert data['runExit'] == 0 and data['failure'].endswith('ENVIRONMENT_RESULT_OR_ENTRY_DOMAIN_ORACLE_FAILED')
    assert data['actual'][3] == 'body:3:1:1:0:1:1:1'
    assert data['expected'][3] == 'body:3:0:0:0:1:1:1'
    assert data['actual'][-2] == 'entry:4294967299:1'
    assert data['expected'][-2] == 'entry:4294967299:2'

old_managed = read(E / 'records/managed12836/inputs-after.json')
assert any(row['path'].replace('\\', '/').endswith('/CodeGen/WindowsLlvmRuntimePlatform.cs') and row['sha256'] == sha(E / 'WindowsLlvmRuntimePlatform-before.cs.txt') for row in old_managed['files'])
old_native = read(E / 'records/v12855/compiler-build01/result.json')
assert any(path.replace('\\', '/').endswith('/selfhost/llvm/emitter/environment_runtime.slg') and digest == sha(E / 'environment_runtime-before.slg.txt') for path, digest in old_native['inputHashesEnd'].items())
for folder, identity in [('environment12866-before', '43BD6F07B8FABC546336D36353B3E9529985654AF150FB820275D034955A9750'), ('environment12874-native-before', 'F655097C46491F9C78F591E9F86B13AEF48DE03E57143FFE7CC21B6EFE5AC095')]:
    build = read(E / 'records' / folder / 'environment.exe.compiler-build.json')
    assert build['status'] == 'passed' and build['inputsStable'] and build['processesStopped']
    assert identity in build['inputHashes'].values()
    assert build['llvmSha256'] == sha(E / 'records' / folder / 'environment.exe.ll')

if phase == 'candidate':
    q = read(E / 'qualification12890.json')
    assert q['focused'] == [75, 75] and not q['claimsGoalComplete']
    for path, digest in q['sourceHashes'].items():
        assert sha(ROOT / path) == digest == sha(E / 'qualified-source' / path), path
    managed = (ROOT / 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs').read_text(encoding='utf-8-sig')
    selfhost = (ROOT / 'selfhost/llvm/emitter/environment_runtime.slg').read_text(encoding='utf-8-sig')
    verify_sources(managed, selfhost)
    for path in ['records/environment12870-managed/environment.exe.ll', 'records/environment12880-source/environment84/emitted.ll', 'records/environment12888-native/environment.exe.ll']:
        assert body(managed) == body((E / path).read_text(encoding='utf-8-sig')), path
    for name in ['environment12871-managed-helper', 'environment12882-source-helper', 'environment12889-native-helper']:
        data = result(name, 24, 24)
        assert data['actual'] == data['expected'] and data['runExit'] == 0
        assert data['actual'][3] == 'body:3:0:0:0:1:1:1'
        assert data['actual'][5] == 'body:5:0:1:0:1:1:2'
        assert data['actual'][7] == 'body:7:1:1:0:1:1:2'
        assert data['actual'][-2] == 'entry:4294967299:2'
        entry = (E / 'records' / name / 'production-entry.ll.txt').read_text(encoding='utf-8-sig')
        assert '%name_fits_i32 = icmp ule i64 %name_len, 2147483647' in entry
        assert entry.strip() in body(managed)
    want = (ROOT / 'examples/regression/expected/84-process-environment.stdout.txt').read_text(encoding='utf-8-sig').encode()
    for name, prefix in [('environment12873-managed-normal', 'normal'), ('environment12881-runtime', 'environment84-run'), ('environment12888-native', 'normal')]:
        data = result(name, 1, 1)
        assert (E / 'records' / name / (prefix + '.stdout')).read_bytes() == want
        assert (E / 'records' / name / (prefix + '.stderr')).read_bytes() == b''
    result('environment12877-preflight', 4, 4)
    stdlib = result('environment12878-stdlib', 1, 1)
    assert stdlib['fullStdlibSourceCount'] == 144 and stdlib['checkedSemanticDiagnosticCount'] == 0
    build = read(E / 'records/v12885/compiler-build01/result.json')
    assert build['status'] == 'passed' and build['inputsStable'] and build['compilerSha256'] == q['nativeCompilerSha256']
    assert build['steps'] == {'semanticPreflight': 0, 'build': 0, 'llvmAs': 0, 'v004': 0, 'parallelCallbacks': 0}

print(json.dumps({'status': 'passed', 'phase': phase, 'beforeFailuresPerBackend': [8, 24], 'candidateFocused': [75, 75] if phase == 'candidate' else None, 'claimsGoalComplete': False}))
