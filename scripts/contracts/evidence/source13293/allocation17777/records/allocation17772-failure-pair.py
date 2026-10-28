from pathlib import Path
import hashlib,json,sys

r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_llvm_allocation import allocation_failure_binding
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output,cleanup_output

b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cp=b/'allocation17772-failure-contract.json'
contract=json.loads(cp.read_text(encoding='utf-8'))
clang=r/'.tools/llvm-22.1.8/bin/clang.exe'
sources=[(r/c['llvm']).resolve() for c in contract['cases']]
inputs=[cp,clang,Path(__file__).resolve(),r/'scripts/verification_llvm_allocation.py',r/'scripts/verification_execution.py',r/'scripts/verification_contract_lease.py',r/contract['sourceFixture'],*sources]
pins={str(p):sha(p) for p in inputs}
out=b/'allocation17773-failure-pair';keep=[b/f'v{n}/compiler-build01' for n in (12432,16382,17599)]
initialize_output(r,out,reusable_directories=keep);out.mkdir()
record=dict(schemaVersion=1,status='running',scope='Both producers obey one allocation-failure rule: null check before payload use, a fatal failure branch, and a diagnostic owned by that exact source function/failure block. Generated block identifiers need not be byte-identical. Original source, stdout and common LLVM oracles remain unchanged.',inputHashes=pins,completed=0,total=2,cases=[],controls=[],claimsGeneratedIdentifierEquality=False,claimsGoalComplete=False)
x=VerificationExecution(r,out,record,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
def encoded(message):return ''.join('\\'+format(byte,'02X') for byte in message.encode('utf-8'))
def verify_control(identity,text,expected):
    try:allocation_failure_binding(text,contract['allocationBytes'],contract['sourceFunction']);accepted=True
    except ValueError:accepted=False
    assert accepted==expected,identity
    record['controls'].append(dict(id=identity,passed=True));x.save()
with VerificationContractLease(inputs):
    try:
        for case,source in zip(contract['cases'],sources):
            text=source.read_text(encoding='utf-8-sig');binding=allocation_failure_binding(text,contract['allocationBytes'],contract['sourceFunction'])
            identity=case['id'];old=binding['failureBlock'];new=old[:-1]+('X' if old[-1]!='X' else 'Y')
            verify_control(identity+'/original',text,True)
            renamed=text.replace(old,new).replace(binding['encodedDiagnostic'],encoded(contract['sourceFunction']+':'+new))
            verify_control(identity+'/consistent-generated-label-move',renamed,True)
            check=binding['condition']+' = icmp ne ptr '+binding['testedPointer']
            verify_control(identity+'/reversed-null-test',text.replace(check,check.replace('icmp ne','icmp eq'),1),False)
            verify_control(identity+'/missing-trap',text.replace('call void @llvm.trap()',''),False)
            verify_control(identity+'/wrong-source-function',text.replace(binding['encodedDiagnostic'],encoded('maim:'+old),1),False)
            verify_control(identity+'/wrong-failure-block',text.replace(binding['encodedDiagnostic'],encoded(contract['sourceFunction']+':'+new),1),False)
            needle='call ptr @sollang_alloc(i64 '+str(contract['allocationBytes'])+')'
            verify_control(identity+'/payload-use-before-guard',text.replace(needle,needle+'\n  store i8 1, ptr '+binding['allocationPointer'],1),False)
            modified=text.replace(needle,'call ptr @sollang_test_fail_alloc(i64 '+str(contract['allocationBytes'])+')')+'\ndefine internal ptr @sollang_test_fail_alloc(i64 %bytes) {\nentry:\n  ret ptr null\n}\n'
            if 'define dso_local i32 @sollang_start()' in text:
                modified+='\ndefine i32 @main() {\nentry:\n  %value = call i32 @sollang_start()\n  ret i32 %value\n}\n'
            folder=out/identity;folder.mkdir();llvm=folder/'failure.ll';llvm.write_text(modified,encoding='utf-8');exe=folder/'failure.exe'
            row=dict(id=identity,status='running',passed=False,sourceBinding=binding);record['cases'].append(row);x.save()
            run=x.run([str(clang),'-Wno-override-module',str(llvm),'-O1','-o',str(exe),'-lws2_32','-lshell32','-lbcrypt','-lole32'],folder/'link',timeout=180)
            (folder/'link.stdout').write_text(run.stdout,encoding='utf-8');(folder/'link.stderr').write_text(run.stderr,encoding='utf-8')
            assert run.returncode==0 and not run.stderr.strip(),run.stderr
            row['buildExit']=run.returncode
            run=x.run([str(exe)],folder/'run',timeout=180)
            (folder/'run.stdout').write_text(run.stdout,encoding='utf-8');(folder/'run.stderr').write_text(run.stderr,encoding='utf-8')
            row.update(runExit=run.returncode,stderr=run.stderr,stdout=run.stdout)
            assert (run.returncode & 0xffffffff)==(case['expectedRuntimeExit'] & 0xffffffff)
            assert not run.stdout and run.stderr==binding['diagnostic']
            row.update(status='passed',passed=True);record['completed']+=1;x.save()
        record['status']='passed'
    except BaseException as exc:error=exc
    finally:x.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ('status','completed','total','inputsStable','processesStopped','failure')})+' controls='+str(len(record['controls'])))
if record['status']!='passed':raise SystemExit(1)
cleanup_output(r,out,execute=True,reusable_directories=keep)
