from pathlib import Path
import shutil,json,hashlib
B=Path('artifacts/scratch/resume-20261006-owner-continuation22');P=B/'oracle17625-proposal';shutil.copytree(B/'oracle17623-proposal',P)
f=P/'42-fixed-array-placement.slg.llvm.regex-counts.txt'
with f.open('a',encoding='utf-8') as out:out.write(r'1'+'\t'+r'(?m)^  call void @free\(ptr %fixedbacking[0-9]+_[0-9]+\)\r?$'+'\n')
p=P/'proposal.json';d=json.loads(p.read_text(encoding='utf-8'));d['files'][0]['source']=f.as_posix();d['files'][0]['sha256']=hashlib.sha256(f.read_bytes()).hexdigest().upper();d['previousCandidateFailure']='oracle17624-controls14/result.json: duplicate-drop mutation accepted; strengthened exact free count';p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
