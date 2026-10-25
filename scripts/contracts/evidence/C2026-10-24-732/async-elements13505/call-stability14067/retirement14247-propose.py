from pathlib import Path
import sys,json,hashlib,datetime
R=Path.cwd();B=R/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(R/'scripts'))
from completed_artifact_plan import consumer_closure_record
old=B/'v14010/compiler-build01';replacement=B/'v14112/compiler-build01';out=B/'retirement14247-proposal';out.mkdir(exist_ok=False)
binary=str(old/'compiler.exe');rows=[]
for p in B.rglob('result.json'):
    try:
        raw=p.read_text(encoding='utf-8-sig')
        if 'v14010' not in raw:continue
        d=json.loads(raw);pins=d.get('inputHashes',d.get('inputSha256',d.get('inputHashesStart',{})))
        if isinstance(pins,dict) and binary in pins:rows.append(dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest().upper(),status=d.get('status'),completed=d.get('completed'),total=d.get('total')))
    except (ValueError,OSError):continue
names=['case129014040','case129014043-validate','result14035-native12','returned14032-native3']
consumers=[B/n/'result.json' for n in names]
inventory=dict(schemaVersion=1,status='read-only-inventory',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),retiringProduct=str(old),replacement=str(replacement),directPinnedRecords=rows,proposedConsumerResults=[str(p) for p in consumers],childRunnerCoverage='Catalog parent returned14032-native3 owns the three child runner records; stopped supervisor evidence is required by canonical lifecycle verifier.',preflightCoverage='returned14031-preflight is validated with0 executed cases; not a runtime consumer.',retirementExecuted=False,claimsTestsPassed=False)
(out/'inventory.json').write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8')
try:
    proposal=consumer_closure_record(R,old,consumers,replacement,legacy_terminal=True)
    (out/'proposed-consumer-closure.json').write_text(json.dumps(proposal,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(status='proposal-validated',directPinnedRecords=len(rows),proposedConsumers=len(consumers),retirementExecuted=False)))
except Exception as e:
    (out/'failure.json').write_text(json.dumps(dict(status='proposal-rejected',exception=type(e).__name__,failure=str(e),retirementExecuted=False),indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(status='proposal-rejected',failure=str(e),retirementExecuted=False)))
