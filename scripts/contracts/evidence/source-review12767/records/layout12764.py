from pathlib import Path
import sys,json,hashlib
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'layout12764-semantic';o.mkdir(exist_ok=False)
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest().upper()
managed=b/'managed12710/compiler/Sollang.Compiler.dll';native=b/'v12757/compiler-build01/compiler.exe';h=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe';proof=read(b/'scratch12755-source/result.json');build=read(native.parent/'result.json');assert build['status']=='passed' and build['compilerSha256']==sha(native)
inputs=list((b/'layout12764-inputs').glob('*.slg'))+[managed,native,h,h.with_suffix('.dll'),h.with_suffix('.deps.json'),h.with_suffix('.runtimeconfig.json'),Path(__file__)]
for p in inputs:
 if str(p) in proof['inputHashes']:assert proof['inputHashes'][str(p)]==sha(p),str(p)
pins={str(p):sha(p) for p in inputs};d={'schemaVersion':1,'status':'running','scope':'Semantic-only observations on three tiny unused type declarations; no LLVM code generation, backing storage allocation or program execution. Observation completion is not positive qualification.','inputHashes':pins,'completed':0,'total':3,'cases':[],'codegenInvoked':False,'claimsGoalComplete':False};x=VerificationExecution(r,o,d,lambda:all(Path(p).is_file() and sha(Path(p))==v for p,v in pins.items()),sha);err=None
try:
 for p in sorted((b/'layout12764-inputs').glob('*.slg')):
  a=x.run([str(h),str(managed),str(p)],o/(p.stem+'-csharp'),timeout=15);j=json.loads(a.stdout);assert j['codegenInvoked']==False
  z=x.run([str(native),'validate',str(p)],o/(p.stem+'-native'),timeout=15)
  assert 'target triple' not in z.stdout and 'define ' not in z.stdout
  d['cases'].append({'id':p.stem,'source':str(p),'csharpExit':a.returncode,'csharpStdout':a.stdout,'csharpStderr':a.stderr,'nativeExit':z.returncode,'nativeStdout':z.stdout,'nativeStderr':z.stderr});d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
print(json.dumps({'status':d['status'],'cases':d['cases'],'inputsStable':d.get('inputsStable'),'processesStopped':d.get('processesStopped')}))
