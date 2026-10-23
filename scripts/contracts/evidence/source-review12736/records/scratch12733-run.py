from pathlib import Path
import sys,json,hashlib,re,shutil
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';backend=sys.argv[1];assert backend in ['managed','native'];o=b/('scratch12733-'+backend)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cpath=b/'scratch12733-cases.json';c=read(cpath);compiler=b/('managed12710/compiler/Sollang.Compiler.exe' if backend=='managed' else 'v12722/compiler-build01/compiler.exe')
expected='95E8C2ABA0F8F3EB7AF9A3D959C21D9D8FCFA388C16C809ACFEA842D7D8FFD15' if backend=='managed' else '176259CF34B20130F13FF2B7C5FB1D77AD044F6BE9693D9B54AAC519C8B3909B'
identity=compiler.with_suffix('.dll') if backend=='managed' else compiler
assert sha(identity)==expected
formatter=b/'v12432/compiler-build01/compiler.exe'
inputs=[Path(__file__),cpath,compiler,identity,formatter]+[root/row['source'] for row in c['cases']]+list((root/'stdlib').rglob('*.slg'))+[root/'.tools/llvm-22.1.8/bin'/name for name in ['clang.exe','llvm-as.exe','llvm-link.exe','opt.exe','llc.exe']]
if backend=='native':
 pre=b/'scratch12733-managed/result.json';d=read(pre);assert d['status']=='passed' and d['completed']==d['total']==len(c['cases']) and d['inputsStable'] and d['processesStopped'];inputs.append(pre)
 buildpath=compiler.parent/'result.json';build=read(buildpath);assert build['status']=='passed' and build['inputsStable'] and build['compilerSha256']==expected
 inputs.append(buildpath)
 inputs += [Path(p) for p in build['inputHashesEnd'] if Path(p).is_relative_to(root/'selfhost')]
else:inputs += list(compiler.parent.glob('Sollang.Compiler.*'))
adapter=b/'scratch12644-build.ps1';pwsh=Path(shutil.which('pwsh'));inputs += [adapter,pwsh]+[root/'scripts'/p for p in ['verification-compiler-build.ps1','verification-process.ps1','contracts/verification-compiler-build.json']]
pins={str(p):sha(p) for p in inputs if p.is_file()};assert all(p.is_file() for p in inputs)
o.mkdir(exist_ok=False)
r={'schemaVersion':1,'status':'running','backend':backend,'scope':c['scope'],'compilerIdentitySha256':expected,'inputHashes':pins,'completed':0,'total':len(c['cases']),'cases':[],'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for case in c['cases']:
  a=x.run([str(formatter),'format','--check',case['source']],o/(case['id']+'-format'),timeout=30)
  if a.returncode or a.stderr.strip():raise ValueError('FORMAT_FAILED '+case['id']+a.stderr)
 for case in c['cases']:
  exe=o/(case['id']+'.exe');a=x.run([str(pwsh),'-NoProfile','-File',str(adapter),'-Compiler',str(compiler),'-Source',str(root/case['source']),'-Output',str(exe)],o/(case['id']+'-build'),timeout=125)
  row={'id':case['id'],'status':'running','buildExit':a.returncode,'expectedStdout':case['stdout']};r['cases'].append(row);x.save()
  if a.returncode or a.stderr.strip():raise ValueError('BUILD_FAILED '+case['id']+a.stderr)
  llvm=exe.with_suffix('.exe.ll');text=llvm.read_text(encoding='utf-8-sig');block='';function='';allocations=[]
  for line in text.splitlines():
   if line.startswith('define '):function=line
   if re.match(r'^[\w.$-]+:',line):block=line.split(':',1)[0]
   if ' = alloca ' in line:allocations.append({'function':function,'block':block,'instruction':line.strip()})
  a=x.run([str(exe)],o/(case['id']+'-run'),timeout=3);row.update(runExit=a.returncode,stdout=a.stdout,stderr=a.stderr,emittedLlvmSha256=sha(llvm),allocationObservations=allocations)
  if a.returncode!=case['exit'] or a.stdout.replace('\r\n','\n')!=case['stdout'] or a.stderr.replace('\r\n','\n')!=case['stderr']:raise ValueError('ORACLE_FAILED '+case['id'])
  row.update(status='passed',passed=True);r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
