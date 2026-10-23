from pathlib import Path
import hashlib,json
E=Path(__file__).resolve().parent
R=E.parents[3]
def load(p):return json.loads(p.read_text(encoding="utf-8-sig"))
for entry in load(E/"candidate-manifest.json")["files"]:
    assert hashlib.sha256((E/entry["path"]).read_bytes()).hexdigest().upper()==entry["sha256"],entry["path"]
P=E/"candidate-records"
for name,count in [("pattern13213-semantic",6),("pattern13215-array-semantic",7),("pattern13216-source",23),("pattern13217-managed",6),("pattern13221-native",6),("pattern13222-native",17)]:
    p=load(P/name/"result.json")
    assert p["status"]=="passed" and p["completed"]==p["total"]==count
    assert p["inputsStable"] and p["processesStopped"]
stdlib=load(P/"pattern13214-stdlib/result.json")
assert stdlib["status"]=="passed" and stdlib["fullStdlibSourceCount"]==144 and stdlib["checkedSemanticDiagnosticCount"]==0
image=load(P/"native-build/result.json")
assert image["status"]=="passed" and image["inputsStable"] and all(x==0 for x in image["steps"].values())
assert image["compilerSha256"]=="99F45F979992ADFB2E68954731049DB7A6019B5A1F50FFE8A66679EC2D30A61A"
qualification=load(E/"candidate-qualification13223.json")
assert len(qualification["byteAndProductChecks"])==23
assert sum(x["kind"]=="runtime" for x in qualification["byteAndProductChecks"])==16
assert all(x.get("llvmExecutableProducts",0)==0 for x in qualification["byteAndProductChecks"])
baseline=load(R/"scripts/contracts/evidence/C2026-10-24-723/records/pattern13199-native/result.json")
current=load(P/"pattern13221-native/result.json")
assert baseline["status"]=="failed" and baseline["cases"][0]["runStdout"]==""
assert next(x for x in current["cases"] if x["id"]=="readonly-subject-noise-after")["runStdout"]=="37"
assert next(x for x in current["cases"] if x["id"]=="readonly-direct-subject")["buildExit"]==1
assert "extractvalue" in load(E/"result.json")["observedBuildStderr"]
print(json.dumps({"status":"passed","scope":"C723/C724 focused candidate plus C722 requalification","source":23,"runtime":16,"native":23,"negativeProducts":0,"claimsGlobalClosure":False}))
