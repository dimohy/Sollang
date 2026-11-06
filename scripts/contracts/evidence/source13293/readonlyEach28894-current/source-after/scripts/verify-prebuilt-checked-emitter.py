"""Verify a pinned checked emitter using the existing focused execution APIs."""
import argparse
import importlib.util
import json
from pathlib import Path

from completed_artifact_plan import initialize_output, cleanup_output, GENERATED
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_stdlib_source_preflight import validate as validate_stdlib

ROOT = Path(__file__).resolve().parents[1]
NUMERIC = ROOT / 'scripts/verify-c385-preir-call-numeric.py'
spec = importlib.util.spec_from_file_location('checked_emitter_numeric', NUMERIC)
n = importlib.util.module_from_spec(spec)
spec.loader.exec_module(n)


def validate_consumer_contract(contract):
    fields = {'schemaVersion', 'cases', 'harnessBuildOptimization', 'harnessBuildJobs',
              'semanticPreflightProof', 'stdlibSourcePreflightProof', 'windowsLinkBridge',
              'reusableCheckedProducer', 'expectedManagedDllSha256'}
    case_fields = {'id', 'source', 'additionalSources', 'programSource', 'programAdditionalSources',
                   'runArguments', 'observedSourceOrder', 'exit', 'stderr', 'stdout',
                   'expectedAllocations', 'emittedLlvm', 'expectedEmittedRuntimeExit'}
    if not isinstance(contract, dict) or set(contract) - fields or contract.get('schemaVersion') != 1:
        raise ValueError('PREBUILT_CHECKED_CONTRACT_UNSUPPORTED')
    if not isinstance(contract.get('cases'), list) or not contract['cases']:
        raise ValueError('PREBUILT_CHECKED_CASES_REQUIRED')
    for case in contract['cases']:
        if (not isinstance(case, dict) or set(case) - case_fields
                or not isinstance(case.get('stdout'), str) or case['stdout'] != case['stdout'].strip()
                or type(case.get('expectedEmittedRuntimeExit', 0)) is not int):
            raise ValueError('PREBUILT_CHECKED_CASE_UNSUPPORTED')


def source_build_inputs(record_path, contract_path, managed_dll, root=ROOT):
    proof = json.loads(Path(record_path).read_text(encoding='utf-8-sig'))
    pins = proof.get('inputHashes')
    if (proof.get('status') != 'passed' or proof.get('completed') != 1 or proof.get('total') != 1
            or proof.get('inputsStable') is not True or proof.get('processesStopped') is not True
            or not isinstance(pins, dict) or not pins):
        raise ValueError('PREBUILT_CHECKED_SOURCE_PROOF_INCOMPLETE')
    product = Path(proof['product']).resolve()
    if (not product.is_relative_to(Path(root).resolve() / 'artifacts') or product.suffix != '.exe'
            or not product.is_file() or n.sha(product) != proof.get('productSha256')):
        raise ValueError('PREBUILT_CHECKED_PRODUCT_CHANGED')
    for path in (Path(contract_path).resolve(), Path(managed_dll).resolve()):
        if pins.get(str(path)) != n.sha(path):
            raise ValueError('PREBUILT_CHECKED_CONSUMER_INPUT_NOT_COVERED: ' + str(path))
    for path, expected in pins.items():
        if not Path(path).is_file() or n.sha(Path(path)) != expected:
            raise ValueError('PREBUILT_CHECKED_SOURCE_INPUT_CHANGED: ' + path)
    return proof, product, [Path(record_path).resolve(), product, *map(Path, pins)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source-build-proof', 'contract', 'managed-compiler', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--diagnostics-plan', type=Path)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    contract_path, output = args.contract.resolve(), args.output.resolve()
    managed_dll = args.managed_compiler.resolve().with_suffix('.dll')
    configuration = n.load_diagnostics_plan(args.diagnostics_plan)
    contract = json.loads(n.read(contract_path))
    validate_consumer_contract(contract)
    if contract.get('expectedManagedDllSha256', n.sha(managed_dll)) != n.sha(managed_dll):
        raise ValueError('PREBUILT_CHECKED_MANAGED_COMPILER_CHANGED')
    group = n.reusable_producer(contract)
    if group is None or any(case.get('emittedLlvm') is not True for case in contract['cases']):
        raise ValueError('PREBUILT_CHECKED_EMITTED_CASES_REQUIRED')
    observed = n.contract_observed_sources(contract)
    preflights = n.emission_semantic_proof(contract, contract['cases'])
    stdlib_inputs = n.emission_stdlib_source_proof_inputs(contract, contract['cases'], observed)
    validate_stdlib(ROOT, stdlib_inputs[0])
    bridge, bridge_inputs = n.emission_windows_link_bridge(contract)
    proof, producer, source_inputs = source_build_inputs(args.source_build_proof, contract_path, managed_dll)
    llvm = ROOT / '.tools/llvm-22.1.8/bin'
    paths = [Path(__file__), contract_path, *source_inputs, *observed, *preflights, *stdlib_inputs,
             *bridge_inputs, NUMERIC, ROOT / 'scripts/verification_execution.py',
             ROOT / 'scripts/verification_contract_lease.py', ROOT / 'scripts/verification_step_diagnostics.py',
             ROOT / 'scripts/verification_llvm_allocation.py', ROOT / 'scripts/verification_stdlib_source_preflight.py',
             ROOT / 'scripts/verify-checked-package-emitter.py', ROOT / 'scripts/completed_artifact_plan.py',
             ROOT / 'scripts/ArtifactLifecycle.ps1', ROOT / 'scripts/Invoke-CompletedArtifactCleanup.ps1',
             ROOT / 'scripts/contracts/artifact-lifecycle.json',
             ROOT / 'tests/native-interop/owned_array_audit.c', llvm / 'llvm-as.exe', llvm / 'clang.exe',
             *([] if args.diagnostics_plan is None else [args.diagnostics_plan.resolve()])]
    pins = {str(path): n.sha(path) for path in paths}
    stable = lambda: all(Path(path).is_file() and n.sha(Path(path)) == digest for path, digest in pins.items())
    with VerificationContractLease(list(map(Path, pins))):
        admitted, product, _ = source_build_inputs(args.source_build_proof, contract_path, managed_dll)
        if not stable() or admitted != proof or product != producer or json.loads(n.read(contract_path)) != contract:
            raise ValueError('PREBUILT_CHECKED_INPUT_CHANGED_BEFORE_EXECUTION')
        initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
        output.mkdir(exist_ok=False)
        record = dict(schemaVersion=1, status='running', completed=0, total=len(contract['cases']), cases=[],
                      inputHashes=pins, producerSha256=proof['productSha256'],
                      scope='Current checked SLG LLVM/runtime decisions, not Native CLI or Stage acceptance')
        execution = VerificationExecution(ROOT, output, record, stable, n.sha)
        execution.save()
        error = None
        try:
            policy = execution.run(['dotnet', str(bridge), 'policy', str(managed_dll), n.sha(managed_dll)],
                                   output / 'policy', timeout=30)
            if policy.returncode != 0 or policy.stderr.strip():
                raise ValueError('PREBUILT_CHECKED_ENTRY_POLICY_FAILED')
            entry = json.loads(policy.stdout)['entryPoint']
            validator_path = ROOT / 'scripts/verify-checked-package-emitter.py'
            validator_spec = importlib.util.spec_from_file_location('checked_emitter_entry', validator_path)
            validator = importlib.util.module_from_spec(validator_spec)
            validator_spec.loader.exec_module(validator)
            for case in contract['cases']:
                folder = output / case['id']
                folder.mkdir()
                budget = n.CaseBudget()
                row = dict(id=case['id'], status='running', passed=False, programSource=case['programSource'],
                           programSha256=n.sha(ROOT / case['programSource']))
                record['cases'].append(row)
                execution.save()
                def run(command, prefix):
                    timeout = budget.remaining(command, 180)
                    return execution.run(command, prefix, timeout=timeout,
                        diagnostics=n.diagnostics_for_timeout(configuration, prefix, timeout)).returncode
                if run([str(producer), *case['runArguments']], folder / 'emit') != 0 or n.read(folder / 'emit.stderr').strip():
                    raise ValueError('PREBUILT_CHECKED_EMISSION_FAILED: ' + case['id'])
                emitted = folder / 'emitted.ll'
                emitted.write_bytes((folder / 'emit.stdout').read_bytes())
                validator.validate_emitted_entrypoint(n.read(emitted), 'windows', windows_entry_point=entry)
                if run([str(llvm / 'llvm-as.exe'), str(emitted), '-o', str(folder / 'emitted.bc')], folder / 'grammar') != 0 or n.read(folder / 'grammar.stderr').strip():
                    raise ValueError('PREBUILT_CHECKED_LLVM_INVALID: ' + case['id'])
                native = folder / 'emitted.exe'
                if run(['dotnet', str(bridge), 'link', str(managed_dll), n.sha(managed_dll), str(llvm.parent),
                        str(emitted), str(native), str(folder), '-O1', '1'], folder / 'link') != 0 or n.read(folder / 'link.stderr').strip():
                    raise ValueError('PREBUILT_CHECKED_LINK_FAILED: ' + case['id'])
                link = json.loads(n.read(folder / 'link.stdout'))
                if link.get('status') != 'passed' or link.get('entryPoint') != entry:
                    raise ValueError('PREBUILT_CHECKED_LINK_RESULT_INVALID')
                if (run([str(native)], folder / 'run') != case.get('expectedEmittedRuntimeExit', 0)
                        or n.read(folder / 'run.stdout').strip() != case['stdout'] or n.read(folder / 'run.stderr').strip()):
                    raise ValueError('PREBUILT_CHECKED_RUNTIME_MISMATCH: ' + case['id'])
                if 'expectedAllocations' in case:
                    audit, passed = n.audit_llvm_program(emitted, folder, case['expectedAllocations'], case['stdout'], run)
                    row.update(audit)
                    if not passed:
                        raise ValueError('PREBUILT_CHECKED_ALLOCATION_AUDIT_FAILED: ' + case['id'])
                budget.remaining(['case-completion', case['id']], budget.seconds)
                row.update(status='passed', passed=True, emittedLlvmSha256=n.sha(emitted),
                           wholeCaseElapsedSeconds=budget.elapsed())
                record['completed'] += 1
                execution.save()
                print(case['id'] + ': PASS', flush=True)
            record['status'] = 'passed'
        except BaseException as caught:
            error = caught
            raise
        finally:
            record['generatedOutputHashes'] = {str(path): n.sha(path) for path in output.rglob('*')
                                               if path.is_file() and GENERATED.search(path.name)}
            execution.finalize(error, cleanup=False)
    if record['status'] == 'passed' and record['inputsStable'] and record['processesStopped']:
        cleanup_output(ROOT, output, reusable_directories=args.reusable_directory)


if __name__ == '__main__':
    main()
