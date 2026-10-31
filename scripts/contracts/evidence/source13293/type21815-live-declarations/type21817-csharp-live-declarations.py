from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'type21817-csharp-live-declarations';CPP=B/'managed21775/compiler/Sollang.Compiler.exe';manifest=ROOT/'scripts/probes/codegen-live-declarations/sources.txt';sources=[ROOT/s for s in manifest.read_text(encoding='utf-8-sig').splitlines() if s];fixtures=[ROOT/'scripts/probes/codegen-interface-fields/before.slg'];referencePath=B/'type21816-csharp-declarations/result.json';reference=json.loads(referencePath.read_text(encoding='utf-8-sig'));assert reference['status']=='passed' and reference['inputsStable'] and reference['processesStopped'];byName={case['observation']['name']:case['observation'] for case in reference['cases']};selected=[byName['cache.interfaces.'+name] for name in ['Zeta','Alpha','Choice']];expected=''.join(''.join(value+'\n' for value in row['fields'])+format(row['hash'],'016x')+'\n' for row in selected);sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),manifest,*sources,*fixtures,referencePath,*sorted((ROOT/'stdlib').rglob('*.slg'))];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,cases=[],inputHashes=inputs,scope='CSharp compiles live struct/enum declaration facts and feeds their shared key rules; exact fields and hashes against actual loaded CSharp declaration vectors. Traits/functions and complete module interface remain pending.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  exe=OUT/'program.exe';done=ex.run([str(CPP),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2'],OUT/'build',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout[-2500:]+done.stderr
  done=ex.run([str(exe),*map(str,fixtures)],OUT/'run',timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout==expected,(done.stdout,done.stderr,expected)
  result.update(status='passed',completed=1,fieldSpellings=len(expected.splitlines()),stdout=done.stdout,cases=[dict(id='live-declaration-facts',passed=True,fieldSpellings=len(expected.splitlines()),stdout=done.stdout)])
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
