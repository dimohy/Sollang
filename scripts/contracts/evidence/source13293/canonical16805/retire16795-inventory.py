from pathlib import Path
import subprocess,json,collections
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';binary=b/'v16730/compiler-build01/compiler.exe';expected='5184988C734374FC01D6E5078F1A90B54EF88018B0EE42D54E6E6EFB84DC35B1';found=subprocess.run(['rg','-l','-F','--hidden','--no-ignore','-g','result.json','v16730',str(b)],capture_output=True,text=True,encoding='utf-8',check=False);assert found.returncode in [0,1];rows=[];counts=collections.Counter()
for name in found.stdout.splitlines():
 p=Path(name)
 try:d=json.loads(p.read_text(encoding='utf-8-sig'))
 except (ValueError,OSError):continue
 pins=[]
 for field in ['inputHashes','inputHashesStart','inputHashesEnd']:
  pins.extend((field,k,v) for k,v in d.get(field,{}).items() if isinstance(v,str) and Path(k).as_posix().lower().endswith('/v16730/compiler-build01/compiler.exe'))
 pinned=any(v.upper()==expected for _,_,v in pins);processes=d.get('processes',[]);direct=any(any('v16730/compiler-build01/compiler.exe' in str(arg).replace('\\','/').lower() for arg in x.get('command',[])) for x in processes if isinstance(x,dict));category='binary-pinned-owned-process' if pinned and processes else 'binary-pinned-aggregate-or-observer' if pinned else 'command-reference-unpinned' if direct else 'metadata-reference-only';counts[category]+=1
 if pinned or direct:rows.append({'path':str(p),'status':d.get('status'),'completed':d.get('completed'),'total':d.get('total'),'category':category,'processCount':len(processes),'processesStopped':d.get('processesStopped'),'cases':len(d.get('cases',[])),'pinKeys':[k for _,k,_ in pins]})
plan={'schemaVersion':1,'status':'read-only-inventory;no-retirement-executed','product':str(binary.parent),'replacement':str(b/'v16382/compiler-build01'),'matchedResultFiles':len(found.stdout.splitlines()),'categories':dict(counts),'consumerCandidates':rows,'claimsConsumersClosed':False};(b/'retire16795-inventory.json').write_bytes((json.dumps(plan,indent=2)+'\n').encode());print(json.dumps({'matched':plan['matchedResultFiles'],'categories':dict(counts),'candidates':len(rows)}))
