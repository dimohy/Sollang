from pathlib import Path
import sys,json,hashlib,re
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'block15124-native20';o.mkdir(exist_ok=False)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cpath=b/'scratch12691-contract.json';c=read(cpath);compiler=b/'v14775/compiler-build01/compiler.exe';buildpath=compiler.parent/'result.json';build=read(buildpath)
expected=build['compilerSha256']
assert build['status']=='passed' and build['inputsStable'] and build['inputHashesStart']==build['inputHashesEnd'] and build['compilerSha256']==sha(compiler)==expected
d=read(b/'block15123-managed-full20.json');assert d['status']=='passed' and d['completed']==d['total']==20 and d['inputsStable'] and d['processesStopped']
managed={row['id']:row for row in d['cases']}
for case in c['cases']:assert managed[case['id']]['stdout']==case['stdout'] and managed[case['id']]['passed']
from verification_source_proof import current_build_inputs
pins={str(p):sha(p) for p in current_build_inputs(root,build)}
for p,h in d['inputHashes'].items():assert sha(p)==h,p
for p in [Path(__file__),cpath,compiler,buildpath]+[root/row['source'] for row in c['cases']]+[b/'block15123-managed-full20.json',b/'block15123-source-comparison.json']:pins[str(p)]=sha(p)
r={'schemaVersion':1,'status':'running','scope':'Current retained NativeF90 original20 replay with exact original flags, source/oracles, build120s/run3s. Current CSharp20 raw full output checked first; source producer20 separately pending. No new compiler build.','compilerSha256':expected,'inputHashes':pins,'completed':0,'total':20,'cases':[],'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for case in c['cases']:
  exe=o/(case['id']+'.exe');a=x.run([str(compiler),'build',str(root/case['source']),'-o',str(exe),'--target','windows-x64','--stdlib',str(root/'stdlib'),'--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8'),'--keep-temps'],o/(case['id']+'-build'),timeout=120)
  row={'id':case['id'],'status':'running','expectedBuildExit':0,'buildExit':a.returncode,'expectedRunExit':case['exit'],'expectedStdout':case['stdout'],'expectedStderr':case['stderr']};r['cases'].append(row);x.save()
  if a.returncode or a.stderr.strip():raise ValueError('NATIVE_BUILD_FAILED '+case['id']+a.stderr)
  llvm=exe.with_suffix('.exe.ll');text=llvm.read_text(encoding='utf-8-sig');block=None;function='';allocations=[]
  for line in text.splitlines():
   if line.startswith('define '):function=line
   if re.match(r'^[\w.$-]+:',line):block=line.split(':',1)[0]
   if ' = alloca ' in line and ('@main(' in function or '@sollang_m144_' in function):allocations.append({'function':function,'block':block,'instruction':line.strip()})
  a=x.run([str(exe)],o/(case['id']+'-run'),timeout=3);row.update(runExit=a.returncode,stdout=a.stdout,stderr=a.stderr,emittedLlvmSha256=sha(llvm),allocationObservations=allocations)
  if a.returncode!=case['exit'] or a.stdout.replace('\r\n','\n')!=case['stdout'] or a.stderr.replace('\r\n','\n')!=case['stderr']:raise ValueError('NATIVE_ORACLE_FAILED '+case['id'])
  row.update(status='passed',passed=True);r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
