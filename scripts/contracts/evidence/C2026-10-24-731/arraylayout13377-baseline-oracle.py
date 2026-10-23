from pathlib import Path
import argparse,json,hashlib,sys
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
a=argparse.ArgumentParser();a.add_argument('--compiler',type=Path,required=True);a.add_argument('--output',type=Path,required=True);args=a.parse_args();compiler=args.compiler.resolve();out=args.output.resolve();out.mkdir(exist_ok=False)
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';contract=b/'substitution13375-guards-contract.json';c=json.loads(contract.read_text());assert sha(compiler)=='EB1476A851AA60C02B0C66C1F0746E232AA76A7905FFD45ADCA3399458F649BA'
paths=[compiler,compiler.parent/'result.json',contract,b/'substitution13375-guards-managed/result.json',b/'arraylayout13376-source-comparison.json',Path(__file__),*[r/x['source'] for x in c['cases']],*sorted((r/'stdlib').rglob('*.slg'))];pins={str(p):sha(p) for p in paths}
d=dict(schemaVersion=1,status='running',completed=0,total=2,inputHashes=pins,cases=[],scope='Actual retained EB14 baseline compiler with known C731. Its original test-tool epoch is preserved; this is a pinned compiler diagnostic counterexample, not current whole-source qualification.',claimsCurrentBuildInputsVerified=False,claimsGoalComplete=False)
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);err=None
try:
 for case in c['cases']:
  folder=out/case['id'];folder.mkdir();p=x.run([str(compiler),'build',str(r/case['source']),'-o',str(folder/'probe.exe'),'--target','windows-x64','--keep-temps','-O1','--jobs','1','--llvm',str(r/'.tools/llvm-22.1.8'),'--stdlib',str(r/'stdlib')],folder/'build',timeout=120)
  llvm=[str(f.relative_to(folder)) for f in folder.rglob('*') if f.is_file() and '.ll' in f.suffixes];passed=p.returncode==1 and p.stderr.strip()==case['stderr'] and not llvm
  d['cases'].append(dict(id=case['id'],status='passed' if passed else 'failed',passed=passed,buildExit=p.returncode,buildStderr=p.stderr.strip(),unexpectedLlvmOutputs=llvm,rejectedBeforeLlvm=p.returncode==1 and not llvm))
  if passed:d['completed']+=1
  assert passed,'C731 exact source diagnostic/pre-LLVM invariant failed: '+case['id']
 d['status']='passed'
except BaseException as e:err=e
finally:x.finalize(err,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']},ensure_ascii=False));sys.exit(0 if d['status']=='passed' else 1)
