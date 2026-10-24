from pathlib import Path
import sys,json,hashlib
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
source=r/'scripts/probes/declared-value-layout/growable-bounded-elements-runtime.slg'
program=b/'bounded13535-trace.slg';literal=json.dumps(source.read_bytes().decode('utf-8'))
program.write_text('''import sollang.compiler.semantic.context as semanticContext
import sollang.compiler.semantic.expression_type_ids as expressionTypes

main {
    ['''+literal+''',; ~] => sources
    sources -> semanticContext.prepare => prepared
    prepared -> expressionTypes.resolveContext => resolved
    "sourceCount=$(prepared.package.sources -> len)" -> println
    resolved.fields -> each field {
        "field owner=$(field.ownerType) ordinal=$(field.ordinal) type=$(field.fieldType)" -> println
    }
    0 => astIndex!
    prepared.package.nodes -> each node {
        true -> if {
            "ast=$(astIndex!) kind=$(node.kind) parent=$(node.parent) start=$(node.start)" -> println
        }
        astIndex! + 1 => astIndex!
    }
    resolved.expressions -> each expression {
        prepared.package.nodes[expression.astNode] => node
        true -> if {
            "expression ast=$(expression.astNode) type=$(expression.typeId) status=$(expression.status)" -> println
        }
    }
    0 => typeIndex!
    resolved.types -> each type {
        true -> if {
            "type=$(typeIndex!) kind=$(type.kind) first=$(type.first) length=$(type.length) origin=$(type.origin)" -> println
        }
        typeIndex! + 1 => typeIndex!
    }
}
''',encoding='utf-8')
contract=json.loads((b/'bounded13527-contract.json').read_text(encoding='utf-8'));sources=[r/p for p in contract['reusableCheckedProducer']['additionalSources']]
compiler=b/'managed13519/compiler/Sollang.Compiler.exe';formatter=b/'v12432/compiler-build01/compiler.exe'
inputs=[Path(__file__),program,source,compiler,compiler.with_suffix('.dll'),compiler.with_suffix('.deps.json'),compiler.with_suffix('.runtimeconfig.json'),formatter,*sources]
pins={str(p):sha(p) for p in inputs};out=b/'bounded13535-trace';out.mkdir(exist_ok=False)
d=dict(schemaVersion=1,status='running',completed=0,total=1,scope='Actual SLG one-source AST/type observation only; no stdlib144/package equivalence or runtime acceptance.',sourceSha256=sha(source),producerBuildBudget=1,originalSourceRunsAdded=0,claimsGoalComplete=False,inputHashes=pins)
x=VerificationExecution(r,out,d,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha);error=None
try:
 p=x.run([str(formatter),'format',str(program)],out/'format',timeout=30);assert p.returncode==0,p.stderr
 # Formatting is an explicit pre-build input mutation, so re-pin the exact
 # canonical bytes before any build or execution; the final record retains it.
 pins[str(program)]=sha(program);d['inputHashes']=dict(pins)
 cmd=[str(compiler),'build',str(program),*[str(p) for p in sources],'-o',str(out/'probe.exe'),'--target','windows-x64','--llvm',str(r/'.tools/llvm-22.1.8'),'-O0','--jobs','4','--keep-temps']
 p=x.run(cmd,out/'build',timeout=180);assert p.returncode==0,p.stderr
 p=x.run([str(out/'probe.exe')],out/'run',timeout=30);assert p.returncode==0 and not p.stderr and 'sourceCount=1' in p.stdout and 'field owner=' in p.stdout,p.stderr

 import re
 rows=p.stdout.splitlines()
 fields=[tuple(map(int,re.fullmatch(r'field owner=(\d+) ordinal=(\d+) type=(\d+)',line).groups())) for line in rows if line.startswith('field owner=')]
 types={int(m[1]):tuple(map(int,m.groups()[1:])) for line in rows if (m:=re.fullmatch(r'type=(\d+) kind=(-?\d+) first=(-?\d+) length=(-?\d+) origin=(-?\d+)',line))}
 asts={int(m[1]):tuple(map(int,m.groups()[1:])) for line in rows if (m:=re.fullmatch(r'ast=(\d+) kind=(-?\d+) parent=(-?\d+) start=(\d+)',line))}
 expressions={int(m[1]):int(m[2]) for line in rows if (m:=re.fullmatch(r'expression ast=(\d+) type=(-?\d+) status=0',line))}
 assert len(fields)==1,fields
 field_type=fields[0][2];element_type=types[field_type][1]
 assert types[field_type][0]==3 and types[element_type][0]==12 and types[element_type][2]==2,types
 roots=[a for a,(kind,parent,start) in asts.items() if kind==37 and parent in asts and asts[parent][0]==40]
 assert len(roots)==1,roots
 outer=roots[0];children=[a for a,(kind,parent,start) in asts.items() if kind==37 and parent==outer]
 assert len(children)==2 and expressions[outer]==field_type and all(expressions[a]==element_type for a in children),(outer,children,expressions)
 d.update(status='passed',completed=1,scope='Post-fix actual SLG canonical field/child identity validation; not LLVM/runtime package acceptance.',checks=dict(declaredFieldShape=True,outerLiteralIdentity=True,innerEmptyLiteralIdentities=True),diagnosticBuildsBeforeFix=2,postFixValidationBuilds=1)

except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if d['status']=='passed' else 1)
