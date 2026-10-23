from pathlib import Path
import hashlib
import json

E = Path(__file__).resolve().parent

def load(name):
    return json.loads((E / name).read_text(encoding="utf-8-sig"))

for entry in load("baseline-manifest.json")["files"]:
    assert hashlib.sha256((E / entry["path"]).read_bytes()).hexdigest().upper() == entry["sha256"], entry["path"]
managed = load("records/pattern13198-managed/result.json")
native = load("records/pattern13199-native/result.json")
observer = load("records/pattern13199-observation/result.json")
assert managed["status"] == "passed" and managed["completed"] == managed["total"] == 1
assert native["status"] == "failed" and native["completed"] == 0 and native["total"] == 1
assert observer["status"] == "passed" and observer["completed"] == 1
assert all(x["inputsStable"] and x["processesStopped"] for x in [managed, native, observer])
assert managed["cases"][0]["runStdout"] == "37"
assert native["cases"][0]["runExit"] == 0 and native["cases"][0]["runStdout"] == ""
ir = (E / "records/pattern13199-observation/observe.stdout").read_text()
payloads = [list(map(int, line.split()[1:])) for line in ir.splitlines() if line.startswith("ir ")]
payloads = [x for x in payloads if x[3] == 29]
assert len(payloads) == 2 and {x[0] for x in payloads} == {0, 3}
assert all(x[4:9] == [1, 1, 1, -1, 1] for x in payloads)
batch = load("records/parsing13160/native-current-batch-results.json")
assert batch["state"] == "cancelled" and batch["passed"] == 158 and batch["total"] == 405
assert sum(not x["Success"] and x["Error"].startswith("CANCELLATION_REQUESTED") for x in batch["results"]) == 247
controller = load("records/parsing13160/native-controller.execution.json")
assert controller["status"] == "failed" and controller["exit"] == 1 and controller["processesStopped"]
print("PASS C723 baseline: CSharp37 versus native empty stdout; phase0/final3 Int payload mislabeled Text. Whole158 passed;247 canceled/unverified, zero genuine whole failures. Source repair pending.")
