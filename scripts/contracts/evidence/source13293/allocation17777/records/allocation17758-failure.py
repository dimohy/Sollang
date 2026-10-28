import argparse, hashlib, json, sys
from pathlib import Path

r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output, cleanup_output

p=argparse.ArgumentParser();p.add_argument('--llvm',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--contract',type=Path,required=True);a=p.parse_args();contract=json.loads(a.contract.read_text(encoding='utf-8'));case=contract['cases'][0]
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
source=a.llvm.resolve();out=a.output.resolve();text=source.read_text(encoding='utf-8-sig')
needle='call ptr @sollang_alloc(i64 4800)'
assert text.count(needle)==1,'Only the original42 user allocation is instrumented'
assert 'call void @llvm.trap()' in text
modified=text.replace(needle,'call ptr @sollang_test_fail_alloc(i64 4800)')+'\ndefine internal ptr @sollang_test_fail_alloc(i64 %bytes) {\nentry:\n  ret ptr null\n}\n'
if 'define dso_local i32 @sollang_start()' in text:
    modified+='\ndefine i32 @main() {\nentry:\n  %value = call i32 @sollang_start()\n  ret i32 %value\n}\n'
clang=r/'.tools/llvm-22.1.8/bin/clang.exe'
inputs=[a.contract.resolve(),source,clang,Path(__file__).resolve(),r/'scripts/verification_execution.py',r/'scripts/verification_contract_lease.py',r/'examples/regression/42-fixed-array-placement.slg']
pins={str(path):sha(path) for path in inputs}
keep=[b/f'v{n}/compiler-build01' for n in (12432,16382,17599)]
initialize_output(r,out,reusable_directories=keep);out.mkdir()
llvm=out/'allocation-failure.ll';llvm.write_text(modified,encoding='utf-8')
record=dict(schemaVersion=1,status='running',scope='Original42 allocation failure injection at the one4800-byte user allocation. Original source and expected files unchanged. Successful parity requires the exact managed trap exit, excluding a null-write access violation.',inputHashes=pins,completed=0,total=1,cases=[],claimsGoalComplete=False)
x=VerificationExecution(r,out,record,lambda:all(Path(k).is_file() and sha(k)==h for k,h in pins.items()),sha);error=None
with VerificationContractLease(inputs):
    try:
        exe=out/'allocation-failure.exe'
        run=x.run([str(clang),'-Wno-override-module',str(llvm),'-O1','-o',str(exe),'-lws2_32','-lshell32','-lbcrypt','-lole32'],out/'link',timeout=180)
        (out/'link.stdout').write_text(run.stdout,encoding='utf-8');(out/'link.stderr').write_text(run.stderr,encoding='utf-8')
        assert run.returncode==0 and not run.stderr.strip(),run.stderr
        run=x.run([str(exe)],out/'run',timeout=180)
        (out/'run.stdout').write_text(run.stdout,encoding='utf-8');(out/'run.stderr').write_text(run.stderr,encoding='utf-8')
        code=run.returncode & 0xffffffff
        assert code==0xc000001d,hex(code)
        assert code==(case['expectedRuntimeExit'] & 0xffffffff)
        assert not run.stdout.strip()
        assert run.stderr.strip()==case['stderr'], 'ALLOCATION_FAILURE_DIAGNOSTIC_MISMATCH: '+repr(run.stderr)
        record['cases'].append(dict(id=case['id'],status='passed',passed=True,buildExit=0,runExit=run.returncode,unsignedRunExit=code,instrumentedLlvmSha256=sha(llvm)))
        record.update(status='passed',completed=1)
    except BaseException as exc:error=exc
    finally:x.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ('status','completed','total','inputsStable','processesStopped','failure')}))
if record['status']!='passed':raise SystemExit(1)
cleanup_output(r,out,execute=True,reusable_directories=keep)
