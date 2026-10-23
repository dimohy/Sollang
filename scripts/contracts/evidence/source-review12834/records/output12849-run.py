from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
sys.dont_write_bytecode=True
sys.path.insert(0,str(root/'scripts/contracts/evidence/source-review12767'))
from large_layout_storage import observe, verify_helper_source
layoutGuard=root/'scripts/contracts/evidence/source-review12767/large_layout_storage.py'
sys.path.insert(0,str(root/'scripts/contracts/evidence/source-review12834'))
from source_guard import verify as verify_output_sources
verify_output_sources((root/'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs').read_text(encoding='utf-8-sig'),(root/'selfhost/llvm/emitter/text_output_runtime.slg').read_text(encoding='utf-8-sig'))
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'output12849-source';o.mkdir(exist_ok=False)
assert verify_helper_source((root/'selfhost/llvm/text/foundation.slg').read_text(encoding='utf-8-sig'),(root/'scripts/probes/source-review-boundaries/layout-production-helper.slg').read_text(encoding='utf-8-sig'))
cpath=b/'output12848-contract.json';c=json.loads(cpath.read_text(encoding='utf-8-sig'));pre=root/c['preflight'];proof=json.loads(pre.read_text(encoding='utf-8-sig'))
assert proof['status']=='passed' and proof['inputsStable'] and proof['processesStopped'] and proof['codegenInvoked']==False
stdlib= json.loads((b/'output12847-stdlib/result.json').read_text(encoding='utf-8-sig'));assert stdlib['status']=='passed' and stdlib['inputsStable'] and stdlib['processesStopped'] and stdlib['checkedSemanticDiagnosticCount']==0
compiler=b/'managed12836/compiler/Sollang.Compiler.exe'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
assert sha(compiler.with_suffix('.dll'))=='43BD6F07B8FABC546336D36353B3E9529985654AF150FB820275D034955A9750'
sources=[root/c['source']]+[root/p for p in c['additionalSources']]
manifest=root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt';canonical=[root/line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
assert sources[1:]==canonical[1:] and len(sources)==151
for p in canonical:
 assert proof['inputHashes'][str(p)]==sha(p),str(p)
harness=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
formatter=b/'v12432/compiler-build01/compiler.exe'
inputs=[harness,harness.with_suffix('.dll'),harness.with_suffix('.deps.json'),harness.with_suffix('.runtimeconfig.json'),formatter]+sources+[root/p for p in c['stdlibSourceOrder']]+[root/x['source'] for x in c['cases']]+[cpath,Path(__file__),pre,manifest]+list(compiler.parent.glob('Sollang.Compiler.*'))
inputs += [b/'output12847-stdlib/result.json']
inputs += [layoutGuard]+[root/p for p in c['runtimeInputFiles']]
pins={str(p):sha(p) for p in inputs if p.is_file()}
r={'schemaVersion':1,'status':'running','scope':c['scope'],'inputHashes':pins,'completed':0,'total':1,'cases':[],'budget':c['budget'],'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 a=x.run([str(formatter),'format','--check',str(sources[0])],o/'wrapper-format',timeout=30)
 if a.returncode or a.stderr.strip():raise ValueError('WRAPPER_FORMAT_PREFLIGHT_FAILED')
 a=x.run([str(harness),str(compiler.with_suffix('.dll')),*[str(p) for p in sources]],o/'wrapper-semantic',timeout=60)
 if a.returncode or a.stderr.strip():raise ValueError('WRAPPER_SEMANTIC_PREFLIGHT_FAILED: '+a.stderr[:500])
 frontend=json.loads(a.stdout)
 if frontend['warnings'] or frontend['codegenInvoked'] or frontend['sourceCount']!=151:raise ValueError('WRAPPER_FRONTEND_CONTRACT_FAILED')
 r['wrapperPreflight']=frontend;x.save()
 exe=o/'producer.exe';a=x.run([str(compiler),'build',*[str(p) for p in sources],'-o',str(exe),'--target','windows-x64','--keep-temps','--llvm',str(root/'.tools/llvm-22.1.8')],o/'build',timeout=180);r['buildExit']=a.returncode
 if a.returncode or a.stderr.strip():raise ValueError('PRODUCER_BUILD_FAILED: '+a.stderr[:1000])
 r['producerSha256']=sha(exe);r['producerBuildCount']=1
 for case in c['cases']:
  folder=o/case['id'];folder.mkdir();row={'id':case['id'],'status':'running','source':case['source'],'target':case['target']};r['cases'].append(row);x.save()
  a=x.run([str(exe),case['source'],case['target']],folder/'emit',timeout=180);row['emissionExit']=a.returncode
  if case.get('admitted') == False:
   expected='parallel callback SourceText is supported only as a direct top-level tryParallel Result payload'
   if a.returncode != 1 or a.stderr.strip() or a.stdout.count(expected) != 1 or 'target triple =' in a.stdout:raise ValueError('NEGATIVE_ADMISSION_FAILED '+case['id']+a.stdout[:500]+a.stderr[:500])
   row.update(status='passed',admissionRejected=True);r['completed']+=1;x.save();continue
  if a.returncode or a.stderr.strip():raise ValueError('EMISSION_FAILED: '+case['id']+a.stderr[:500])
  llvm=folder/'emitted.ll';llvm.write_bytes((folder/'emit.stdout').read_bytes());row['emittedLlvmSha256']=sha(llvm)
  if case['id'].startswith('layout-'):row.update(observe(llvm.read_text(encoding='utf-8-sig')))
  a=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble',timeout=180);row['assemblyExit']=a.returncode
  if a.returncode or a.stderr.strip():raise ValueError('ASSEMBLY_FAILED: '+case['id']+a.stderr[:500])
  row['status']='passed';r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
