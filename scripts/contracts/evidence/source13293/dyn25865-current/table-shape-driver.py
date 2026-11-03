from pathlib import Path
import sys,json,hashlib,re,shutil
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();side=sys.argv[1];assert side in ['managed','native'];producer=b/('dyn25852-managed' if side=='managed' else 'dyn25861-native');out=b/('dyn25853-tables-managed' if side=='managed' else 'dyn25862-tables-native');reuse=[b/'handle25807-native',b/'join25830-native',b/'v20050/compiler-build01'] if side=='managed' else [b/'join25830-native',b/'dyn25860-native',b/'v20050/compiler-build01'];initialize_output(r,out,reusable_directories=reuse);out.mkdir();record=json.loads((producer/'result.json').read_text());assert record['status']=='passed' and record['completed']==record['total']==6 and record['inputsStable'] and record['processesStopped'];assert all(sha(p)==h for p,h in record['inputHashes'].items());contract=b/'dyn25850-plan/table-shape-contract.json';rows=json.loads(contract.read_text())['cases'];paths=[Path(__file__),producer/'result.json',contract,*map(Path,record['inputHashes'])];pins={str(p):sha(p) for p in paths};v=dict(status='running',completed=0,total=5,inputHashes=pins,cases=[],scope='Inspect sealed producer LLVM outputs before final cleanup; one table per reachable trait/concrete pair',observedArtifactHashes={},claimsGoalComplete=False);x=VerificationExecution(r,out,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 for row in rows:
  ll=producer/row['id']/'probe.exe.ll';digest=sha(ll);assert record['generatedOutputHashes'][str(ll)]==digest;v['observedArtifactHashes'][str(ll)]=digest;text=ll.read_text(encoding='utf-8-sig');lines=[line for line in text.splitlines() if line.startswith('@sollang_dyn_') and ' x ptr] [' in line];assert len(lines)==row['vtables'],(row['id'],row['vtables'],len(lines),lines)
  symbols=[]
  for line in lines:
   match=re.fullmatch(r'(@sollang_dyn_\S+) = (?:internal|private) constant \[(\d+) x ptr\] \[(.+)\](?:, align \d+)?',line);assert match,line;assert int(match[2])==2;refs=re.findall(r'ptr @([A-Za-z0-9_]+)',match[3]);assert len(refs)==2
   for symbol in refs:assert len(re.findall(r'^define[^\n]*@'+re.escape(symbol)+r'\(',text,re.M))==1,symbol
   symbols.extend(refs)
  assert len(symbols)==len(set(symbols));assert sha(ll)==digest;(out/(row['id']+'.vtable-definitions.txt')).write_text('\n'.join(lines)+'\n',encoding='utf-8');v['cases'].append(dict(id=row['id'],passed=True,expectedTables=row['vtables'],tables=len(lines),wrapperFunctions=len(symbols),llvmSha256=digest));v['completed']+=1;x.save();print(row['id']+': TABLE PASS',flush=True)
 v['status']='passed'
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
if error:raise error
cleanup_output(r,producer,reusable_directories=reuse)
