from pathlib import Path
import datetime,hashlib,json,shutil
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
e=root/'scripts/contracts/evidence/source13293'
out=e/'type-runtime13334'
out.mkdir(exist_ok=False)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rel(p):return p.relative_to(root).as_posix()
proofs={}
for side,name in [('managed','type-runtime13332-managed'),('native','type-runtime13333-native')]:
    directory=base/name
    r=read(directory/'result.json')
    assert r['status']=='passed' and r['completed']==r['total']==3 and r['inputsStable'] and r['processesStopped']
    assert all(x['passed'] for x in r['cases'])
    assert all(Path(p).is_file() and sha(Path(p))==h for p,h in r['inputHashes'].items())
    target=out/side
    target.mkdir()
    for p in directory.rglob('*'):
        if p.is_file() and p.suffix in ['.json','.txt','.stdout','.stderr'] and '.sollang-cache' not in p.parts:
            q=target/p.relative_to(directory)
            q.parent.mkdir(exist_ok=True,parents=True)
            shutil.copy2(p,q)
    proofs[side]=dict(path=rel(target/'result.json'),sha256=sha(directory/'result.json'))
for name in ['type-runtime13332-contract.json','type-runtime13332-plan.json','type-runtime13333-source-comparison.json']:
    shutil.copy2(base/name,out/name)
comparison=read(out/'type-runtime13333-source-comparison.json')
assert all(sha(root/p)==h for p,h in comparison['sourceHashes'].items())
save(out/'additional-source-inspection.json',dict(sourceComparison=rel(out/'type-runtime13333-source-comparison.json'),sourceComparisonSha256=sha(out/'type-runtime13333-source-comparison.json'),inspections=[dict(path='selfhost/ir/typed/resolved_context_finalize.slg',readRanges=[[927,978],[2263,2275]],finding='Final contextual/call repairs include direct await consumers and late call/result/value alias sealing; caller performs the final selected declared runtime seal afterwards.'),dict(path='selfhost/ir/typed/resolved_context_normalize_phases.slg',readRanges=[[2172,2206]],finding='CompletionReactor owner plus selected declared intrinsic distinguishes dequeue/dequeueTerminal/close opcodes; earlier provisional opcode may be overwritten only through the admitted declaration path.')],claimsNewWholeFileReview=False))
qualification=dict(schemaVersion=1,status='passed',completed=3,total=3,percentage=100.0,observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Original3 Task/runtime identity programs per compiler; focused final selected-declaration boundary only. Does not close all socket operations, public cases, normalization branches or whole source phase.',managed=proofs['managed'],native=proofs['native'],sourceComparison=rel(out/'type-runtime13333-source-comparison.json'),sourceHashes=comparison['sourceHashes'],implementationChanged=False,compilerRebuilt=False,originalSourcesAndOraclesUnchanged=True,claimsPhaseClosure=False,claimsGoalComplete=False,retainedArtifactUse='Outputs retained until immutable phase-contract compatibility review; no automatic reuse claim.')
save(out/'qualification.json',qualification)
p=root/'scripts/contracts/structural-parity-detail.json'
d=read(p)
row=next(x for x in d['phaseProgress'] if x['phase']=='type-commit')
inventory=row['decisionInventory']
assert len(inventory['requiredDecisionIds'])==8
id='type-commit.final-selected-runtime-and-task-identity'
decision=dict(id=id,status='complete',managedSources=[n for n in comparison['sourceHashes'] if n.endswith('.cs')],selfhostSources=[n for n in comparison['sourceHashes'] if n.endswith('.slg')],**{k:comparison[k] for k in ['structure','branches','logic','diagnostics']},sourceComparisonRecord=rel(out/'type-runtime13333-source-comparison.json'),managedFirstRecord=proofs['managed']['path'],pairedRecord=proofs['native']['path'],focusedQualification=rel(out/'qualification.json'),relatedCallerInspection=comparison['relatedCallerInspection'],completionScope=qualification['scope'])
inventory['requiredDecisionIds'].append(id)
inventory['decisions'].append(decision)
inventory.setdefault('decisionInventoryExpansionHistory',[]).append(dict(previousRequiredDecisionCount=8,currentRequiredDecisionCount=9,reason='Final selected intrinsic/async producer identity crosses the typed normalization/finalization boundary; exact original3 current pair passed.',evidence=rel(out/'qualification.json'),changesFrozenSourceScopes=False))
row['remaining']='Current cache provider API4 and final selected runtime/Task API3 decisions are qualified.50/79 phase files still lack named decision associations; full remaining branch comparisons and immutable phase-exhaustive proof plus all original final gates remain.'
save(p,d)
capture=read(e/'source13324-inventory.json')
gaps=[]
for phase,curr in zip(capture['phases'],d['phaseProgress']):
    assert phase['phase']==curr['phase']
    sides={}
    for side in ['managed','selfhost']:
        files={x['path'] for x in phase['sources'][side]}
        covered={n for q in curr['decisionInventory']['decisions'] for n in q[side+'Sources']}
        assert covered<=files
        sides[side]=dict(completed=len(covered),total=len(files),percentage=round(len(covered)/len(files)*100,2),missing=sorted(files-covered))
    gaps.append(dict(phase=curr['phase'],registeredDecisions=len(curr['decisionInventory']['decisions']),sides=sides,claimsPhaseClosure=False))
done=sum(x['completed'] for row in gaps for x in row['sides'].values())
total=sum(x['total'] for row in gaps for x in row['sides'].values())
assert (done,total)==(178,547)
save(e/'decision-source-gaps13334.json',dict(schemaVersion=1,status='current-named-source-decision-associations',observedAtUtc=qualification['observedAtUtc'],completed=done,total=total,percentage=round(done/total*100,2),phaseRows=gaps,scope='Named file-to-phase decision associations only; not full branch comparison, physical reading, phase closure or overall goal completion.',claimsPhaseClosure=False,claimsGoalComplete=False))
p=root/'scripts/contracts/active-goal-progress.json'
d=read(p)
save(out/'current-work.before.json',d['currentWork'])
native=read(base/'type-runtime13333-native/result.json')
steps=[dict(id=c['id'],status='complete',evidence=proofs['native']['path']) for c in native['cases']]
save(out/'focused-gate.json',dict(schemaVersion=1,status='passed',completed=3,total=3,steps=steps,scope=qualification['scope']))
gate='type-commit-final-selected-runtime3-current'
d['focusedGates'].append(dict(name=gate,status='complete',completed=3,total=3,evidence=rel(out/'focused-gate.json'),scope=qualification['scope']))
d['currentFocusedGate']=gate
d['currentWork']=dict(id='final-runtime-identity-source-comparison',parentDefectId='C2026-09-12-385',status='active',workKind='workflow-task-not-an-additional-implementation-unit',implementationChanged=False,compilerBuildInvoked=False,title='Final selected runtime/Task type identity',focus='Current CSharp3/Native3 passed. Exact selected declaration, async producer and final call/result identity boundary compared; no implementation edit or product build.',next='Compare remaining contextual numeric/materialization sealing and typed IR construction/finalization providers, then other phase inventories and immutable phase-exhaustive proofs before final original14/source7/runtime2708/Stage.',steps=[dict(id='managed-first',status='complete',evidence=proofs['managed']['path']),dict(id='source-comparison',status='complete',evidence=rel(out/'type-runtime13333-source-comparison.json')),dict(id='paired-focused',status='complete',evidence=rel(out/'qualification.json')),dict(id='phase-exhaustive',status='pending')],focusedCases=steps,activeExecutions=[],snapshot='scripts/contracts/evidence/C2026-10-24-729/checkpoint13329.json',observedAtUtc=qualification['observedAtUtc'],currentManagedProduct='artifacts/scratch/resume-20261006-owner-continuation22/managed13239/compiler/Sollang.Compiler.exe',currentNativeProduct='artifacts/scratch/resume-20261006-owner-continuation22/v13312/compiler-build01/compiler.exe')
d['currentNamedSourceDecisionAssociations'].update(completed=done,percentage=round(done/total*100,2),evidence=rel(e/'decision-source-gaps13334.json'))
d['currentFinalRuntimeIdentityQualification']=dict(completed=3,total=3,managedAndNative=True,evidence=rel(out/'qualification.json'),claimsWholePhaseComplete=False)
save(p,d)
shutil.copy2(Path(__file__),out/Path(__file__).name)
print('Current CSharp3/Native3 qualified; type decisions8->9, named source links26->29/79; source phase closure remains0/7.')
