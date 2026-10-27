from pathlib import Path
import json,shutil,re,gzip,hashlib,subprocess
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');e=Path('scripts/contracts/evidence/source13293/io17061');e.mkdir(exist_ok=True)
def put(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def copy(p):
 q=e/p.relative_to(b);q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
for p in b.iterdir():
 if not re.match(r'(readonly170(5[7-8]|6[7-8]|72|8[2-6]|9[4-8])|io170(6[2-6]|7[0-9]|80|8[7-9]|90)|managed170(60|64|69)|capture170(60|64|69)|prepare170(57|62|75|81|82|85|94|97)|register17061)',p.name):continue
 if p.is_dir() and (p/'result.json').exists():assert json.loads((p/'result.json').read_text())['status']!='running',p
 for f in ([p] if p.is_file() else p.rglob('*')):
  if not f.is_file() or any(x in f.relative_to(b).parts for x in ['bin','obj','compiler','artifacts','.sollang-cache']):continue
  # The workspace base contains "artifacts"; only relative components above
  # are inspected, so owned diagnostics are retained.
  if f.suffix in ['.json','.slg','.py','.txt','.stdout','.stderr','.bin']:copy(f)
  elif f.suffix=='.ll':
   q=e/f.relative_to(b);q.parent.mkdir(parents=True,exist_ok=True);q.with_suffix('.ll.gz').write_bytes(gzip.compress(f.read_bytes(),mtime=0))
for file in ['storage_placement_readonly.slg']:
 copy(b/'placement16881-candidate'/file)
copy(b/'placement17097-candidate/storage_placement_readonly.slg')
for path in ['src/Sollang.Compiler/CodeGen/LlvmEmitter.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Ir.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.RuntimeIntrinsics.cs','scripts/verify-c385-preir-call-numeric.py','scripts/completed_artifact_plan.py','scripts/verify-owned-index-full-stdlib-source-preflight.py','scripts/test_completed_artifacts.py']:
 for version in ['before','after']:
  q=e/version/path;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(subprocess.run(['git','show','HEAD:'+path],capture_output=True,check=True).stdout if version=='before' else Path(path).read_bytes())
q=dict(schemaVersion=1,status='csharp8-and-actual-slg8-qualified-general-native-pending',csharp=dict(completed=8,total=8,evidence=(e/'io17071-managed8/result.json').as_posix()),actualSlg=dict(completed=8,total=8,evidence=(e/'io17080-source8/result.json').as_posix()),relatedRestrictions=dict(completed=2,total=2,evidence=(e/'io17090-scope2/result.json').as_posix()),caseBudgetSeconds=180,canonicalCsharpChanged=True,canonicalSlgChanged=False,wholeGoalComplete=False,pending=['General Native compiler integration/requalification after all units','Final original/source/runtime/Stage/backlog gates'])
put(e/'qualification.json',q)
put(e/'readonly-qualification.json',dict(schemaVersion=1,csharpReference=dict(completed=17,total=17,normal=16,exactWarningDiagnostic=1,evidence=(e/'readonly17086-reference17/source-frame-result.json').as_posix()),slgReadonlyAdmission=dict(completed=17,total=17,evidence=(e/'readonly17098-managed17/result.json').as_posix()),captures=dict(completed=13,total=13,binarySha256=hashlib.sha256((b/'readonly17057-ast.bin').read_bytes()).hexdigest().upper(),decoded=(e/'readonly17072-ast13.json').as_posix()),pending=['Wider interpolation qualified/direct/flowed call and control cases','Wider source statement controls','Mutable header, full frame and shared consumer integration','General Native matching-current-input tests'],claimsGoalComplete=False))
p=Path('scripts/contracts/active-goal-progress.json');d=json.loads(p.read_text(encoding='utf-8-sig'));d['currentIoFailureAbiEvidence']=(e/'qualification.json').as_posix();d['currentStorageReadonlyAdmissionEvidence']=(e/'readonly-qualification.json').as_posix();d['currentWork']['focus']='C745 CSharp8 and actual SLG source8 pass with exact native runtime success/failure exits, scope restrictions2 retained. C742 readonly all-use admission17 matches CSharp, including canonical legacy interpolation index/len/readonly and owning function calls. General Native old product was correctly rejected before execution for input drift. Canonical epoch16797 66/111/100 retained, not repeated.';d['currentWork']['next']='Lifecycle161 and successful generated output cleanup are complete. Continue C742 wider readonly/source families, headers and full frame consumers; integrate qualified C743/C744/C745 private units after remaining source controls. Preserve whole final/Stage/backlog scope.';d['currentWork']['activeExecutions']=[];put(p,d)
shutil.copy2(Path(__file__),e/Path(__file__).name)
