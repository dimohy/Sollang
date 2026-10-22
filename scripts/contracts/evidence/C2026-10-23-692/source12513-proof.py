from pathlib import Path
import json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
paths=[b/'source12511-source/result.json',b/'source12513-runtime/result.json',b/'ownership12510-preflight/result.json']
source,runtime,pre=map(read,paths)
for record,n in [(source,29),(runtime,23),(pre,4)]:
 assert record['status']=='passed' and record['completed']==record['total']==n and record['inputsStable'] and record['processesStopped']
 for path,h in record['inputHashes'].items():assert sha(Path(path))==h,path
assert not pre['codegenInvoked']
assert sha(b/'source12511-source/producer.exe')==source['producerSha256']
assert len([case for case in source['cases'] if case.get('admissionRejected')])==6
rows=[]
for case in runtime['cases']:
 emitted=next(row for row in source['cases'] if row['id']==case['id'])
 assert case['passed'] and case['runExit']==0 and emitted['status']=='passed' and emitted['assemblyExit']==0
 linked=next(row for row in runtime['steps'] if row['id']==case['id']+'-link');assert linked['exit']==0
 rows.append({'id':case['id'],'passed':True,'status':'passed','emittedLlvmSha256':emitted['emittedLlvmSha256'],'assemblyExit':0,'nativeLinkExit':0,'nativeRunExit':case['runExit'],'nativeRunStdout':case['stdout'],'rawEmissionResult':str(paths[0]),'rawRuntimeResult':str(paths[1])})
pins={}
for record in [source,runtime]:
 for path,h in record['inputHashes'].items():
  assert path not in pins or pins[path]==h; pins[path]=h
for path in [*paths,Path(__file__)]:pins[str(path)]=sha(path)
proof={'schemaVersion':1,'status':'passed','mode':'managed','scope':'Actual current canonical SLG source normal runtime23 projected from complete29-case source gate. Six required rejected carriers separately qualified in that gate. Not additional executions.','completed':23,'total':23,'cases':rows,'semanticPreflight':{'status':'passed-current-source','codegenInvoked':False,'evidence':str(paths[2])},'inputHashes':pins,'inputsStable':True,'processesStopped':True,'claimsGoalComplete':False}
(b/'source12513-runtime-proof.json').write_bytes((json.dumps(proof,ensure_ascii=False,indent=2)+'\n').encode())
print('Normal runtime23 proof with full current input closure prepared for required fresh native admission; negative6 remain separate.')
