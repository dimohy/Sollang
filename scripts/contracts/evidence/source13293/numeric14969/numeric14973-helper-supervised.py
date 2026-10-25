from pathlib import Path
import hashlib,json,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def rd(p):return json.loads(p.read_text(encoding='utf-8-sig'))
compiler=b/'v14775/compiler-build01/compiler.exe';out=b/'numeric14973-helper-supervised';payload=b/'numeric14973-helper'
assert not out.exists() and not payload.exists()
paths=[*sorted((r/'selfhost').rglob('*.slg')),*sorted((r/'stdlib').rglob('*.slg')),r/'scripts/verify-contextual-integer-literals.ps1',r/'scripts/contracts/fixtures/c394-contextual-integer-range.json',r/'scripts/contracts/fixtures/1715-native-negative-float-context.slg',r/'scripts/probes/contextual-integer-literals.slg',r/'scripts/probes/contextual-integer-literals/range-diagnostics.slg',r/'scripts/verification_execution.py',Path(__file__),compiler,b/'v14775/compiler-build01/result.json',b/'numeric14970-managed10/result.json',r/'scripts/contracts/evidence/source13293/numeric14969/current-source-comparison14971.json',r/'.tools/llvm-22.1.8/bin/clang.exe',r/'.tools/llvm-22.1.8/bin/llvm-as.exe']
pins={str(p):sha(p) for p in paths};out.mkdir()
d=dict(schemaVersion=1,status='running',scope='Existing production numeric context helper: actual current compiler source IR plus extracted current helper/assertion groups and lexical bounds62. Does not certify whole32-bit target or phase completion.',completed=0,total=1,inputHashes=pins,claimsGoalComplete=False)
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);err=None
try:
 result=x.run(['pwsh','-NoProfile','-File',str(r/'scripts/verify-contextual-integer-literals.ps1'),'-CandidateCompiler',str(compiler),'-ExpectedCandidateSha256',sha(compiler),'-OutputDirectory',str(payload),'-RequireCandidateSealed'],out/'helper',timeout=180)
 assert result.returncode==0,result.stderr
 proof=rd(payload/'result.json');assert proof['completed']==proof['total'] and proof['candidateSealingRequired'];bounds=proof['signedAndRangeDiagnostics'];assert bounds['completed']==bounds['total']==62
 d.update(status='passed',completed=1,helperAssertionGroups=proof['completed'],lexicalBoundsCases=62,nativeCandidateUnsealedNodes=proof['nativeCandidateTopology']['candidateUnsealedNodeCount'])
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped','helperAssertionGroups','lexicalBoundsCases']}));sys.exit(0 if d['status']=='passed' else 1)
