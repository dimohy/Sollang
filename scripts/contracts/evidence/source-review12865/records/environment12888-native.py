from pathlib import Path
import sys,json,hashlib,shutil
sys.dont_write_bytecode=True;r=Path.cwd();sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'environment12888-native';o.mkdir(exist_ok=False);compiler=b/'v12885/compiler-build01/compiler.exe';source=r/'examples/regression/84-process-environment.slg';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));expected='988B064ABB0E4B1366C76D550ECCC009AE5B17BD2C90E7BED471B474DA95897F';assert sha(compiler)==expected;build=read(compiler.parent/'result.json');assert build['status']=='passed' and build['inputsStable'] and build['compilerSha256']==expected
for name in ['environment12883-managed.json','environment12884-source.json']:
 d=read(b/name);assert d['status']=='passed' and d['completed']==d['total']==25 and d['inputsStable'] and d['processesStopped']
pwsh=Path(shutil.which('pwsh'));adapter=b/'scratch12644-build.ps1';inputs=[Path(__file__),compiler,compiler.parent/'result.json',source,pwsh,adapter,b/'environment12883-managed.json',b/'environment12884-source.json']+list((r/'stdlib').rglob('*.slg'))+[Path(p) for p in build['inputHashesEnd'] if Path(p).is_relative_to(r/'selfhost')]+[r/'scripts'/p for p in ['verification-compiler-build.ps1','verification-process.ps1','contracts/verification-compiler-build.json']]
inputs += [r/'scripts/probes/run-environment-fixture.py',r/'examples/regression/expected/84-process-environment.env.txt',r/'examples/regression/expected/84-process-environment.stdout.txt']
pins={str(p):sha(p) for p in inputs};record={'schemaVersion':1,'status':'running','scope':'C714 fresh native existing84 child-only synthetic environment; helper24 separate.','compilerSha256':expected,'inputHashes':pins,'completed':0,'total':1,'cases':[],'claimsGoalComplete':False};x=VerificationExecution(r,o,record,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 exe=o/'environment.exe';a=x.run([str(pwsh),'-NoProfile','-File',str(adapter),'-Compiler',str(compiler),'-Source',str(source),'-Output',str(exe)],o/'build',timeout=125);assert a.returncode==0 and not a.stderr.strip(),a.stderr
 a=x.run([sys.executable,'-X','utf8',str(r/'scripts/probes/run-environment-fixture.py'),str(exe),str(r/'examples/regression/expected/84-process-environment.env.txt')],o/'normal',timeout=10);assert a.returncode==0
 assert (o/'normal.stdout').read_bytes()==(r/'examples/regression/expected/84-process-environment.stdout.txt').read_text(encoding='utf-8-sig').encode()
 assert (o/'normal.stderr').read_bytes()==b''
 record.update(status='passed',completed=1,cases=[{'id':'environment84','status':'passed','passed':True,'buildExit':0,'runExit':a.returncode,'stdout':a.stdout,'stderr':a.stderr,'rawStdoutSha256':sha(o/'normal.stdout'),'rawStderrSha256':sha(o/'normal.stderr'),'emittedLlvmSha256':sha(o/'environment.exe.ll'),'programSha256':sha(exe)}])
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
