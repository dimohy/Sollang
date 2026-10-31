from pathlib import Path
import json,hashlib,sys,time
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'cache21704-csharp-codec';CPP=B/'managed21702/compiler/Sollang.Compiler.dll';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();inputs=[Path(__file__),CPP,*managed_runtime_inputs(CPP),ROOT/'scripts/probes/codegen-identity/Limits.cs',ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj',ROOT/'src/Sollang.Compiler/Cli/IncrementalCodegenCache.cs',ROOT/'src/Sollang.Compiler/CodeGen/LlvmCodegenUnit.cs',ROOT/'Directory.Build.props',ROOT/'global.json'];inputs=list(dict.fromkeys(inputs));hashes={str(p):sha(p) for p in inputs};assert hashes[str(CPP)]==json.loads((B/'managed21702/result.json').read_text())['generatedOutputHashes'][str(CPP)];initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 result=dict(schemaVersion=1,status='running',completed=0,total=36,cases=[],inputHashes=hashes,maximumCaseSeconds=180,scope='CSharp-first actual CheckedLength boundary observation15, existing actual codec identity encode/read controls4; actual24-word record6 with valid envelope checksum and deliberately oversized declared fragment lengths; no large payload allocation',claimsGoalComplete=False);run=VerificationExecution(ROOT,OUT,result,lambda:all(p.is_file() and sha(p)==hashes[str(p)] for p in inputs),sha);error=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  done=run.run(['dotnet','build','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false',str(ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj'),'-c','Release','-o',str(OUT/'harness'),'--artifacts-path',str(OUT/'dotnet-artifacts')],OUT/'build',timeout=budget());assert done.returncode==0,done.stdout+done.stderr
  done=run.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP),str(OUT/'lengths'),'declared-lengths'],OUT/'lengths',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr;rows=[json.loads(s) for s in done.stdout.splitlines()];assert len(rows)==15
  maxima={'identity':1048576,'fragment':1073741824,'fragment words':2147483647}
  for row in rows:
   maximum=maxima[row['description']];assert row['maximum']==maximum;accepted=row['value']<=maximum;assert row['accepted'] is accepted;assert row['result']==(row['value'] if accepted else None);assert row['diagnostic']==(None if accepted else 'artifact '+row['description']+' length is invalid');result['cases'].append(dict(id=row['description']+'-'+str(row['value']),passed=True,observation=row));result['completed']+=1
  run.save();done=run.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP),str(OUT/'identity')],OUT/'identity',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr;rows=[json.loads(s) for s in done.stdout.splitlines()];assert [r['length'] for r in rows]==[0,1,1048576,1048577]
  for row in rows:
   accepted=row['length']<=1048576;assert row['accepted'] is accepted and row['diagnostic']==(None if accepted else 'artifact identity length is invalid');result['cases'].append(dict(id='codec-identity-'+str(row['length']),passed=True,observation=row));result['completed']+=1
  done=run.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP),str(OUT/'records'),'declared-records'],OUT/'records',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr;rows=[json.loads(s) for s in done.stdout.splitlines()];assert len(rows)==9
  for row in rows:
   accepted=row['kind']==0 and row['declaredFragmentBytes']==0;assert row['accepted'] is accepted and row['diagnostic']==(None if accepted else 'artifact unit kind is invalid' if row['kind'] else 'artifact fragment length is invalid');assert len(row['words'])==24;result['cases'].append(dict(id=row['label'],passed=True,observation=row));result['completed']+=1
  done=run.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP),str(OUT/'context-records'),'context-records'],OUT/'context-records',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr;rows=[json.loads(line) for line in done.stdout.splitlines()];assert len(rows)==8
  for row in rows:
   assert row['accepted']==(row['row']==7) and row['diagnostic']==(None if row['row']==7 else 'artifact context mismatch'),row
   result['cases'].append(dict(id='context-'+str(row['row']),passed=True,observation=row));result['completed']+=1
  result['status']='passed'
 except BaseException as e:error=e
 finally:run.finalize(error,cleanup=False)
 if error:raise error
print(json.dumps(dict(status=result['status'],completed=result['completed'],total=result['total'],inputsStable=result['inputsStable'],processesStopped=result['processesStopped'])))
