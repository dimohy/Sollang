from pathlib import Path
import json,sys,hashlib,re
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from verification_contract_lease import VerificationContractLease
from verification_source_proof import current_build_inputs
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
b=root/'artifacts/scratch/resume-20261006-owner-continuation22';out=b/'locator16019/slg-native';compiler=b/'v15969/compiler-build01/compiler.exe';source=b/'locator16019/plan-probe.slg'
manifest=root/'examples/regression/expected/1255-selfhost-enum-arm-root-ir.sources.txt'
closure=[root/v.strip() for v in manifest.read_text(encoding='utf-8-sig').splitlines()[1:] if v.strip() and not v.lstrip().startswith('#')]
extra=root/'selfhost/syntax/source_decoding.slg'
if extra not in closure:closure.append(extra)
extraDiagnostics=root/'selfhost/syntax/diagnostics.slg'
if extraDiagnostics not in closure:closure.append(extraDiagnostics)
sources=[source,*closure]
provided=set()
required=set()
for p in [*sources,*sorted((root/'stdlib').rglob('*.slg'))]:
 t=p.read_text(encoding='utf-8-sig')
 provided.update(re.findall(r'^namespace\s+([\w.]+)',t,re.M))
 required.update(re.findall(r'^import\s+([\w.]+)',t,re.M))
missing=sorted(v for v in required if v.startswith(('sollang.compiler.','syntax.generated.')) and v not in provided)
assert not missing,('SOURCE_IDENTITY_IMPORT_CLOSURE_MISSING',missing)
inputs=[manifest,b/'locator16019/expected.stdout',*sorted((root/'stdlib').rglob('*.slg')),b/'locator16019/control.slg',compiler,b/'v15969/compiler-build01/result.json',*current_build_inputs(root,json.loads((b/'v15969/compiler-build01/result.json').read_text(encoding='utf-8-sig'))),*sources,Path(__file__),root/'scripts/verification_execution.py']
with VerificationContractLease(inputs):
    out.mkdir(exist_ok=False);pins={str(p):sha(p) for p in inputs};result=dict(schemaVersion=1,status='running',inputHashes=pins,claimsTestPassed=False,claimsGoalComplete=False)
    run=VerificationExecution(root,out,result,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
    try:
        exe=out/'probe.exe';command=[str(compiler),'build',*map(str,sources),'-o',str(exe),'--llvm',str(root/'.tools/llvm-22.1.8'),'--target','windows-x64','-O0','--jobs','1']
        built=run.run(command,out/'build',timeout=180);result['buildExit']=built.returncode
        if built.returncode!=0:raise ValueError('SOURCE_IDENTITY_PROBE_BUILD_FAILED')
        observed=run.run([str(exe),str(b/'locator16019/control.slg')],out/'run',timeout=180);result['runExit']=observed.returncode
        result['controlMatched']=observed.returncode==0 and not observed.stderr and observed.stdout.replace('\r\n','\n')==(b/'locator16019/expected.stdout').read_text(encoding='utf-8')
        assert result['controlMatched'],'SOURCE_IDENTITY_CONTROL_MISMATCH'
        result['status']='observed-not-qualified'
    except BaseException as failure:error=failure
    finally:run.finalize(error,cleanup=False)
    assert error is None,error
print(json.dumps({k:result.get(k) for k in ['status','buildExit','runExit','processesStopped']}))
