from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'yield22021-csharp-controls';CPP=B/'managed21997/compiler/Sollang.Compiler.exe';contractPath=ROOT/'scripts/contracts/evidence/source13293/yield22019-input-contract/controls.json';contract=json.loads(contractPath.read_text(encoding='utf-8-sig'));cases=[contract['positive'],*contract['negative']];assert [c['id'] for c in cases]==['P1','N1']
paths=[Path(__file__),CPP,*managed_runtime_inputs(CPP),contractPath,ROOT/'scripts/contracts/inherent-block-method-parity.schema.json',ROOT/'scripts/verify-llvm-direct-call-closure.ps1',*[ROOT/c[k] for c in cases for k in ['source','expected']],*sorted((ROOT/'stdlib').rglob('*.slg'))];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(list(map(Path,inputs))):
 result=dict(schemaVersion=1,status='running',completed=0,total=2,cases=[],inputHashes=inputs,maximumCaseSeconds=180,scope='Current CSharp scalar/transformed readonly yield inputs and later producer failure order.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  for case in cases:
   label=case['id'];exe=OUT/(label+'.exe');ll=Path(str(exe)+'.ll');expected=(ROOT/case['expected']).read_text(encoding='utf-8-sig').strip();command=[str(CPP),'build',str(ROOT/case['source']),'-o',str(exe),'--target','windows-x64','--llvm',str(ROOT/'.tools/llvm-22.1.8'),'--jobs','24','-O2']
   if label=='P1':command.append('--keep-temps')
   done=ex.run(command,OUT/(label+'-build'),timeout=budget())
   if label=='P1':
    assert done.returncode==0 and not done.stderr,done.stdout+done.stderr
    done=ex.run([str(exe)],OUT/(label+'-run'),timeout=budget());assert done.returncode==0 and not done.stderr and done.stdout.strip()==expected,(done.returncode,done.stdout,done.stderr,expected)
    done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(OUT/'P1.bc')],OUT/'assemble',timeout=budget());assert done.returncode==0 and not done.stderr,done.stderr
    done=ex.run(['pwsh','-NoProfile','-File',str(ROOT/'scripts/verify-llvm-direct-call-closure.ps1'),'-LlvmPath',str(ll)],OUT/'closure',timeout=budget());assert done.returncode==0,done.stdout+done.stderr
   else:
    assert done.returncode!=0 and not done.stdout and len(done.stderr.strip().splitlines())==1 and expected in done.stderr and not exe.exists() and not ll.exists(),(done.returncode,done.stdout,done.stderr,expected)
   result['cases'].append(dict(id=label,passed=True));result['completed']+=1
  result['status']='passed'
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
print(json.dumps({k:result.get(k) for k in ['status','completed','total','inputsStable','processesStopped']}))
