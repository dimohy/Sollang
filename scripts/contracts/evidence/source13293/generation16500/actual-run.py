from pathlib import Path
import sys,json,hashlib
sys.dont_write_bytecode=True
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
b=r/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'parsing16491-producers';o.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
helper=b/'current-parser-lexer-producer-reproduction2-02/invoke-current-producers.ps1';compiler=b/'managed16362/compiler/Sollang.Compiler.exe'
shared=['syntax/sollang.lexer','syntax/sollang.grammar','src/Sollang.Compiler.Generators/ParserSourceGenerator.cs','src/Sollang.Compiler.Generators/LexerSourceGenerator.cs','src/Sollang.Compiler/Cli/GrammarCompiler.cs','src/Sollang.Compiler/Sollang.Compiler.csproj','src/Sollang.Compiler.Generators/Sollang.Compiler.Generators.csproj']
outputs={'GeneratedParser.g.cs':'src/Sollang.Compiler/obj/generated/Sollang.Compiler.Generators/Sollang.Compiler.Generators.ParserSourceGenerator/GeneratedParser.g.cs','GeneratedLexer.g.cs':'src/Sollang.Compiler/obj/generated/Sollang.Compiler.Generators/Sollang.Compiler.Generators.LexerSourceGenerator/GeneratedLexer.g.cs','sollang_grammar.slg':'syntax/generated/sollang_grammar.slg'}
inputs=[Path(__file__),helper,r/'scripts/verification_execution.py']+[r/p for p in shared+list(outputs.values())]+list(compiler.parent.glob('Sollang.Compiler.*'))+list((r/'src/Sollang.Compiler.Generators').glob('*.cs'))
pins={str(p):sha(p) for p in inputs}
d=dict(schemaVersion=1,status='running',completed=0,total=3,inputHashes=pins,cases=[],scope='Fresh current source generator reproduction; no canonical outputs or public compiler binary changed.',claimsGoalComplete=False)
x=VerificationExecution(r,o,d,lambda:all(sha(p)==v for p,v in pins.items()),sha);error=None
try:
 a=x.run(['dotnet','build',str(r/'src/Sollang.Compiler.Generators/Sollang.Compiler.Generators.csproj'),'--no-restore','--disable-build-servers','-nr:false','-p:UseSharedCompilation=false','-c','Release','-t:Rebuild','-o',str(o/'producer')],o/'producer-build',timeout=120)
 assert a.returncode==0 and not a.stderr.strip(),(a.stdout,a.stderr)
 producer=o/'producer/Sollang.Compiler.Generators.dll';d['generatorProducerSha256']=sha(producer)
 a=x.run(['pwsh','-NoProfile','-File',str(helper),'-Producer',str(producer),'-Root',str(r),'-Output',str(o)],o/'emit-csharp',timeout=30);assert a.returncode==0 and not a.stderr.strip(),(a.stdout,a.stderr)
 a=x.run([str(compiler),'grammar','build','syntax/sollang.lexer','syntax/sollang.grammar','-o',str(o/'sollang_grammar.slg')],o/'emit-slg',timeout=30);assert a.returncode==0 and not a.stderr.strip(),(a.stdout,a.stderr)
 for name,target in outputs.items():
  h=sha(o/name);assert h==sha(r/target),('GENERATION_MISMATCH',name,h,sha(r/target))
  d['cases'].append({'id':name,'status':'passed','actualSha256':h,'canonical':target});d['completed']+=1;x.save()
 d['status']='passed'
except BaseException as exc:error=exc
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:d.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
if d['status']!='passed':raise SystemExit(1)
