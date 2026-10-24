from pathlib import Path
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
s=(b/'bounded13533-trace.py').read_text(encoding='utf-8').replace('bounded13533','bounded13535')
needle=" d.update(status='passed',completed=1)"
assert s.count(needle)==1
s=s.replace(needle,'''
 import re
 rows=p.stdout.splitlines()
 fields=[tuple(map(int,re.fullmatch(r'field owner=(\\d+) ordinal=(\\d+) type=(\\d+)',line).groups())) for line in rows if line.startswith('field owner=')]
 types={int(m[1]):tuple(map(int,m.groups()[1:])) for line in rows if (m:=re.fullmatch(r'type=(\\d+) kind=(-?\\d+) first=(-?\\d+) length=(-?\\d+) origin=(-?\\d+)',line))}
 asts={int(m[1]):tuple(map(int,m.groups()[1:])) for line in rows if (m:=re.fullmatch(r'ast=(\\d+) kind=(-?\\d+) parent=(-?\\d+) start=(\\d+)',line))}
 expressions={int(m[1]):int(m[2]) for line in rows if (m:=re.fullmatch(r'expression ast=(\\d+) type=(-?\\d+) status=0',line))}
 assert len(fields)==1,fields
 field_type=fields[0][2];element_type=types[field_type][1]
 assert types[field_type][0]==3 and types[element_type][0]==12 and types[element_type][2]==2,types
 roots=[a for a,(kind,parent,start) in asts.items() if kind==37 and parent in asts and asts[parent][0]==40]
 assert len(roots)==1,roots
 outer=roots[0];children=[a for a,(kind,parent,start) in asts.items() if kind==37 and parent==outer]
 assert len(children)==2 and expressions[outer]==field_type and all(expressions[a]==element_type for a in children),(outer,children,expressions)
 d.update(status='passed',completed=1,scope='Post-fix actual SLG canonical field/child identity validation; not LLVM/runtime package acceptance.',checks=dict(declaredFieldShape=True,outerLiteralIdentity=True,innerEmptyLiteralIdentities=True),diagnosticBuildsBeforeFix=2,postFixValidationBuilds=1)
''')
# Preserve the exact generated validator with its result and source hashes.
p=b/'bounded13535-run.py';p.write_text(s,encoding='utf-8')
import subprocess,sys
sys.exit(subprocess.run([sys.executable,str(p)],cwd=r).returncode)
