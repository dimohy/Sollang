from pathlib import Path
import hashlib,json,re,sys,time,subprocess
sys.path.insert(0,str(Path.cwd()/"scripts"))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs,unique_input_files
from completed_artifact_plan import initialize_output
started=time.monotonic();root=Path.cwd();base=root/"artifacts/scratch/resume-20261006-owner-continuation22";plan_path=base/"lexical18886-plan.json";plan=json.loads(plan_path.read_text());out=base/"lexical18887-run1";compiler=Path(plan["compiler"])
assert plan["budget"]=={"maximumTotalSeconds":180,"maximumBuilds":1,"maximumRuntimeInvocations":1,"automaticRetry":False}
subprocess.run([str(base/"v12432/compiler-build01/compiler.exe"),"format","--check",str(root/plan["probe"]),str(root/"scripts/probes/lexical-function-lookup-observer.slg")],check=True)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()==v for p,v in plan["runtimeInputHashes"].items())
paths=unique_input_files([plan_path,Path(__file__),root/plan["probe"],*[root/p for p in plan["buildClosure"]],*[Path(p) for p in plan["runtimeSources"]],*managed_runtime_inputs(compiler),*sorted((root/"stdlib").rglob("*.slg")),root/".tools/llvm-22.1.8/bin/clang.exe",root/"scripts/verification_execution.py",root/"scripts/contracts/artifact-lifecycle.json"])
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
pins={str(p):sha(p) for p in paths};stable=lambda:all(Path(p).is_file() and sha(p)==v for p,v in pins.items())
initialize_output(root,out,reusable_directories=[base/(v+"/compiler-build01") for v in ["v12432","v18309","v18825"]]);out.mkdir()
row={"id":"lexical-function-global-names-microbenchmark","status":"running","passed":False};result={"schemaVersion":1,"status":"running","completed":0,"total":1,"inputHashes":pins,"cases":[row],"budget":plan["budget"],"sourceCount":3,"originalAcceptance":False}
execution=VerificationExecution(root,out,result,stable,sha);error=None
try:
 def remaining():
  value=180-(time.monotonic()-started)
  if value<=0:raise TimeoutError("CALL_CONTEXT_PROFILE_TOTAL_180S_EXHAUSTED")
  return value
 exe=out/"probe.exe";build=execution.run([str(compiler),"build",str(root/plan["probe"]),*[str(root/p) for p in plan["buildClosure"]],"-o",str(exe),"--target","windows-x64","--keep-temps","-O2","--jobs","1","--llvm",str(root/".tools/llvm-22.1.8")],out/"build",timeout=remaining());row.update(buildExit=build.returncode,buildStderr=build.stderr.strip())
 if build.returncode!=0 or build.stderr.strip():raise ValueError("CALL_CONTEXT_PROFILE_BUILD_FAILED: "+build.stderr.strip())
 run=execution.run_program(exe,{"arguments":plan["runtimeSources"]},out/"run",timeout=remaining());row.update(runExit=run.returncode,runStdout=run.stdout.strip(),runStderr=run.stderr.strip())
 if run.returncode!=0 or run.stderr.strip():raise ValueError("CALL_CONTEXT_PROFILE_RUNTIME_FAILED")
 lines=run.stdout.strip().splitlines()
 if len(lines)!=5 or lines[:2]!=["phase=source-preparation","sources=3"]:raise ValueError("LEXICAL_PROFILE_LINES_INVALID")
 rows=[]
 for source,line in enumerate(lines[2:]):
  match=re.fullmatch(r"source=(\d+) functions=(\d+) lookups=(\d+) ms=(\d+) checksum=(-?\d+) valid=(true|false)",line)
  if match is None:raise ValueError("LEXICAL_PROFILE_OBSERVATION_INVALID")
  observedSource,functions,lookups,milliseconds,checksum=map(int,match.groups()[:5])
  if observedSource!=source or functions<=0 or lookups!=128*functions or match.group(6)!="true":raise ValueError("LEXICAL_PROFILE_LOOKUP_IDENTITY_MISMATCH")
  rows.append(dict(sourceModule=source,path=plan["runtimeSources"][source],functions=functions,lookups=lookups,milliseconds=milliseconds,checksum=checksum,valid=True))
 result["sourceTimings"]=rows
 observation=dict(sources=3,functions=sum(r["functions"] for r in rows),lookups=sum(r["lookups"] for r in rows),milliseconds=sum(r["milliseconds"] for r in rows),checksum=sum(r["checksum"] for r in rows))
 row.update(status="passed",passed=True);result.update(status="passed",completed=1,observation=observation)
except BaseException as exc:
 error=exc;row.update(status="failed");result.update(status="failed",failure=str(exc))
finally:
 result["inputHashesEnd"]={str(p):sha(p) for p in paths};execution.finalize(error,cleanup=False)
print(json.dumps({"status":result["status"],"completed":result["completed"],"total":1,"observation":result.get("observation"),"topSources":sorted(result.get("sourceTimings",[]),key=lambda r:r["milliseconds"],reverse=True)[:8],"processes":[{"exit":p.get("exit"),"milliseconds":p.get("durationMilliseconds")} for p in result["processes"]]}))
if error:raise error
