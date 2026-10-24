from pathlib import Path
import subprocess,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
s=(b/'bounded13548-template.slg').read_text(encoding='utf-8')
s='import sollang.compiler.ir.typed as typedIr\nimport sys.process as process\n'+s
needle='    callContext.types => resolved';assert s.count(needle)==1
s=s.replace(needle,needle+'\n    prepared -> typedIr.lowerResolvedContextParallel(resolved) => ir')
at=s.rfind('}')
s=s[:at]+'''    0 => checked!
    ir -> each node {
        node.sourceModule == 144 and node.kind == 14 and node.astNode >= 0
            and prepared.package.nodes[range.astStart + node.astNode].kind == 37 -> if {
                -1 => expected!
                resolved.expressions -> each expression {
                    expression.sourceModule == 144 and expression.astNode == node.astNode
                        and expression.status == 0 -> if { expression.typeId => expected! }
                }
                "ir ast=$(node.astNode) type=$(node.typeId) expected=$(expected!) kind=$(node.typeKind)" -> println
                expected! >= 0 and resolved.types[expected!].kind == 12 -> if {
                    node.typeId != expected! or node.typeKind != 12 -> if {
                        "IR_CONTEXTUAL_BOUNDED_IDENTITY_LOST" -> println
                        process.exit(1)
                    }
                    checked! + 1 => checked!
                }
            }
    }
    checked! < 2 -> if { process.exit(1) }
    "boundedIrChecks=$(checked!)" -> println
'''+s[at:]
(b/'bounded13550-template.slg').write_text(s,encoding='utf-8')
s=(b/'bounded13548-run.py').read_text(encoding='utf-8').replace('bounded13548','bounded13550')
s=s.replace("and 'field owner=' in p.stdout","and 'field owner=' in p.stdout and 'boundedIrChecks=' in p.stdout")
s=s.replace('final main literal types only, no LLVM/runtime acceptance.','post-fix semantic/Typed IR identity relationship validation only, no LLVM/runtime acceptance.')
p=b/'bounded13550-run.py';p.write_text(s,encoding='utf-8')
sys.exit(subprocess.run([sys.executable,str(p)],cwd=r).returncode)
