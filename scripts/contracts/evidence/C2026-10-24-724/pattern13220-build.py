from pathlib import Path
import sys,json,hashlib
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
source=b/'pattern13216-source/result.json';p=json.loads(source.read_text(encoding='utf-8-sig'))
assert p['status']=='passed' and p['completed']==p['total']==23 and p['inputsStable'] and p['processesStopped']
for path,h in p['inputHashes'].items():assert sha(path)==h,path
positive=[row for row in p['cases'] if row.get('nativeRunExit')==0 and row.get('passed') is True]
negative=[row for row in p['cases'] if row.get('admissionRejected') is True]
assert len(positive)==16 and len(negative)==7
pins=dict(p['inputHashes']);pins[str(source)]=sha(source)
producer=Path(p['producerPath']);assert sha(producer)==p['producerSha256'];pins[str(producer)]=sha(producer)
for row in positive:
    folder=b/'pattern13216-source'/row['id']
    assert sha(folder/'emitted.ll')==row['emittedLlvmSha256']
    for name in ['emitted.ll','emitted.exe','emitted.bc','run.stdout','run.stderr']:pins[str(folder/name)]=sha(folder/name)
runtime=dict(schemaVersion=1,status='passed',mode='managed',scope='Projection of sixteen actual current checked-emitter LLVM/assembly/link/runtime executions; no additional execution or compiler-image acceptance claimed.',inputHashes=pins,completed=16,total=16,cases=positive,semanticPreflight=p['semanticPreflight'],inputsStable=True,processesStopped=True,sourceExecutionRecord=str(source),sourceExecutionSha256=sha(source),claimsGoalComplete=False)
projection=b/'pattern13216-source/positive-runtime-proof.json';assert projection.is_file();assert json.loads(projection.read_text(encoding='utf-8-sig'))==runtime
out=b/'pattern13220-native-build';out.mkdir(exist_ok=False)
inputs=[Path(path) for path in pins]+[projection,Path(__file__),b/'pattern13220-build.ps1',b/'pattern13217-managed/result.json',b/'pattern13214-stdlib/result.json']+list((r/'scripts').glob('*.ps1'))+list((r/'scripts/contracts').glob('*.json'))
build_pins={str(path):sha(path) for path in inputs if path.is_file()}
j=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=build_pins,scope='One fresh current-source image after CSharp23, source23/runtime16, semantic13 and full stdlib144 passed. Native focused and original whole gates remain pending.',budget={'compilerImageBuilds':1,'previousAdmissionAttempts':1,'previousCompilerImageBuilds':0,'admissionCorrection':'C725 forwards canonical protected roots; no compiler/stdlib/semantic guards relaxed','timeoutSeconds':600,'jobs':4,'optimization':'O1','cacheSeed':None,'retryCount':0},claimsGoalComplete=False)
x=VerificationExecution(r,out,j,lambda:all(sha(path)==h for path,h in build_pins.items()),sha);error=None
try:
    a=x.run(['pwsh','-NoProfile','-File',str(b/'pattern13220-build.ps1')],out/'check',timeout=600)
    j.update(actualExit=a.returncode,stdout=a.stdout,stderr=a.stderr)
    if a.returncode:raise ValueError('CURRENT_IMAGE_BUILD_FAILED '+a.stderr[-1500:])
    j.update(status='passed',completed=1)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:j.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if j['status']!='passed':raise SystemExit(1)
