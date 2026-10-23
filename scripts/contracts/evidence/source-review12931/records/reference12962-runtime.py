from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';source=b/'reference12961-source';o=b/'reference12962-runtime';o.mkdir(exist_ok=False)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
pre=source/'result.json';proof=read(pre);cp=b/'reference12960-contract.json';c=read(cp)
assert proof['status']=='passed' and proof['completed']==proof['total']==7 and proof['inputsStable'] and proof['processesStopped']
pins=dict(proof['inputHashes']);clang=root/'.tools/llvm-22.1.8/bin/clang.exe'
for p in [Path(__file__),pre,cp,source/'producer.exe',clang]+[source/case['id']/'emitted.ll' for case in c['cases'] if case.get('admitted') != False]:pins[str(p)]=sha(p)
for case,row in zip(c['cases'],proof['cases']):
 assert case['id']==row['id']
 if case.get('admitted') != False:assert sha(source/case['id']/'emitted.ll')==row['emittedLlvmSha256']
r={'schemaVersion':1,'status':'running','mode':'managed','scope':'C716/C717 source normal3 compiled and executed; four exact rejection controls are in the parent seven-case emission proof.','inputHashes':pins,'completed':0,'total':3,'semanticPreflight':{'status':'passed-current-source','codegenInvoked':False,'evidenceReference':str(b/'reference12958-preflight/result.json')},'cases':[],'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for case in c['cases']:
  if case.get('admitted') == False:continue
  llvm=source/case['id']/'emitted.ll';exe=o/(case['id']+'.exe')
  a=x.run([str(clang),'-Wno-override-module',str(llvm),'-O0','-o',str(exe),'-lws2_32','-lshell32','-lbcrypt','-lole32'],o/(case['id']+'-link'),timeout=120)
  row={'id':case['id'],'status':'running','assemblyExit':0,'nativeLinkExit':a.returncode,'emittedLlvmSha256':sha(llvm)};r['cases'].append(row);x.save()
  if a.returncode or a.stderr.strip():raise ValueError('LINK_FAILED '+case['id']+a.stderr)
  a=x.run([str(exe)],o/(case['id']+'-run'),timeout=10)
  row.update(runExit=a.returncode,nativeRunExit=a.returncode,stdout=a.stdout,nativeRunStdout=a.stdout,stderr=a.stderr)
  if a.returncode!=case['exit'] or a.stdout.replace('\r\n','\n')!=case['stdout'] or a.stderr.replace('\r\n','\n')!=case['stderr']:raise ValueError('RUNTIME_ORACLE_FAILED '+case['id'])
  row.update(status='passed',passed=True);r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
