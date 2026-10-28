from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
def load(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
names=['42-fixed-array-placement','39-stack-promoted-int-dictionary','1401-selfhost-reserve-before-aggregate-transfer','2174-dynamic-array-growth-ownership','81-byte-arena','581-materialized-text-arena','1510-named-fixed-implicit-return-cleanup']
direct=[]
for name in names[2:6]:
    direct.append(dict(id=name,source='examples/regression/'+name+'.slg',exit=0,stderr='',stdout=Path('examples/regression/expected',name+'.stdout.txt').read_text(encoding='utf-8').strip()))
save(b/'allocation17755-managed4.json',dict(schemaVersion=1,scope='Managed reference controls for shared allocation reserve, growth, raw Arena and materialization. No original or expected edits.',expectedManagedDllSha256='9ED84BC45E4FF74F7C242C8B986D4FCE3DADE53E316655EB88B9A234EC3C637E',cases=direct,budget=dict(caseSeconds=180,retryCount=0)))
d=load(b/'slice17720-source8.json');old=load(b/'slice17716-provider-map.json');reverse={v:k for k,v in old.items()};new=load(b/'allocation17750-provider-map.json')
def remap(p):return new.get(reverse.get(p,p),reverse.get(p,p))
producer=d['reusableCheckedProducer'];producer['id']='shared-allocation-source7';producer['source']=(b/'allocation17755-emitter.slg').as_posix();producer['additionalSources']=[remap(p) for p in producer['additionalSources']]
stdlib=producer['stdlibSourceOrder'];cases=[]
for name in names:
    source='examples/regression/'+name+'.slg'
    row=dict(id=name,source=producer['source'],programSource=source,runArguments=[source],additionalSources=producer['additionalSources'],observedSourceOrder=stdlib+[source],exit=0,stderr='',stdout=Path('examples/regression/expected',name+'.stdout.txt').read_text(encoding='utf-8').strip(),emittedLlvm=True,runStderr='',expectedEmittedRuntimeExit=0)
    if name==names[0]:row['expectedAllocations']=1
    if name==names[1]:row['expectedAllocations']=0
    cases.append(row)
d.update(scope='Private shared allocation-family and expression guard candidate. Seven actual SLG runtime controls; original42 common LLVM and injected-failure decisions remain independent required checks. No general Native or whole-goal completion.',cases=cases,semanticPreflightProof=(b/'allocation17753-semantic/result.json').as_posix(),stdlibSourcePreflightProof=(b/'canonical17752-stdlib/result.json').as_posix(),sourceComparison=(b/'allocation17748-comparison.json').as_posix(),formatCheckSources=[producer['source']])
inputs=[remap(p) for p in d['runtimeInputFiles'] if 'slice17720-emitter' not in p]
inputs += [row['programSource'] for row in cases]+['examples/regression/expected/'+name+'.stdout.txt' for name in names]
inputs += [d['sourceComparison'],(b/'allocation17741-comparison.json').as_posix(),(b/'allocation17755-managed4/result.json').as_posix(),'examples/regression/expected/42-fixed-array-placement.llvm.contains.txt','examples/regression/expected/42-fixed-array-placement.llvm.not-contains.txt']
d['runtimeInputFiles']=list(dict.fromkeys(inputs))
save(b/'allocation17755-source7.json',d)
print('prepared managed4 and SLG source7; no execution')
