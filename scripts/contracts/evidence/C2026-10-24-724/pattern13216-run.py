from pathlib import Path
import sys, json, hashlib
root=Path.cwd(); sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_stdlib_source_preflight import validate
b=root/'artifacts/scratch/resume-20261006-owner-continuation22'
cp=b/'pattern13216-contract.json';c=json.loads(cp.read_text());out=b/'pattern13216-source';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
stdlib=root/c['stdlibSourceProof'];validate(root,stdlib)
managed=root/c['managedProof'];mp=json.loads(managed.read_text(encoding='utf-8-sig'))
observation=root/c['sourceObservation'];op=json.loads(observation.read_text(encoding='utf-8-sig'))
assert mp['status']=='passed' and mp['completed']==mp['total']==6 and mp['inputsStable'] and mp['processesStopped']
assert op['status']=='passed' and op['completed']==op['total']==6 and op['inputsStable'] and op['processesStopped']
array_mp=json.loads((root/c['managedArrayProof']).read_text(encoding='utf-8-sig'))
array_sem=json.loads((root/c['arraySemanticProof']).read_text(encoding='utf-8-sig'))
assert array_mp['status']=='passed' and array_mp['completed']==array_mp['total']==17 and array_mp['inputsStable'] and array_mp['processesStopped']
assert array_sem['status']=='passed' and array_sem['completed']==array_sem['total']==7 and array_sem['inputsStable'] and array_sem['processesStopped']
for proof in [mp,op,array_mp,array_sem]:
    for name,h in proof['inputHashes'].items():assert sha(name)==h,name
compiler=b/'managed13056/compiler/Sollang.Compiler.exe';harness=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe';formatter=b/'v12432/compiler-build01/compiler.exe'
manifest=root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
canonical=[root/line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
sources=[root/c['producer']]+canonical[1:]
inputs=sources+[root/x['source'] for x in c['cases']]+[cp,stdlib,managed,observation,root/c['managedArrayProof'],root/c['arraySemanticProof'],manifest,Path(__file__),formatter]+list(compiler.parent.glob('Sollang.Compiler.*'))+list(harness.parent.glob('SemanticPreflight.*'))+list((root/'stdlib').rglob('*.slg'))
pins={str(p):sha(p) for p in inputs if p.is_file()}
j={'schemaVersion':1,'status':'running','mode':'managed','scope':c['scope'],'inputHashes':pins,'completed':0,'total':23,'cases':[],'budget':c['budget'],'claimsGoalComplete':False}
x=VerificationExecution(root,out,j,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
    a=x.run([str(formatter),'format','--check',str(sources[0])],out/'format',timeout=30)
    if a.returncode or a.stderr.strip():raise ValueError('C723_EMITTER_FORMAT_FAILED '+a.stderr[:1000])
    a=x.run([str(harness),str(compiler.with_suffix('.dll')),*map(str,sources)],out/'frontend',timeout=60)
    if a.returncode or a.stderr.strip():raise ValueError('C723_EMITTER_FRONTEND_FAILED '+a.stderr[:1000])
    f=json.loads(a.stdout)
    if f['warnings'] or f['codegenInvoked'] or f['sourceCount']!=151:raise ValueError('C723_EMITTER_FRONTEND_CONTRACT '+json.dumps(f))
    j['semanticPreflight']={'status':'passed-current-source','codegenInvoked':False,'evidenceReference':str(out/'frontend.stdout')};x.save()
    exe=out/'producer.exe';j['producerPath']=str(exe)
    a=x.run([str(compiler),'build',*map(str,sources),'-o',str(exe),'--target','windows-x64','--keep-temps','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')],out/'build',timeout=180)
    if a.returncode or a.stderr.strip():raise ValueError('C723_EMITTER_BUILD_FAILED '+a.stderr[:1000])
    j['producerSha256']=sha(exe);j['producerBuildCount']=1;x.save()
    for case in c['cases']:
        folder=out/case['id'];folder.mkdir();row={'id':case['id'],'status':'running'};j['cases'].append(row);x.save()
        a=x.run([str(exe),case['source'],'windows'],folder/'emit',timeout=180);row['emissionExit']=a.returncode
        if case['exit']==1:
            if a.returncode!=1 or a.stderr.strip() or a.stdout.strip()!=case['stderr'] or 'target triple =' in a.stdout:raise ValueError('C723_NEGATIVE_ADMISSION_MISMATCH '+case['id']+' '+a.stdout[:600]+a.stderr[:300])
            row.update(status='passed',admissionRejected=True);j['completed']+=1;x.save();continue
        if a.returncode or a.stderr.strip():raise ValueError('C723_EMISSION_FAILED '+case['id']+' '+a.stdout[:500]+a.stderr[:500])
        llvm=folder/'emitted.ll';llvm.write_bytes((folder/'emit.stdout').read_bytes());row['emittedLlvmSha256']=sha(llvm)
        a=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble',timeout=120)
        row['assemblyExit']=a.returncode
        if a.returncode or a.stderr.strip():raise ValueError('C723_ASSEMBLY_FAILED '+case['id']+' '+a.stderr[:500])
        native=folder/'emitted.exe';a=x.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O0','-o',str(native),'-lws2_32','-lshell32','-lbcrypt','-lole32'],folder/'link',timeout=120);row['nativeLinkExit']=a.returncode
        if a.returncode or a.stderr.strip():raise ValueError('C723_LINK_FAILED '+case['id']+' '+a.stderr[:500])
        a=x.run([str(native)],folder/'run',timeout=10);row.update(nativeRunExit=a.returncode,nativeRunStdout=a.stdout,nativeRunStderr=a.stderr)
        if a.returncode or a.stderr or a.stdout.replace('\r\n','\n')!=case['runtimeStdout']:raise ValueError('C723_RUNTIME_MISMATCH '+case['id']+' '+repr(a.stdout))
        row.update(status='passed',passed=True);j['completed']+=1;x.save()
    j['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:j.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if j['status']!='passed':raise SystemExit(1)
