from pathlib import Path
import sys,json,hashlib,re
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'input12441-read-branches02';o.mkdir(exist_ok=False)
module=b/'input12439-source/read-linux/emitted.ll';helpers=b/'stdout12395-runtime-emitter/ordinary.ll'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
inputs=[Path(__file__),module,helpers,root/'.tools/llvm-22.1.8/bin/llvm-as.exe',root/'.tools/llvm-22.1.8/bin/clang.exe'];pins={str(p):sha(p) for p in inputs}
r={'schemaVersion':1,'status':'running','scope':'Exact current emitted Linux readInt and text helper bodies with deterministic write/read/exit shims on Windows x64. Prompt failure must avoid reading; unrelated prior failure must preserve healthy read. Two checks in one process run.','inputHashes':pins,'completed':0,'total':2}
x=VerificationExecution(root,o,r,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 original=module.read_text(encoding='utf-8-sig');text=helpers.read_text(encoding='utf-8-sig');functions=re.findall(r'^define[^\n]*\n.*?^}',original,re.M|re.S);readers=[f for f in functions if '%prompt_ok = call i1 @sollang_runtime_print_checked' in f];assert len(readers)==1;reader=readers[0]
 bodies=re.findall(r'^define[^\n]*\n.*?^}',text,re.M|re.S)
 for body in bodies:assert body in original
 symbol=re.search(r'@(\w+)\(',reader).group(1)
 r['extractedReadBodySha256']=hashlib.sha256(reader.encode()).hexdigest().upper();r['textHelperBodiesMatchCompleteProgram']=True;r['exitShimMapping']='Production exit call is explicitly mapped to internal probe_exit to avoid Windows CRT duplicate exit symbol; branch is not expected to execute in these two controls.'
 stub='''
%sollang.text = type { ptr, i64 }
@probe_mode = global i1 true
@probe_reads = global i32 0
define i64 @write(i32 %fd, ptr %data, i64 %len) {
 %fail = load i1, ptr @probe_mode
 %count = select i1 %fail, i64 -1, i64 %len
 ret i64 %count
}
declare void @llvm.trap()
define internal void @probe_exit(i32 %status) {
 call void @llvm.trap()
 unreachable
}
define i64 @read(i32 %fd, ptr %data, i64 %capacity) {
 %prior = load i32, ptr @probe_reads
 %next = add i32 %prior, 1
 store i32 %next, ptr @probe_reads
 store i8 52, ptr %data
 %second = getelementptr i8, ptr %data, i64 1
 store i8 50, ptr %second
 %third = getelementptr i8, ptr %data, i64 2
 store i8 10, ptr %third
 ret i64 3
}
define i32 @main() {
 %prompt = insertvalue %sollang.text zeroinitializer, i64 1, 1
 %failed_result = call i32 @READ(%sollang.text %prompt)
 %failed_reads = load i32, ptr @probe_reads
 %not_read = icmp eq i32 %failed_reads, 0
 %zero = icmp eq i32 %failed_result, 0
 %failure_state = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %failed = icmp eq i8 %failure_state, 1
 %failed_a = and i1 %not_read, %zero
 %failed_pass = and i1 %failed_a, %failed
 store i1 false, ptr @probe_mode
 %healthy_result = call i32 @READ(%sollang.text %prompt)
 %healthy_reads = load i32, ptr @probe_reads
 %read_three = icmp eq i32 %healthy_reads, 1
 %forty_two = icmp eq i32 %healthy_result, 42
 %retained_state = load atomic i8, ptr @sollang_runtime_io_failed monotonic, align 1
 %retained = icmp eq i8 %retained_state, 1
 %healthy_a = and i1 %read_three, %forty_two
 %healthy_pass = and i1 %healthy_a, %retained
 %passed = and i1 %failed_pass, %healthy_pass
 %exit = select i1 %passed, i32 0, i32 1
 ret i32 %exit
}
'''.replace('@READ(', '@'+symbol+'(')
 llvm=o/'probe.ll';llvm.write_bytes(('%sollang.text = type { ptr, i64 }\n'+text.replace('declare i64 @write(i32, ptr, i64)','')+reader.replace('call void @exit(i32 1)','call void @probe_exit(i32 1)')+'\n'+stub.replace('%sollang.text = type { ptr, i64 }\n','')).encode())
 a=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(o/'probe.bc')],o/'assemble',timeout=30)
 if a.returncode or a.stderr.strip():raise ValueError('ASSEMBLY_FAILED '+a.stderr[:700])
 exe=o/'probe.exe';a=x.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),'-Wno-override-module',str(llvm),'-O0','-o',str(exe)],o/'link',timeout=30)
 if a.returncode or a.stderr.strip():raise ValueError('LINK_FAILED '+a.stderr[:700])
 a=x.run([str(exe)],o/'run',timeout=30);r['runtimeExit']=a.returncode
 if a.returncode or a.stdout.strip() or a.stderr.strip():raise ValueError('READ_BRANCH_ORACLE_FAILED')
 r['status']='passed';r['completed']=2
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure']}))
