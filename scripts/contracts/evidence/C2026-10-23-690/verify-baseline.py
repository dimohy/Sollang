from pathlib import Path
import json
e=Path(__file__).resolve().parent
d=json.loads((e/'compound-recursive-original.exe.compiler-build.json').read_text(encoding='utf-8-sig'))
a=json.loads((e/'compound-recursive-original.exe.compiler-build.execution.json').read_text(encoding='utf-8-sig'))
assert d['inputsStable'] and d['processesStopped'] and a['exit']==1
s=(e/'compound-recursive-original.exe.compiler-build.execution.json.stderr.log').read_text(encoding='utf-8-sig')
assert 'PHI node entries do not match predecessors' in s and 'try_parallel_drop_i' in s
print('Actual CSharp build exit1: recursive tryParallel prefix cleanup emits invalid PHI predecessor/dominance. No generated program executed.')
