"""Replay frozen C713 observations without a compiler binary or scratch output."""
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


def record(name, completed, total, status='passed'):
    data = read(E / 'records' / name / 'result.json')
    assert data['status'] == status and data['completed'] == completed and data['total'] == total, name
    assert data['inputsStable'] and data['processesStopped'], name
    return data


phase = sys.argv[1]
assert phase in ('baseline', 'candidate')
manifest = read(E / 'proof-inputs12859.json')
for path, digest in manifest['archiveHashes'].items():
    assert sha(E / path) == digest, path
for path, digest in manifest['languageInputHashes'].items():
    assert sha(ROOT / path) == digest, path

for name, passed in [('output12859-managed-before-helper', 19), ('output12844-native-before-helper', 23)]:
    data = record(name, passed, 31, 'failed')
    assert data['failure'].endswith('OUTPUT_WIDTH_OR_PROGRESS_ORACLE_FAILED')
    assert data['runExit'] == 0
    assert data['actual'][5] == '0:0:4294967296:1:0:0'
    assert data['expected'][5] == '0:0:4294967296:1:4294967296:0'

record('output12860-before-normal', 2, 2)
for backend in ('managed', 'native'):
    assert (E / 'records/output12860-before-normal' / (backend + '.stdout')).read_bytes() == 'stdout 한글🙂\n'.encode()
    assert (E / 'records/output12860-before-normal' / (backend + '.stderr')).read_bytes() == 'stderr 한글🙂\r\n'.encode()

before_managed = read(E / 'records/managed12799/inputs-after.json')
assert any(row['path'].replace('\\', '/').endswith('/CodeGen/WindowsLlvmRuntimePlatform.cs') and row['sha256'] == sha(E / 'WindowsLlvmRuntimePlatform-before.cs.txt') for row in before_managed['files'])
before_native = read(E / 'records/v12824/compiler-build01/result.json')
assert any(path.replace('\\', '/').endswith('/selfhost/llvm/emitter/text_output_runtime.slg') and digest == sha(E / 'text_output_runtime-before.slg.txt') for path, digest in before_native['inputHashesEnd'].items())
for folder, identity in [('output12834-before', 'A1DFF102778FA55AD62AE013E096F4B4AA6DDEAAD08055BCE193A9E5C0078E6B'), ('output12843-native-before', '31FABDDA072924547E04FC9CBB6B9E667AE3E73CDB6156006D8AA07060C561E5')]:
    build = read(E / 'records' / folder / 'streams.exe.compiler-build.json')
    assert build['status'] == 'passed' and build['inputsStable'] and build['processesStopped']
    assert identity in build['inputHashes'].values()
    assert build['llvmSha256'] == sha(E / 'records' / folder / 'streams.exe.ll')

if phase == 'candidate':
    q = read(E / 'qualification12859.json')
    assert q['focused'] == [165, 165] and not q['claimsGoalComplete']
    for path, digest in q['sourceHashes'].items():
        assert sha(ROOT / path) == digest == sha(E / 'qualified-source' / path), path
    managed = (ROOT / 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs').read_text(encoding='utf-8-sig')
    selfhost = (ROOT / 'selfhost/llvm/emitter/text_output_runtime.slg').read_text(encoding='utf-8-sig')
    verify_sources(managed, selfhost)
    for path in ['records/output12837-managed/streams.exe.ll', 'records/output12849-source/streams/emitted.ll', 'records/output12856-native/streams.exe.ll']:
        text = (E / path).read_text(encoding='utf-8-sig')
        for name in ['sollang_write_stream_chunk', 'sollang_write_stream']:
            assert body(managed, name) == body(text, name), path
    for name in ['output12840-managed-helper', 'output12851-source-helper', 'output12857-native-helper']:
        data = record(name, 31, 31)
        assert data['actual'] == data['expected'] and data['runExit'] == 0
        assert data['actual'][5] == '0:0:4294967296:1:4294967296:0'
        assert data['actual'][23] == '1:1:1048576:1:1048576:0'
        assert data['actual'][-3:] == ['failure2:0', 'failure3:0', 'failure4:0']
        assert any(Path(path).name == 'api-substitutes.c' and digest == sha(E / 'records' / name / 'api-substitutes.c') for path, digest in data['inputHashes'].items())
    for name in ['output12841-console', 'output12852-source-console', 'output12858-native-console']:
        data = record(name, 23, 23)
        assert data['actual'] == data['expected'] and data['runExit'] == 0
        assert data['actual'][4] == '4:0:1:1:1' and data['actual'][14] == '6:1:1:1:1'
    for name in ['output12850-runtime', 'output12856-native']:
        record(name, 1, 1)
    normal = read(E / 'records/output12837-managed/normal.json')
    assert normal['exitCode'] == 0
    out = 'stdout 한글🙂\n'.encode()
    err = 'stderr 한글🙂\r\n'.encode()
    for prefix in ['records/output12837-managed/normal.execution.json', 'records/output12850-runtime/streams-run', 'records/output12856-native/normal']:
        stdout_suffix = '.stdout.log' if prefix.endswith('.json') else '.stdout'
        stderr_suffix = '.stderr.log' if prefix.endswith('.json') else '.stderr'
        assert (E / (prefix + stdout_suffix)).read_bytes() == out
        assert (E / (prefix + stderr_suffix)).read_bytes() == err
    record('output12846-preflight', 4, 4)
    stdlib = record('output12847-stdlib', 1, 1)
    assert stdlib['fullStdlibSourceCount'] == 144 and stdlib['checkedSemanticDiagnosticCount'] == 0
    build = read(E / 'records/v12855/compiler-build01/result.json')
    assert build['status'] == 'passed' and build['inputsStable']
    assert build['compilerSha256'] == q['nativeCompilerSha256']
    assert build['steps'] == {'semanticPreflight': 0, 'build': 0, 'llvmAs': 0, 'v004': 0, 'parallelCallbacks': 0}
    for backend in ['managed', 'source']:
        aggregate = read(E / 'records' / ('output12853-managed.json' if backend == 'managed' else 'output12854-source.json'))
        assert aggregate['status'] == 'passed' and aggregate['completed'] == aggregate['total'] == 55
        assert aggregate['inputsStable'] and aggregate['processesStopped']

print(json.dumps({'status': 'passed', 'phase': phase, 'beforeFailures': {'CSharp': 12, 'SLG': 8}, 'candidateFocused': [165, 165] if phase == 'candidate' else None, 'claimsGoalComplete': False}))
