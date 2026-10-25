from pathlib import Path
import json,hashlib,sys,shutil
from xml.sax.saxutils import escape
R=Path.cwd();B=R/'artifacts/scratch/resume-20261006-owner-continuation22';P=R/'scripts/probes/dictionary-storage-boundaries';sys.path.insert(0,str(R/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output,cleanup_output
from verification_fingerprints import managed_runtime_inputs
out=B/'dictionary14412-managed-arithmetic';retained=[B/'v12432/compiler-build01',B/'v14280/compiler-build01'];initialize_output(R,out,reusable_directories=retained);out.mkdir(exist_ok=False)
project=out/'Arithmetic.csproj'
project.write_text('<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup>'+''.join('<Compile Include="'+escape(str(p),{'"':'&quot;'})+'" />' for p in [P/'managed-arithmetic.cs',R/'src/Sollang.Compiler/Semantics/IntDictionaryLayout.cs'])+'</ItemGroup></Project>',encoding='utf-8')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
dotnet=Path(shutil.which('dotnet'));assert dotnet.is_file()
inputs=[Path(__file__).resolve(),project,P/'managed-arithmetic.cs',P/'arithmetic.json',R/'src/Sollang.Compiler/Semantics/IntDictionaryLayout.cs',R/'scripts/verification_execution.py',R/'scripts/completed_artifact_plan.py',dotnet]
pins={str(p):sha(p) for p in inputs};data=json.loads((P/'arithmetic.json').read_text(encoding='utf-8'));expected=[','.join(str(row[k]) for k in ['length','capacity','entriesOffset','allocationBytes']) for row in data['rows']]+['layout=4,8,4']
record=dict(schemaVersion=1,status='running',scope='Actual CSharp IntDictionaryLayout source arithmetic without allocation; no whole compiler or Native acceptance.',inputHashes=pins,completed=0,total=len(expected),cases=[],maximumBuilds=1,caseBudgetSeconds=180,claimsGoalComplete=False)
stable=lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
x=VerificationExecution(R,out,record,stable,sha);error=None
try:
 build=x.run([str(dotnet),'build',str(project),'-c','Release','--nologo','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false'],out/'build',timeout=180)
 assert build.returncode==0 and not build.stderr and '0 Warning(s)' in build.stdout,build.stdout+'\n'+build.stderr
 run=x.run([str(dotnet),str(out/'bin/Release/net11.0/Arithmetic.dll'),str(P/'arithmetic.json')],out/'run',timeout=180)
 assert run.returncode==0 and not run.stderr,run.stderr
 actual=run.stdout.strip().splitlines();assert actual==expected,(actual,expected)
 record.update(status='passed',completed=len(expected),cases=[dict(id='arithmetic-'+str(i),status='passed',passed=True,buildExit=0,runExit=0,expected=v,actual=actual[i]) for i,v in enumerate(expected)])
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
if record['status']=='passed' and record['inputsStable'] and record['processesStopped']:cleanup_output(R,out,execute=True,reusable_directories=retained)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}));sys.exit(0 if record['status']=='passed' else 1)
