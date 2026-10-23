from pathlib import Path
import hashlib
import json

E = Path(__file__).resolve().parent
R = E.parents[3]

def load(p):
    return json.loads(p.read_text(encoding="utf-8-sig"))

for entry in load(E / "baseline-manifest.json")["files"]:
    assert hashlib.sha256((E / entry["path"]).read_bytes()).hexdigest().upper() == entry["sha256"]
signal = load(E / "signal-observed13208.json")
managed = load(R / signal["managedProof"])
source = load(R / signal["sourceProof"])
native = load(E / "result.json")
assert managed["status"] == "passed" and managed["completed"] == 6
assert managed["cases"][-1]["buildExit"] == 1
assert managed["cases"][-1]["buildStderr"] == signal["expectedDiagnostic"]
assert source["status"] == "failed" and source["completed"] == 5 and source["total"] == 6
assert "C723_NEGATIVE_ADMISSION_MISMATCH" in source["failure"]
assert native["observedBuildExit"] == 1 and "extractvalue" in native["observedBuildStderr"]
assert "defined with type 'ptr'" in native["observedBuildStderr"]
assert all(x["inputsStable"] and x["processesStopped"] for x in [managed, source, native])
print("PASS C724 baseline: CSharp source enum-subject rejection versus SLG LLVM admission and historical NativeF1 ptr/enum LLVM failure. Semantic repair pending.")
