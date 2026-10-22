from pathlib import Path
import sys,json,hashlib,importlib.util
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'owner12351-source';o.mkdir(exist_ok=False)
cpath=b/'owner12351-contract.json';c=json.loads(cpath.read_text(encoding='utf-8-sig'));proof=json.loads((b/'owner12351-preflight/result.json').read_text(encoding='utf-8-sig'))
assert proof['status']=='passed' and proof['inputsStable'] and proof['processesStopped']
producer=c['reusableCheckedProducer'];sources=[root/producer['source']]+[root/p for p in producer['additionalSources']]
compiler=b/'managed12260/bin/Sollang.Compiler.exe'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=sources+[root/p for p in producer['stdlibSourceOrder']]+[root/x['programSource'] for x in c['cases']]+[cpath,Path(__file__),b/'owner12351-preflight/result.json']+list(compiler.parent.glob('Sollang.Compiler.*'))
pins={str(p):sha(p) for p in inputs if p.is_file()}
r={'schemaVersion':1,'status':'running','scope':'One canonical SLG checked producer: three full runtime controls, two negative semantic controls, original L06 Windows LLVM assembly check. Public runtime is not performed by this batch.','inputHashes':pins,'completed':0,'total':6,'cases':[],'budget':{'producerBuilds':1,'emissions':6,'buildTimeoutSeconds':180,'emissionTimeoutSeconds':180,'publicRuntimeRuns':0},'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None

def run(command,prefix,timeout=180):
 if not x.stable():raise ValueError('INPUT_DRIFT_BEFORE_COMMAND')
 return x.run(command,prefix,timeout=timeout)
try:
 spec=importlib.util.spec_from_file_location('validator',root/'scripts/verify-checked-package-emitter.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v);v.validate_reusable(c,root)
 exe=o/'producer.exe';a=run([str(compiler),'build',*[str(p) for p in sources],'-o',str(exe),'--target','windows-x64','--keep-temps','--llvm',str(root/'.tools/llvm-22.1.8')],o/'build');r['buildExit']=a.returncode
 if a.returncode or a.stderr.strip():raise ValueError('PRODUCER_BUILD_FAILED: '+a.stderr[:300])
 r['producerSha256']=sha(exe);r['producerBuildCount']=1
 for case in c['cases']:
  folder=o/case['id'];folder.mkdir();row={'id':case['id'],'programSource':case['programSource'],'status':'running','scope':'public-assembly-only' if case['id'].startswith('public-') else 'runtime' if case['emittedLlvm'] else 'negative-semantic'};r['cases'].append(row);x.save()
  a=run([str(exe),case['programSource']],folder/'emit');row['emissionExit']=a.returncode
  if a.returncode or a.stderr.strip():raise ValueError('EMISSION_PROCESS_FAILED: '+case['id'])
  if not case['emittedLlvm']:
   if a.stdout.strip()!=case['stdout']:raise ValueError('NEGATIVE_DIAGNOSTIC_MISMATCH: '+case['id'])
  else:
   llvm=folder/'emitted.ll';llvm.write_bytes((folder/'emit.stdout').read_bytes());row['llvmSha256']=sha(llvm)
   a=run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble');row['assemblyExit']=a.returncode
   if a.returncode or a.stderr.strip():raise ValueError('LLVM_ASSEMBLY_FAILED: '+case['id'])
   row['entryPoint']=v.validate_emitted_entrypoint(llvm.read_text(encoding='utf-8-sig'),'windows')
   if row['scope']=='runtime':
    binary=folder/'emitted.exe';a=run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O1','-o',str(binary),'-lws2_32','-lshell32','-lbcrypt','-lole32'],folder/'link');row['linkExit']=a.returncode
    if a.returncode or a.stderr.strip():raise ValueError('LINK_FAILED: '+case['id'])
    a=run([str(binary)],folder/'runtime');row['runtimeExit']=a.returncode;row['runtimeStdout']=a.stdout.strip()
    if a.returncode or a.stderr.strip() or a.stdout.strip()!=case['stdout']:raise ValueError('RUNTIME_ORACLE_FAILED: '+case['id'])
  row['status']='passed';r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
