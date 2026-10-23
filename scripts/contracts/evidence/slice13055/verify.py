from pathlib import Path
import json,hashlib,sys
E=Path(__file__).resolve().parent;R=E.parents[3]
def load(p):return json.loads(p.read_text(encoding="utf-8-sig"))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
m=load(E/"manifest.json")
for x in m["files"]:assert sha(E/x["archive"])==x["sha256"],x["archive"]
assert sys.argv[1:]==["baseline721"]
b=load(E/"records/slice13054-managed/result.json");assert b["status"]=="failed" and b["inputsStable"] and b["processesStopped"]
row=next(x for x in b["cases"] if x["id"]=="primary-mutable-fixed");assert row["buildExit"]==1 and "has no addressable storage" in row["buildStderr"]
x=load(E/"causal-input721.json");p=R/x["source"];assert sha(p)==x["sha256"]==b["inputHashes"][str(p)]
print("baseline721: PASS actual unchanged fixed mutable owner storage failure; current source/native acceptance remains separate")
