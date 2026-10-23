from pathlib import Path
import sys,json,hashlib
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';o=b/'diagnostic12675';o.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
manifest=root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt';sources=[b/'diagnostic12671.slg']+[root/s for s in manifest.read_text(encoding='utf-8-sig').splitlines()[1:] if s.strip()];compiler=b/'managed12581/compiler/Sollang.Compiler.exe'
formatter=b/'v12432/compiler-build01/compiler.exe';harness=b/'stdout12388-preflight/bin/Release/net11.0/SemanticPreflight.exe'
inputs=[formatter,harness,harness.with_suffix('.dll'),harness.with_suffix('.deps.json'),harness.with_suffix('.runtimeconfig.json'),Path(__file__),manifest,compiler,compiler.with_suffix('.dll')]+sources+list((root/'stdlib').rglob('*.slg'));pins={str(p):sha(p) for p in inputs}
r={'schemaVersion':1,'status':'running','scope':'One frontend-only diagnostic build and run for semantic AST result roots versus lowered map Unit type. Second focused frontend-only discriminator, no production LLVM emission. Print only target IR node identities and canonical argument resolver values; no production LLVM emission and no goal qualification claim.','inputHashes':pins,'completed':0,'total':1,'cases':[],'buildBudget':1,'claimsGoalComplete':False}
x=VerificationExecution(root,o,r,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 a=x.run([str(formatter),'format','--check',str(sources[0])],o/'format',timeout=30)
 if a.returncode or a.stderr.strip():raise ValueError('DIAGNOSTIC_FORMAT_PREFLIGHT_FAILED '+a.stderr)
 a=x.run([str(harness),str(compiler.with_suffix('.dll')),*[str(p) for p in sources]],o/'semantic',timeout=60)
 if a.returncode or a.stderr.strip():raise ValueError('DIAGNOSTIC_SEMANTIC_PREFLIGHT_FAILED '+a.stderr)
 pre=json.loads(a.stdout);assert not pre['warnings'] and not pre['codegenInvoked'];r['wrapperPreflight']=pre;x.save()
 exe=o/'diagnostic.exe';a=x.run([str(compiler),'build',*[str(p) for p in sources],'-o',str(exe),'--target','windows-x64','--keep-temps','--llvm',str(root/'.tools/llvm-22.1.8')],o/'build',timeout=180)
 if a.returncode or a.stderr.strip():raise ValueError('DIAGNOSTIC_BUILD_FAILED '+a.stderr)
 a=x.run([str(exe)],o/'run',timeout=90)
 if a.returncode or a.stderr.strip():raise ValueError('DIAGNOSTIC_RUN_FAILED '+a.stderr)
 assert 'expression=38,type=2,status=0' in a.stdout and 'expression=17,type=2,status=0' in a.stdout,'CALLBACK_CALL_TYPE_NOT_REFINED'
 r['cases']=[{'id':'stream-consumer-identities','status':'passed','passed':True,'buildExit':0,'runExit':0,'stdout':a.stdout}];r.update(status='passed',completed=1)
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}))
