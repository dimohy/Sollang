from pathlib import Path
import hashlib,json
E=Path(__file__).resolve().parent
def load(name):return json.loads((E/name).read_text(encoding="utf-8-sig"))
for entry in load("baseline-manifest.json")["files"]:
    assert hashlib.sha256((E/entry["path"]).read_bytes()).hexdigest().upper()==entry["sha256"]
native=load("native-build-result.json");outer=load("controller-result.json")
assert native["status"]=="failed" and native["compilerSha256"] is None
assert native["steps"]["build"] is None
assert outer["status"]=="failed" and outer["inputsStable"] and outer["processesStopped"]
assert "ARTIFACT_REPARSE_POINT" in (E/"semantic-preflight.stderr.txt").read_text()
assert load("signal-observed13219.json")["retainedDefaultGuardRejections"]
print("PASS C725 baseline: validated explicit roots lost at child semantic preflight, default reparse guard rejects; zero compiler-image builds executed. Path propagation repair pending.")
