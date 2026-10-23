"""Replay frozen C715 observations; this does not execute a compiler again."""
from pathlib import Path
import hashlib
import json
import sys

sys.dont_write_bytecode = True
from source_guard import tracker, verify

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
manifest = read(E / 'proof-inputs12924.json')
for path, digest in manifest['archiveHashes'].items():
    assert sha(E / path) == digest, path
for path, digest in manifest['languageInputHashes'].items():
    assert sha(ROOT / path) == digest, path

for name in ['environment12898-tracker-before', 'environment12917-native-before-tracker']:
    before = result(name, 0, 1, 'failed')
    assert before['failure'].endswith('ENVIRONMENT_CONCURRENT_OWNERSHIP_FAILED')
    fields = dict(part.split('=') for part in before['actual'].split())
    assert fields['accepted'] == '8192' and 0 < int(fields['retained']) < 8192
    assert fields['nodes'] == fields['payloads'] == fields['retained'] and fields['errors'] == '0'
    assert before['runExit'] == 1
old_managed = (E / 'WindowsLlvmRuntimePlatform-before.cs.txt').read_text(encoding='utf-8-sig')
old_source = (E / 'environment_runtime-before.slg.txt').read_text(encoding='utf-8-sig')
assert tracker(old_managed) == tracker(old_source) and 'cmpxchg' not in tracker(old_managed)
for folder, compiler in [('environment12897-parallel-managed', 'CD46C2EE7B244A8B30B1151005A157A05D9E4720310ADB676B1FE3D81FF14AFE'),
                         ('environment12916-native-before', '988B064ABB0E4B1366C76D550ECCC009AE5B17BD2C90E7BED471B474DA95897F')]:
    build = read(E / 'records' / folder / 'environment.exe.compiler-build.json')
    assert build['status'] == 'passed' and build['inputsStable'] and build['processesStopped']
    assert compiler in build['inputHashes'].values()
    llvm = E / 'records' / folder / 'environment.exe.ll'
    assert build['llvmSha256'] == sha(llvm)
    assert tracker(llvm.read_text(encoding='utf-8-sig')) == tracker(old_managed)

if phase == 'candidate':
    qualification = read(E / 'qualification12924.json')
    assert qualification['focused'] == [81, 81] and not qualification['claimsGoalComplete']
    for path, digest in qualification['sourceHashes'].items():
        assert sha(ROOT / path) == digest == sha(E / 'qualified-source' / path), path
    managed = (ROOT / 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs').read_text(encoding='utf-8-sig')
    selfhost = (ROOT / 'selfhost/llvm/emitter/environment_runtime.slg').read_text(encoding='utf-8-sig')
    verify(managed, selfhost)
    for folder, llvm in [('environment12900-parallel-managed', 'environment.exe.ll'),
                         ('environment12907-source/parallel64', 'emitted.ll'),
                         ('environment12919-native-parallel', 'environment.exe.ll')]:
        assert tracker(managed) == tracker((E / 'records' / folder / llvm).read_text(encoding='utf-8-sig'))
    for name in ['environment12901-tracker-managed', 'environment12910-source-tracker', 'environment12920-native-tracker']:
        data = result(name, 1, 1)
        assert data['actual'] == 'accepted=8192 retained=8192 nodes=8192 payloads=8192 errors=0'
    for name in ['environment12902-result-managed', 'environment12909-source-result', 'environment12921-native-result']:
        data = result(name, 24, 24)
        assert data['actual'] == data['expected'] and data['runExit'] == 0
    for name in ['environment12913-managed-programs', 'environment12922-native-programs']:
        result(name, 2, 2)
    result('environment12908-runtime', 2, 2)
    native = read(E / 'records/v12915/compiler-build01/result.json')
    assert native['status'] == 'passed' and native['inputsStable']
    completion = read(E / 'records/v12915/compiler-build01/artifact-cleanup-plan.json.execution.json')
    assert completion['status'] == 'completed'
    assert completion['completionDispositions'][0]['disposition'] == 'verified-complete'
    assert all(value == 0 for value in native['steps'].values())
    assert native['compilerSha256'] == qualification['nativeCompilerSha256']
    native_inputs = native['inputHashesEnd']
    assert any(path.replace('\\', '/').endswith('/selfhost/llvm/emitter/environment_runtime.slg')
               and digest == sha(ROOT / 'selfhost/llvm/emitter/environment_runtime.slg')
               for path, digest in native_inputs.items())
print('C715 ' + phase + ' frozen observations verified; original final gates remain pending.')
