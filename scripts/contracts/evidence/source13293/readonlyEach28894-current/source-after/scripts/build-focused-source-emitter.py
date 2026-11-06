"""Build one source emitter after focused CSharp and canonical semantic proof."""
from pathlib import Path
import argparse
import hashlib
import json
import importlib.util

from completed_artifact_plan import initialize_output, assert_build_space
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_step_diagnostics import SlowStepDiagnostics

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def diagnostics_plans(path, separated, budget):
    if path is None:
        return {}
    configuration = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    expected = ({'emit': budget['emissionTimeoutSeconds'], 'grammar': 30,
                 'link': budget['linkTimeoutSeconds']} if separated
                else {'build': budget['timeoutSeconds']})
    if (not isinstance(configuration, dict) or set(configuration) != {'schemaVersion', 'phases'}
            or configuration['schemaVersion'] != 1 or not isinstance(configuration['phases'], dict)
            or set(configuration['phases']) != set(expected)):
        raise ValueError('SOURCE_BUILD_DIAGNOSTICS_PHASES_INVALID')
    for phase, timeout in expected.items():
        if SlowStepDiagnostics(configuration['phases'][phase]).hard_timeout_seconds != timeout:
            raise ValueError('SOURCE_BUILD_DIAGNOSTICS_TIMEOUT_MISMATCH: ' + phase)
    return configuration['phases']


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
    parser.add_argument('--separate-llvm-phases', type=Path,
                        help='Explicit bridge build proof for separately budgeted emission and production linking')
    parser.add_argument('--checked-package-contract', type=Path,
                        help='Validated reusable checked producer instead of the canonical CLI or stream probe')
    parser.add_argument('--diagnostics-plan', type=Path,
                        help='Explicit phase sampling plans; hard deadlines must match the selected build mode')
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    comparison = json.loads(args.source_comparison.read_text(encoding='utf-8'))
    separated = args.separate_llvm_phases is not None
    budget = comparison['separatedSourceBuildBudget' if separated else 'sourceEmitterBudget']
    assert output == (ROOT / budget['output']).resolve()
    assert budget['maximumBuilds'] == 1
    if separated:
        assert comparison['status'] == 'compared-before-slg-edit'
        assert budget['emissionTimeoutSeconds'] == 180 and budget['linkTimeoutSeconds'] == 240
    else:
        assert budget['timeoutSeconds'] == 180
    assert not args.checked_package_contract or (separated and not args.cli), 'CHECKED_SOURCE_BUILD_MODE_INVALID'
    assert not output.exists(), 'SOURCE_EMITTER_BUILD_BUDGET_ALREADY_USED'
    phase_plans = diagnostics_plans(args.diagnostics_plan, separated, budget)
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
    optimization = '-O2'
    bridge = None
    bridge_inputs = []
    if separated:
        bridge_record = json.loads(args.separate_llvm_phases.read_text(encoding='utf-8-sig'))
        assert (bridge_record['status'] == 'passed' and bridge_record['completed'] == bridge_record['total'] == 1
                and bridge_record['inputsStable'] and bridge_record['processesStopped']), 'SOURCE_EMISSION_BRIDGE_PROOF_INVALID'
        bridge = Path(bridge_record['bridgeProduct'])
        assert sha(bridge) == bridge_record['bridgeSha256'], 'SOURCE_EMISSION_BRIDGE_CHANGED'
        assert all(sha(path) == value for path, value in bridge_record['inputHashes'].items()), 'SOURCE_EMISSION_BRIDGE_INPUT_CHANGED'
        bridge_inputs = [args.separate_llvm_phases, *managed_runtime_inputs(bridge),
                         *map(Path, bridge_record['inputHashes'])]
    if args.checked_package_contract:
        checked = json.loads(args.checked_package_contract.read_text(encoding='utf-8-sig'))
        validator_path = ROOT / 'scripts/verify-checked-package-emitter.py'
        spec = importlib.util.spec_from_file_location('source_build_checked_validator', validator_path)
        validator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(validator)
        validator.validate_reusable(checked, ROOT)
        group = checked['reusableCheckedProducer']
        assert [ROOT / path for path in group['additionalSources']] == sources, 'CHECKED_SOURCE_BUILD_CANONICAL_CLOSURE_CHANGED'
        assert checked['harnessBuildOptimization'] == '-O1' and checked['harnessBuildJobs'] == 24
        wrapper, support = ROOT / group['source'], []
        optimization = '-O1'
        bridge_inputs += [args.checked_package_contract, validator_path, ROOT / 'scripts/generate-selection-result-emitter.py']
    llvm = ROOT / '.tools/llvm-22.1.8'
    assert (llvm / 'bin/clang.exe').is_file() and (llvm / 'bin/llvm-as.exe').is_file()
    paths = [Path(__file__), compiler, *managed_runtime_inputs(compiler), args.semantic_result,
             *preflight_paths, *preflight_inputs, *reference_inputs,
             args.source_comparison, reference_path, manifest, wrapper, *support, *sources,
             *sorted((ROOT / 'stdlib').rglob('*.slg')), *bridge_inputs,
             ROOT / 'scripts/verification_step_diagnostics.py',
             *([] if args.diagnostics_plan is None else [args.diagnostics_plan.resolve()]),
             *[llvm / 'bin' / name for name in ('llvm-as.exe', 'clang.exe', 'lld-link.exe', 'llvm-lib.exe', 'opt.exe', 'llc.exe', 'llvm-link.exe')]]
    inputs = {str(path.resolve()): sha(path) for path in paths}
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    product = output / ('compiler.exe' if args.cli else 'producer.exe' if args.checked_package_contract else 'emitter.exe')
    if separated:
        source_paths = [wrapper, *support, *sources]
        source_inputs = [*source_paths, *sorted((ROOT / 'stdlib').rglob('*.slg'))]
        emission_manifest = output / 'emission-inputs.json'
        emission_manifest.write_text(json.dumps(dict(schemaVersion=1, target='windows-x64',
            outputKind='executable', sourcePaths=list(map(str, source_paths)),
            inputHashes={str(path): inputs[str(path.resolve())] for path in source_inputs}), indent=2), encoding='utf-8')
        inputs[str(emission_manifest)] = sha(emission_manifest)
    def fingerprint(hashes):
        data = dict(inputs=hashes, optimization=optimization.removeprefix('-'), jobs=24, target='windows-x64')
        return hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':')).encode()).hexdigest().upper()
    with VerificationContractLease(list(map(Path, inputs))):
        result = dict(schemaVersion=1, status='running', completed=0, total=1,
                      inputHashes=inputs, claimsGoalComplete=False,
                      scope='Current source emitter for pending focused consumers; no Stage or cache reuse claim.')
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in inputs.items()), sha)
        def diagnostics(phase):
            return (SlowStepDiagnostics(phase_plans[phase], output / (phase + '.diagnostics.json'))
                    if phase in phase_plans else None)
        error = None
        try:
            assert_build_space(output)
            if separated:
                llvm_output = output / 'program.ll'
                done = execution.run(['dotnet', str(bridge), 'emit', str(compiler.with_suffix('.dll')),
                    sha(compiler.with_suffix('.dll')), str(emission_manifest), str(llvm_output)],
                    output / 'emit', timeout=budget['emissionTimeoutSeconds'], diagnostics=diagnostics('emit'))
                assert done.returncode == 0 and not done.stderr, done.stdout[-2000:] + done.stderr
                emission = json.loads(done.stdout)
                assert (emission['status'] == 'passed' and emission['warnings'] == []
                        and emission['outputSha256'] == sha(llvm_output)), 'SOURCE_EMISSION_RESULT_INVALID'
                grammar = execution.run([str(llvm / 'bin/llvm-as.exe'), str(llvm_output), '-o', str(output / 'program.bc')],
                                        output / 'grammar', timeout=30, diagnostics=diagnostics('grammar'))
                assert grammar.returncode == 0 and not grammar.stderr, grammar.stderr
                work = output / '.slg-tmp'
                work.mkdir()
                done = execution.run(['dotnet', str(bridge), 'link', str(compiler.with_suffix('.dll')),
                    sha(compiler.with_suffix('.dll')), str(llvm), str(llvm_output), str(product), str(work),
                    optimization, '24'], output / 'link', timeout=budget['linkTimeoutSeconds'], diagnostics=diagnostics('link'))
                assert done.returncode == 0 and not done.stderr, done.stdout[-2000:] + done.stderr
                lines = done.stdout.strip().splitlines()
                assert lines[:-1] == [f'[native {i}/24] optimized partition' for i in range(1, 25)], 'SOURCE_LINK_PARTITION_OUTPUT_INVALID'
                link_result = json.loads(lines[-1])
                assert (link_result['status'] == 'passed' and link_result['mode'] == 'link'
                        and link_result['optimization'] == optimization and link_result['maximumWorkers'] == 24
                        and link_result['compilerAssemblySha256'] == sha(compiler.with_suffix('.dll'))), 'SOURCE_LINK_RESULT_INVALID'
                result.update(phaseMode='explicit-separated-emission-and-production-link',
                              emission=emission, link=link_result, originalCombinedBudgetPassed=False)
            else:
                done = execution.run([str(compiler), 'build', str(wrapper), *map(str, support), *map(str, sources),
                                      '-o', str(product), '--target', 'windows-x64',
                                      '--llvm', str(llvm), '--jobs', '24', optimization],
                                     output / 'build', timeout=budget['timeoutSeconds'], diagnostics=diagnostics('build'))
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
                          product=str(product), productSha256=sha(product),
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
