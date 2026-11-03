from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output,cleanup_output
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();o=b/sys.argv[1];c=Path(sys.argv[2]).resolve();fmt=b/'platform25661-managed/compiler/Sollang.Compiler.exe';src=r/'scripts/probes/file-completion-publication/buffer-controls.slg';reuse=[b/'io25639-native',b/'platform25669-native',b/'v20050/compiler-build01'];initialize_output(r,o,reusable_directories=reuse);o.mkdir();paths=[Path(__file__),src,*managed_runtime_inputs(fmt),*sorted((r/'stdlib').rglob('*.slg')),r/'syntax/sollang.grammar',r/'syntax/sollang.lexer'];paths.extend(managed_runtime_inputs(c) if c.with_suffix('.dll').is_file() else [c]);birth=None
if len(sys.argv)>3:
 birth=Path(sys.argv[3]).resolve();d=json.loads(birth.read_text());assert d['status']=='passed' and d['inputsStable'] and d['processesStopped'];assert all(sha(p)==h for p,h in d['inputHashes'].items());paths.extend([birth,*map(Path,d['inputHashes'])])
pins={str(p.resolve()):sha(p) for p in paths};expected='write=2,2\nread=2,65,66,false\neof=0,true\nempty=0,false\nrange=2\ncancel-range=2\ncancel-task=true\ncancel-open=true';v=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,cases=[],scope='Original ownership APIs across successful async open/read/write, EOF vs empty, invalid range vs cancellation precedence, true Task cancellation and async open cancellation. Eight observations in one program; separate from macro16.',claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);err=None
with VerificationContractLease([Path(p) for p in pins]):
 try:
  d=x.run([str(fmt),'format','--check',str(src)],o/'format',timeout=30);assert d.returncode==0 and not d.stderr,(d.stdout,d.stderr)
  d=x.run([str(c),'build',str(src),'-o',str(o/'probe.exe'),'--target','windows-x64','--keep-temps','--llvm',str(r/'.tools/llvm-22.1.8'),'--jobs','4','-O1'],o/'build',timeout=180);assert d.returncode==0 and not d.stderr,(d.stdout,d.stderr)
  cache=o/'.sollang-cache';assert cache.is_dir();data=cache/'file-buffer-owned.bin';assert not data.exists()
  d=x.run([str(o/'probe.exe'),str(data)],o/'run',timeout=30);assert d.returncode==0 and not d.stderr and d.stdout.strip()==expected,(d.returncode,d.stdout,d.stderr)
  assert data.is_file() and data.read_bytes()==b'';v.update(status='passed',completed=1,cases=[dict(id='buffer-controls',passed=True,compileExit=0,runExit=0,observations=8,ownedRuntimeFile=str(data),ownedRuntimeFileSha256=sha(data))])
 except BaseException as z:err=z
 finally:x.finalize(err,cleanup=False)
if err:raise err
cleanup_output(r,o,reusable_directories=reuse,execute=False)
print(json.dumps({k:v[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
