"""Verify actual C# type-universe cache fields against frozen layout vectors."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output, cleanup_output

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--baseline-result', type=Path)
    parser.add_argument('--emitter', type=Path)
    parser.add_argument('--verify-source', action='store_true')
    parser.add_argument('--registered-sources', type=Path)
    parser.add_argument('--include-type-names', action='store_true')
    parser.add_argument('--allocation-controls', action='store_true')
    parser.add_argument('--include-codegen-request', action='store_true')
    parser.add_argument('--emission-only-projection', action='store_true')
    parser.add_argument('--include-stable-identities', action='store_true')
    parser.add_argument('--stable-candidate-file', type=Path)
    parser.add_argument('--stable-function-output', type=Path)
    parser.add_argument('--stable-call-input-output', type=Path)
    parser.add_argument('--declaration-type-uses', action='store_true')
    parser.add_argument('--stable-registration-output', type=Path)
    parser.add_argument('--stable-body-registration-output', type=Path)
    parser.add_argument('--stable-function-module')
    parser.add_argument('--stable-user-functions', action='store_true')
    parser.add_argument('--stable-emission-output', type=Path)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    assert not args.include_type_names or args.registered_sources, "type names require registered sources"
    assert not args.include_codegen_request or args.registered_sources, "codegen request requires registered sources"
    assert not (args.include_type_names and args.include_codegen_request), "select one observation mode"
    assert not args.emission_only_projection or args.include_codegen_request, "projection requires codegen request mode"
    assert not args.include_stable_identities or args.registered_sources, "stable identities require registered sources"
    assert not (args.include_stable_identities and (args.include_codegen_request or args.include_type_names)), "select one observation mode"
    assert not args.stable_candidate_file or args.include_stable_identities, "candidate validation requires stable identity mode"
    assert not args.stable_function_output or (args.include_stable_identities and (args.stable_function_module or args.stable_user_functions)), 'function comparison requires stable identity mode and function scope'
    assert not args.stable_user_functions or (args.stable_function_output and not args.stable_function_module), 'select one function comparison scope'
    assert not (args.stable_function_output or args.stable_call_input_output) or not args.declaration_type_uses, 'function comparison requires whole-program observation'
    assert not args.stable_emission_output or (args.include_stable_identities and not args.declaration_type_uses), 'emission comparison requires whole-program stable identities'
    assert not args.stable_function_module or (args.stable_function_output or args.stable_call_input_output), 'function module requires native output'
    assert not args.stable_call_input_output or (args.include_stable_identities and args.stable_function_module), 'call input comparison requires stable identity mode and module'
    assert not args.declaration_type_uses or (args.include_stable_identities and args.stable_candidate_file), 'declaration uses require stable identities and ordered type candidates'
    assert not args.declaration_type_uses or not (args.verify_source or args.emitter), 'declaration uses require bound observation mode'
    assert not args.stable_registration_output or args.declaration_type_uses, 'registration comparison requires declaration uses'
    assert not args.stable_body_registration_output or (args.include_stable_identities and not args.declaration_type_uses), 'body registration comparison requires whole-program stable identities'
    assert not args.allocation_controls or not (args.registered_sources or args.emitter or args.verify_source or args.baseline_result), 'allocation controls are an independent CSharp factory observation'
    compiler = args.compiler.resolve()
    output = args.output.resolve()
    harness = ROOT / 'scripts/probes/codegen-identity/CodegenLimits.csproj'
    vectors = ROOT / 'scripts/probes/codegen-type-universe/vectors.json'
    inputs = [Path(__file__), compiler, *managed_runtime_inputs(compiler), harness,
              harness.with_name('Limits.cs'), vectors, ROOT / 'Directory.Build.props', ROOT / 'global.json']
    baseline = None
    if args.baseline_result:
        baseline = json.loads(args.baseline_result.read_text(encoding='utf-8'))
        assert baseline['status'] == 'passed' and baseline['completed'] == baseline['total'] == 9
        assert baseline['inputsStable'] and baseline['processesStopped']
        # The new compiler is expected to change; frozen input vectors must not.
        assert baseline['inputHashes'][str(vectors.resolve())] == sha(vectors)
        inputs.append(args.baseline_result)
    if args.registered_sources:
        assert not args.emitter and not args.verify_source and not args.baseline_result
        inputs += sorted(args.registered_sources.glob('*.slg'))
    if args.stable_candidate_file:
        candidates = json.loads(args.stable_candidate_file.read_text(encoding='utf-8'))
        assert isinstance(candidates, list) and candidates and all(isinstance(value, str) for value in candidates), "candidate file must contain identity strings"
        inputs.append(args.stable_candidate_file)
    if args.stable_function_output:
        inputs.append(args.stable_function_output)
    if args.stable_call_input_output:
        inputs.append(args.stable_call_input_output)
    if args.stable_registration_output:
        inputs.append(args.stable_registration_output)
    if args.stable_body_registration_output:
        inputs.append(args.stable_body_registration_output)
    if args.stable_emission_output:
        inputs.append(args.stable_emission_output)
    sources = []
    if args.emitter or args.verify_source:
        assert baseline, 'paired format proof requires the frozen CSharp reference'
        manifest = ROOT / 'scripts/probes/codegen-type-universe/sources.txt'
        sources = [ROOT / line for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line]
        inputs += [manifest, *sources]
        if args.emitter:
            producer_path = args.emitter.parent / 'result.json'
            producer = json.loads(producer_path.read_text(encoding='utf-8'))
            assert producer['status'] == 'passed' and producer['inputsStable'] and producer['processesStopped']
            assert all(sha(p) == digest for p, digest in producer['inputHashes'].items())
            inputs += [args.emitter, producer_path, *map(Path, producer['inputHashes'])]
    fingerprints = {str(p.resolve()): sha(p) for p in inputs}
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    with VerificationContractLease(list(map(Path, fingerprints))):
        result = dict(schemaVersion=1, status='running', completed=0, total=1 if args.registered_sources else 18 if args.emitter else 9, cases=[],
                      inputHashes=fingerprints, claimsGoalComplete=False,
                      scope='Actual BuildTypeUniverseHash and table records: eight registered layout categories, '
                            'field/variant/type order, null fixed length, Unicode and category mutations. '
                            'Metadata-only; no Native type-pool selection or cache reuse claim.')
        if args.allocation_controls:
            result['total'] = 1
            result['scope'] = 'Actual CSharp deferred fixed-array reservation, occupied identities and relative allocation trajectory; semantic arena coordinates and canonical metadata IDs remain distinct.'
        if args.include_codegen_request:
            result['scope'] = 'Actual CSharp Open request, source modules, emission hashes and complete keys; no SLG production cache claim.'
        if args.include_stable_identities:
            result['scope'] = 'Actual CSharp structural type identities and bound function identity fields; no SLG identity or production reuse claim.'
        if args.declaration_type_uses:
            result['scope'] = 'Actual CSharp declaration registry followed by ordered concrete type uses; whole-compilation body traversal and production cache consumption are separate.'
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in fingerprints.items()), sha)
        error = None
        try:
            if sources:
                expected = ''.join('\n'.join([*case['observation']['fields'],
                    format(case['observation']['hash'], '016x')]) + '\n' for case in baseline['cases'])
                def run(command, label, timeout=180):
                    done = execution.run(list(map(str, command)), output / label, timeout=timeout)
                    assert done.returncode == 0 and not done.stderr, (label, done.stdout[-1500:], done.stderr)
                    return done
                for backend in (['managed', 'slg'] if args.emitter else ['managed']):
                    executable = output / (backend + '.exe')
                    if backend == 'managed':
                        run([compiler, 'build', *sources, '-o', executable, '--target', 'windows-x64',
                             '--llvm', ROOT / '.tools/llvm-22.1.8', '--jobs', 24, '-O2'], 'managed-build')
                    else:
                        done = run([args.emitter, 'plain-windows', ROOT / 'stdlib', output / 'unused.semantic',
                                    output / 'unused-stage.semantic', *sources], 'emit')
                        llvm = output / 'program.ll'
                        llvm.write_text(done.stdout, encoding='utf-8', newline='\n')
                        run([ROOT / '.tools/llvm-22.1.8/bin/llvm-as.exe', llvm, '-o', output / 'program.bc'], 'assemble')
                        run([ROOT / '.tools/llvm-22.1.8/bin/clang.exe', llvm, '-O0', '-Wno-override-module',
                             '-o', executable, '-lkernel32', '-lshell32', '-lws2_32', '-lbcrypt'], 'link')
                    done = run([executable], backend + '-run', 10)
                    assert done.stdout == expected, (backend, done.stdout, expected)
                    result['cases'] += [dict(id=backend + ':' + case['id'], passed=True,
                                            observation=case['observation']) for case in baseline['cases']]
                    result['completed'] += 9
                result['status'] = 'passed'
            else:
                shutil.copyfile(vectors, output / 'vectors.json')
                built = execution.run(['dotnet', 'build', '--disable-build-servers', '-nodeReuse:false',
                                       '-p:UseSharedCompilation=false', str(harness), '-c', 'Release',
                                       '-o', str(output / 'harness'), '--artifacts-path', str(output / 'dotnet-artifacts')],
                                      output / 'build', timeout=180)
                assert built.returncode == 0, built.stdout + built.stderr
                done = execution.run(['dotnet', str(output / 'harness/CodegenLimits.dll'),
                                      str(compiler.with_suffix('.dll')), str(args.registered_sources.resolve() if args.registered_sources else output),
                                      ('registered-declaration-type-use-vectors' if args.declaration_type_uses else 'registered-stable-identity-vectors' if args.include_stable_identities else 'registered-codegen-request-emission-only-vectors' if args.emission_only_projection else 'registered-codegen-request-vectors' if args.include_codegen_request else 'registered-type-universe-named-vectors' if args.include_type_names else 'registered-type-universe-vectors') if args.registered_sources else 'type-allocation-vectors' if args.allocation_controls else 'type-universe-vectors',
                                      *([str(args.stable_candidate_file.resolve())] if args.stable_candidate_file else [])],
                                     output / 'run', timeout=180)
                assert done.returncode == 0 and not done.stderr, done.stdout + done.stderr
                if args.allocation_controls:
                    row = json.loads(done.stdout)
                    assert row == dict(first=2, reservation=True, duplicateShape=False, occupied=False,
                                       allocated=[3, 4, 5, 7], reserved=6, repeated=6), 'CSHARP_DEFERRED_RESERVATION_TRAJECTORY_MISMATCH'
                    result['cases'].append(dict(id='deferred-static-array-allocation', passed=True, actual=row))
                    result['completed'] = 1
                    result['status'] = 'passed'
                elif args.registered_sources:
                    row = json.loads(done.stdout)
                    if args.declaration_type_uses:
                        assert row['registrations'] and all(r['canonical'] == r['identity'] for r in row['registrations'])
                        if args.stable_registration_output:
                            lines = args.stable_registration_output.read_text(encoding='utf-8-sig').splitlines()
                            assert all(line == 'utf16:4' or line.startswith(('registered-use:', 'declaration-next:')) for line in lines), 'NATIVE_REGISTRATION_CAPTURE_ERROR'
                            actual = [(int(line.split(':', 2)[1]), line.split(':', 2)[2]) for line in lines if line.startswith('registered-use:')]
                            expected = [(r['id'], r['identity']) for r in row['registrations']]
                            assert actual == expected, 'ORDERED_TYPE_REGISTRATION_MISMATCH'
                            assert [int(line.split(':')[1]) for line in lines if line.startswith('declaration-next:')] == [row['declarationNextTypeId']], 'DECLARATION_TYPE_REGISTRATION_MISMATCH'
                            result['registrationComparison'] = dict(completed=len(actual), total=len(expected), exact=True,
                                scope='Declaration registry followed by explicit ordered concrete type uses; whole-compilation body traversal is separate.')
                    elif args.include_stable_identities:
                        assert row['types'] and row['functions'] and all(r['identity'] for r in row['functions'])
                        if args.stable_emission_output:
                            lines = args.stable_emission_output.read_text(encoding='utf-8-sig').splitlines()
                            assert not any(line.startswith(('function-capture-error:', 'function-emission-error')) for line in lines), 'NATIVE_EMISSION_CAPTURE_ERROR'
                            entries = [line.split(':', 2) for line in lines if line.startswith('emission:')]
                            actual = {entry[2]: int(entry[1]) for entry in entries}
                            assert len(actual) == len(entries) and actual == row['emissionHashes'], 'MODULE_EMISSION_HASH_MISMATCH'
                            result['emissionComparison'] = dict(completed=len(actual), total=len(row['emissionHashes']), exact=True)
                        if args.stable_body_registration_output:
                            lines = args.stable_body_registration_output.read_text(encoding='utf-8-sig').splitlines()
                            assert all(line == 'utf16:4' or line.startswith(('registered-body:', 'declaration-next:', 'unresolved-plans:', 'value-calls:', 'use:')) for line in lines), 'NATIVE_BODY_REGISTRATION_CAPTURE_ERROR'
                            assert [int(line.split(':')[1]) for line in lines if line.startswith('unresolved-plans:')] == [0], 'UNRESOLVED_BODY_TYPE_USES'
                            assert [int(line.split(':')[1]) for line in lines if line.startswith('declaration-next:')] == [row['declarationNextTypeId']], 'DECLARATION_TYPE_REGISTRATION_MISMATCH'
                            actual = [(int(line.split(':', 2)[1]), line.split(':', 2)[2]) for line in lines if line.startswith('registered-body:')]
                            expected = [(entry['id'], entry['identity']) for entry in row['types'] if entry['id'] >= row['declarationNextTypeId']]
                            assert actual == expected, 'WHOLE_BODY_TYPE_REGISTRATION_MISMATCH'
                            assert [type_id for type_id, _ in actual] == list(range(row['declarationNextTypeId'], row['nextAllocatedTypeId'])), 'INCOMPLETE_BODY_TYPE_REGISTRATION'
                            result['bodyRegistrationComparison'] = dict(completed=len(actual), total=len(expected), exact=True,
                                scope='All newly allocated body type identities and numeric IDs for the fixture and its loaded standard library.')
                        if args.stable_function_output:
                            native_lines = args.stable_function_output.read_text(encoding='utf-8').splitlines()
                            assert not any(value.startswith(('function-error:', 'function-capture-error:', 'error:', 'specialization-error:', 'specialization-field-error:')) for value in native_lines), 'NATIVE_FUNCTION_CAPTURE_ERROR'
                            actual = [value[len('function:'):] for value in native_lines if value.startswith('function:')]
                            expected = [entry['identity'] for entry in row['functions'] if (entry['facts']['Kind'] == 0 if args.stable_user_functions else entry['facts']['ModuleName'] == args.stable_function_module)]
                            assert expected and sorted(actual) == sorted(expected), 'STABLE_FUNCTION_IDENTITY_MISMATCH'
                            result['functionComparison'] = dict(module=args.stable_function_module, scope='all-user-functions' if args.stable_user_functions else 'module', completed=len(actual), total=len(expected), exact=True)
                        if args.stable_call_input_output:
                            native_lines = args.stable_call_input_output.read_text(encoding='utf-8-sig').splitlines()
                            assert all(line == 'utf16:4' or line.startswith('argument:') for line in native_lines), 'NATIVE_CALL_INPUT_CAPTURE_ERROR'
                            actual = {line[len('argument:'):] for line in native_lines if line.startswith('argument:')}
                            type_identities = {entry['id']: entry['identity'] for entry in row['types']}
                            expected = set()
                            for entry in row['functions']:
                                facts = entry['facts']
                                if facts['ModuleName'] != args.stable_function_module or facts['SpecializedType'] is None:
                                    continue
                                if facts['InputType'] is not None:
                                    expected.add(type_identities[facts['InputType']])
                                expected.update(type_identities[parameter['Type']] for parameter in facts['AdditionalParameters'])
                            assert expected and actual == expected, 'STABLE_CALL_INPUT_IDENTITY_MISMATCH'
                            result['callInputComparison'] = dict(module=args.stable_function_module, completed=len(actual), total=len(expected), exact=True,
                                scope='Concrete typed generic-call input identities only; specialization names and production cache integration are separate.')
                        if args.stable_candidate_file:
                            assert len(row['candidateValidation']) == len(candidates)
                            assert all(r['equal'] for r in row['candidateValidation']), 'STABLE_IDENTITY_CANONICAL_MISMATCH'
                    elif args.include_codegen_request:
                        assert row['modules'] and row['emissions'] and isinstance(row['typeUniverseHash'], int)
                        names = [entry['name'] for entry in row['moduleKeys']]
                        assert len(names) == len(set(names))
                        assert set(names) == {entry['name'] for entry in row['modules']} | {entry['name'] for entry in row['emissions']}
                        if args.emission_only_projection:
                            assert len(set(names) - {entry['name'] for entry in row['modules']}) == 1
                        assert all(set(row[k]) == {'interfaceHash', 'implementationHash'} for k in ('prefix', 'suffix'))
                    else:
                        assert set(row['records']) == {'Structs', 'Enums', 'Boxes', 'References', 'DynTraits',
                                                       'StaticArrays', 'DynamicArrays', 'Dictionaries'}
                        assert all(row['records'][name] for name in row['records']), 'missing registered category'
                    result.update(status='passed', completed=1,
                                  cases=[dict(id='actual-stable-identities' if args.include_stable_identities else 'actual-codegen-request' if args.include_codegen_request else 'actual-registered-types', passed=True, observation=row)])
                else:
                    rows = [json.loads(line) for line in done.stdout.splitlines()]
                    assert len(rows) == 9
                    if baseline:
                        assert rows == [case['observation'] for case in baseline['cases']]
                    result.update(status='passed', completed=9,
                                  cases=[dict(id=row['id'], passed=True, observation=row) for row in rows])
        except BaseException as exc:
            error = exc
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))
    if args.allocation_controls and result['status'] == 'passed':
        cleanup_output(ROOT, output, reusable_directories=args.reusable_directory)


if __name__ == '__main__':
    main()
