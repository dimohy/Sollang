from pathlib import Path
import sys,json,hashlib,shutil,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22'
OUT=B/'cache22061-csharp-module-catalog'
CPP=B/'managed21997/compiler/Sollang.Compiler.dll'
fixtures=[ROOT/'scripts/probes/codegen-module-interface'/name for name in ['Z.slg','a.slg','empty.slg','other.slg']]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),ROOT/'scripts/probes/codegen-identity/Limits.cs',ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj',ROOT/'Directory.Build.props',ROOT/'global.json',*fixtures,*sorted((ROOT/'stdlib').rglob('*.slg'))]
inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=3,cases=[],inputHashes=inputs,maximumCaseSeconds=180,scope='Actual CSharp compilation module catalog: full identity, stable identity order, source implementation, interface, duplicate import deduplication, standard library flag; existing production cache proof remains authoritative for reuse.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  vectors=OUT/'module-sources';vectors.mkdir()
  for fixture in fixtures:shutil.copyfile(fixture,vectors/fixture.name)
  (vectors/'Z.slg').write_text((vectors/'Z.slg').read_text(encoding='utf-8').replace('namespace cache.module_order','namespace cache.module_order\nimport cache.other as peer'),encoding='utf-8')
  (vectors/'a.slg').write_text((vectors/'a.slg').read_text(encoding='utf-8').replace('namespace cache.module_order','namespace cache.module_order\nimport cache.other as peer'),encoding='utf-8')
  done=ex.run(['dotnet','build','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false',str(ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj'),'-c','Release','-o',str(OUT/'harness'),'--artifacts-path',str(OUT/'dotnet-artifacts')],OUT/'build',timeout=budget());assert done.returncode==0,done.stdout+done.stderr
  done=ex.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP),str(vectors),'module-catalog-vectors'],OUT/'run',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
  rows=[json.loads(line) for line in done.stdout.splitlines()]
  assert len(rows)==3
  assert rows==sorted(rows,key=lambda row:(row['stableHash'],row['name']))
  byName={row['name']:row for row in rows}
  assert byName['cache.module_order']['imports']==['cache.other']
  assert all(not row['isStandardLibrary'] for row in rows)
  assert byName['cache.empty']['imports']==byName['cache.other']['imports']==[]
  result.update(status='passed',completed=3,cases=[dict(id=r['name'],passed=True,observation=r) for r in rows])
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
