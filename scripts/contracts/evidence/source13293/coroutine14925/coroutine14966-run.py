from pathlib import Path
import sys,json,hashlib,re,gzip
root=Path.cwd();sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
from completed_artifact_plan import initialize_output
R=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'))
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
cp=Path(__file__).with_suffix('.json');c=R(cp);pins=c['inputHashes'];pins[str(cp.resolve())]=H(cp);pins[str(Path(__file__).resolve())]=H(Path(__file__))
stable=lambda:all(Path(p).is_file() and H(p)==h for p,h in pins.items())
assert stable(),'SOURCE5_CURRENT_INPUT_DRIFT'
out=Path(c['output']);initialize_output(root,out,reusable_directories=list(map(Path,c['reusableDirectories'])));out.mkdir(exist_ok=False)
r=dict(schemaVersion=1,status='running',scope=c['scope'],completed=0,total=5,inputHashes=pins,cases=[],compilerBuilds=0,claimsGoalComplete=False)
x=VerificationExecution(root,out,r,stable,H);error=None
pattern=re.compile(r'^node (-?\d+) kind (-?\d+) parent (-?\d+) source (-?\d+) ast (-?\d+) symbol (-?\d+) target (-?\d+) type (-?\d+)/(-?\d+)/(-?\d+)/(-?\d+)/(-?\d+)/(-?\d+) payload (-?\d+) opcode (-?\d+) operands (-?\d+)/(-?\d+)/(-?\d+) flags (\d+)$')
opcodes={'start':-324,'track':-325,'snapshot':-326,'close':-327};norm=lambda p:Path(p).read_bytes().replace(bytes((13,10)),bytes((10,)))
try:
 for item in c['cases']:
  case=item['case'];folder=out/case['id'];folder.mkdir();prefix=folder/item['capture'];row=dict(id=case['id'],status='running',passed=False);r['cases'].append(row);x.save();done=x.run(item['command'],prefix,timeout=180);row['buildExit']=done.returncode;assert done.returncode==item['expectedExit'],'SOURCE5_EXIT_MISMATCH:'+case['id']
  if case['kind']=='metadata':
   assert not done.stderr,'SOURCE5_UNEXPECTED_STDERR:'+case['id'];counts={k:0 for k in opcodes};programRows=0;tasks=0;asyncCalls=0;totalRows=0
   with prefix.with_suffix('.stdout').open(encoding='utf-8-sig') as handle:
    for line in handle:
     if not line.strip():continue
     match=pattern.fullmatch(line.strip());assert match,'SOURCE5_TYPED_IR_ROW_FORMAT';v=list(map(int,match.groups()));totalRows+=1
     if v[3]!=item['sourceIndex']:continue
     programRows+=1
     if v[1]==6 and v[14] in opcodes.values():
      name=next(k for k,code in opcodes.items() if code==v[14]);counts[name]+=1;tasks+=int(v[8]==14);asyncCalls+=int((v[18]//8)%2==1)
   observed={k:n>0 for k,n in counts.items()};assert programRows>0 and observed==case['expectedFlags'] and tasks==0 and asyncCalls==0,'SOURCE5_INTRINSIC_IDENTITY_MISMATCH:'+case['id'];row.update(observedFlags=observed,callCounts=counts,programRows=programRows,totalRows=totalRows,canonicalDiagnosticTaskValues=tasks,allDiagnosticCallsSynchronous=True)
   # Retain the original complete stdout bytes in gzip; this is storage compression only.
   raw=prefix.with_suffix('.stdout');archive=raw.with_suffix('.stdout.gz')
   with raw.open('rb') as src,gzip.open(archive,'wb') as dst:
    while chunk:=src.read(1024*1024):dst.write(chunk)
   row['losslessStdoutArchive']=dict(path=str(archive),originalSha256=H(raw),originalBytes=raw.stat().st_size,archiveSha256=H(archive))
  else:
   old=Path(item['originalCapture']);assert norm(prefix.with_suffix('.stderr'))==norm(old.with_suffix('.stderr')) and norm(prefix.with_suffix('.stdout'))==norm(old.with_suffix('.stdout')),'SOURCE5_ORIGINAL_DIAGNOSTIC_MISMATCH:'+case['id'];row['exactDiagnosticAndSourceLine']=True
  row.update(status='passed',passed=True);r['completed']+=1;x.save()
 r['status']='passed'
except BaseException as caught:error=caught
finally:x.finalize(error,cleanup=False)
print(json.dumps({k:r.get(k) for k in ['status','completed','total','failure','inputsStable','processesStopped']}));sys.exit(0 if r['status']=='passed' else 1)
