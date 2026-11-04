import hashlib,json,pathlib,re,sys
root=pathlib.Path.cwd(); sys.path.insert(0,str(root/'scripts'))
from verification_llvm_allocation import instrument_owned_allocation_audit,task_start_failure_trace
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
b=root/'artifacts/scratch/resume-20261006-owner-continuation22'; output=b/'start28322-observer-controls'
source=b/'start28319-csharp/primary/probe.exe.ll'; shim=root/'tests/native-interop/owned_array_audit.c'; clang=root/'.tools/llvm-22.1.8/bin/clang.exe'
def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest().upper()
inputs={str(p):sha(p) for p in [source,shim,clang,pathlib.Path(__file__).resolve(),root/'scripts/verification_llvm_allocation.py',b/'start28322-observer-contract.json']}
text=instrument_owned_allocation_audit(source.read_text(encoding='utf-8-sig'),task_start_failure=True)
function=re.search(r'^define[^\n]* @sollang_fn_asyncstart_consume\([^\n]*\)[^\n]*\{\n.*?^}',text,re.M|re.S)
assert function
start=function.start()+function[0].index('call ptr @audit_task_start_fail(')
calls=list(re.finditer(r'^\s*call void @sollang_drop_[\w.$-]+\(ptr %it\)\s*$',text[start:function.end()],re.M))
assert len(calls)==1,'bind the actual declaration-owned primary drop call, not its private type number'
first=calls[0]; a=start+first.start(); z=start+first.end()
variants={'missing-owned-release':text[:a]+text[z:],'duplicate-owned-release':text[:z]+'\n'+text[a:z]+text[z:]}
reusable=[b/'v20050/compiler-build01',b/'order26416-native',b/'deque27418-native']
initialize_output(root,output,reusable_directories=reusable); output.mkdir()
result={'schemaVersion':1,'status':'running','completed':0,'total':2,'inputHashes':inputs,'cases':[],'scope':'Real allocator observer rejects missing/double release mutations of current CSharp task-start failure cleanup; original compiler/source inputs unchanged.'}
execution=VerificationExecution(root,output,result,lambda:all(pathlib.Path(p).exists() and sha(p)==h for p,h in inputs.items()),sha)
error=None
try:
    for name,body in variants.items():
        llvm=output/(name+'.ll'); exe=output/(name+'.exe'); llvm.write_text(body,encoding='utf-8',newline='\n')
        linked=execution.run([str(clang),'-Wno-override-module',str(llvm),str(shim),'-DEXPECTED_ALLOCATIONS=2','-DAUDIT_TASK_START_FAILURE=1','-O1','-o',str(exe),'-lws2_32','-lshell32','-lbcrypt','-lole32'],output/(name+'-link'),timeout=180)
        assert linked.returncode==0 and not linked.stderr
        ran=execution.run([str(exe)],output/(name+'-run'),timeout=180)
        accepted=(ran.returncode&0xffffffff)==0xc000001d and ran.stdout=='' and ran.stderr==task_start_failure_trace(2)
        assert (ran.returncode&0xffffffff)==0xc000001d and not accepted,(name,ran.returncode,ran.stderr)
        if name=='missing-owned-release': assert ran.stderr.endswith('task-start-release:released=1,live=1\n')
        else: assert 'invalid release: pointer is not a live audited allocation' in ran.stderr
        result['cases'].append({'id':name,'status':'passed','passed':True,'mutantDisposition':'rejected-as-required','runExit':ran.returncode,'runStderr':ran.stderr,'acceptedByExactReleaseOracle':accepted}); result['completed']+=1; execution.save()
    result['status']='passed'
except BaseException as caught: error=caught
finally: execution.finalize(error,cleanup=False)
if error: raise error
cleanup_output(root,output,execute=True,reusable_directories=reusable)
print('actual missing/double-owned-release controls rejected2/2')
