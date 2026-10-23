from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'literal13151-nested-check';o.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
compiler=b/'managed13056/compiler/Sollang.Compiler.exe';source=b/'literal13151-nested-count.slg';mini=b/'literal13141-semantic/semantic.exe';base=json.loads((mini.parent/'result.json').read_text());assert base['status']=='passed' and base['inputsStable'] and base['processesStopped']
pins=dict(base['inputHashes']);pins.update({str(p):sha(p) for p in [source,mini,Path(__file__)]});r={'schemaVersion':1,'status':'running','scope':'Check nested fixed literal extent using current CSharp then already-built actual SLG semantic driver. Diagnostic-only; not full admission.','inputHashes':pins,'completed':0,'total':2,'claimsGoalComplete':False};x=VerificationExecution(root,o,r,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 a=x.run([str(compiler),'build',str(source),'-o',str(o/'probe.exe'),'--target','windows-x64','--keep-temps','--jobs','1','--llvm',str(root/'.tools/llvm-22.1.8')],o/'managed',timeout=180);r['managed']={'exit':a.returncode,'stdout':a.stdout,'stderr':a.stderr};x.save()
 assert a.returncode==1 and 'fixed array expects 2 elements, got 1' in a.stderr and not (o/'probe.exe.ll').exists()
 r['completed']=1;x.save()
 a=x.run([str(mini),str(source.relative_to(root))],o/'semantic',timeout=180);r['semantic']={'exit':a.returncode,'stdout':a.stdout,'stderr':a.stderr};x.save()
 assert a.returncode==0 and not a.stderr.strip()
 values=[int(v) for v in a.stdout.strip().splitlines()];assert values[:3]==[41,1,2],values
 r.update(status='passed',completed=2)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure','managed','semantic']}))
if r['status']!='passed':raise SystemExit(1)
