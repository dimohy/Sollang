from pathlib import Path
import json,hashlib,sys
B=Path(__file__).resolve().parent;R=B.parents[2];sys.path.insert(0,str(R/'scripts'));from verification_source_proof import current_build_inputs
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8'));sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
proofs={};paths=[]
for name,n in [('statement-priority-semantic03',4),('statement-priority-stdlib01',1),('statement-priority-managed01',80),('native-statement-priority01',1),('native-statement-priority-admission01',1),('statement-priority-paired01',80)]:
    p=B/name/'result.json';r=read(p);assert r['status']=='passed' and r['completed']==r['total']==n and r['inputsStable'] and r['processesStopped'],name
    assert all(Path(q).is_file() and sha(q)==v for q,v in r['inputHashes'].items()),name
    paths.append(p);proofs[name]=r
contractPath=B/'statement-priority-contract03.json';contract=read(contractPath);assert len(contract['cases'])==80
for name in ['statement-priority-managed01','statement-priority-paired01']:
    rows=proofs[name]['cases'];assert [c['id'] for c in rows]==[c['id'] for c in contract['cases']]
    for expected,actual in zip(contract['cases'],rows):
        assert actual['passed'] and actual['status']=='passed' and actual['buildExit']==expected['exit'] and actual['buildStderr'].strip()==expected.get('stderr','').strip(),expected['id']
        if expected.get('requireNoLlvm'):assert actual['rejectedBeforeLlvm'] and not actual.get('unexpectedLlvmOutputs'),expected['id']
        if 'stdout' in expected:assert actual['runExit']==expected.get('runExit',0) and actual['runStdout'].strip()==expected['stdout'].strip() and actual['runStderr'].strip()==expected.get('runStderr','').strip(),expected['id']
comparisonPath=B/'statement-native-comparison01.json';comparison=read(comparisonPath);assert comparison['status']=='compared-before-slg-edit' and all(sha(p)==v for p,v in comparison['inputHashes'].items())
mappingPath=B/'partial-queries-integration01/mapping.json';mapping=read(mappingPath);assert sha(mapping['source'])==mapping['after'] and sha(mapping['testedSource'])==mapping['testedSourceSha256'] and mapping['sameTestedBody']
def function(text,name):
    a=text.index('\n'+name+' ')+1;b=text.index('\n}',a)+2;return text[a:b]+'\n'
assert function(Path(mapping['source']).read_text(encoding='utf-8'),'analyzeResolvedLoweredContextWithReturnSites')==function(Path(mapping['testedSource']).read_text(encoding='utf-8'),'candidateMoveReadReturnSites').replace('candidateMoveReadReturnSites ','analyzeResolvedLoweredContextWithReturnSites ',1)
build=proofs['native-statement-priority01'];admission=proofs['native-statement-priority-admission01'];birth=current_build_inputs(R,build);exe=B/'native-statement-priority01/compiler.exe';assert sha(exe)==build['compilerSha256']==admission['compilerSha256']
allPaths=[Path(__file__),contractPath,comparisonPath,mappingPath,*paths]
out=dict(schemaVersion=1,status='passed',completed=167,total=167,inputsStable=True,processesStopped=True,compilerSha256=sha(exe),sourceInputCount=len(birth),inputHashes={str(p.resolve()):sha(p) for p in allPaths},scope='Current semantic4/stdlib1/CSharp80/producer1/admission1/Native80 only; exact tested four-query core. Original/source/runtime/Stage and whole goal remain pending.',claimsGoalComplete=False,originalCredit=0,sourceClosureCredit=0,stageCredit=0)
dest=B/'statement-priority-qualification01.json';assert not dest.exists();dest.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in out.items() if k!='inputHashes'}))
