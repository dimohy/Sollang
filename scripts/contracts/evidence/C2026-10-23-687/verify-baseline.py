from pathlib import Path
import json
E=Path(__file__).resolve().parent
d=json.loads((E/'callback-local.execution.json').read_text(encoding='utf-8-sig'))
assert d['exit']==-1073740940 and d['processesStopped']
print('Genuine CSharp Windows program exit C0000374 (-1073740940); build0; expected runtime0. Observed runtime record preserved, not a new program execution.')
