from pathlib import Path
import sys,json,hashlib,gzip,re
E=Path(__file__).resolve().parent
R=E.parents[3]
def load(p):return json.loads(p.read_text(encoding="utf-8-sig"))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def record(name):return load(E/"records"/name/"result.json")
m=load(E/"manifest.json")
for f in m["files"]:assert sha(E/f["archive"])==f["sha256"],f["archive"]
mode=sys.argv[1]
if mode.startswith("baseline"):
 if mode=="baseline719":
  b=record("slice13036-native-baseline");assert b["status"]=="passed" and b["inputsStable"] and b["processesStopped"]
  rows={r["id"]:r for r in b["cases"]}
  for name in ["primary-dynamic","primary-nominal"]:
   row=rows[name];assert row["classification"]=="undefined-llvm-value" and row["buildExit"]!=0 and "undefined value" in row["stderr"]
   source=str(R/row["source"]);assert sha(Path(source))==b["inputHashes"][source]
  data=gzip.decompress((E/m["original487Llvm"]["path"]).read_bytes());assert hashlib.sha256(data).hexdigest().upper()==m["original487Llvm"]["originalSha256"]
  assert b"extractvalue %sollang.array.i32 %v126689, 0" in data and not re.search(rb"%v126689\s*=",data)
 elif mode=="baseline720":
  b=record("slice13035-managed");assert b["status"]=="failed" and b["inputsStable"] and b["processesStopped"]
  row=next(r for r in b["cases"] if r["id"]=="primary-fixed");assert row["buildExit"]==1 and "expected Int array view but received" in row["buildStderr"]
  case=next(c for c in load(E/"records/slice13035/managed-contract.json")["cases"] if c["id"]=="primary-fixed")
  source=str(R/case["source"]);assert sha(Path(source))==b["inputHashes"][source]
 else:raise AssertionError(mode)
 print(mode+": PASS actual unchanged causal inputs and retained original failure")
elif mode=="candidate":
 for name in ["slice13039-managed","slice13043-source","slice13044-runtime"]:
  d=record(name);assert d["status"]=="passed" and d["completed"]==d["total"]==5 and d["inputsStable"] and d["processesStopped"]
  assert all(x["status"]=="passed" for x in d["cases"])
 for name in ["primary-dynamic","primary-nominal"]:
  text=(E/"records/slice13043-source"/name/"emitted.ll").read_text(encoding="utf-8")
  assert re.search(r"slice_data = extractvalue %sollang.array.i32 %arg, 0",text)
 source=record("slice13043-source")
 path=R/"selfhost/llvm/text/call_arguments.slg";assert source["inputHashes"][str(path)]==sha(path)
 snapshot=load(E/"records/managed13037/inputs-after.json")
 path=R/"src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs";item=next(x for x in snapshot["files"] if x["path"]==str(path));assert item["sha256"].upper()==sha(path)
 print("candidate: PASS current CSharp5 and SLGSource5 assembly/runtime; fresh native image and original487 remain pending")
else:raise AssertionError(mode)
