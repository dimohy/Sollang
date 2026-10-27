from pathlib import Path
import json,hashlib,sys,time,shutil,struct
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
contractpath=b/'duplicate16790-contract.json';plan=json.loads(contractpath.read_text(encoding='utf-8-sig'));compiler=b/'managed16362/compiler/Sollang.Compiler.exe';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();assert sha(compiler.with_suffix('.dll'))=='375D9B7D7448758904AFE49F1F8DDD9136E218EFFCC75A221E63C395B501DDB1'
proofpaths=[root/plan[k] for k in ['referenceProof','semanticProof','stdlibProof']];inputs=[Path(__file__),contractpath,*proofpaths,*compiler.parent.glob('Sollang.Compiler.*'),root/plan['producer'],*[root/p for p in plan['providers']],*[root/p for p in plan['stdlibSources']],*[root/p for c in plan['cases'] for p in c['sources']],root/'scripts/verification_execution.py',root/'scripts/verification_contract_lease.py'];proofs=[]
for p in proofpaths:
 r=json.loads(p.read_text(encoding='utf-8-sig'));assert r['status']=='passed' and r['completed']==r['total'] and r['inputsStable'] and r['processesStopped'],p
 for name,h in r['inputHashes'].items():assert Path(name).is_file() and sha(name)==h.upper(),name
 inputs.extend(map(Path,r['inputHashes']));proofs.append(r)
references={c['id']:c for c in proofs[0]['cases']};assert set(references)=={c['id'] for c in plan['cases']}
llvmroot=root/'.tools/llvm-22.1.8/bin';assembler=llvmroot/'llvm-as.exe';linker=llvmroot/'clang.exe';assert assembler.is_file() and linker.is_file();inputs.extend([assembler,linker]);inputs=list(dict.fromkeys(inputs));out=b/'duplicate16792-cache10';out.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 pins={str(p):sha(p) for p in inputs};r=dict(schemaVersion=1,status='running',completed=0,total=len(plan['cases']),inputHashes=pins,cases=[],scope=plan['scope'],producerBudgetSeconds=180,caseBudgetSeconds=180,fixedProgramIds=[c['id'] for c in plan['cases']],generalCompilerProduct=False,claimsGoalComplete=False);x=VerificationExecution(root,out,r,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
 def run(command,prefix,deadline=None):
  remaining=180 if deadline is None else int(deadline-time.monotonic())
  if remaining<=0:raise TimeoutError('FIXED_SOURCE_CASE_180_SECONDS_EXHAUSTED')
  return x.run(command,prefix,timeout=remaining)
 try:
  producer=out/'fixed-producer.exe';build=run([str(compiler),'build',str(root/plan['producer']),*[str(root/p) for p in plan['providers']],'-o',str(producer),'--target','windows-x64','-O0','--jobs','1','--keep-temps','--llvm',str(llvmroot.parent)],out/'producer-build');stderr=(out/'producer-build.stderr').read_text(encoding='utf-8-sig').strip();r['producerBuild']=dict(exit=build.returncode,stderr=stderr,source=plan['producer'])
  if build.returncode or stderr:raise ValueError('FIXED_SOURCE_PRODUCER_BUILD_FAILED')
  r['producerBuild'].update(sha256=sha(producer),buildCount=1);x.save()
  for case in plan['cases']:
   folder=out/case['id'];folder.mkdir();deadline=time.monotonic()+180;reference=references[case['id']];emission=run([str(producer),case['id'],str(folder/'cache.semantic'),str(folder/'cache.staged'),'cold'],folder/'emission',deadline);actual=(folder/'emission.stdout').read_text(encoding='utf-8-sig').replace('\r\n','\n').strip();stderr=(folder/'emission.stderr').read_text(encoding='utf-8-sig').strip();row=dict(id=case['id'],status='running',expectedReferenceExit=reference['buildExit'],emissionExit=emission.returncode,emissionStderr=stderr);ok=emission.returncode==0 and not stderr
   if reference['buildExit']!=0:
    expected=reference['buildStderr']+'\nrejected=1';row.update(expectedDiagnostic=reference['buildStderr'],actualDiagnostic=actual,emittedLlvm=False);ok=ok and actual==expected
   elif ok:
    ll=folder/'emitted.ll';ll.write_bytes((folder/'emission.stdout').read_bytes());row.update(emittedLlvm=True,emittedLlvmSha256=sha(ll));assembly=run([str(assembler),str(ll),'-o',str(folder/'emitted.bc')],folder/'assemble',deadline);row['assemblyExit']=assembly.returncode;ok=assembly.returncode==0 and not (folder/'assemble.stderr').read_text(encoding='utf-8-sig').strip()
    if ok:
     program=folder/'program.exe';linked=run([str(linker),'-Wno-override-module',str(ll),'-O1','-o',str(program),'-lws2_32','-lshell32','-lbcrypt','-lole32'],folder/'link',deadline);row['linkExit']=linked.returncode;ok=linked.returncode==0 and not (folder/'link.stderr').read_text(encoding='utf-8-sig').strip()
     if ok:
      executed=run([str(program)],folder/'program',deadline);stdout=(folder/'program.stdout').read_text(encoding='utf-8-sig').strip();runerr=(folder/'program.stderr').read_text(encoding='utf-8-sig').strip();row.update(runExit=executed.returncode,runStdout=stdout,runStderr=runerr,expectedStdout=reference['runStdout']);ok=executed.returncode==0 and not runerr and stdout==reference['runStdout']
   if ok and reference['buildExit']==0:
    destination=folder/'cache.semantic';staged=folder/'cache.staged';assert staged.is_file(),'POSITIVE_CACHE_NOT_STAGED'
    shutil.copyfile(staged,destination);cacheHash=sha(destination)
    warm=run([str(producer),case['id'],str(destination),str(folder/'warm.staged'),'warm'],folder/'warm',deadline)
    warmtext=(folder/'warm.stdout').read_text(encoding='utf-8-sig').replace('\r\n','\n').strip();warmerr=(folder/'warm.stderr').read_text(encoding='utf-8-sig').strip()
    ok=warm.returncode==0 and not warmerr and warmtext==actual and sha(destination)==cacheHash and (folder/'warm.staged').is_file()
    if ok:
     header=struct.unpack('<9Q',(folder/'warm.staged').read_bytes()[:72]);ok=header[4]==0 and header[5]>0
     row.update(warmFrameLoadStatus=header[4],warmFrameReused=header[5],warmFrameRejected=header[6],warmFrameSkipped=header[7])
    row.update(warmExit=warm.returncode,warmStderr=warmerr,warmLlvmExact=warmtext==actual,cacheSha256=cacheHash,loadedFrameValidated=ok)
   elif ok:
    ok=not (folder/'cache.staged').exists();row['rejectedBeforeCacheStage']=ok
   row.update(status='passed' if ok else 'failed',passed=ok);r['cases'].append(row)
   if not ok:raise ValueError('FIXED_DECLARATION_CASE_DIFFERENCE:'+case['id'])
   r['completed']+=1;x.save()
  r['status']='passed'
 except BaseException as caught:error=caught
 finally:x.finalize(error,cleanup=False)
 print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
 if error:raise error
