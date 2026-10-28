import json
from pathlib import Path

b = Path('artifacts/scratch/resume-20261006-owner-continuation22')
d = json.loads((b/'dictionary17704-source5.json').read_text())
old = json.loads((b/'dictionary17700-provider-map.json').read_text())
reverse = {v:k for k,v in old.items()}
providers = json.loads((b/'slice17716-provider-map.json').read_text())
def remap(path):
    path = reverse.get(path,path)
    return providers.get(path,path)
producer = d['reusableCheckedProducer']
producer['id'] = 'common-slice-carrier-source8'
producer['source'] = str(b/'slice17720-emitter.slg').replace('\\','/')
producer['additionalSources'] = [remap(p) for p in producer['additionalSources']]
stdlib = producer['stdlibSourceOrder']
specs = [
 ('38-stack-promoted-dynamic-array', 'examples/regression/38-stack-promoted-dynamic-array.slg', 0),
 ('39-stack-promoted-int-dictionary', 'examples/regression/39-stack-promoted-int-dictionary.slg', 0),
 ('51-fixed-array-value-generics', 'examples/regression/51-fixed-array-value-generics.slg', None),
 ('1510-named-fixed-implicit-return-cleanup', 'examples/regression/1510-named-fixed-implicit-return-cleanup.slg', None),
 ('1511-named-fixed-explicit-return-cleanup', 'examples/regression/1511-named-fixed-explicit-return-cleanup.slg', None),
 ('1519-fixed-stack-argument-return', 'examples/regression/1519-fixed-stack-argument-return.slg', None),
 ('dynamic-int-owning-control', str(b/'dynamic17330-owning-control.slg').replace('\\','/'), 1),
 ('dynamic-int-nested-guard', str(b/'dynamic17343-nested.slg').replace('\\','/'), 0),
]
oldcases = {c['id']:c for c in json.loads((b/'placement17661-current16.json').read_text())['cases']}
cases=[]
for name,source,alloc in specs:
    stdout = Path('examples/regression/expected',name+'.stdout.txt').read_text().strip() if source.startswith('examples/') else oldcases[name]['stdout']
    case = dict(id=name,source=producer['source'],programSource=source,runArguments=[source],additionalSources=producer['additionalSources'],observedSourceOrder=stdlib+[source],exit=0,stderr='',stdout=stdout,emittedLlvm=True,runStderr='',expectedEmittedRuntimeExit=0)
    if alloc is not None:
        case['expectedAllocations']=alloc
    cases.append(case)
d['cases']=cases
d['scope']='Private shared named slice ABI alignment and checked planned readonly-call pointer. Original sources and common assertions unchanged. Eight runtime controls, four allocation audits, common original38 checked separately. No general Native or whole-goal completion.'
d['semanticPreflightProof']=str(b/'slice17719-semantic/result.json').replace('\\','/')
d['sourceComparison']=str(b/'slice17716-comparison.json').replace('\\','/')
d['formatCheckSources']=[producer['source']]
inputs=[remap(p) for p in d['runtimeInputFiles'] if 'dictionary17704-emitter' not in p and 'dictionary17700-comparison' not in p]
inputs += [source for _,source,_ in specs]
inputs += ['examples/regression/expected/'+name+'.stdout.txt' for name,source,_ in specs if source.startswith('examples/')]
inputs += [d['sourceComparison'],str(b/'common17703-csharp38.json').replace('\\','/'),'examples/regression/expected/38-stack-promoted-dynamic-array.llvm.contains.txt','examples/regression/expected/38-stack-promoted-dynamic-array.llvm.not-contains.txt']
d['runtimeInputFiles']=list(dict.fromkeys(inputs))
(b/'slice17720-source8.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
print('prepared source8; no execution')
