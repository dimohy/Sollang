from pathlib import Path
import hashlib
import json

E = Path(__file__).resolve().parent
R = E.parents[3]


def load(p):
    return json.loads(p.read_text(encoding="utf-8-sig"))


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest().upper()


for item in load(E / "manifest.json")["files"]:
    assert sha(E / item["archive"]) == item["sha256"], item["archive"]
for item in load(E / "input-fingerprint.json")["files"]:
    assert sha(R / item["path"]) == item["sha256"], item["path"]
B = E / "records/artifacts/scratch/resume-20261006-owner-continuation22"
d = load(B / "slice13084-original487-native/native-current-batch-results.json")
assert d["state"] == "cancelled" and d["passed"] == 43 and d["total"] == 405
assert d["compilerSha256"] == "3E306ECBC9E6B71EB5B9DBDD235019B24609368EB882019A4C40C3B306AC84D7"
failures = [x for x in d["results"] if not x["Success"]]
assert sum(x["Error"].splitlines()[0] == "CANCELLATION_REQUESTED" for x in failures) == 361
actual = [x for x in failures if x["Error"].splitlines()[0] != "CANCELLATION_REQUESTED"]
assert len(actual) == 1 and actual[0]["Fixture"] == "1188-io-memory-reader-caller-buffer"
assert "expects [UInt8; ~] but received [UInt8; 4]" in actual[0]["Error"]
for p in [B / "parsing13085/native-controller.execution.json", B / "literal13111-managed/controller.execution.json"]:
    c = load(p)
    managed = "literal13111" in str(p)
    assert c["processesStopped"] and c["status"] == ("passed" if managed else "failed")
    assert c["exit"] == (0 if managed else 1)
log = (B / "literal13111-managed/controller.execution.json.stdout.log").read_text(encoding="utf-8-sig")
assert "PASS" in log and "1188-io-memory-reader-caller-buffer" in log
print("PASS genuine original1188 native literal/formal mismatch and focused managed success;43 passed,1 real failure,361 canceled-unverified. Repair remains pending.")
