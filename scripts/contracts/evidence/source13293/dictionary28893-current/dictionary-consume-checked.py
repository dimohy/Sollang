"""Consume the already verified producer with the existing verification APIs."""
import pathlib, sys, json, importlib.util
ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output, cleanup_output, GENERATED
spec = importlib.util.spec_from_file_location('numeric', ROOT / 'scripts/verify-c385-preir-call-numeric.py')
n = importlib.util.module_from_spec(spec)
spec.loader.exec_module(n)
b = pathlib.Path(__file__).resolve().parent
contract_path = b / 'dictionary-checked-contract.json'
contract = json.loads(contract_path.read_text())
group = n.reusable_producer(contract)
observed = n.contract_observed_sources(contract)
preflights = n.emission_semantic_proof(contract, contract['cases'])
preflights += n.emission_stdlib_source_proof_inputs(contract, contract['cases'], observed)
bridge, bridge_inputs = n.emission_windows_link_bridge(contract)
proof_path = b / 'dictionary-checked-build01/result.json'
proof = json.loads(proof_path.read_text())
assert proof['status'] == 'passed' and proof['completed'] == proof['total'] == 1
assert proof['inputsStable'] and proof['processesStopped']
producer = pathlib.Path(proof['product'])
assert n.sha(producer) == proof['productSha256']
assert proof['inputHashes'][str(contract_path)] == n.sha(contract_path)
assert all(n.sha(pathlib.Path(p)) == h for p,h in proof['inputHashes'].items())
managed = b / 'dictionary-managed01/compiler/Sollang.Compiler.dll'
llvm = ROOT / '.tools/llvm-22.1.8/bin'
paths = [pathlib.Path(__file__), contract_path, proof_path, producer, *map(pathlib.Path, proof['inputHashes']),
         *observed, *preflights, *bridge_inputs, ROOT / 'scripts/verify-c385-preir-call-numeric.py',
         ROOT / 'scripts/verification_execution.py', ROOT / 'scripts/verification_llvm_allocation.py',
         ROOT / 'tests/native-interop/owned_array_audit.c', *[llvm/x for x in ['llvm-as.exe','clang.exe']]]
pins = {str(p):n.sha(p) for p in paths}
stable = lambda: all(pathlib.Path(p).is_file() and n.sha(pathlib.Path(p)) == h for p,h in pins.items())
out = b / 'dictionary-checked-consumers01'
reuse = [b/'dictionary-managed01/compiler', b/'contained-native-recovered01', ROOT/'artifacts/scratch/resume-20261006-owner-continuation22/v20050/compiler-build01']
initialize_output(ROOT, out, reusable_directories=reuse)
out.mkdir()
record = dict(schemaVersion=1,status='running',completed=0,total=len(contract['cases']),cases=[],inputHashes=pins,
              scope='Current checked SLG LLVM and runtime decisions, not Native CLI or Stage acceptance',producerSha256=n.sha(producer))
with VerificationContractLease(list(map(pathlib.Path,pins))):
    execution = VerificationExecution(ROOT,out,record,stable,n.sha)
    execution.save()
    error = None
    try:
        policy = execution.run(['dotnet',str(bridge),'policy',str(managed),n.sha(managed)],out/'policy',timeout=30)
        assert policy.returncode == 0 and not policy.stderr
        entry = json.loads(policy.stdout)['entryPoint']
        validator_spec = importlib.util.spec_from_file_location('entry',ROOT/'scripts/verify-checked-package-emitter.py')
        validator = importlib.util.module_from_spec(validator_spec);validator_spec.loader.exec_module(validator)
        for case in contract['cases']:
            folder = out/case['id'];folder.mkdir();budget = n.CaseBudget()
            row = dict(id=case['id'],status='running',passed=False,programSource=case['programSource'],programSha256=n.sha(ROOT/case['programSource']))
            record['cases'].append(row);execution.save()
            def run(command,prefix):
                return execution.run(command,prefix,timeout=budget.remaining(command,180)).returncode
            assert run([str(producer),*case['runArguments']],folder/'emit') == 0
            assert not n.read(folder/'emit.stderr').strip()
            emitted = folder/'emitted.ll';emitted.write_bytes((folder/'emit.stdout').read_bytes())
            validator.validate_emitted_entrypoint(n.read(emitted),'windows',windows_entry_point=entry)
            assert run([str(llvm/'llvm-as.exe'),str(emitted),'-o',str(folder/'emitted.bc')],folder/'grammar') == 0
            assert not n.read(folder/'grammar.stderr').strip()
            native = folder/'emitted.exe'
            assert run(['dotnet',str(bridge),'link',str(managed),n.sha(managed),str(llvm.parent),str(emitted),str(native),str(folder),'-O1','1'],folder/'link') == 0
            assert not n.read(folder/'link.stderr').strip()
            link = json.loads(n.read(folder/'link.stdout'))
            assert link['status'] == 'passed' and link['entryPoint'] == entry
            assert run([str(native)],folder/'run') == 0
            assert n.read(folder/'run.stdout').strip() == case['stdout'] and not n.read(folder/'run.stderr').strip()
            if 'expectedAllocations' in case:
                audit,passed = n.audit_llvm_program(emitted,folder,case['expectedAllocations'],case['stdout'],run)
                row.update(audit);assert passed, 'ALLOCATION_AUDIT_FAILED'
            row.update(status='passed',passed=True,emittedLlvmSha256=n.sha(emitted),wholeCaseElapsedSeconds=budget.elapsed())
            record['completed'] += 1;execution.save();print(case['id']+': PASS',flush=True)
        record['status'] = 'passed'
    except BaseException as caught:
        error = caught
        raise
    finally:
        record['generatedOutputHashes'] = {str(p):n.sha(p) for p in out.rglob('*') if p.is_file() and GENERATED.search(p.name)}
        execution.finalize(error,cleanup=False)
if record['status'] == 'passed' and record['inputsStable'] and record['processesStopped']:
    cleanup_output(ROOT,out,reusable_directories=reuse)
