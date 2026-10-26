from pathlib import Path
import json,sys,hashlib,shutil,time
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
source=b/'historical-c527-source15677/source';manifest=b/'historical-c527-source15677/source-manifest.json';m=json.loads(manifest.read_text(encoding='utf-8-sig'));fixture=r/'examples/regression/1872-interpolation-large-integer-to-float.slg';assert sha(fixture)=='2EEBBFA63EE8005249B08D561F3C20CDA8564AE0A50046DDD5AE4F0413B6D3B9'
files=m['files']+m['supplementalGitBuildInputs']
for item in files:assert sha(source/item['path'])==item['sha256']
inputs=[manifest,b/'historical-c527-plan15675.json',fixture,*[source/item['path'] for item in files],Path(__file__),r/'scripts/verification_execution.py',r/'.tools/llvm-22.1.8/bin/clang.exe',r/'.tools/llvm-22.1.8/bin/lld-link.exe'];out=b/'historical-c527-replay15681';generated={};binaryLease=None;started=time.monotonic()
with VerificationContractLease(inputs):
 out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,completed=0,total=3,scope='Actual unchanged pre-fix Git compiler replay, not recovery of missing original LLVM bytes',historicalCommit=m['commit'],originalBaselineRecovered=False,originalFixtureUnchanged=True,aggregateBudgetSeconds=600,programCaseBudgetSeconds=180,standardLibraryAuthority='Unmodified historical Git source embedded by the original compiler project')
 execution=VerificationExecution(r,out,result,lambda:all(sha(p)==h for p,h in {**pins,**generated}.items()),sha);error=None
 def run(cmd,prefix,timeout=180):
  if time.monotonic()-started+timeout>600:raise ValueError('HISTORICAL_REPLAY_BUDGET_EXHAUSTED_BEFORE_STEP')
  return execution.run(cmd,prefix,timeout=timeout)
 try:
  dotnet=shutil.which('dotnet');assert dotnet
  probe=run([dotnet,'--list-sdks'],out/'sdk',30);assert probe.returncode==0
  assert (source/'global.json').read_bytes()==(r/'global.json').read_bytes()
  policy=json.loads((source/'global.json').read_text(encoding='utf-8-sig'))['sdk'];assert policy['rollForward']=='latestFeature' and policy['allowPrerelease'] is True
  resolved=run([dotnet,'--version'],out/'resolved-sdk',30);assert resolved.returncode==0 and resolved.stdout.strip().startswith('11.0.100-')
  result.update(sdkPolicy=policy,resolvedSdk=resolved.stdout.strip())
  command=[dotnet,'build',str(source/'src/Sollang.Compiler/Sollang.Compiler.csproj'),'-c','Release','-o',str(out/'compiler'),'--no-incremental','--disable-build-servers','-warnaserror','/p:UseSharedCompilation=false','/p:SourceRevisionId='+m['commit']]
  built=run(command,out/'compiler-build');result['compilerBuildExit']=built.returncode
  if built.returncode:raise ValueError('HISTORICAL_COMPILER_BUILD_FAILED')
  compiler=out/'compiler/Sollang.Compiler.exe';paths=[compiler,compiler.with_suffix('.dll'),compiler.with_suffix('.deps.json'),compiler.with_suffix('.runtimeconfig.json')];generated.update({str(p):sha(p) for p in paths});binaryLease=VerificationContractLease(paths);binaryLease.__enter__();result['generatedCompilerPins']=generated;result['completed']=1;execution.save()
  program=out/'fixture.exe';compiled=run([str(compiler),'build',str(fixture),'-o',str(program),'--llvm',str(r/'.tools/llvm-22.1.8'),'--target','windows-x64','-O1','--keep-temps'],out/'fixture-build');result['fixtureBuildExit']=compiled.returncode
  if compiled.returncode:raise ValueError('HISTORICAL_ORIGINAL_FIXTURE_BUILD_FAILED')
  ll=out/'fixture.exe.ll';assert ll.is_file();text=ll.read_text(encoding='utf-8-sig');result['actualLlvmSha256']=sha(ll);result['badLlvmPredicate']='sitofp i32 4294967296 to double';result['badLlvmPredicateObserved']=result['badLlvmPredicate'] in text
  if not result['badLlvmPredicateObserved']:raise ValueError('HISTORICAL_GIT_SOURCE_DID_NOT_REPRODUCE_PREDICATE')
  result['completed']=2;execution.save();ran=run([str(program)],out/'fixture-run');result.update(fixtureRunExit=ran.returncode,fixtureStdout=ran.stdout,expectedDerivedBadStdout='value=0\n')
  if ran.returncode or ran.stderr or ran.stdout.replace('\r\n','\n')!='value=0\n':raise ValueError('HISTORICAL_DERIVED_BAD_BEHAVIOR_NOT_REPRODUCED')
  result.update(status='passed',completed=3)
 except BaseException as failure:error=failure
 finally:
  execution.finalize(error,cleanup=False)
  if binaryLease:binaryLease.__exit__(None,None,None)
print(json.dumps({k:result.get(k) for k in ['status','completed','total','badLlvmPredicateObserved','fixtureStdout','failure','inputsStable','processesStopped']}))
