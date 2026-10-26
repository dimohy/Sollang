from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'parsing16502-supervised';o.mkdir(exist_ok=False);sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
contract=b/'parsing16501/execution-contract.json';c=read(contract);managed=r/c['compilerBinaries']['managed']['path'];build=read(r/c['compilerBinaries']['managed']['buildRecord']);pins={str(r/p):h for p,h in build['sourceHashesStart'].items()}
for p in [Path(__file__),contract,b/'parsing16501/reviewed-inventory.json',r/c['compilerBinaries']['managed']['buildRecord'],r/c['generationRecord']['path'],*managed.parent.glob('Sollang.Compiler.*'),*list((r/'scripts').glob('native-exact-*.ps1')),r/'scripts/verify-native-exact-fixture-batch.ps1',r/'scripts/verify-native-exact-fixture.ps1',r/'scripts/verification_execution.py']:
 pins[str(p)]=sha(p)
d=dict(schemaVersion=1,status='running',completed=0,total=405,inputHashes=pins,cases=[],phaseContract=str(contract),phase='parsing',compilerSide='managed',caseBudgetSeconds=180,aggregateBudgetSeconds=427*180,scope='Immutable full405 plan plus all22 phase witnesses. Actual current CSharp first. No phase completion credit before whole batch, witnesses and structural validator.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 command=['pwsh','-NoProfile','-File',str(r/'scripts/verify-native-exact-fixture-batch.ps1'),'-Compiler',str(managed),'-Label','managed','-Platform','windows','-LlvmRoot',str(r/'.tools/llvm-22.1.8'),'-StdlibRoot',str(r/'stdlib'),'-RepositoryRoot',str(r),'-OutputDirectory',str(b/'parsing16501/managed'),'-Jobs','4','-TimeoutMilliseconds','180000','-PhaseExecutionContract',str(contract),'-CompilerSide','managed']
 a=x.run(command,o/'execution',timeout=d['aggregateBudgetSeconds']);report=read(b/'parsing16501/managed/managed-batch-results.json');d['batchReport']=str(b/'parsing16501/managed/managed-batch-results.json');d['completed']=report.get('passed',0);assert a.returncode==0 and report['state']=='passed',('PARSING_MANAGED_BATCH_FAILED',a.returncode,report.get('state'));d.update(status='passed',completed=405)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if d['status']=='passed' else 1)
