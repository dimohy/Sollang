from pathlib import Path
import sys,json,hashlib,shutil
sys.dont_write_bytecode=True;r=Path.cwd();sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'output12856-native';o.mkdir(exist_ok=False);compiler=b/'v12855/compiler-build01/compiler.exe';source=r/'scripts/probes/source-review-boundaries/windows-output-streams.slg';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));expected='F655097C46491F9C78F591E9F86B13AEF48DE03E57143FFE7CC21B6EFE5AC095';assert sha(compiler)==expected;build=read(compiler.parent/'result.json');assert build['status']=='passed' and build['inputsStable'] and build['compilerSha256']==expected
for name in ['output12853-managed.json','output12854-source.json']:
 d=read(b/name);assert d['status']=='passed' and d['completed']==d['total']==55 and d['inputsStable'] and d['processesStopped']
pwsh=Path(shutil.which('pwsh'));adapter=b/'scratch12644-build.ps1';inputs=[Path(__file__),compiler,compiler.parent/'result.json',source,pwsh,adapter,b/'output12853-managed.json',b/'output12854-source.json']+list((r/'stdlib').rglob('*.slg'))+[Path(p) for p in build['inputHashesEnd'] if Path(p).is_relative_to(r/'selfhost')]+[r/'scripts'/p for p in ['verification-compiler-build.ps1','verification-process.ps1','contracts/verification-compiler-build.json']]
pins={str(p):sha(p) for p in inputs};record={'schemaVersion':1,'status':'running','scope':'C713 fresh native normal Unicode output; exact stdoutLF/stderrCRLF bytes.31+23 helper cases separate.','compilerSha256':expected,'inputHashes':pins,'completed':0,'total':1,'cases':[],'claimsGoalComplete':False};x=VerificationExecution(r,o,record,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 exe=o/'streams.exe';a=x.run([str(pwsh),'-NoProfile','-File',str(adapter),'-Compiler',str(compiler),'-Source',str(source),'-Output',str(exe)],o/'build',timeout=125);assert a.returncode==0 and not a.stderr.strip(),a.stderr
 a=x.run([str(exe)],o/'normal',timeout=5);assert a.returncode==0
 assert (o/'normal.stdout').read_bytes()=='stdout 한글🙂\n'.encode()
 assert (o/'normal.stderr').read_bytes()=='stderr 한글🙂\r\n'.encode()
 record.update(status='passed',completed=1,cases=[{'id':'streams','status':'passed','passed':True,'buildExit':0,'runExit':a.returncode,'stdout':a.stdout,'stderr':a.stderr,'rawStdoutSha256':sha(o/'normal.stdout'),'rawStderrSha256':sha(o/'normal.stderr'),'emittedLlvmSha256':sha(o/'streams.exe.ll'),'programSha256':sha(exe)}])
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
