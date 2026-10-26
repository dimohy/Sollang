from pathlib import Path
import json,sys,subprocess,concurrent.futures,datetime
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'style16266-semantic';jobs=json.loads((o/'plan.json').read_text())['jobs'];result=dict(schemaVersion=1,status='running',completed=0,total=len(jobs),cases=[],scope='Managed semantic checks of development fixtures after value-identical raw literal normalization; frozen original fixtures untouched')
def save(): (o/'result.json').write_text(json.dumps(result,indent=2)+'\n')
def run(job):
 cmd=[sys.executable,str(r/'scripts/verify-focused-selfhost-semantic-preflight.py'),'--output',job['output'],'--compiler',str(b/'managed15892/compiler/Sollang.Compiler.exe'),'--manifest',job['manifest'],'--expected-managed-dll-sha256','222B61D3952EC00E693D5A48FFD3BE0199CEEF0E7EE5C86FAE29FE0A21620853']
 for v in ['v12432','v16203','v16219']:cmd+=['--reusable-directory',str(b/v/'compiler-build01')]
 stdout=o/(job['id']+'.stdout');stderr=o/(job['id']+'.stderr')
 with stdout.open('wb') as a,stderr.open('wb') as z:done=subprocess.run(cmd,stdout=a,stderr=z)
 p=Path(job['output'])/'result.json';proof=json.loads(p.read_text(encoding='utf-8-sig')) if p.exists() else {}
 passed=done.returncode==0 and proof.get('status')=='passed' and proof.get('completed')==proof.get('total')==4 and proof.get('inputsStable') and proof.get('processesStopped')
 return dict(id=job['id'],status='passed' if passed else 'failed',exitCode=done.returncode,result=str(p))
save()
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for row in pool.map(run,jobs):
  result['cases'].append(row);result['completed']+=row['status']=='passed';save();print(row['id']+': '+row['status'],flush=True)
result['status']='passed' if result['completed']==result['total'] else 'failed';result['finishedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save();print(json.dumps({k:result[k] for k in ['status','completed','total']}))
