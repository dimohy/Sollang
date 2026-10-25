from pathlib import Path
import sys,json,hashlib,re
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cp=Path(__file__).with_suffix('.json');c=R(cp);pins=c['inputHashes'];pins[str(cp.resolve())]=H(cp);pins[str(Path(__file__).resolve())]=H(Path(__file__))
stable=lambda:all(Path(p).is_file() and H(p)==h for p,h in pins.items())
assert stable(),'RUNTIME9_INPUT_DRIFT_BEFORE_EXECUTION'
out=Path(c['output']);initialize_output(root,out,reusable_directories=list(map(Path,c['reusableDirectories'])));out.mkdir(exist_ok=False)
r=dict(schemaVersion=1,status='running',scope=c['scope'],completed=0,total=9,cases=[],inputHashes=pins,claimsGoalComplete=False)
x=VerificationExecution(root,out,r,stable,H);error=None
try:
 emitted=x.run([c['producer'],'x'*21],out/'runtime-source',timeout=180);assert emitted.returncode==0 and not emitted.stderr
 text=(out/'runtime-source.stdout').read_text(encoding='utf-8-sig');start=text.index('define internal { ptr, i32 } @sollang_diagnostic_start(');end=text.index('\n}',start)+2;body=text[start:end];assert body.count('@malloc(')==1
 globalLine=next(line for line in text.splitlines() if line.startswith('@sollang_diagnostic_next_session_id ='))
 module=Path(c['typeDefinitionModule']).read_text(encoding='utf-8-sig');headers=[line for line in module.splitlines() if line.startswith('target ') or re.match(r'^%[^ ]+ = type ',line)];assert any('diagnostic_session = type' in line for line in headers)
 # The original C fixture supplies this allocator fault hook; keep production source separately.
 body=body.replace('@malloc(', '@diagnostic_test_alloc(')
 glue='\ndeclare ptr @diagnostic_test_alloc(i64)\ndefine ptr @diagnostic_start_probe(i32 %capacity, ptr %error) {\nentry:\n  %pair = call { ptr, i32 } @sollang_diagnostic_start(i32 %capacity)\n  %session = extractvalue { ptr, i32 } %pair, 0\n  %status = extractvalue { ptr, i32 } %pair, 1\n  store i32 %status, ptr %error, align 4\n  ret ptr %session\n}\ndefine void @diagnostic_set_next_id(i64 %id) {\nentry:\n  store i64 %id, ptr @sollang_diagnostic_next_session_id, align 8\n  ret void\n}\ndefine i64 @diagnostic_get_next_id() {\nentry:\n  %id = load i64, ptr @sollang_diagnostic_next_session_id, align 8\n  ret i64 %id\n}\n'
 llvm=out/'runtime.ll';llvm.write_text('\n'.join(headers)+'\n'+globalLine+'\n'+body+'\n'+glue,encoding='utf-8');r['currentProductionRuntimeSourceSha256']=H(out/'runtime-source.stdout');r['derivedRuntimeSha256']=H(llvm);r['originalCFixtureSha256']=H(c['fixture']);x.save()
 assembly=x.run([str(root/'.tools/llvm-22.1.8/bin/llvm-as.exe'),str(llvm),'-o',str(out/'runtime.bc')],out/'assemble',timeout=180);assert assembly.returncode==0 and not assembly.stderr
 link=x.run([str(root/'.tools/llvm-22.1.8/bin/clang.exe'),str(llvm),c['fixture'],'-O0','-Wno-override-module','-o',str(out/'runtime.exe')],out/'link',timeout=180);assert link.returncode==0 and not link.stderr
 run=x.run([str(out/'runtime.exe')],out/'run',timeout=180);norm=lambda p:Path(p).read_bytes().replace(bytes((13,10)),bytes((10,)));assert run.returncode==0 and not run.stderr and norm(out/'run.stdout')==norm(c['expectedStdout'])
 r.update(status='passed',completed=9,cases=[dict(id='actual-start-runtime-nine-controls',status='passed',passed=True,controlsCompleted=9,controlsTotal=9,productionSourceModified=False,allocatorInterposition='Original diagnostic_test_alloc C fixture hook')])
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if r['status']=='passed' else 1)
