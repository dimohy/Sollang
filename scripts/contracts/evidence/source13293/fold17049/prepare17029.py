from pathlib import Path
import json,hashlib,sys
sys.path.insert(0,str(Path('scripts').resolve()))
from slg_fixture_literals import multiline_raw_literal
B=Path('artifacts/scratch/resume-20261006-owner-continuation22');out=B/'fold17029-candidate'
comparison=dict(status='compared-before-slg-edit',csharpReference=(B/'interp16996-managed8/result.json').as_posix(),diagnostic=(B/'fold17028-ast-baseline/result.json').as_posix(),observed='Canonical interpolation root17 retains flow AST5. Its source is range AST6 and terminal fold is AST9; final IR has fold Int but no node for AST5. Closest-descendant selection ties source and consumer, selecting Range.',csharpDecision='Complete FoldExpression evaluates its source/initial/body and returns RuntimeInt. Complete flow consumes the final target result; the source operand cannot supply the result merely because its AST is at the same depth.',slgDecision='Share sourceExpressionValueIndex between semantic interpolation type inference and LLVM value selection. Resolve a terminal control by its actual source AST and IR kind; retain the original ownership root for all effects and inputs. Exclude function/type declarations, preserve noncontrol nearest-expression lookup.',claimsGoalComplete=False)
(B/'fold17029-source-comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
s=Path('selfhost/semantic/interpolation_inference.slg').read_text(encoding='utf-8-sig')
start=s.index('        prepared.package.ranges[sourceModule] => range\n',s.index('    node.kind == 17 -> if {',s.index('expressionTypeId prepared:')))
end=s.index('    (node.kind == 0 or node.kind == 2',start)
s=s[:start]+'''        sourceModule -> typedIr.sourceExpressionValueIndex(node.valueAst, 0, Int(ir -> len), prepared.package, ir) => selected
        selected >= 0 and ir[selected].typeId >= 0 and ir[selected].typeId < (types -> len)
            -> if { ir[selected].typeId -> return }
        -1 -> return
    }
'''+s[end:]
(out/'interpolation_inference.slg').write_bytes(s.encode())
s=(B/'interp17015-candidate/foundation.slg').read_text()
start=s.index('    context.ranges[sourceModule] => range\n',s.index('canonicalInterpolationValueIndex node:'))
end=s.index('\n}\n\nemitCanonicalInterpolation',start)
s=s[:start]+'''    ownerIndex -> functionEnd(context, state) => end
    sourceModule -> typedIr.sourceExpressionValueIndex(node.valueAst, ownerIndex + 1, end, context, context.ir) => selected
    selected -> aggregateValueIndex(context, state)'''+s[end:]
# EmitContext carries the same source fields but is not PackageAnalysis; the
# new query takes those source arrays explicitly in the following adapter step.
(out/'foundation.pending.slg').write_bytes(s.encode())
body='''import sollang.compiler.semantic.context as semanticContext
import sollang.compiler.semantic.expression_type_ids as expressionTypeIds
import sollang.compiler.ir.typed as typedIr
import sys.process as process

inspect name: Text, source: Text -> Unit uses Console, Process {
    [source,; ~] -> semanticContext.prepare => prepared
    prepared -> expressionTypeIds.resolveContext => facts
    prepared -> typedIr.lowerResolvedContext(facts) => ir
    false => found!
    prepared.interpolations -> each fragment {
        fragment.kind == 17 -> if {
            0 -> typedIr.sourceExpressionValueIndex(fragment.valueAst, 0, Int(ir -> len), prepared.package, ir) => selected
            selected < 0 -> if { process.exit(1) }
            ir[selected].typeId < 0 or ir[selected].typeId >= (facts.types -> len)
                -> if { process.exit(2) }
            "$name|$(facts.types[ir[selected].typeId].symbol)" -> println
            true => found!
        }
    }
    not found! -> if { "$name|none" -> println }
}

main {
'''
ref=json.loads((B/'interp16993-managed8.json').read_text());expected=[]
for i,c in enumerate(ref['cases']):
 source=Path(c['source']).read_text();body+=multiline_raw_literal(source)+f' => source{i}\n    '+json.dumps(c['id'])+f' -> inspect(source{i})\n'
 expected.append(c['id']+('|none' if c['id']=='direct-if-control' else '|2'))
body+='}\n';p=B/'fold17029-query8.slg';p.write_bytes(body.encode())
d=json.loads((B/'fold17025-type-contract.json').read_text());c=d['cases'][0];c['id']='source-value-query8';c['source']=p.as_posix();c['stdout']='\n'.join(expected)
c['additionalSources']=[(out/'interpolation_inference.slg').as_posix() if x=='selfhost/semantic/interpolation_inference.slg' else x for x in c['additionalSources']]
c['additionalSources'].insert(0,(out/'source_values.slg').as_posix())
d['formatCheckSources']=[p.as_posix(),(out/'source_values.slg').as_posix(),(out/'interpolation_inference.slg').as_posix()]
d['runtimeInputFiles']=[(B/'interp16996-managed8/result.json').as_posix(),(B/'fold17029-source-comparison.json').as_posix()]
d['scope']='Shared source expression result query on fixed CSharp8 control programs; typed result selection only, not LLVM/runtime or general Native acceptance.'
(B/'fold17029-query8.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
