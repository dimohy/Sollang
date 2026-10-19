"""Classify paired format preflight failures before compiling a derived fixture.

Reuse VerificationExecution for immutable input pins and process shutdown. This
probe can be removed when the canonical formatter parity command owns this gate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def classify(managed, native):
    if managed.returncode or managed.stderr.strip():
        return 'FORMAT_PREFLIGHT_MANAGED_NOT_CANONICAL'
    if native.returncode or native.stderr.strip():
        if 'appendSource:bb_source_text_byte_bounds_fail' in native.stderr:
            return 'FORMAT_PREFLIGHT_NATIVE_SOURCE_BOUNDS'
        return 'FORMAT_PREFLIGHT_NATIVE_MISMATCH'
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contract', type=Path, required=True)
    parser.add_argument('--native-build', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    contract_path = args.contract.resolve()
    contract = json.loads(contract_path.read_text(encoding='utf-8-sig'))
    names = contract.get('formatCheckSources')
    declared = {case['source'] for case in contract['cases']}
    if not names or len(set(names)) != len(names) or any(name not in declared for name in names):
        raise ValueError('FORMAT_PAIR_SOURCE_CONTRACT_INVALID')
    sources = [(ROOT / name).resolve() for name in names]
    if any(not path.is_relative_to(ROOT) or not path.is_file() for path in sources):
        raise ValueError('FORMAT_PAIR_SOURCE_MISSING')
    build_path = args.native_build.resolve() / 'result.json'
    build = json.loads(build_path.read_text(encoding='utf-8-sig'))
    build_inputs = current_build_inputs(ROOT, build)
    native = build_path.parent / 'compiler.exe'
    if sha(native) != build['compilerSha256']:
        raise ValueError('FORMAT_PAIR_NATIVE_BINARY_CHANGED')
    managed = ROOT / 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe'
    output = args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('FORMAT_PAIR_FRESH_OUTPUT_REQUIRED')
    inputs = list(dict.fromkeys([Path(__file__).resolve(), contract_path, *sources,
                                build_path, native, *build_inputs, *managed_runtime_inputs(managed)]))
    pins = {str(path): sha(path) for path in inputs}
    stable = lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in inputs)
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    result = dict(schemaVersion=1, status='running', inputHashes=pins, total=1,
                  completed=0, codegenInvoked=False, sourceCount=len(sources),
                  scope='Paired formatter preflight only; no compiler behavior acceptance')
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        first = runner.run([str(managed), 'format', '--check', *map(str, sources)], output / 'managed-format', 60)
        if first.returncode or first.stderr.strip():
            raise ValueError('FORMAT_PREFLIGHT_MANAGED_NOT_CANONICAL')
        second = runner.run([str(native), 'format', '--check', *map(str, sources)], output / 'native-format', 60)
        failure = classify(first, second)
        result['failureId'] = failure
        result['managedCanonical'] = True
        result['nativeCanonical'] = failure is None
        if failure:
            raise ValueError(failure)
        result.update(status='passed', completed=1)
    except BaseException as exc:
        error = exc
        result.setdefault('failureId', str(exc))
        raise
    finally:
        runner.finalize(error)


if __name__ == '__main__':
    main()
