from pathlib import Path
import json,hashlib,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';sys.path.insert(0,str(r/'scripts'));from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_source_proof import current_build_inputs
from completed_artifact_plan import initialize_output,cleanup_output
side=sys.argv[1];assert side in ['managed','native'];c=b/('abi25712-managed/compiler/Sollang.Compiler.exe' if side=='managed' else 'abi25750-native/compiler.exe');fmt=b/'abi25712-managed/compiler/Sollang.Compiler.exe';o=b/('abi25759-scalars-'+side);src=r/'scripts/probes/library-abi-admission/scalars.slg';reuse=[b/'abi25734-native',b/'v20050/compiler-build01'];
if side=='native':reuse.append(b/'abi25750-native')
initialize_output(r,o,reusable_directories=reuse);o.mkdir();sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();paths=[Path(__file__),src,c,*managed_runtime_inputs(fmt),*sorted((r/'stdlib').rglob('*.slg'))]
if side=='native':
 birth=b/'abi25750-native/result.json';paths.extend([birth,*current_build_inputs(r,json.loads(birth.read_text()))]);proof=json.loads((b/'abi25715-scalars-managed/result.json').read_text());assert proof['status']=='passed' and proof['completed']==proof['total']==1 and proof['inputsStable'] and proof['processesStopped'];assert all(sha(p)==h for p,h in proof['inputHashes'].items());paths.append(b/'abi25715-scalars-managed/result.json')
pins={str(p.resolve()):sha(p) for p in paths};v=dict(schemaVersion=1,status='running',completed=0,total=1,inputHashes=pins,cases=[],scope='One shared library exports every11 admitted scalar result kinds plus ordered two-input wrapper; actual ctypes calls cover signed/unsigned widths, float widths and Unit return. Metadata equality required for Native.',claimsGoalComplete=False);x=VerificationExecution(r,o,v,lambda:all(sha(p)==h for p,h in pins.items()),sha);error=None
try:
 q=x.run([str(fmt),'format','--check',str(src)],o/'format',timeout=30);assert q.returncode==0 and not q.stderr,(q.stdout,q.stderr)
 args=[str(c),'build',str(src),'-o',str(o/'scalars.dll'),'--library','--target','windows-x64','--llvm',str(r/'.tools/llvm-22.1.8'),'--jobs','1','-O0']
 if side=='native':args+=['--stdlib',str(r/'stdlib')]
 q=x.run(args,o/'build',timeout=180);assert q.returncode==0 and not q.stderr,(q.stdout,q.stderr);metadata=json.loads((o/'scalars.windows-x64.slglib.json').read_text(encoding='utf-8-sig'));v['interface']=metadata
 if side=='native':assert metadata==proof['interface'],'SCALAR_ABI_INTERFACE_DRIFT'
 script='''import ctypes,json,sys
from pathlib import Path
m=json.loads(Path(sys.argv[2]).read_text(encoding="utf-8-sig"));lib=ctypes.CDLL(sys.argv[1]);types={"Unit":None,"Int8":ctypes.c_int8,"Int16":ctypes.c_int16,"Int32":ctypes.c_int32,"Int64":ctypes.c_int64,"UInt8":ctypes.c_uint8,"UInt16":ctypes.c_uint16,"UInt32":ctypes.c_uint32,"UInt64":ctypes.c_uint64,"Float32":ctypes.c_float,"Float64":ctypes.c_double};expected={"signed8":-101,"signed16":-30000,"signed32":-1234567,"signed64":-1234567890123,"unsigned8":250,"unsigned16":65000,"unsigned32":4000000000,"unsigned64":18000000000000000000,"float32":1.25,"float64":1234.5,"reset":None,"sum":37};assert len(m["exports"])==len(expected)==12;seen=set()
for e in m["exports"]:
 n=e["name"];f=getattr(lib,e["symbol"]);f.argtypes=[types[p["type"]] for p in e["parameters"]];f.restype=types[e["result"]];args=([12,25] if n=="sum" else [] if n=="reset" else [expected[n]]);actual=f(*args);assert actual==expected[n],(n,actual,expected[n]);seen.add(n)
assert seen==set(expected);print("12 exports: PASS")
'''
 q=x.run([sys.executable,'-c',script,str(o/'scalars.dll'),str(o/'scalars.windows-x64.slglib.json')],o/'call',timeout=30);assert q.returncode==0 and not q.stderr and q.stdout.strip()=='12 exports: PASS',(q.stdout,q.stderr);v.update(status='passed',completed=1,cases=[dict(id='all-fixed-width-and-unit-results',passed=True,exportInvocations=12)])
except BaseException as e:error=e
finally:x.finalize(error,cleanup=False)
if error:raise error
cleanup_output(r,o,reusable_directories=reuse);print(json.dumps({k:v[k] for k in ['status','completed','total','inputsStable','processesStopped']}))
