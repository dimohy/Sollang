from pathlib import Path
import json
e=Path(__file__).resolve().parent
d=json.loads((e/'result.json').read_text(encoding='utf-8-sig'))
assert d['buildExit']==1 and not d['generatedProgramExecuted']
assert "undefined value '%v118130'" in d['stderr']
b=json.loads((e/'recursive.exe.compiler-build.json').read_text(encoding='utf-8-sig'))
assert b['inputsStable'] and b['processesStopped']
print('Pre-C688 actual native compile exit1: tryParallel result SSA undefined. Same source current emission also fails assembly; valid CSharp output1 already passed. No generated program executed.')
