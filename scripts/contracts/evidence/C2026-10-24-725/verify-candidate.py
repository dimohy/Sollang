from pathlib import Path
import hashlib,json,sys
E=Path(__file__).resolve().parent
R=E.parents[3]
def load(name):return json.loads((E/name).read_text(encoding="utf-8-sig"))
for entry in load("candidate-manifest.json")["files"]:
    assert hashlib.sha256((E/entry["path"]).read_bytes()).hexdigest().upper()==entry["sha256"]
before=load("native-build-result.json")
after=load("candidate-native-build-result.json")
outer=load("candidate-controller-result.json")
pre=load("candidate-semantic-preflight.json")
assert before["status"]=="failed" and before["steps"]["build"] is None
assert after["status"]=="passed" and after["inputsStable"] and all(x==0 for x in after["steps"].values())
assert outer["status"]=="passed" and outer["inputsStable"] and outer["processesStopped"]
assert pre["status"]=="passed" and pre["completed"]==pre["total"]==4
directories=after["pendingConsumerProtection"]["reusableCompilerDirectories"]
assert 1<=len(set(directories))<=3
for name in ["scripts/completed_artifact_plan.py","scripts/ArtifactLifecycle.ps1","scripts/contracts/artifact-lifecycle.json","scripts/verify-focused-selfhost-semantic-preflight.py"]:
    assert before["inputHashesStart"][str(R/name)]==hashlib.sha256((R/name).read_bytes()).hexdigest().upper()
sys.path.insert(0,str(R/"scripts"))
from completed_artifact_plan import default_reusable_directories,assert_artifact_path
rejected=0
for path in default_reusable_directories(R):
    try:assert_artifact_path(R,path)
    except ValueError as error:
        assert str(error)=="ARTIFACT_REPARSE_POINT"
        rejected+=1
assert rejected==3
for path in directories:assert_artifact_path(R,Path(path))
print(json.dumps({"status":"passed","scope":"C725 canonical-path propagation","semanticPreflight":4,"freshImageBuild":1,"legacyReparseRejections":rejected,"claimsPolicyChangeComplete":False,"claimsGlobalClosure":False}))
