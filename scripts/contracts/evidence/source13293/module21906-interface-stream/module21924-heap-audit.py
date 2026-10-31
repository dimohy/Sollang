from pathlib import Path
import json,hashlib,sys,time
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'module21924-heap-audit';parent=B/'module21923-csharp-keep-llvm';LLVM=parent/'program.exe.ll';audit=ROOT/'scripts/contracts/evidence/source13293/forms21852-function-coverage/diagnostic-source/heap-audit-history.c';fixtures=[ROOT/'scripts/probes/codegen-module-interface'/name for name in ['Z.slg','a.slg','empty.slg','other.slg']];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),LLVM,parent/'result.json',audit,*fixtures];inputs={str(p.resolve()):sha(p) for p in paths};initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir()
with VerificationContractLease(paths):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,cases=[],inputHashes=inputs,scope='Diagnostic only: one relink of the preserved failed LLVM with allocation/free auditing and linker map, max60s. Does not change the original oracle or qualify the original input.',claimsGoalComplete=False)
 ex=VerificationExecution(ROOT,OUT,result,lambda:all(sha(p)==h for p,h in inputs.items()),sha);err=None;start=time.monotonic();budget=lambda:max(1,60-(time.monotonic()-start))
 try:
  text=LLVM.read_text(encoding='utf-8-sig');a=text.index('define internal ptr @sollang_alloc(');b=text.index('declare void @llvm.memcpy',a);text=text[:a]+'declare ptr @sollang_alloc(i64)\ndeclare void @sollang_free(ptr)\n'+text[b:];ll=OUT/'audit.ll';ll.write_text(text,encoding='utf-8',newline='\n');exe=OUT/'audit.exe';done=ex.run([str(ROOT/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),str(audit),'-O0','-g','-Wno-override-module','-o',str(exe),'-Wl,/map:'+str(OUT/'audit.map'),'-lkernel32','-lshell32','-lws2_32','-lbcrypt'],OUT/'link',timeout=budget());assert done.returncode==0,done.stderr
  done=ex.run([str(exe),*map(str,fixtures)],OUT/'run',timeout=budget());result.update(status='passed' if done.returncode==0 else 'failed',completed=1,cases=[dict(id='instrumented-failed-input',passed=done.returncode==0,exit=done.returncode,stdout=done.stdout,stderr=done.stderr)]);print(json.dumps(dict(exit=done.returncode,stderr=done.stderr)))
 except BaseException as error:err=error
 finally:ex.finalize(err,cleanup=False)
 if err:raise err
