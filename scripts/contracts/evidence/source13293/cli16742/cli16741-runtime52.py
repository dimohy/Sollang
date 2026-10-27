from pathlib import Path
import json,sys,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
b=root/'artifacts/scratch/resume-20261006-owner-continuation22'
strict=b/'cli16731-native9/87bc35592029e47c5b47/runner/result.json'
original=json.loads(strict.read_text(encoding='utf-8-sig'));assert original['status']=='failed'
process=original['processes'][0];assert process['role']=='compile' and process['exit']==0 and process['shutdownConfirmed']
command=process['command'];program=Path(command[command.index('-o')+1]);llvm=program.with_suffix(program.suffix+'.ll')
fixture=b/'runner16643-fixture';oracle=fixture/'examples/regression/expected/52-multi-file-modules.stdout.txt'
paths=[Path(__file__),strict,Path(original['cases'][0]['resultPath']),program,llvm,oracle,*map(Path,original['fixtureInputHashes'])]
paths=list(dict.fromkeys(paths));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
out=b/'cli16741-runtime52';out.mkdir(exist_ok=False)
with VerificationContractLease(paths):
 pins={str(p):sha(p) for p in paths};r=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,cases=[],scope='Execute the retained exact original52 program after successful current Native compilation. Its strict LLVM structural assertion remains failed; this separate runtime observation cannot replace or promote the original test.',strictOriginalResult=str(strict),strictOriginalStatus='failed',claimsOriginalPassed=False,claimsGoalComplete=False)
 x=VerificationExecution(fixture,out,r,lambda:all(Path(p).is_file() and sha(p)==v for p,v in pins.items()),sha);error=None
 try:
  observed=x.run([str(program)],out/'runtime',timeout=180)
  actual=(out/'runtime.stdout').read_text(encoding='utf-8-sig').replace('\r\n','\n').strip();expected=oracle.read_text(encoding='utf-8-sig').replace('\r\n','\n').strip();stderr=(out/'runtime.stderr').read_text(encoding='utf-8-sig')
  ok=observed.returncode==0 and not stderr and actual==expected;r['cases'].append(dict(id='retained-original52-runtime',status='passed' if ok else 'failed',passed=ok,exit=observed.returncode,actualStdout=actual,expectedStdout=expected,stderr=stderr))
  if not ok:raise ValueError('C741_ORIGINAL52_RUNTIME_DIFFERENCE')
  r.update(status='passed',completed=1)
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
