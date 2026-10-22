from pathlib import Path
import json
e=Path(__file__).resolve().parent
d=json.loads((e/'callback-nested-field.execution.json').read_text(encoding='utf-8-sig'))
b=json.loads((e/'callback-nested-field.exe.compiler-build.json').read_text(encoding='utf-8-sig'))
assert d['exit']==-1073740940 and d['processesStopped'] and b['status']=='passed' and b['inputsStable']
print('Genuine CSharp nested immutable field result: build0, runtime C0000374; preserved actual record, no repeated program execution.')
