from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache21727-key-rule-pairs';CPP=B/'managed21725/compiler/Sollang.Compiler.exe';NATIVE=B/'v21323/compiler-build01/compiler.exe';P=ROOT/'scripts/probes/codegen-cache-key-rules';sources=[ROOT/p for p in (P/'sources.txt').read_text().splitlines() if p];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),NATIVE,NATIVE.parent/'result.json',P/'sources.txt',*sources,ROOT/'scripts/probes/codegen-identity/Limits.cs',ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj',ROOT/'scripts/contracts/evidence/source13293/cache21715-key-rules/source-comparison.json',*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,maximumCaseSeconds=180,claimsGoalComplete=False,scope='Current generated CSharp key plans consumed by the SLG hasher, compiled and run by current CSharp and pinned Native21323. Nine original and four generated changed/empty/repeated plans match actual CSharp HashRule; missing/duplicate inputs reject. Production metadata, lookup and publication remain pending.')
 generatedInputs={}
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()) and all(sha(p)==h for p,h in generatedInputs.items()),sha);err=None
 try:
  done=ex.run(['dotnet','build','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false',str(ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj'),'-c','Release','-o',str(OUT/'harness'),'--artifacts-path',str(OUT/'dotnet-artifacts')],OUT/'harness-build',timeout=180);assert done.returncode==0,done.stdout+done.stderr
  done=ex.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP.with_suffix('.dll')),str(OUT/'vectors'),'key-rule-vectors'],OUT/'vectors',timeout=180);assert done.returncode==0 and not done.stderr,done.stdout+done.stderr;rows=[json.loads(line) for line in done.stdout.splitlines()];assert len(rows)==13;expected=''.join(row['name']+'='+str(row['hash'])+'\n' for row in rows)+'missing=ok\nduplicate=ok\n';(OUT/'expected.stdout.txt').write_text(expected,encoding='utf-8',newline='\n')
  generatedInputs[str(OUT/'vectors/key-rule-smoke.slg')]=sha(OUT/'vectors/key-rule-smoke.slg');generatedInputs[str(OUT/'expected.stdout.txt')]=sha(OUT/'expected.stdout.txt');result['generatedInputHashes']=generatedInputs;ex.save()
  for role,compiler in [('csharp',CPP),('native-seed',NATIVE)]:
   d=OUT/role;d.mkdir();start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start));exe=d/'program.exe';args=[str(compiler),'build',*map(str,sources),str(OUT/'vectors/key-rule-smoke.slg'),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','1','-O0']
   if role=='native-seed':args+=['--stdlib',str(ROOT/'stdlib')]
   done=ex.run(args,d/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-1800:]+done.stderr
   done=ex.run([str(exe)],d/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,done.stdout[-1500:]+done.stderr;assert all(sha(p)==h for p,h in generatedInputs.items());result['cases'].append(dict(id=role,passed=True,generatedInputHashes=dict(generatedInputs),keyRules=13,negativeControls=2,expectedSha256=hashlib.sha256(expected.encode()).hexdigest().upper()));result['completed']+=1;ex.save()
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
