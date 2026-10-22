from pathlib import Path
import json
e=Path(__file__).resolve().parent
d=json.loads((e/'callback-local.exe.compiler-build.execution.json').read_text(encoding='utf-8-sig'))
assert d['exit']==1 and d['processesStopped']
s=(e/'expression-type-records.execution.json.stdout.log.source0.txt').read_text(encoding='utf-8-sig')
assert 'ast 32 kind 48 parent 18 start 189 type 1247/3/-1/-1/-1/0/' in s
assert 'ast 44 kind 15 parent 32 start 299 type 31/3/-1/-1/-1/2/' in s
print('Actual compile exit1; parallel role incorrectly retains growable Unit while final callback payload is growable Int. Existing records checked; no program rerun.')
