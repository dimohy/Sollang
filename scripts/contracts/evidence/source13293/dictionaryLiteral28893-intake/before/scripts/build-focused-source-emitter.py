"""Build one source emitter after focused CSharp and canonical semantic proof."""
from pathlib import Path
import argparse
import hashlib
import json

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def managed_reference_inputs(record_path, root=ROOT):
    """Admit canonical proofs or the existing synchronous formatter producer."""
    record_path = Path(record_path)
    record = json.loads(record_path.read_text(encoding='utf-8-sig'))
    if record.get('status') != 'passed' or record.get('inputsStable') is not True:
        raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_FAILED')
    if 'inputHashes' in record:
        if (type(record.get('completed')) is not int or record['completed'] <= 0
                or type(record.get('total')) is not int
                or record['completed'] != record.get('total')
                or record.get('processesStopped') is not True):
            raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_INCOMPLETE')
        hashes = record['inputHashes']
    elif record.get('phase') == 'managed-first':
        # This producer waits for each direct formatter process with subprocess.run.
        # Validate its actual pinned contract/oracles rather than inventing counts.
        hashes = record.get('inputHashesStart')
        if not hashes or hashes != record.get('inputHashesEnd'):
            raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_INPUT_CHANGED')
        producer = Path(root) / 'scripts/verify-managed-first-fixture.py'
        contract_path = Path(record['contract'])
        if str(producer.resolve()) not in hashes or str(contract_path) not in hashes:
            raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_PRODUCER_MISSING')
        contract = json.loads(contract_path.read_text(encoding='utf-8-sig'))
        cases, rows = contract.get('cases'), record.get('cases')
        if (contract.get('schemaVersion') != 1 or not isinstance(cases, list)
                or not cases or not isinstance(rows, list) or len(cases) != len(rows)
                or len({case['id'] for case in cases}) != len(cases)):
            raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_CASES_INVALID')
        for case, row in zip(cases, rows):
            source = record_path.parent / (case['id'] + '.slg')
            if (case.get('mode') != 'format-stdin' or row.get('id') != case['id']
                    or row.get('passed') is not True
                    or row.get('observed') != case.get('expected')
                    or str(source.resolve()) not in hashes
                    or hashes.get(str(source.resolve()), '').upper() != row.get('sourceSha256')
                    or row.get('sourceSha256') != hashlib.sha256(
                        case['source'].encode('utf-8')).hexdigest().upper()):
                raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_ORACLE_MISMATCH')
    else:
        raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_UNSUPPORTED')
    if not isinstance(hashes, dict) or not hashes or any(
            not Path(path).is_file() or sha(path) != digest.upper()
            for path, digest in hashes.items()):
        raise ValueError('SOURCE_EMITTER_MANAGED_PROOF_INPUT_CHANGED')
    return record, list(map(Path, hashes))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('compiler', 'output', 'semantic-result', 'source-comparison'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--cli', action='store_true', help='Build the canonical native CLI entrypoint instead of the emitter probe')
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    comparison = json.loads(args.source_comparison.read_text(encoding='utf-8'))
    budget = comparison['sourceEmitterBudget']
    assert output == (ROOT / budget['output']).resolve()
    assert budget['maximumBuilds'] == 1 and budget['timeoutSeconds'] == 180
    assert not output.exists(), 'SOURCE_EMITTER_BUILD_BUDGET_ALREADY_USED'
    reference_path = ROOT / comparison['csharpFirst']
    reference, reference_inputs = managed_reference_inputs(reference_path)
    semantic = json.loads(args.semantic_result.read_text(encoding='utf-8'))
    preflight_paths = [ROOT / name for name in comparison.get('requiredNativePreflights', [])]
    preflight_inputs = []
    for preflight_path in preflight_paths:
        preflight = json.loads(preflight_path.read_text(encoding='utf-8'))
        assert preflight['status'] == 'passed' and preflight['completed'] == preflight['total'] > 0, 'SOURCE_EMITTER_NATIVE_PREFLIGHT_FAILED'
        assert preflight['inputsStable'] and preflight['processesStopped'], 'SOURCE_EMITTER_NATIVE_PREFLIGHT_INCOMPLETE'
        assert all(sha(path) == value for path, value in preflight['inputHashes'].items()), 'SOURCE_EMITTER_NATIVE_PREFLIGHT_INPUT_CHANGED'
        preflight_inputs.extend(map(Path, preflight['inputHashes']))
    assert semantic['status'] == 'passed' and semantic['completed'] == semantic['total']
    assert semantic['inputsStable'] and semantic['processesStopped']
    assert semantic['total'] == 4
    manifest = ROOT / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
    sources = [ROOT / line for line in manifest.read_text(encoding='utf-8-sig').splitlines()
               if line and not line.endswith('selfhost-sollangc-driver.slg')]
    for source in [manifest, *sources]:
        assert semantic['inputHashes'][str(source.resolve())] == sha(source)
    wrapper = ROOT / 'scripts/probes/codegen-unit-stream/emitter.slg'
    support = [wrapper.with_name('registry_context.slg'), wrapper.with_name('registry_root.slg'), wrapper.with_name('registry_uses.slg'), wrapper.with_name('registry_universe.slg')]
    if args.cli:
        wrapper = manifest.with_name('selfhost-sollangc-driver.slg')
        support = []
    llvm = ROOT / '.tools/llvm-22.1.8'
    assert (llvm / 'bin/clang.exe').is_file() and (llvm / 'bin/llvm-as.exe').is_file()
    paths = [Path(__file__), compiler, *managed_runtime_inputs(compiler), args.semantic_result,
             *preflight_paths, *preflight_inputs, *reference_inputs,
             args.source_comparison, reference_path, manifest, wrapper, *support, *sources,
             *sorted((ROOT / 'stdlib').rglob('*.slg'))]
    inputs = {str(path.resolve()): sha(path) for path in paths}
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    product = output / ('compiler.exe' if args.cli else 'emitter.exe')
    def fingerprint(hashes):
        data = dict(inputs=hashes, optimization='O2', jobs=24, target='windows-x64')
        return hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':')).encode()).hexdigest().upper()
    with VerificationContractLease(list(map(Path, inputs))):
        result = dict(schemaVersion=1, status='running', completed=0, total=1,
                      inputHashes=inputs, claimsGoalComplete=False,
                      scope='Current source emitter for pending focused consumers; no Stage or cache reuse claim.')
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in inputs.items()), sha)
        error = None
        try:
            done = execution.run([str(compiler), 'build', str(wrapper), *map(str, support), *map(str, sources),
                                  '-o', str(product), '--target', 'windows-x64',
                                  '--llvm', str(llvm), '--jobs', '24', '-O2'],
                                 output / 'build', timeout=budget['timeoutSeconds'])
            assert done.returncode == 0 and not done.stderr, done.stdout[-2000:] + done.stderr
            if args.cli:
                final_inputs = {path: sha(Path(path)) for path in inputs}
                assert final_inputs == inputs, 'COMPILER_SOURCE_INPUT_CHANGED'
                result.update(compilerSha256=sha(product), inputHashesStart=inputs,
                              inputHashesEnd=final_inputs, inputFingerprint=fingerprint(inputs),
                              finalInputFingerprint=fingerprint(final_inputs),
                              inputFingerprintKind='sha256-canonical-input-json-v1',
                              compilerProduct=str(product))
            result.update(status='passed', completed=1,
                          cases=[dict(id='current-source-emitter-build', passed=True)])
        except BaseException as exc:
            error = exc
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
