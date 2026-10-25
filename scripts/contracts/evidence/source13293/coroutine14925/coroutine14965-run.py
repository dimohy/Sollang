from pathlib import Path
import sys,json,hashlib,re,time
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cp=Path(__file__).with_suffix('.json');c=R(cp);pins=c['inputHashes'];converter=Path(__file__).with_name('coroutine14965-convert.ps1');pins[str(cp.resolve())]=H(cp);pins[str(Path(__file__).resolve())]=H(Path(__file__));pins[str(converter.resolve())]=H(converter)
stable=lambda:all(Path(p).is_file() and H(p)==h for p,h in pins.items())
assert stable(),'ALLOCATION9_CURRENT_INPUT_DRIFT'
out=Path(c['output']);initialize_output(root,out,reusable_directories=list(map(Path,c['reusableDirectories'])));out.mkdir(exist_ok=False)
for case in c['cases']:(out/case['id']).mkdir()
r=dict(schemaVersion=1,status='running',scope=c['scope'],completed=0,total=9,originalMemoryTotal=8,cases=[],inputHashes=pins,compilerInvocations=0,claimsWholePhaseComplete=False,claimsGoalComplete=False)
x=VerificationExecution(root,out,r,stable,H);error=None;norm=lambda p:Path(p).read_bytes().replace(bytes((13,10)),bytes((10,)))
try:
 convert=x.run(['pwsh','-NoProfile','-File',str(converter),'-Plan',str(cp.resolve())],out/'convert',timeout=180);assert convert.returncode==0 and not convert.stderr,'ALLOCATION_CONVERTER_FAILED'
 for case in c['cases']:
  folder=out/case['id'];ll=Path(case['auditLlvm']);row=dict(id=case['id'],status='running',passed=False,expectedCount=case['expectedCount'],auditLlvmSha256=H(ll));r['cases'].append(row);x.save();start=time.monotonic()
  assembled=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(ll),'-o',str(folder/'audit.bc')],folder/'assemble',timeout=180);assert assembled.returncode==0 and not assembled.stderr,'ALLOCATION_LLVM_AS_FAILED:'+case['id']
  linked=x.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),str(ll),c['shim'],'-O0','-Wno-override-module','-o',str(folder/'audit.exe'),'-lbcrypt','-lshell32','-lws2_32','-lole32'],folder/'link',timeout=max(1,180-(time.monotonic()-start)));assert linked.returncode==0 and not linked.stderr,'ALLOCATION_LINK_FAILED:'+case['id']
  ran=x.run([str(folder/'audit.exe')],folder/'run',timeout=max(1,180-(time.monotonic()-start)));data=norm(folder/'run.stdout');match=re.search(rb'allocations=(\d+),releases=(\d+),invalid=(\d+)\n$',data);assert ran.returncode==0 and not ran.stderr and match,'ALLOCATION_RUNTIME_FAILED:'+case['id'];alloc,release,invalid=map(int,match.groups());assert alloc==release and invalid==0 and data[:match.start()]==norm(case['originalProgramStdout']),'ALLOCATION_ORACLE_MISMATCH:'+case['id']
  if case['expectedCount'] is not None:assert alloc==case['expectedCount'],'PRODUCTION_OFF_EXACT_ALLOCATION_MISMATCH'
  row.update(status='passed',passed=True,allocations=alloc,releases=release,invalid=invalid,exactProgramOutput=True,liveListEmptyVerifiedByOriginalShim=True);r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if r['status']=='passed' else 1)
