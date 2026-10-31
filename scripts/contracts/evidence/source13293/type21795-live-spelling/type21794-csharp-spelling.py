from pathlib import Path
import json,hashlib,sys,time
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output
B=ROOT/'artifacts/scratch/resume-20261006-owner-continuation22';OUT=B/'type21794-csharp-spelling';CPP=B/'managed21775/compiler/Sollang.Compiler.dll';sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();inputs=[Path(__file__),CPP,*managed_runtime_inputs(CPP),ROOT/'scripts/probes/codegen-identity/Limits.cs',ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj',ROOT/'src/Sollang.Compiler/Cli/IncrementalCodegenCache.cs',ROOT/'src/Sollang.Compiler/CodeGen/LlvmCodegenUnit.cs',*sorted((ROOT/'scripts/probes/codegen-type-spelling').glob('*.slg')),ROOT/'Directory.Build.props',ROOT/'global.json'];inputs=list(dict.fromkeys(inputs));hashes={str(p):sha(p) for p in inputs};assert hashes[str(CPP)]==json.loads((B/'managed21775/result.json').read_text())['generatedOutputHashes'][str(CPP)];initialize_output(ROOT,OUT,reusable_directories=[B/x/'compiler-build01' for x in ['v18915','v20050','v21323']]);OUT.mkdir(exist_ok=False)
with VerificationContractLease(inputs):
 result=dict(schemaVersion=1,status='running',completed=0,total=1,cases=[],inputHashes=hashes,maximumCaseSeconds=180,scope='Actual CSharp parser public type spelling for reference/box/dyn, arrays, dictionary, labeled product, generic builtin constructors, explicit import aliases, Self/Range and decimal normalization; syntax metadata only, no semantics/runtime proof.',claimsGoalComplete=False);run=VerificationExecution(ROOT,OUT,result,lambda:all(p.is_file() and sha(p)==hashes[str(p)] for p in inputs),sha);error=None;start=time.monotonic();budget=lambda:max(1,180-(time.monotonic()-start))
 try:
  import shutil
  vectors=OUT/'module-sources';vectors.mkdir()
  for fixture in (ROOT/'scripts/probes/codegen-type-spelling').glob('*.slg'):shutil.copyfile(fixture,vectors/fixture.name)
  done=run.run(['dotnet','build','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false',str(ROOT/'scripts/probes/codegen-identity/CodegenLimits.csproj'),'-c','Release','-o',str(OUT/'harness'),'--artifacts-path',str(OUT/'dotnet-artifacts')],OUT/'build',timeout=budget());assert done.returncode==0,done.stdout+done.stderr
  done=run.run(['dotnet',str(OUT/'harness/CodegenLimits.dll'),str(CPP),str(OUT/'module-sources'),'interface-vectors'],OUT/'module-sources',timeout=budget());assert done.returncode==0 and not done.stderr,done.stdout+done.stderr;rows=[json.loads(line) for line in done.stdout.splitlines()];assert len(rows)==1
  assert rows[0]['name']=='types' and rows[0]['fields'][:4]==['struct','cache.type_fields.Fields','','public']
  for row in rows:
   result['cases'].append(dict(id=row['name'],passed=True,observation=row));result['completed']+=1
  result['status']='passed'
 except BaseException as e:error=e
 finally:run.finalize(error,cleanup=False)
 if error:raise error
print(json.dumps(dict(status=result['status'],completed=result['completed'],total=result['total'],inputsStable=result['inputsStable'],processesStopped=result['processesStopped'])))
