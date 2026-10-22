from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[4];e=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
record=read(e/'baseline-contract12520.json')
assert hashlib.sha256((root/record['source']).read_bytes()).hexdigest().upper()==record['sourceSha256']
execution=read(e/'range-maximum-map.execution.json')
assert execution['exit']==-1 and execution['processesStopped']
assert '3000 ms' in execution['failure'] and 'process tree terminated' in execution['failure']
assert record['managed']['runExit']==0 and record['managed']['stdout']=='2\n'
llvm=(e/'baseline.llvm.txt').read_text(encoding='utf-8-sig')
assert '_done = icmp sgt i32' in llvm and '_next = add i32 %stream' in llvm
print('Frozen two-element maximum Range: CSharp returns2, native build0 then actual3000ms timeout with process shutdown. Actual LLVM increments i32 cursor into wraparound; no repeated program execution.')
