from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
def load(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
name='581-materialized-text-arena'
save(b/'resize17785-managed-materialize1.json',dict(schemaVersion=1,scope='Retain LLVM for the previously unverified materialize allocation-failure path. Existing normal proof is reused; this individual compile is required because the prior successful LLVM was cleaned under the lifecycle contract.',expectedManagedDllSha256='9ED84BC45E4FF74F7C242C8B986D4FCE3DADE53E316655EB88B9A234EC3C637E',cases=[dict(id=name,source='examples/regression/'+name+'.slg',exit=0,stderr='',stdout=Path('examples/regression/expected',name+'.stdout.txt').read_text(encoding='utf-8').strip())]))
d=load(b/'allocation17765-source7.json');reverse={v:k for k,v in load(b/'allocation17761-provider-map.json').items()};new=load(b/'resize17781-provider-map.json')
def remap(p):return new.get(reverse.get(p,p),reverse.get(p,p))
p=d['reusableCheckedProducer'];p['id']='guarded-resize-source4';p['source']=(b/'resize17785-emitter.slg').as_posix();p['additionalSources']=[remap(x) for x in p['additionalSources']]
cases=[]
programs=[('reserve-loop-grow-and-keep',(b/'resize17780-loop-control.slg').as_posix(),'3\n16\n2',2)]
for name in ['1401-selfhost-reserve-before-aggregate-transfer','581-materialized-text-arena','42-fixed-array-placement']:
    programs.append((name,'examples/regression/'+name+'.slg',Path('examples/regression/expected',name+'.stdout.txt').read_text(encoding='utf-8').strip(),1 if name.startswith('42-') else None))
for name,source,stdout,count in programs:
    row=dict(id=name,source=p['source'],additionalSources=p['additionalSources'],programSource=source,runArguments=[source],observedSourceOrder=p['stdlibSourceOrder']+[source],exit=0,stderr='',stdout=stdout,emittedLlvm=True,runStderr='',expectedEmittedRuntimeExit=0)
    if count is not None:row['expectedAllocations']=count
    cases.append(row)
d.update(cases=cases,scope='Shared literal/reserve/materialize null guard and correct phi predecessor blocks. One producer, four programs including loop growth/keep, function reserve-transfer, Arena materialize and original42. Fault injection is a separate required consumer.',semanticPreflightProof=(b/'resize17782-semantic/result.json').as_posix(),stdlibSourcePreflightProof=(b/'canonical17783-stdlib/result.json').as_posix(),sourceComparison=(b/'resize17781-comparison.json').as_posix(),formatCheckSources=[p['source']])
inputs=[remap(x) for x in d['runtimeInputFiles']]
inputs+=[row['programSource'] for row in cases]+[d['sourceComparison'],(b/'resize17780-managed1/result.json').as_posix(),(b/'resize17785-managed-materialize1/result.json').as_posix()]
d['runtimeInputFiles']=list(dict.fromkeys(inputs));save(b/'resize17785-source4.json',d)
