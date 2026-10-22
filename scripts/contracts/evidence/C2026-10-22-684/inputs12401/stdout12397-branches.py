from pathlib import Path
import sys,json,hashlib,re
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';src=b/'stdout12395-runtime-emitter';o=b/'stdout12397-branches';o.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
proof=json.loads((src/'result.json').read_text(encoding='utf-8-sig'));assert proof['status']=='passed' and proof['inputsStable'] and proof['processesStopped']
inputs=[Path(__file__),src/'result.json',src/'ordinary.ll',src/'parallel.ll',root/'.tools/llvm-22.1.8/bin/clang.exe',root/'.tools/llvm-22.1.8/bin/llvm-as.exe']
pins={str(p):sha(p) for p in inputs};r={'schemaVersion':1,'status':'running','scope':'Exact SLG Linux text helper bodies with deterministic write/TLS/sink shims on Windows x64. Seven distinct checks in two program runs, not actual Linux syscall checks.','inputHashes':pins,'completed':0,'total':7,'cases':[]}
x=VerificationExecution(root,o,r,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
stub='''
@probe_mode = global i32 0
@probe_calls = global i32 0
@probe_captures = global i32 0
@probe_failures = global i32 0
define void @check(i1 %ok) {
 %prior = load i32, ptr @probe_failures
 %failed = xor i1 %ok, true
 %count = zext i1 %failed to i32
 %next = add i32 %prior, %count
 store i32 %next, ptr @probe_failures
 ret void
}
define i64 @write(i32 %fd, ptr %data, i64 %len) {
entry:
 %n = load i32, ptr @probe_calls
 %next = add i32 %n, 1
 store i32 %next, ptr @probe_calls
 %mode = load i32, ptr @probe_mode
 switch i32 %mode, label %full [ i32 1, label %failure i32 2, label %short i32 3, label %partial i32 4, label %stalled ]
failure: ret i64 -1
short: ret i64 1
partial:
 %first = icmp eq i32 %n, 0
 %part = select i1 %first, i64 1, i64 %len
 ret i64 %part
stalled:
 %first_zero = icmp eq i32 %n, 0
 %stalled_part = select i1 %first_zero, i64 1, i64 0
 ret i64 %stalled_part
full: ret i64 %len
}
'''
ordinary='''
define i32 @main() {
 store i32 2, ptr @probe_mode
 %short_ok = call i1 @sollang_runtime_write_stdout(ptr null, i64 2)
 %short_flag = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %short_failed = icmp eq i8 %short_flag, 1
 %short_false = xor i1 %short_ok, true
 %short_pass = and i1 %short_false, %short_failed
 call void @check(i1 %short_pass)
 store i32 0, ptr @probe_mode
 %later_ok = call i1 @sollang_runtime_write_stdout(ptr null, i64 2)
 call void @sollang_runtime_flush_stdout()
 %sticky_flag = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %retained = icmp eq i8 %sticky_flag, 1
 %sticky_pass = and i1 %later_ok, %retained
 call void @check(i1 %sticky_pass)
 store i32 1, ptr @probe_mode
 store i32 0, ptr @probe_calls
 %empty_ok = call i1 @sollang_runtime_write_stdout(ptr null, i64 0)
 %empty_calls = load i32, ptr @probe_calls
 %not_called = icmp eq i32 %empty_calls, 0
 %empty_pass = and i1 %empty_ok, %not_called
 call void @check(i1 %empty_pass)
 store atomic i8 0, ptr @sollang_runtime_io_failed monotonic, align 1
 store i32 0, ptr @probe_calls
 store i32 3, ptr @probe_mode
 %stderr_ok = call i1 @sollang_runtime_write_stderr(ptr null, i64 3)
 %stderr_calls = load i32, ptr @probe_calls
 %stderr_twice = icmp eq i32 %stderr_calls, 2
 %stderr_flag = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %stderr_clean = icmp eq i8 %stderr_flag, 0
 %stderr_a = and i1 %stderr_ok, %stderr_twice
 %stderr_pass = and i1 %stderr_a, %stderr_clean
 call void @check(i1 %stderr_pass)
 store i32 0, ptr @probe_calls
 store i32 4, ptr @probe_mode
 %zero_ok = call i1 @sollang_runtime_write_stderr(ptr null, i64 3)
 %zero_false = xor i1 %zero_ok, true
 %zero_flag = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %zero_failed = icmp eq i8 %zero_flag, 1
 %zero_calls = load i32, ptr @probe_calls
 %zero_twice = icmp eq i32 %zero_calls, 2
 %zero_a = and i1 %zero_false, %zero_failed
 %zero_pass = and i1 %zero_a, %zero_twice
 call void @check(i1 %zero_pass)
 %failures = load i32, ptr @probe_failures
 ret i32 %failures
}
'''
parallel='''
define ptr @pthread_getspecific(i32 %key) { ret ptr @probe_captures }
define void @sollang_memory_output_sink_append(ptr %sink, ptr %data, i64 %len) {
 %previous = load i32, ptr @probe_captures
 %next = add i32 %previous, 1
 store i32 %next, ptr @probe_captures
 ret void
}
define i32 @main() {
 store i32 1, ptr @probe_mode
 call void @sollang_memory_output_sink_write(ptr null, ptr null, i64 2)
 %direct_flag = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %direct_failed = icmp eq i8 %direct_flag, 1
 call void @check(i1 %direct_failed)
 store atomic i8 0, ptr @sollang_runtime_io_failed monotonic, align 1
 store i32 0, ptr @probe_calls
 store i1 true, ptr @sollang_output_sink_tls_ready
 %ok = call i1 @sollang_runtime_append_stdout_checked(ptr null, i64 2)
 %calls = load i32, ptr @probe_calls
 %no_os = icmp eq i32 %calls, 0
 %captures = load i32, ptr @probe_captures
 %one_capture = icmp eq i32 %captures, 1
 %capture_flag = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %clean = icmp eq i8 %capture_flag, 0
 %a = and i1 %ok, %no_os
 %c = and i1 %one_capture, %clean
 %passed = and i1 %a, %c
 call void @check(i1 %passed)
 %failures = load i32, ptr @probe_failures
 ret i32 %failures
}
'''
try:
 for mode,main,checks in [('ordinary',ordinary,5),('parallel',parallel,2)]:
  original=(src/(mode+'.ll')).read_text(encoding='utf-8-sig');s=original.replace('declare i64 @write(i32, ptr, i64)','')
  if mode=='parallel':s=s.replace('declare ptr @pthread_getspecific(i32)','').replace('declare void @sollang_memory_output_sink_append(ptr, ptr, i64)','')
  helpers=re.findall(r'^define[^\n]*\n.*?^}',original,re.M|re.S)
  assert helpers
  for body in helpers:assert body in s
  llvm=o/(mode+'.ll');llvm.write_bytes((s+stub+main).encode());row={'id':mode,'checks':checks,'productionHelperBodySha256':[hashlib.sha256(f.encode()).hexdigest().upper() for f in helpers]};r['cases'].append(row)
  a=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(o/(mode+'.bc'))],o/(mode+'-assemble'),timeout=30)
  if a.returncode or a.stderr.strip():raise ValueError('ASSEMBLY_FAILED: '+a.stderr[:600])
  exe=o/(mode+'.exe');a=x.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O0','-o',str(exe)],o/(mode+'-link'),timeout=30)
  if a.returncode or a.stderr.strip():raise ValueError('LINK_FAILED: '+a.stderr[:600])
  a=x.run([str(exe)],o/(mode+'-run'),timeout=30);row['runtimeExit']=a.returncode
  if a.returncode or a.stdout.strip() or a.stderr.strip():raise ValueError('BRANCH_ORACLE_FAILED: '+mode+str(a.returncode))
  row['passed']=True;r['completed']+=checks;x.save()
 r['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure']}))
