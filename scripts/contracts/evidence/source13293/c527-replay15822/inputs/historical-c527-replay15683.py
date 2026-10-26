from pathlib import Path
import json,sys,hashlib,time
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
proof=b/'historical-c527-replay15682/result.json';prior=json.loads(proof.read_text(encoding='utf-8-sig'));assert prior['compilerBuildExit']==0 and prior['processesStopped'] and prior['inputsStable']
for p,h in {**prior['inputHashes'],**prior['generatedCompilerPins']}.items():assert sha(p)==h.upper(),p
source=b/'historical-c527-source15677/source';fixture=source/'examples/regression/1872-interpolation-large-integer-to-float.slg';original=r/'examples/regression/1872-interpolation-large-integer-to-float.slg';assert fixture.read_bytes()==original.read_bytes()
selected=next(p for p in [fixture.parent,*fixture.parent.parents] if (p/'Sollang.slnx').is_file() and (p/'stdlib').is_dir());assert selected==source
compiler=b/'historical-c527-replay15682/compiler/Sollang.Compiler.exe';out=b/'historical-c527-replay15683';inputs=[*[Path(p) for p in prior['inputHashes']],*[Path(p) for p in prior['generatedCompilerPins']],proof,source/'Sollang.slnx',fixture,b/'historical-c527-source15677/resolved-inputs15683.json',Path(__file__)];inputs=list(dict.fromkeys(inputs))
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=2,scope='Actual unchanged historical Git compiler and library with byte-identical original case; not original-file recovery',reusedCompilerBuildProof=str(proof),reusedCompilerScope='Successful compiler build only; failed previous fixture stage is not reused',historicalCommit=prior['historicalCommit'],originalBaselineRecovered=False,selectedHistoricalRoot=str(source),historicalStdlibSourceCount=len(list((source/'stdlib').rglob('*.slg'))),programCaseBudgetSeconds=180)
 execution=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
 try:
  program=out/'fixture.exe';compiled=execution.run([str(compiler),'build',str(fixture),'-o',str(program),'--llvm',str(r/'.tools/llvm-22.1.8'),'--target','windows-x64','-O1','--keep-temps'],out/'fixture-build',timeout=180);result['fixtureBuildExit']=compiled.returncode
  if compiled.returncode:raise ValueError('ISOLATED_HISTORICAL_FIXTURE_BUILD_FAILED')
  ll=out/'fixture.exe.ll';assert ll.is_file();text=ll.read_text(encoding='utf-8-sig');result['actualLlvmSha256']=sha(ll);result['badLlvmPredicate']='sitofp i32 4294967296 to double';result['badLlvmPredicateObserved']=result['badLlvmPredicate'] in text
  if not result['badLlvmPredicateObserved']:raise ValueError('HISTORICAL_SOURCE_DID_NOT_REPRODUCE_PREDICATE')
  result['completed']=1;execution.save();ran=execution.run([str(program)],out/'fixture-run',timeout=180);result.update(fixtureRunExit=ran.returncode,fixtureStdout=ran.stdout,expectedDerivedBadStdout='value=0\n')
  if ran.returncode or ran.stderr or ran.stdout.replace('\r\n','\n')!='value=0\n':raise ValueError('HISTORICAL_BAD_BEHAVIOR_NOT_REPRODUCED')
  result.update(status='passed',completed=2)
 except BaseException as failure:error=failure
 finally:execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','badLlvmPredicateObserved','fixtureStdout','failure','inputsStable','processesStopped']}))
