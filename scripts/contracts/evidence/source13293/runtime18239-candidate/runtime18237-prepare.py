from pathlib import Path
import json,copy,importlib.util,sys
root=Path.cwd();sys.path.insert(0,str(root/'scripts'));b=root/'artifacts/scratch/resume-20261006-owner-continuation22'
c=json.loads((b/'runtime18203-source16.json').read_text());managed=json.loads((b/'runtime18235-managed2.json').read_text())
emitter=(b/'runtime18237-emitter.slg').relative_to(root).as_posix()
c['scope']='Current reserve lowering, typed collection dispatch and capacity receiver diagnostics. Previous13/16 remains historical; new CSharp precedence and payload preservation controls extend current scope to18.'
c['semanticPreflightProof']=(b/'runtime18231-semantic/result.json').relative_to(root).as_posix()
c['stdlibSourcePreflightProof']=(b/'runtime18233-stdlib/result.json').relative_to(root).as_posix()
c['budget']['newEpochReason']='Semantic capacity admission, both reserve lowering paths and emitter branch implementation changed after source comparison. One current checked producer, no retry.'
c['reusableCheckedProducer']['id']='runtime-reachability-source18';c['reusableCheckedProducer']['source']=emitter;c['formatCheckSources']=[emitter]
for row in c['cases']:row['source']=emitter
for control in managed['cases']:
    row=copy.deepcopy(c['cases'][-1]);row.update(id=control['id'],source=emitter,programSource=control['source'],runArguments=[control['source']],observedSourceOrder=c['reusableCheckedProducer']['stdlibSourceOrder']+[control['source']],stdout=control['stdout'],runStderr='',emittedLlvm=True,expectedEmittedRuntimeExit=0)
    c['cases'].append(row)
first=['text-capacity-rejected','collection-sizes','859-collection-reserve','reserve-preserves-values','declared-capacity']
c['cases']=sorted(c['cases'],key=lambda x:first.index(x['id']) if x['id'] in first else len(first))
c['runtimeInputFiles']=sorted(set(c['runtimeInputFiles']+[control['source'] for control in managed['cases']]+[(b/'runtime18235-managed2/result.json').relative_to(root).as_posix(),'scripts/contracts/evidence/source13293/runtime18226-partial/source-comparison.json']))
path=b/'runtime18237-source18.json';path.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
spec=importlib.util.spec_from_file_location('existing_generator',root/'scripts/generate-selection-result-emitter.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
order,groups=g.validated_runtime_program_groups(c,root)
(root/emitter).write_bytes(g.render('',checked=True,package_paths=order,runtime_program_paths=list(groups),checked_files=True,runtime_program_groups=groups))
print({'cases':len(c['cases']),'stdlibSourceCount':len(order),'compilerSources':len(c['reusableCheckedProducer']['additionalSources'])})
