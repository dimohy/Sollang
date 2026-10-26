from pathlib import Path
import json,hashlib,shutil,subprocess
from datetime import datetime,timezone
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';out=r/'scripts/contracts/evidence/source13293/contextual15957';out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
names=['contextual15949-emitter','contextual15950-slg6','contextual15951-negative6','contextual15955-allocation4','contextual15956-prior-native-control','contextual15945-slg6','contextual15942-native1','aggregate15926-native66','contextual15946-managed6','contextual15948-managed-negative6']
for name in names:
 j=json.loads((b/name/'result.json').read_text(encoding='utf-8-sig'));assert j['processesStopped'],name
 for p in (b/name).rglob('*'):
  if p.is_file() and (p.name=='result.json' or p.suffix in ['.stdout','.stderr','.ll']):
   q=out/'executions'/name/p.relative_to(b/name);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
changed=subprocess.run(['git','diff','--name-only'],capture_output=True,text=True,check=True).stdout.splitlines()
for name in changed:
 if not name.startswith('selfhost/'):continue
 p=r/name;q=out/'source-tested'/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
for pattern in ['contextual1594*.py','contextual1594*.json','contextual1595*.py','contextual1595*.json']:
 for p in b.glob(pattern):
  q=out/'inputs'/p.name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
q=dict(schemaVersion=1,status='focused-runtime-and-allocation-verified-existing-diagnostic-order-gap-open',observedAtUtc=datetime.now(timezone.utc).isoformat(),runtime=dict(completed=6,total=6),allocation=dict(completed=4,total=4,expected=[10,11,9,8]),negativeControls=dict(completed=5,total=6),managedRuntime=dict(completed=6,total=6),managedNegativeControls=dict(completed=6,total=6),baseline='Prior Native A0 and current SLG both choose later indexed assignment type error instead of earlier unknown dictionary key; unchanged original oracle retained.',claimsStandaloneNativePassed=False,claimsPhaseClosure=False,claimsGoalComplete=False,files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()})
(out/'qualification.json').write_text(json.dumps(q,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(status=q['status'],files=len(q['files']))))
