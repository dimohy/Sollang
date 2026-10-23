from pathlib import Path
import json,hashlib,sys,re
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'representation12726';o.mkdir(exist_ok=False);source=b/'scratch12720-source/1486-interpolation-capacity-receivers/emitted.ll';opt=r/'.tools/llvm-22.1.8/bin/opt.exe'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
pins={str(p):sha(p) for p in [Path(__file__),source,opt,b/'scratch12720-source/result.json']}
d={'schemaVersion':1,'status':'running','scope':'Existing LLVM dead-code elimination confirms checked-emission unused entry scratch reservations are removable. No byte-identical frame/performance claim; diagnostic only, no goal count.','inputHashes':pins,'completed':0,'total':1,'cases':[],'claimsGoalComplete':False};x=VerificationExecution(r,o,d,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 text=source.read_text();names=re.findall(r'(%calltext[0-9]+_arg[0-9]+_root[0-9]+_buffer) = alloca',text);assert len(names)==43 and all(len(re.findall(re.escape(n)+r'\b',text))==1 for n in names)
 target=o/'dead-code-eliminated.ll';a=x.run([str(opt),'-passes=dce','-S',str(source),'-o',str(target)],o/'opt',timeout=60)
 if a.returncode or a.stderr.strip():raise ValueError('DCE_FAILED '+a.stderr)
 out=target.read_text();assert all(n not in out for n in names)
 d['cases']=[{'id':'unused-entry-scratch','status':'passed','passed':True,'optimizationExit':0,'removedReservationCount':43,'outputSha256':sha(target)}];d.update(status='passed',completed=1)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
