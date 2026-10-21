from pathlib import Path
import json,sys
contract=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
folder=Path(sys.argv[2]); record=json.loads((folder/"result.json").read_text(encoding="utf-8-sig")); rows=[]
for cid in ["future-index-loan","future-mutable-loan"]:
 expected=next(c for c in contract["cases"] if c["id"]==cid); actual=next(c for c in record["cases"] if c["id"]==cid)
 stdout=(folder/cid/"run.stdout").read_text(encoding="utf-8-sig").strip(); stderr=(folder/cid/"build.stderr").read_text(encoding="utf-8-sig").strip()
 passed=actual["buildExit"]==0 and actual["runExit"]==0 and stdout==expected["stdout"] and stderr==expected["stderr"]
 rows.append(dict(id=cid,passed=passed,stdout=stdout,stderr=stderr))
print(json.dumps(rows,ensure_ascii=False));sys.exit(0 if all(r["passed"] for r in rows) else 1)
