from pathlib import Path
import hashlib,json,sys,time
sys.path.insert(0,str(Path.cwd()/"scripts"))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs,unique_input_files
from completed_artifact_plan import initialize_output
root=Path.cwd();base=root/"artifacts/scratch/resume-20261006-owner-continuation22"
plan=base/"parameters18730-plan.json";contract=json.loads(plan.read_text());case=contract["cases"][0]
out=base/sys.argv[1];compiler=base/"managed18577/compiler/Sollang.Compiler.exe"
keep=[base/(name+"/compiler-build01") for name in ["v12432","v18309","v18715"]]
initialize_output(root,out,reusable_directories=keep);out.mkdir()
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
paths=unique_input_files([plan,Path(__file__),root/case["source"],*[root/p for p in case["additionalSources"]],*[root/p for p in contract["runtimeInputFiles"]],*managed_runtime_inputs(compiler),*sorted((root/"stdlib").rglob("*.slg")),root/".tools/llvm-22.1.8/bin/clang.exe",root/"scripts/verification_execution.py",root/"scripts/contracts/artifact-lifecycle.json"])
pins={str(p):sha(p) for p in paths};stable=lambda:all(Path(p).is_file() and sha(p)==v for p,v in pins.items())
row={"id":case["id"],"status":"running","passed":False}
result={"schemaVersion":1,"status":"running","completed":0,"total":1,"inputHashes":pins,"cases":[row],"budgetSeconds":180,"compilerDllSha256":sha(compiler.with_suffix(".dll")),"measurementScope":"whole runtime process including source preparation and binding query, one sample"}
execution=VerificationExecution(root,out,result,stable,sha);started=time.monotonic();error=None
try:
 exe=out/"probe.exe"
 def remaining():
  seconds=180-(time.monotonic()-started)
  if seconds<=0:raise TimeoutError("CASE_TOTAL_180S_EXHAUSTED")
  return seconds
 build=execution.run([str(compiler),"build",str(root/case["source"]),*[str(root/p) for p in case["additionalSources"]],"-o",str(exe),"--target","windows-x64","--keep-temps","-O2","--jobs","1","--llvm",str(root/".tools/llvm-22.1.8")],out/"build",timeout=remaining());row.update(buildExit=build.returncode,buildStderr=build.stderr.strip());assert build.returncode==0 and not build.stderr.strip(),build.stderr
 run=execution.run_program(exe,{"arguments":case["runArguments"]},out/"run",timeout=remaining());row.update(runExit=run.returncode,runStdout=run.stdout.strip(),runStderr=run.stderr.strip());assert run.returncode==0 and not run.stderr.strip() and run.stdout.strip()==case["stdout"],row
 row.update(status="passed",passed=True);result.update(status="passed",completed=1)
except BaseException as exc:
 error=exc;row.update(status="failed");result.update(status="failed",failure=str(exc))
finally:
 result["inputHashesEnd"]={str(p):sha(p) for p in paths};execution.finalize(error,cleanup=False)
print(json.dumps({"status":result["status"],"completed":result["completed"],"total":result["total"],"processes":[{"exit":p.get("exit"),"milliseconds":p.get("durationMilliseconds")} for p in result["processes"]],"case":row}))
if error:raise error
