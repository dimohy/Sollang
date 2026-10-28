from pathlib import Path
import argparse,hashlib,json,sys

r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_llvm_allocation import allocation_failure_call_binding,allocation_failure_binding
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output,cleanup_output
b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cp=b/'resize17787-failure-contract.json';contract=json.loads(cp.read_text(encoding='utf-8'))
clang=r/'.tools/llvm-22.1.8/bin/clang.exe'
inputs=[cp,clang,Path(__file__).resolve(),r/'scripts/verification_llvm_allocation.py',r/'scripts/verification_execution.py',r/'scripts/verification_contract_lease.py']
inputs += [(r/x).resolve() for x in contract['sourceFixtures']]
inputs += [(r/c['llvm']).resolve() for c in contract['cases']+contract['negativeCases']+contract['constantCompatibility']]
inputs=list(dict.fromkeys(inputs));pins={str(p):sha(p) for p in inputs}
out=args.output.resolve();keep=[b/f'v{n}/compiler-build01' for n in (12432,16382,17599)]
initialize_output(r,out,reusable_directories=keep);out.mkdir()
record=dict(schemaVersion=1,status='running',scope='Exact declared grow call sites in reserve and materialize. Both producers use the same source-function/failure-block binding and trap exit contract; no producer-specific expected messages. Generated identifier byte equality and the whole compiler are not claimed.',inputHashes=pins,completed=0,total=len(contract['cases']),cases=[],controls=[],claimsGoalComplete=False)
x=VerificationExecution(r,out,record,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
def encoded(message):return ''.join('\\'+format(c,'02X') for c in message.encode('utf-8'))
def control(identity,text,case,expected):
    try:allocation_failure_call_binding(text,case['allocationCall'],case['sourceFunction']);accepted=True
    except ValueError as failure:accepted=False;failure_id=str(failure)
    assert accepted==expected,identity
    if case.get('expectedFailureId'):
        assert not accepted and failure_id==case['expectedFailureId']
    record['controls'].append(dict(id=identity,passed=True));x.save()
with VerificationContractLease(inputs):
    try:
        for case in contract['negativeCases']:
            text=(r/case['llvm']).read_text(encoding='utf-8-sig')
            control(case['id'],text,case,False)
        for case in contract['constantCompatibility']:
            allocation_failure_binding((r/case['llvm']).read_text(encoding='utf-8-sig'),4800,'main')
            record['controls'].append(dict(id=case['id'],passed=True));x.save()
        for case in contract['cases']:
            text=(r/case['llvm']).read_text(encoding='utf-8-sig');needle=case['allocationCall'];owner=case['sourceFunction']
            binding=allocation_failure_call_binding(text,needle,owner);identity=case['id'];old=binding['failureBlock'];new=old[:-1]+('X' if old[-1]!='X' else 'Y')
            control(identity+'/original',text,case,True)
            control(identity+'/consistent-label-move',text.replace(old,new).replace(binding['encodedDiagnostic'],encoded(owner+':'+new)),case,True)
            check=binding['condition']+' = icmp ne ptr '+binding['testedPointer']
            control(identity+'/reversed-null-test',text.replace(check,check.replace('icmp ne','icmp eq'),1),case,False)
            control(identity+'/missing-trap',text.replace('call void @llvm.trap()',''),case,False)
            fake='define internal void @unrelated_failure() {\nentry:\n  br label %'+old+'\n'+old+':\n  %message = alloca ['+str(binding['diagnosticByteCount'])+' x i8]\n  store ['+str(binding['diagnosticByteCount'])+' x i8] c"'+encoded(binding['diagnostic'])+'", ptr %message\n  call void @llvm.trap()\n  unreachable\n}\n'
            control(identity+'/other-function-cannot-hide-missing-trap',fake+text.replace('call void @llvm.trap()',''),case,False)
            other=owner[:-1]+('X' if owner[-1]!='X' else 'Y')
            control(identity+'/wrong-source-function',text.replace(binding['encodedDiagnostic'],encoded(other+':'+old),1),case,False)
            control(identity+'/wrong-failure-block',text.replace(binding['encodedDiagnostic'],encoded(owner+':'+new),1),case,False)
            control(identity+'/publish-before-guard',text.replace(needle,needle+'\n  store i8 1, ptr '+binding['allocationPointer'],1),case,False)
            if needle.startswith('call ptr @sollang_resize('):
                replaced=needle.replace('@sollang_resize','@sollang_test_fail_resize')
                stub='define internal ptr @sollang_test_fail_resize(ptr %old, i64 %used, i64 %bytes) {\nentry:\n  ret ptr null\n}\n'
            else:
                replaced=needle.replace('@sollang_alloc','@sollang_test_fail_alloc')
                stub='define internal ptr @sollang_test_fail_alloc(i64 %bytes) {\nentry:\n  ret ptr null\n}\n'
            modified=text.replace(needle,replaced,1)+'\n'+stub
            if 'define dso_local i32 @sollang_start()' in text:
                modified+='\ndefine i32 @main() {\nentry:\n  %value = call i32 @sollang_start()\n  ret i32 %value\n}\n'
            folder=out/identity;folder.mkdir();llvm=folder/'failure.ll';llvm.write_text(modified,encoding='utf-8');exe=folder/'failure.exe'
            row=dict(id=identity,status='running',passed=False,sourceBinding=binding);record['cases'].append(row);x.save()
            linked=x.run([str(clang),'-Wno-override-module',str(llvm),'-O1','-o',str(exe),'-lws2_32','-lshell32','-lbcrypt','-lole32'],folder/'link',timeout=180)
            (folder/'link.stdout').write_text(linked.stdout,encoding='utf-8');(folder/'link.stderr').write_text(linked.stderr,encoding='utf-8');row['buildExit']=linked.returncode
            assert linked.returncode==0 and not linked.stderr.strip(),linked.stderr
            ran=x.run([str(exe)],folder/'run',timeout=180)
            (folder/'run.stdout').write_text(ran.stdout,encoding='utf-8');(folder/'run.stderr').write_text(ran.stderr,encoding='utf-8');row.update(runExit=ran.returncode,stdout=ran.stdout,stderr=ran.stderr)
            assert (ran.returncode & 0xffffffff)==(case['expectedRuntimeExit'] & 0xffffffff)
            assert ran.stdout==case['stdout'] and ran.stderr==binding['diagnostic']
            row.update(status='passed',passed=True);record['completed']+=1;x.save()
        record['status']='passed'
    except BaseException as exc:error=exc
    finally:x.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ('status','completed','total','inputsStable','processesStopped','failure')})+' controls='+str(len(record['controls'])))
if record['status']!='passed':raise SystemExit(1)
cleanup_output(r,out,execute=True,reusable_directories=keep)
