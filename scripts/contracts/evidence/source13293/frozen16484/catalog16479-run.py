from pathlib import Path
import json,subprocess,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';f=b/'frozen16132'
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest().upper()
authority=f/'artifacts/authority16144.json';partition=b/'catalog16161/result.json'
original=read(authority)['selectedCatalog'];regular=read(partition)['selectedCatalog']
previous_path=b/'catalog16472-chunk00/result.json';previous=read(previous_path)
assert previous['status']=='failed' and previous['completed']==20 and previous['inputsStable'] and previous['processesStopped']
visited={row['id'] for row in previous['cases']};assert len(visited)==21 and previous['cases'][-1]['id']=='102-selfhost-declaration-payloads'
assert set(regular)==set(read(b/'catalog16145/result.json')['selectedCatalog'])-visited
assert len(original)==len(set(original))==2708 and len(regular)==len(set(regular))==2434 and set(regular)<=set(original)
frozen_proof=r/'scripts/contracts/evidence/source13293/frozen16129/fixture-input-proof.json'
proof=read(frozen_proof);assert proof['allExact'] and proof['fixtureInputsCompleted']==proof['fixtureInputsTotal']==7741
for row in proof['entries']:assert sha(f/row['path'])==row['sha256'],row['path']
index=int(sys.argv[1]);assert index>=0
selected=regular[index*50:(index+1)*50];assert selected
plan=b/f'catalog16479-chunk{index:02}-plan.json';assert not plan.exists()
plan.write_text(json.dumps(dict(schemaVersion=1,scope='Strict unchanged original regular assertions; whole LLVM snapshot partition remains separate. Prior current20 passes and failed102 are preserved separately. This remaining selection includes unexecuted known historical failures and stops at its first failure; no oracle relaxation or whole-goal credit.',declaredOriginalTotal=2708,regularTotal=2434,separateLlvmSnapshotTotal=253,preservedCurrentPassed=20,preservedCurrentFailed=1,preservedCurrentResult=dict(path=str(previous_path),sha256=sha(previous_path)),chunk=index,selectedCatalog=selected,caseBudgetSeconds=180,totalBudgetSeconds=len(selected)*180,originalAuthority=dict(path=str(authority),sha256=sha(authority)),partitionAuthority=dict(path=str(partition),sha256=sha(partition)),frozenInputs=dict(path=str(frozen_proof),sha256=sha(frozen_proof),completed=7741,total=7741),excludedKnownFailures=['102-selfhost-declaration-payloads'],claimsGoalComplete=False),indent=2)+'\n',encoding='utf-8')
command=[sys.executable,str(r/'scripts/verify-example-test-catalog.py'),'--preflight',str(b/'catalog16449-preflight/result.json'),'--runner',str(f/'tests/Sollang.ExampleTests/bin/Release/net11.0/Sollang.ExampleTests.dll'),'--compiler',str(b/'managed16362/compiler/Sollang.Compiler.dll'),'--selfhost-driver-build',str(b/'v16382/compiler-build01'),'--selfhost-production-root',str(r),'--fixture-root',str(f),'--source-closure-result',str(f/f'artifacts/source-closure16479-chunk{index:02}.json'),'--output',str(b/f'catalog16479-chunk{index:02}'),'--managed-reference','--execute','--case-budget-seconds','180','--total-budget-seconds',str(len(selected)*180)]
for name in selected:command+=['--exact',name]
for name in ['v12432','v16219','v16382']:command+=['--reusable-compiler-directory',str(b/name/'compiler-build01')]
sys.exit(subprocess.run(command,check=False).returncode)
