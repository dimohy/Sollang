from pathlib import Path
import argparse,hashlib,json,subprocess
parser=argparse.ArgumentParser()
parser.add_argument('--sequence',default='13309')
parser.add_argument('--message',default='Fix shared interpolation integer identity and qualify current compiler prerequisites')
args=parser.parse_args()
root=Path.cwd()
def run(args,**kw): return subprocess.run(args,cwd=root,check=True,capture_output=True,**kw)
def sha(data): return hashlib.sha256(data).hexdigest().upper()
out=root/'scripts/contracts/evidence/progress13282'
actual=run(['pwsh','-NoProfile','-File','scripts/show-project-progress.ps1','-AsJson'])
(out/f'current-report{args.sequence}.stdout.json').write_bytes(actual.stdout)
(out/f'current-report{args.sequence}.stderr.txt').write_bytes(actual.stderr)
json.loads(actual.stdout.decode('utf-8-sig'))
folders=['C2026-10-24-728','C2026-10-24-729','progress13282','c434-original13286','source13293']
for name in folders:
    directory=root/'scripts/contracts/evidence'/name
    files=[dict(path=str(p.relative_to(directory)).replace('\\','/'),sha256=sha(p.read_bytes())) for p in sorted(directory.rglob('*')) if p.is_file() and p!=directory/'manifest.json']
    (directory/'manifest.json').write_text(json.dumps(dict(schemaVersion=1,files=files),indent=2)+'\n',encoding='utf-8')
owned=['.gitattributes','scripts/contracts/active-goal-progress.json','scripts/contracts/compiler-defects.json','scripts/contracts/structural-parity-detail.json','scripts/show-project-progress.ps1','scripts/verify-project-progress.ps1','scripts/test_project_progress_json.py','selfhost/semantic/diagnostics.slg','selfhost/llvm/text/foundation.slg','selfhost/llvm/text/entry_expressions.slg','selfhost/llvm/text/function_calls.slg','selfhost/llvm/text/control_region_expressions.slg','scripts/probes/readonly-array-elements/signed-interpolation-control.slg','scripts/probes/readonly-array-elements/unsigned-interpolation-control.slg']
owned+=['scripts/contracts/evidence/'+name for name in folders]
owned.append('scripts/probes/readonly-array-elements/function-interpolation-control.slg')
run(['git','add','--',*owned])
staged=set(run(['git','ls-files','-z']).stdout.decode('utf-8').split('\0'))
manifest_paths=[]
for name in folders:
    directory=root/'scripts/contracts/evidence'/name
    manifest=json.loads((directory/'manifest.json').read_text(encoding='utf-8'))
    manifest_paths += [(directory/row['path'],row['sha256']) for row in manifest['files']]
missing=[str(path.relative_to(root)).replace('\\','/') for path,expected in manifest_paths if str(path.relative_to(root)).replace('\\','/') not in staged]
if missing: run(['git','add','-f','--',*missing])
for path,expected in manifest_paths:
    name=str(path.relative_to(root)).replace('\\','/')
    assert sha(run(['git','show',':'+name]).stdout)==expected,name
run(['git','diff','--cached','--check'])
print(json.dumps(dict(stagedManifestFiles=len(manifest_paths),forcedExactIgnoredFiles=len(missing),stagedBytesVerified=True,reportCliPassed=True)))
run(['git','commit','-m',args.message])
run(['git','push','origin','v0.5'])
head=run(['git','rev-parse','HEAD']).stdout.decode().strip()
remote=run(['git','ls-remote','origin','refs/heads/v0.5']).stdout.decode().split()[0]
assert head==remote
print(json.dumps(dict(head=head,remote=remote,status=run(['git','status','--short']).stdout.decode())))
