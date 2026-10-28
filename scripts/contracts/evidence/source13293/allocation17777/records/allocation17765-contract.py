from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
d=json.loads((b/'allocation17755-source7.json').read_text(encoding='utf-8'))
p=d['reusableCheckedProducer'];p['id']='physical-allocation-source7';p['source']=(b/'allocation17765-emitter.slg').as_posix();p['additionalSources']=[x.replace('allocation17750-candidate','allocation17761-candidate') for x in p['additionalSources']]
names=['42-fixed-array-placement','51-fixed-array-value-generics','1510-named-fixed-implicit-return-cleanup','1511-named-fixed-explicit-return-cleanup','1519-fixed-stack-argument-return','1401-selfhost-reserve-before-aggregate-transfer','2174-dynamic-array-growth-ownership']
cases=[]
for name in names:
    source='examples/regression/'+name+'.slg'
    row=dict(id=name,source=p['source'],additionalSources=p['additionalSources'],programSource=source,runArguments=[source],observedSourceOrder=p['stdlibSourceOrder']+[source],exit=0,stderr='',stdout=Path('examples/regression/expected',name+'.stdout.txt').read_text(encoding='utf-8').strip(),emittedLlvm=True,runStderr='',expectedEmittedRuntimeExit=0)
    if name==names[0]:row['expectedAllocations']=1
    cases.append(row)
d.update(cases=cases,scope='Physical literal backing identity shared by allocation and cleanup, including fixed returns, ordinary and owned generic arrays, reserve-transfer and empty/growing arrays. Prior raw family7 and strict failure differences are preserved. No full-unit or general Native completion.',semanticPreflightProof=(b/'allocation17764-semantic/result.json').as_posix(),sourceComparison=(b/'allocation17761-comparison.json').as_posix(),formatCheckSources=[p['source']])
files=[x.replace('allocation17750-candidate','allocation17761-candidate') for x in d['runtimeInputFiles']]
files += [row['programSource'] for row in cases]+['examples/regression/expected/'+name+'.stdout.txt' for name in names]
files += [d['sourceComparison'],(b/'allocation17756-source7/result.json').as_posix(),(b/'common17757-candidate42.json').as_posix(),(b/'allocation17760-slg-failure/result.json').as_posix()]
d['runtimeInputFiles']=list(dict.fromkeys(files))
(b/'allocation17765-source7.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
