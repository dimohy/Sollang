from pathlib import Path
import json
E=Path(__file__).resolve().parent
d=json.loads((E/'input12436-native-baseline/result.json').read_text(encoding='utf-8-sig'))
assert d['completed']==d['total']==11 and d['passed']==4 and d['inputsStable'] and d['processesStopped']
print(json.dumps({'actualProgramRuns':11,'matched':4,'mismatches':[{'id':c['id'],'exit':c['runExit'],'stdout':c['stdout']} for c in d['cases'] if not c['passed']],'observationCommandIsNotProgramExit':True}))
