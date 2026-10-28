from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
names=['1001-fixed-repeat-inside-while','1517-named-fixed-loop-region-cleanup','1534-fixed-branch-loop-binding']
def save(p,d):Path(p).write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
direct=[]
for name in names:
    direct.append(dict(id=name,source='examples/regression/'+name+'.slg',exit=0,stderr='',stdout=Path('examples/regression/expected',name+'.stdout.txt').read_text(encoding='utf-8').strip()))
save(b/'allocation17774-managed3.json',dict(schemaVersion=1,scope='Managed controls for literal heap identity and cleanup through loop regions before the new SLG loop consumers. Original inputs/answers unchanged.',expectedManagedDllSha256='9ED84BC45E4FF74F7C242C8B986D4FCE3DADE53E316655EB88B9A234EC3C637E',cases=direct))
d=json.loads((b/'allocation17765-source7.json').read_text(encoding='utf-8'));p=d['reusableCheckedProducer'];p['id']='physical-allocation-loop-source3';p['source']=(b/'allocation17774-emitter.slg').as_posix()
d['cases']=[dict(id=row['id'],source=p['source'],additionalSources=p['additionalSources'],programSource=row['source'],runArguments=[row['source']],observedSourceOrder=p['stdlibSourceOrder']+[row['source']],exit=0,stderr='',stdout=row['stdout'],emittedLlvm=True,runStderr='',expectedEmittedRuntimeExit=0) for row in direct]
d['scope']='Required additional loop-region consumers of the same29-file candidate. Prior whitelist cannot admit these originals. One explicitly budgeted shared producer, no retry or general Native build. Earlier seven programs are not rerun.'
d['formatCheckSources']=[p['source']]
d['runtimeInputFiles']+= [row['source'] for row in direct]+['examples/regression/expected/'+name+'.stdout.txt' for name in names]+[(b/'allocation17774-managed3/result.json').as_posix()]
d['runtimeInputFiles']=list(dict.fromkeys(d['runtimeInputFiles']))
d['executionReason']='Loop literal/return cleanup branches changed but were not exercised by the prior7 source whitelist. Keep the compiler source closure identical and add only3 unverified programs; prior successful producer binaries are not modified.'
save(b/'allocation17774-source3.json',d)
