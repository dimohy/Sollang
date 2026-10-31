from pathlib import Path
import sys,json,hashlib,shutil,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22'
baseline=len(sys.argv)>1 and sys.argv[1]=='baseline'
OUT=B/('module21910-csharp-baseline' if baseline else 'module21913-csharp-current')
CPP=B/('managed21861' if baseline else 'managed21908')/'compiler/Sollang.Compiler.dll'
fixtures=sorted((ROOT/'scripts/probes/codegen-module-interface').glob('*.slg'))
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),ROOT/'scripts/probes/codegen-identity/Limits.cs',ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj',ROOT/'Directory.Build.props',ROOT/'global.json',*fixtures,*sorted((ROOT/'stdlib').rglob('*.slg'))]
if not baseline:paths.append(B/'module21910-csharp-baseline/result.json')
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=3,cases=[],inputHashes=inputs,maximumCaseSeconds=180,scope='Actual CSharp LoadProgram and CreateModuleIdentity: source ordinal order, per-source category/name order and continuous interface field stream; reverse source arguments must not change identity. Empty and unrelated modules included.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  vectors=OUT/'module-sources';vectors.mkdir()
  for fixture in fixtures:shutil.copyfile(fixture,vectors/fixture.name)
  done=ex.run(['dotnet','build','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false',str(ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj'),'-c','Release','-o',str(OUT/'harness'),'--artifacts-path',str(OUT/'dotnet-artifacts')],OUT/'build',timeout=budget());assert done.returncode==0,done.stdout+done.stderr
  done=ex.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP),str(vectors),'module-interface-vectors'],OUT/'run',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
  rows=[json.loads(line) for line in done.stdout.splitlines()];assert [r['name'] for r in rows]==['cache.empty','cache.module_order','cache.other']
  assert not rows[0]['fields']
  fields=rows[1]['fields'];assert fields.index('cache.module_order.Alpha')<fields.index('cache.module_order.Zeta')<fields.index('cache.module_order.AChoice')<fields.index('cache.module_order.ZChoice')<fields.index('cache.module_order.AReader')<fields.index('cache.module_order.ZReader')<fields.index('cache.module_order.first')<fields.index('cache.module_order.last')<fields.index('cache.module_order.EarlierByName')
  if not baseline:assert rows==[c['observation'] for c in json.loads((B/'module21910-csharp-baseline/result.json').read_text())['cases']]
  result.update(status='passed',completed=3,cases=[dict(id=r['name'],passed=True,observation=r) for r in rows])
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
