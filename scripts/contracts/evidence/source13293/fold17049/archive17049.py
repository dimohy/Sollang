from pathlib import Path
import json,shutil,gzip,re
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');e=Path('scripts/contracts/evidence/source13293/fold17049');e.mkdir(exist_ok=True)
# Archive immutable inputs, diagnostics and terminal results only. Generated
# binaries/private caches remain governed by the existing lifecycle runner.
items=[p for p in b.iterdir() if re.match(r'(fold170(2[5-9]|3[1-7]|4[1-8])|readonly170(38|39|40|51)|fold17050|prepare170(25|29|33|38|39|41|43))',p.name)]
for p in items:
 if p.is_dir() and (p/'result.json').exists():
  r=json.loads((p/'result.json').read_text());assert r['status']!='running',p
 for f in ([p] if p.is_file() else p.rglob('*')):
  if not f.is_file() or any(x in f.relative_to(b).parts for x in ['bin','obj','.sollang-cache']):continue
  if f.suffix in ['.json','.slg','.stdout','.stderr','.txt','.py','.ps1']:
   q=e/f.relative_to(b);q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,q)
  elif f.name=='emitted.ll':
   q=e/f.relative_to(b);q.parent.mkdir(parents=True,exist_ok=True);q.with_suffix('.ll.gz').write_bytes(gzip.compress(f.read_bytes(),mtime=0))
r=json.loads((b/'fold17048-source8/result.json').read_text());assert r['processesStopped']
q=dict(schemaVersion=1,status=r['status'],nativeSourceQueryIdentity=dict(completed=8,total=8,evidence=(e/'fold17050-native-query8/result.json').as_posix()),csharp=dict(completed=8,total=8,evidence='artifacts/scratch/resume-20261006-owner-continuation22/interp16996-managed8/result.json'),actualSlg=dict(completed=r['completed'],total=8),evidence=(e/'fold17048-source8/result.json').as_posix(),sourceQueryIdentity=dict(completed=8,total=8,evidence=(e/'fold17045-query8/result.json').as_posix()),checks=['complete flow result Int, not input Range','canonical symbol collector shared by fresh and prepared paths','all binary operands resolved','original symbol prefix fields unchanged','two-source legacy package symbol/name equality with fresh completion','original runtime oracles unchanged'],canonicalCompilerSourcesChanged=False,caseBudgetSeconds=180,claimsGoalComplete=False,pending=['General compiler integration and paired regression','C742 readonly admission and shared consumers','C743 general formatter integration','Final original/source/runtime comparisons and Stage2/Stage3'])
(e/'qualification.json').write_text(json.dumps(q,indent=2)+'\n')
q2=dict(schemaVersion=1,status='reference-qualified',normalWarningFree=dict(completed=12,total=12),explicitWarningDiagnostic=dict(completed=1,total=1,expected='S003@2',normalAcceptance=False),ownedAliasRejection=dict(completed=1,total=1,expectedBuildExit=1,rejectedBeforeLlvm=True),csharpSourceFrames=dict(completed=13,total=13),evidence=(e/'readonly17039-reference13/source-frame-result.json').as_posix(),aliasEvidence=(e/'readonly17040-alias-rejection1/result.json').as_posix(),sourceContract=(e/'readonly17039-fixture-contract.json').as_posix(),originalSourcesOrOraclesChanged=False,claimsGoalComplete=False,pending=['SLG readonly/escape admission matching all CSharp decisions'])
(e/'readonly-qualification.json').write_text(json.dumps(q2,indent=2)+'\n')
p=Path('scripts/contracts/active-goal-progress.json');d=json.loads(p.read_text(encoding='utf-8-sig'));d['currentInterpolationControl8Evidence']=(e/'qualification.json').as_posix();d['currentStorageReadonlyReferenceEvidence']=(e/'readonly-qualification.json').as_posix();d['currentWork']['focus']=f'Canonical66/111/100 stable, not repeated. C744 actualSLG original8 {r["completed"]}/8 after complete-expression result query and appended canonical symbols; general compiler integration remains. C742 readonly CSharp13 source frames plus exact alias rejection1 qualified; warning1 is diagnostic-only.';d['currentWork']['next']='Integrate C744 qualified units only after remaining controls; finish C742 readonly/escape admission and shared frame consumers, then C743 general formatter and final whole-goal gates.';d['currentWork']['activeExecutions']=[];p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(Path(__file__),e/Path(__file__).name)
print(json.dumps(q))
