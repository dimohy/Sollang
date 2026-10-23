from pathlib import Path
import sys,json,hashlib
r=Path.cwd();sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_stdlib_source_preflight import validate
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';old=b/'slice13069-source';cp=b/'slice13069-contract.json';c=json.loads(cp.read_text());proof=json.loads((old/'result.json').read_text(encoding='utf-8-sig'));stdlib=b/'slice13077-stdlib/result.json'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
# Current transitive source gate precedes every new emission. The older
# admission blob is retained only as historical execution provenance.
stdlib_validation=validate(r,stdlib)
assert proof['status']=='passed' and proof['completed']==proof['total']==17 and proof['inputsStable'] and proof['processesStopped']
for p,h in proof['inputHashes'].items():assert Path(p).is_file() and sha(p)==h,p
producer=old/'producer.exe';assert sha(producer)==proof['producerSha256']
canonical=[str(r/line.strip()) for line in (r/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt').read_text().splitlines() if line.strip()]
commands=[p['command'] for p in proof['processes'] if len(p['command'])>2 and p['command'][1]=='build' and '-o' in p['command'] and Path(p['command'][p['command'].index('-o')+1])==producer];assert len(commands)==1
command=commands[0];source_paths=command[2:command.index('-o')];assert source_paths==[str(r/c['source']),*canonical[1:]] and len(source_paths)==151
assert 'slice13077' not in (r/c['source']).read_text() and 'slice13059' not in (r/c['source']).read_text()
o=b/'slice13079-source-requalified';o.mkdir(exist_ok=False);pins=dict(proof['inputHashes'])
for p in [producer,old/'result.json',stdlib,Path(__file__),r/'scripts/verification_stdlib_source_preflight.py']:
 pins[str(p)]=sha(p)
for p,h in json.loads(stdlib.read_text(encoding='utf-8-sig'))['inputHashes'].items():
 assert str(Path(p)) not in pins or pins[str(Path(p))]==h
 pins[str(Path(p))]=h
record={'schemaVersion':1,'status':'running','scope':'Current17 source requalification after current full-stdlib gate. Reuse unchanged producer code with exact151 source closure/managed compiler/tool/runtime identity; no new producer build and no claim old admission was current.','inputHashes':pins,'completed':0,'total':17,'cases':[],'budget':c['budget'],'producerPath':str(producer),'producerSha256':sha(producer),'producerBuildCount':0,'reusedProducer':True,'producerCodeBuildProvenance':str(old/'result.json'),'stdlibSourcePreflight':{'status':'passed-current-source','proof':str(stdlib),'validation':stdlib_validation},'supersededAdmissionProof':{'path':str(b/'slice13059-stdlib/result.json'),'current':False,'role':'historical-only; not the current admission gate'},'claimsGoalComplete':False}
x=VerificationExecution(r,o,record,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for case in c['cases']:
  validate(r,stdlib)
  folder=o/case['id'];folder.mkdir();row={'id':case['id'],'status':'running','source':case['source'],'target':case['target']};record['cases'].append(row);x.save();a=x.run([str(producer),case['source'],case['target']],folder/'emit',timeout=180);row['emissionExit']=a.returncode;assert a.returncode==0 and not a.stderr,(case['id'],a.stderr)
  llvm=folder/'emitted.ll';llvm.write_bytes((folder/'emit.stdout').read_bytes());row['emittedLlvmSha256']=sha(llvm);a=x.run([str(r/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(folder/'emitted.bc')],folder/'assemble',timeout=180);row['assemblyExit']=a.returncode;assert a.returncode==0 and not a.stderr,(case['id'],a.stderr);row['status']='passed';record['completed']+=1;x.save()
 record['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','producerBuildCount','reusedProducer','inputsStable','processesStopped','failure']}))
if record['status']!='passed':raise SystemExit(1)
