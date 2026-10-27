from pathlib import Path
import json
B=Path('artifacts/scratch/resume-20261006-owner-continuation22');out=B/'fold17029-candidate'
s=(out/'foundation.pending.slg').read_text()
s=s.replace('ownerIndex + 1, end, context, context.ir','ownerIndex + 1, end, context.ranges, context.nodes, context.ir',1)
(out/'foundation.slg').write_bytes(s.encode('utf-8'))
d=json.loads((B/'interp17015-contract8.json').read_text())
mapping={(B/'interp17015-candidate/foundation.slg').as_posix():(out/'foundation.slg').as_posix(),'selfhost/semantic/interpolation_inference.slg':(out/'interpolation_inference.slg').as_posix()}
group=d['reusableCheckedProducer'];group['additionalSources']=[mapping.get(p,p) for p in group['additionalSources']]
assert (out/'interpolation_inference.slg').as_posix() in group['additionalSources']
group['additionalSources'].insert(0,(out/'source_values.slg').as_posix())
for c in d['cases']:c['additionalSources']=group['additionalSources']
d['semanticPreflightProof']=(B/'fold17034-semantic/result.json').as_posix()
d['formatCheckSources']=[mapping.get(p,p) for p in d['formatCheckSources']]+[(out/'source_values.slg').as_posix(),(out/'interpolation_inference.slg').as_posix()]
d['runtimeInputFiles']+=[(B/'fold17029-source-comparison.json').as_posix()]
d['scope']='C744 original CSharp8 programs after shared complete-expression result selection. Semantic display type and LLVM value consume one query; original ownership root unchanged, one producer build, case180, retry0.'
(B/'fold17033-contract8.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
(B/'fold17033-sources.txt').write_text('\n'.join([group['source']]+group['additionalSources'])+'\n',encoding='utf-8')
