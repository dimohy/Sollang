from pathlib import Path
import json
B=Path('artifacts/scratch/resume-20261006-owner-continuation22');out=B/'task17490-candidate';out.mkdir(exist_ok=False)
s=(B/'task17456-candidate/semantic_diagnostics.slg').read_text(encoding='utf-8')
start=s.index('public firstExpressionOperandDiagnostic ');head,tail=s[:start],s[start:]
old='    package -> semanticContext.indexExpressionSourceAsts => sourceAstByExpression'
assert tail.count(old)==1
tail=tail.replace(old,old+'\n    package -> semanticContext.indexFlowSourcesByAst => taskFlowSources')
s=head+tail
old='flowSource!, typeIdByAst!, taskValueByAst!, firstChildByAst!'
assert s.count(old)==1
s=s.replace(old,'flowSource!, typeIdByAst!, taskValueByAst!, taskFlowSources, firstChildByAst!')
old='taskValuesByAst: ref [Bool; ~], firstChild:'
assert s.count(old)==1
s=s.replace(old,'taskValuesByAst: ref [Bool; ~], flowSources: ref [Int; ~], firstChild:')
old='''            target.parent >= 0 and prepared.package.nodes[range.astStart + target.parent].kind == 11
                -> if {
                    firstChild[range.astStart + target.parent] => argument!
                    argument! >= 0 -> while {
                        argument! != targetPath! and prepared.package.nodes[argument!].kind != 12
                            -> if { 1 => violation! }
                        nextChild[argument!] => argument!
                    }
                }'''
assert s.count(old)==1
s=s.replace(old,'''            # The parenthesized argument envelope is a sibling of its Path.
            # Reuse canonical call indexing, including the primary flow source.
            calls.ModuleCallResolution { sourceModule: sourceModule, callAst: flowAst, origin: 0, targetModule: -1, targetSourceModule: -1, functionSymbol: -1, status: 0 } => intrinsic
            prepared.package -> semanticContext.indexedCallArgumentAsts(intrinsic, flowSources, firstChild, nextChild) => arguments
            (arguments -> len) > 1 -> if { 1 => violation! }''')
(out/'semantic_diagnostics.slg').write_text(s,encoding='utf-8')
d=json.loads((B/'async17474-source8.json').read_text(encoding='utf-8'))
d=json.loads(json.dumps(d).replace((B/'task17456-candidate/semantic_diagnostics.slg').as_posix(),(out/'semantic_diagnostics.slg').as_posix()).replace((B/'async17474-emitter.slg').as_posix(),(B/'task17490-emitter.slg').as_posix()))
normal=json.loads((B/'task17456-source9.json').read_text(encoding='utf-8'))['cases'][0]
normal.update(source=d['reusableCheckedProducer']['source'],additionalSources=d['reusableCheckedProducer']['additionalSources'])
d['cases']=[normal,*[c for c in d['cases'] if c['id'] in ['c748-await-argument-rejected','c748-nonasync-await-rejected']]]
d['scope']='C748 exact invocation arity: canonical argument envelope sibling indexing after observed AST; known normal zero-argument Task binding control plus two rejection cases. Reuse prior passing storage/Task cases; no whole-suite repeat.'
d['semanticPreflightProof']=(B/'task17490-semantic/result.json').as_posix();d['reusableCheckedProducer']['id']='C748-canonical-Task-argument-index3'
d['runtimeInputFiles']=list(dict.fromkeys([*d['reusableCheckedProducer']['additionalSources'],*d['reusableCheckedProducer']['stdlibSourceOrder'],*[c['programSource'] for c in d['cases']]]))
(B/'task17490-source3.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8');(B/'task17490-sources.txt').write_text('\n'.join([d['reusableCheckedProducer']['source'],*d['reusableCheckedProducer']['additionalSources']])+'\n',encoding='utf-8')
print('CANONICAL_TASK_ARGUMENT_INDEX_CANDIDATE_READY')
