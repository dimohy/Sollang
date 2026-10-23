from pathlib import Path
import copy,datetime,hashlib,json,shutil
root=Path.cwd()
base=root/'artifacts/scratch/resume-20261006-owner-continuation22'
e=root/'scripts/contracts/evidence/source13293'
out=e/'type-cache13328'
out.mkdir(exist_ok=False)
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def relative(p):return p.relative_to(root).as_posix()
proofs={}
for side,name in [('managed','type-cache13325-managed'),('native','type-cache13326-native')]:
    source=base/name
    r=read(source/'result.json')
    assert r['status']=='passed' and r['inputsStable'] and r['processesStopped'] and r['completed']==r['total']==4
    assert all(c['passed'] for c in r['cases'])
    for p,h in r['inputHashes'].items():assert Path(p).is_file() and sha(Path(p))==h
    target=out/side
    target.mkdir()
    for p in source.rglob('*'):
        if p.is_file() and p.suffix in ['.json','.txt','.stdout','.stderr'] and '.sollang-cache' not in p.parts:
            q=target/p.relative_to(source)
            q.parent.mkdir(exist_ok=True,parents=True)
            shutil.copy2(p,q)
    proofs[side]=dict(path=relative(target/'result.json'),sha256=sha(source/'result.json'))
for name in ['type-cache13325-contract.json','type-cache13325-plan.json','type-cache13326-source-comparison.json']:
    shutil.copy2(base/name,out/name)
shutil.copy2(base/'source13324-inventory.json',e/'source13324-inventory.json')
comparison=read(base/'type-cache13326-source-comparison.json')
assert len(comparison['sourceHashes'])==16
assert all(sha(root/p)==h for p,h in comparison['sourceHashes'].items())
qualification=dict(schemaVersion=1,status='passed',completed=4,total=4,percentage=100.0,observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Four unchanged original API programs per compiler;8 actual compiler/program executions. Current type/call provider dependency qualification only, not historical production cold-warm9 or whole source phase.',managed=proofs['managed'],native=proofs['native'],sourceComparison=relative(out/'type-cache13326-source-comparison.json'),sourceHashes=comparison['sourceHashes'],compilerPair=dict(managedDllSha256='841B8823F72CE171E8A4E1AC21A17106075FA59A97484AFCD3A30A6108C59B8F',nativeSha256='34AB2672AF54170BB3F586835F20D4AF3E7576B4E1054F9FD797C0D59309A45E'),implementationChanged=False,compilerRebuilt=False,originalCasesAndOraclesUnchanged=True,claimsPhaseClosure=False,claimsGoalComplete=False)
save(out/'qualification.json',qualification)
p=root/'scripts/contracts/structural-parity-detail.json'
d=read(p)
type_phase=next(row for row in d['phaseProgress'] if row['phase']=='type-commit')
inventory=type_phase['decisionInventory']
assert len(inventory['requiredDecisionIds'])==7
id='type-commit.cache-restored-type-and-call-provider'
decision=dict(id=id,status='complete',managedSources=[p for p in comparison['sourceHashes'] if p.endswith('.cs')],selfhostSources=[p for p in comparison['sourceHashes'] if p.endswith('.slg')],reusedSemanticDecision='semantic.stable-cache-identity-and-production-restoration',**{k:comparison[k] for k in ['structure','branches','logic','diagnostics']},sourceComparisonRecord=relative(out/'type-cache13326-source-comparison.json'),managedFirstRecord=proofs['managed']['path'],pairedRecord=proofs['native']['path'],focusedQualification=relative(out/'qualification.json'),relatedHelperInspection=comparison['inspectedCurrentDelta']['relatedHelper'],completionScope='Current original API4 per compiler and16 specific provider source responsibilities only. No whole-file expansion from related context helper, no production cold-warm9 or phase-exhaustive credit.')
decision['diagnostics']='Current CSharp4/Native4 passed exact original streams. Frame/reference/AST/ordinal/flag/type bounds and missing or mismatched identity rejection remain. Production cold-warm9 remains historical.'
inventory['requiredDecisionIds'].append(id)
inventory['decisions'].append(decision)
inventory.setdefault('decisionInventoryExpansionHistory',[]).append(dict(previousRequiredDecisionCount=7,currentRequiredDecisionCount=8,reason='Type commitment depends on exact restored concrete type/call recipes; current source comparison16 and original API4 pair establish the named provider responsibility.',evidence=relative(out/'qualification.json'),changesFrozenSourceScopes=False))
type_phase['remaining']='Type provider cache source decision now qualified by current API4 pair.53 of79 phase source files still lack named decision associations; full architectural comparisons and immutable phase-exhaustive proof plus original final gates remain.'
semantic=next(row for row in d['phaseProgress'] if row['phase']=='semantic-analysis')
source_decision=next(x for x in semantic['decisionInventory']['decisions'] if x['id']==decision['reusedSemanticDecision'])
source_decision['currentApiRequalification']=dict(completed=4,total=4,managedAndNative=True,evidence=relative(out/'qualification.json'),scope='Current original APIs only; previous production9 not requalified by this result.')
save(p,d)
old_inventory=read(base/'source13324-inventory.json')
gaps=[]
for captured,row in zip(old_inventory['phases'],d['phaseProgress']):
    assert captured['phase']==row['phase']
    sides={}
    for side in ['managed','selfhost']:
        files={x['path'] for x in captured['sources'][side]}
        covered={p for decision in row['decisionInventory']['decisions'] for p in decision[side+'Sources']}
        assert covered<=files
        sides[side]=dict(completed=len(covered),total=len(files),percentage=round(len(covered)/len(files)*100,2),missing=sorted(files-covered))
    gaps.append(dict(phase=row['phase'],registeredDecisions=len(row['decisionInventory']['decisions']),sides=sides,claimsPhaseClosure=False))
done=sum(v['completed'] for row in gaps for v in row['sides'].values())
total=sum(v['total'] for row in gaps for v in row['sides'].values())
assert (done,total)==(175,547),(done,total)
save(e/'decision-source-gaps13328.json',dict(schemaVersion=1,status='current-named-source-decision-associations',observedAtUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),sourceInventory=relative(e/'source13324-inventory.json'),sourceInventorySha256=sha(e/'source13324-inventory.json'),completed=done,total=total,percentage=round(done/total*100,2),phaseRows=gaps,scope='Named file-to-phase decision associations only. Not full branch comparison, physical reading, source7 closure or whole-goal progress. Related helper partial inspection adds no whole-file association.',claimsPhaseClosure=False,claimsGoalComplete=False))
p=root/'scripts/contracts/active-goal-progress.json'
d=read(p)
native=read(base/'type-cache13326-native/result.json')
steps=[dict(id=c['id'],status='complete',evidence=proofs['native']['path']) for c in native['cases']]
gate_path=e/'type-cache-focused-plan13327.json'
save(gate_path,dict(schemaVersion=1,status='passed',completed=4,total=4,steps=steps,qualification=relative(out/'qualification.json'),scope=qualification['scope']))
gate=next(g for g in d['focusedGates'] if g['name']=='C385-type-cache-provider-api4-current')
gate.update(status='complete',completed=4)
d['currentWork'].update(focus='Current CSharp4/Native4 cache provider API pair passed. Type-commit now has8 named decisions covering26/79 file associations;53 remain unassociated. No source edit or compiler build.',next='Compare remaining type/layout/signature/borrow providers and typed IR normalization/finalization boundaries, then remaining phase inventories and immutable phase-exhaustive source proofs before original final acceptance.',activeExecutions=[],focusedCases=steps,observedAtUtc=qualification['observedAtUtc'])
next(x for x in d['currentWork']['steps'] if x['id']=='paired-focused').update(status='complete',evidence=relative(out/'qualification.json'))
d['currentTypeCacheProviderRequalification']=dict(completed=4,total=4,managedAndNative=True,evidence=relative(out/'qualification.json'),claimsWholePhaseComplete=False)
d['currentNamedSourceDecisionAssociations']=dict(completed=done,total=total,percentage=round(done/total*100,2),evidence=relative(e/'decision-source-gaps13328.json'),scope='Named file-to-phase decision associations only; no source7 or branch-exhaustiveness completion claim.')
save(p,d)
shutil.copy2(Path(__file__),out/Path(__file__).name)
print('Current API4 per compiler qualified; type decisions7->8, source associations10->26/79; all phase closures remain0/7.')
