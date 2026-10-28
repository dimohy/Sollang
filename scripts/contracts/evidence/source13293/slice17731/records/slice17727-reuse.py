from pathlib import Path
import hashlib, importlib.util, json, sys

r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_stdlib_source_preflight import validate
from completed_artifact_plan import initialize_output, cleanup_output

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def read(p): return Path(p).read_text(encoding='utf-8-sig')
b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
parent=b/'slice17724-source8/result.json'; proof=json.loads(read(parent))
cp=b/'slice17720-source8.json';c=json.loads(read(cp));producer=proof['reusableCheckedProducer']
assert proof['status']=='failed' and proof['inputsStable'] and proof['processesStopped']
assert producer['status']=='built' and producer['buildExit']==0 and producer['buildStderr']=='' and producer['buildCount']==1
exe=Path(producer['executable']);assert sha(exe)==producer['executableSha256']
first=proof['cases'][0]
expected38=r/'examples/regression/expected/38-stack-promoted-dynamic-array.compiler.stderr.exact.txt'
assert len(proof['cases'])==1 and first['id']=='38-stack-promoted-dynamic-array'
assert first['runExit']==0 and first['runStderr']==read(expected38).strip()
assert 'assemblyExit' not in first
oldcases={x['id']:x for x in json.loads(read(b/'placement17661-current16.json'))['cases']}
stdlib=b/'canonical17722-stdlib/result.json';validate(r,stdlib)
pins=dict(proof['inputHashes'])
for p,h in pins.items(): assert Path(p).is_file() and sha(p)==h,p
for p in [parent,cp,exe,expected38,b/'placement17661-current16.json',Path(__file__).resolve(),r/'scripts/verification_execution.py',r/'scripts/verification_contract_lease.py',r/'scripts/verify-c385-preir-call-numeric.py',b/'common17726-candidate38.json']:
    pins[str(p)]=sha(p)
for p,h in json.loads(read(stdlib))['inputHashes'].items():
    assert p not in pins or pins[p]==h
    pins[p]=h
retained=b/'slice17724-source8/38-stack-promoted-dynamic-array/run.stdout'
pins[str(retained)]=sha(retained)
assert sha(retained)==first['emittedLlvmSha256']
spec=importlib.util.spec_from_file_location('numeric_reuse_kernel',r/'scripts/verify-c385-preir-call-numeric.py');kernel=importlib.util.module_from_spec(spec);spec.loader.exec_module(kernel)
out=b/'slice17727-runtime8'
retained_roots=[b/f'v{n}/compiler-build01' for n in (12432,16382,17599)]
initialize_output(r,out,reusable_directories=retained_roots);out.mkdir()
record=dict(schemaVersion=1,status='running',scope='Reuse the successful checked SLG producer from a failed consumer diagnostic expectation. Preserve the failed record; use the already approved original38 S003 diagnostic and existing managed nested control. No compiler rebuild or expected output edits.',inputHashes=pins,completed=0,total=8,cases=[],producerBuildCount=0,reusedProducer=True,producerPath=str(exe),producerSha256=sha(exe),producerCodeBuildProvenance=str(parent),claimsGoalComplete=False)
x=VerificationExecution(r,out,record,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
def run(command,prefix):
    a=x.run(command,prefix,timeout=180)
    prefix.with_suffix('.stdout').write_text(a.stdout,encoding='utf-8')
    prefix.with_suffix('.stderr').write_text(a.stderr,encoding='utf-8')
    return a.returncode
error=None
with VerificationContractLease([Path(p) for p in pins]):
    try:
        for index,case in enumerate(c['cases']):
            folder=out/case['id'];folder.mkdir();row=dict(id=case['id'],status='running',passed=False)
            record['cases'].append(row);x.save()
            if index==0:
                llvm=folder/'emitted.ll';llvm.write_bytes(retained.read_bytes())
                row.update(emissionExit=0,emissionReused=True,emissionStderr=first['runStderr'],diagnosticAuthority=str(expected38))
            else:
                a=x.run([str(exe),*case['runArguments']],folder/'emit',timeout=180)
                expected=oldcases.get(case['id'],{}).get('stderr','')
                assert a.returncode==0 and a.stderr.strip()==expected,(case['id'],a.stderr)
                llvm=folder/'emitted.ll';llvm.write_text(a.stdout,encoding='utf-8')
                row.update(emissionExit=a.returncode,emissionStderr=a.stderr.strip())
            row['emittedLlvmSha256']=sha(llvm)
            assert run([str(r/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble')==0,case['id']
            assert not read(folder/'assemble.stderr').strip()
            native=folder/'emitted.exe'
            assert run([str(r/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O1','-o',str(native),*kernel.WINDOWS_RUNTIME_LIBRARIES],folder/'link')==0
            assert not read(folder/'link.stderr').strip()
            a=x.run([str(native)],folder/'native-run',timeout=180)
            (folder/'native-run.stdout').write_text(a.stdout,encoding='utf-8');(folder/'native-run.stderr').write_text(a.stderr,encoding='utf-8')
            row.update(assemblyExit=0,nativeLinkExit=0,nativeRunExit=a.returncode,nativeRunStdout=a.stdout.strip())
            assert a.returncode==case['expectedEmittedRuntimeExit'] and a.stdout.strip()==case['stdout'] and not a.stderr.strip(),case['id']
            if 'expectedAllocations' in case:
                audit,passed=kernel.audit_llvm_program(llvm,folder,case['expectedAllocations'],case['stdout'],run)
                row.update(audit);assert passed,case['id']
            row.update(status='passed',passed=True);record['completed']+=1;x.save();print(case['id']+': PASS',flush=True)
        record['status']='passed'
    except BaseException as exc: error=exc
    finally: x.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ('status','completed','total','producerBuildCount','inputsStable','processesStopped','failure')}))
if record['status']!='passed':raise SystemExit(1)
cleanup_output(r,out,execute=True,reusable_directories=retained_roots)
