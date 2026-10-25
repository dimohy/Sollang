from pathlib import Path
import json,hashlib,sys,shutil
R=Path.cwd();B=R/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(R/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
from verification_fingerprints import managed_runtime_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
seed=B/'managed13673/result.json';seed_record=read(seed);assert seed_record['status']=='passed' and seed_record['inputsStable'] and seed_record['processesStopped'];pins=dict(seed_record['inputHashes'])
for p,h in pins.items():assert Path(p).is_file() and sha(p)==h,p
compiler=B/'managed13673/compiler/Sollang.Compiler.dll';assert sha(compiler)==seed_record['compilerDllSha256']=='071D7CF1814FF16994E7768FC91E1E0FC5BC9F86F62B97060C957CD8CB7390BD'
contract_path=R/'scripts/contracts/async-task-observability.json';contract=read(contract_path);cases=[x for x in contract['probeMatrix'] if x.get('managed')];assert len(cases)==13
expected_exit={c['id']:c['expectedBuildExit'] for c in cases};assert sum(v==0 for v in expected_exit.values())==8 and sum(v==1 for v in expected_exit.values())==5
verifier=R/'scripts/verify-managed-async-task-observability-matrix.ps1';assert 'AddMilliseconds(120000)' in verifier.read_text(encoding='utf-8-sig')
inputs=[seed,compiler,contract_path,verifier,R/'scripts/contracts/async-task-observability-managed-matrix-result.schema.json',R/'scripts/verify-llvm-direct-call-closure.ps1',R/'tests/native-interop/owned_array_audit.c',R/'.tools/llvm-22.1.8/bin/clang.exe',R/'.tools/llvm-22.1.8/bin/llvm-as.exe',Path(__file__).resolve(),R/'scripts/verification_execution.py',R/'scripts/completed_artifact_plan.py',Path(shutil.which('dotnet')),Path(shutil.which('pwsh')),*managed_runtime_inputs(compiler)]
inputs += [R/c['source'] for c in cases]+list((R/'scripts/probes/async-task-observability').glob('*.expected.txt'))+list((R/'stdlib').rglob('*.slg'))
for p in inputs:assert p.is_file(),p;pins[str(p)]=sha(p)
retained=[B/'v12432/compiler-build01',B/'v14280/compiler-build01'];out=B/'async14436-managed13';initialize_output(R,out,reusable_directories=retained);out.mkdir(exist_ok=False)
record=dict(schemaVersion=1,status='running',scope='Existing original managed observability matrix13 with current seed; one selected source-location control is not exhaustive suspension branch closure.',inputHashes=pins,completed=0,total=13,cases=[],caseCommandBudgetSeconds=120,aggregateSupervisorBudgetSeconds=4800,aggregateBudgetDerivation='8 positive*4 commands*120 +5 rejected*120 +2 allocation audit commands*120 +120 schema/transport overhead',maximumMatrixInvocations=1,claimsGoalComplete=False)
x=VerificationExecution(R,out,record,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 capture=out/'capture';run=x.run(['pwsh','-NoProfile','-File',str(verifier),'-Compiler',str(compiler),'-ExpectedCompilerSha256',sha(compiler),'-RepositoryRoot',str(R),'-OutputDirectory',str(capture)],out/'matrix',timeout=4800)
 assert run.returncode==0,run.stderr
 raw_path=capture/'result.json';q=read(raw_path);assert q['status']=='passed' and q['completed']==q['total']==13 and q['inputHashesStart']==q['inputHashesEnd'] and not q['inputDrift'] and not q['compilerDrift'] and not q['orphanProcessIds'];assert q['schemaControls']==dict(positiveAccepted=True,negativeRejected=7,negativeTotal=7)
 assert [c['id'] for c in q['cases']]==[c['id'] for c in cases]
 for c in q['cases']:assert c['passed'] and c['compileExit']==expected_exit[c['id']] and not c['orphanProcessIds']
 # Preserve foreign result bytes under an explicit capture name; the supervised
 # result owns the successful generated subtree for canonical cleanup.
 raw_hash=sha(raw_path);destination=capture/'raw-result.json';assert not destination.exists();raw_path.replace(destination);assert sha(destination)==raw_hash
 record.update(status='passed',completed=13,rawCapture=str(destination),rawCaptureSha256=raw_hash,rawCaptureBytesRewritten=False,schemaControls=q['schemaControls'],cases=[dict(id=c['id'],status='passed',passed=True,buildExit=c['compileExit'],expectedBuildExit=expected_exit[c['id']],runExit=c['nativeExit'],sourceSha256=c['sourceSha256'],nativeExact=c['nativeExact'],allocationParity=c['allocationParity']) for c in q['cases']])
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
if record['status']=='passed' and record['inputsStable'] and record['processesStopped']:cleanup_output(R,out,execute=True,reusable_directories=retained)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}));sys.exit(0 if record['status']=='passed' else 1)
