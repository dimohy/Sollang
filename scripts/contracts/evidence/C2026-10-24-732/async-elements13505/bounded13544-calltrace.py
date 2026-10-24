from pathlib import Path
import subprocess,sys
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22'
s=(b/'bounded13543-trace.py').read_text(encoding='utf-8').replace('bounded13543','bounded13544')
needle='''    sources -> semanticContext.prepare => prepared
    prepared -> expressionTypes.resolveContext => resolved'''
assert s.count(needle)==1
s=s.replace(needle,'''    sources -> semanticContext.prepare => initialPrepared
    initialPrepared -> expressionTypes.resolveCallContext => callContext
    callContext.prepared => prepared
    callContext.types => resolved''')
p=b/'bounded13544-run.py';p.write_text(s,encoding='utf-8')
sys.exit(subprocess.run([sys.executable,str(p)],cwd=r).returncode)
