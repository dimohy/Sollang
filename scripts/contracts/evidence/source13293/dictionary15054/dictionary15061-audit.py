from pathlib import Path
import argparse,json,hashlib,ast,sys,re,time
r=Path.cwd();sys.path.insert(0,str(r/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
p=argparse.ArgumentParser();p.add_argument('--mode',choices=['managed','native'],required=True);p.add_argument('--parent',type=Path,required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'));H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';parent=args.parent.resolve();proof=R(parent);assert proof['status']=='passed' and proof['completed']==proof['total']==8 and proof['inputsStable'] and proof['processesStopped'];assert proof['mode']==('managed' if args.mode=='managed' else 'paired')
for f,h in proof['inputHashes'].items():assert H(f)==h,f
old=b/('dictionary-managed-audit10990' if args.mode=='managed' else 'dictionary-native-audit10992');baseline=R(old/'result.json');shim=r/'tests/native-interop/owned_array_audit.c';assert [h for f,h in baseline['inputSha256'].items() if f.endswith('owned_array_audit.c')]==[H(shim)]
tool=r/'scripts/verify-c385-preir-call-numeric.py';tree=ast.parse(tool.read_text(encoding='utf-8-sig'));matches=[z for z in ast.walk(tree) if isinstance(z,ast.For) and isinstance(z.iter,ast.Tuple) and any(isinstance(k,ast.Constant) and k.value=='call ptr @malloc(' for k in ast.walk(z.iter))];assert len(matches)==1;pairs=ast.literal_eval(matches[0].iter);assert ('define i32 @main()','define i32 @slg_program_main()') in pairs
out=args.output.resolve();initialize_output(r,out,reusable_directories=[b/'v12432',b/'v14562',b/'v14775']);out.mkdir(exist_ok=False);pins=dict(proof['inputHashes'])
for f in [parent,old/'result.json',shim,tool,Path(__file__),r/'.tools/llvm-22.1.8/bin/clang.exe']:pins[str(f.resolve())]=H(f)
selected=baseline['cases'];assert [(z['id'],z['expectedCount']) for z in selected]==[('dictionary-interpolation-and-retained35',94),('original-owned-transform-functions',6)]
original_roots={z['id']:old for z in selected}
if args.mode=='native':original_roots['dictionary-interpolation-and-retained35']=b/'dictionary-native-audit10991'
for case in selected:
 original_root=original_roots[case['id']];historical=R(original_root/'result.json');part=next(z for z in historical['cases'] if z['id']==case['id']);assert part['status']=='passed' and part['expectedCount']==case['expectedCount'] and part['stdout']==case['stdout'];assert historical['inputsStable'] and historical['processesStopped']
 for f in [original_root/'result.json',original_root/case['id']/'run.stdout',original_root/case['id']/'run.stderr']:pins[str(f)]=H(f)
for case in selected:
 llvm=parent.parent/case['id']/'probe.exe.ll';assert proof['generatedOutputHashes'][str(llvm)]==H(llvm);pins[str(llvm)]=H(llvm)
stable=lambda:all(Path(f).is_file() and H(f)==h for f,h in pins.items());record=dict(schemaVersion=1,status='running',mode=args.mode,scope='Original dictionary exact allocation94/6, balanced release/no-invalid audit2. Reuse actual current parent LLVM and existing ownership transform data/shim; exact original link O1/macros/libraries and raw program+audit output preserved. No compiler build or case rerun.',inputHashes=pins,completed=0,total=2,cases=[],parentProof=str(parent),compilerSourceChanged=False,compilerBuilds=0,maximumCaseSeconds=180,claimsGoalComplete=False);v=VerificationExecution(r,out,record,stable,H);error=None
try:
 for case in selected:
  started=time.monotonic();folder=out/case['id'];folder.mkdir();row=dict(id=case['id'],status='running',passed=False,expectedCount=case['expectedCount']);record['cases'].append(row);v.save();llvm=parent.parent/case['id']/'probe.exe.ll';text=llvm.read_text(encoding='utf-8-sig')
  for source,target in pairs:text=text.replace(source,target)
  assert len(re.findall(r'^define (?:dso_local )?i32 @slg_program_main\(\)',text,re.M))==1
  text+='\ndeclare ptr @audit_malloc(i64)\ndeclare ptr @audit_realloc(ptr,i64)\ndeclare void @audit_free(ptr)\n';audit=folder/'audit.ll';audit.write_text(text,encoding='utf-8');row['originalCurrentLlvmSha256']=H(llvm);row['auditLlvmSha256']=H(audit)
  original_root=original_roots[case['id']];historical=R(original_root/'result.json');row['originalHistoricalExecutionRoot']=str(original_root);oldcommands=[z['command'] for z in historical['processes'] if any(case['id'] in value for value in z['command'])];assert len(oldcommands)==2
  for name,command in zip(['link','run'],oldcommands):
   rebased=[value.replace('P:\\MyWorks\\Sollang',str(r)).replace(str(original_root),str(out)) for value in command];remaining=180-(time.monotonic()-started);assert remaining>0;done=v.run(rebased,folder/name,timeout=remaining);row[name+'Exit']=done.returncode;assert done.returncode==0 and not done.stderr,(case['id'],name,done.stderr)
   if name=='run':
    assert (folder/'run.stdout').read_bytes().replace(b'\r\n',b'\n')==(original_root/case['id']/'run.stdout').read_bytes().replace(b'\r\n',b'\n');assert done.stdout.replace('\r\n','\n')==case['stdout'];row['stdout']=done.stdout
  row.update(status='passed',passed=True);record['completed']+=1;v.save();print(case['id']+': PASS',flush=True)
 record['status']='passed'
except BaseException as caught:error=caught
finally:v.finalize(error,cleanup=False)
print(json.dumps({k:record.get(k) for k in ['status','completed','total','inputsStable','processesStopped','failure']}));sys.exit(0 if record['status']=='passed' else 1)
