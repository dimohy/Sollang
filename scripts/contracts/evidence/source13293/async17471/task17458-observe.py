import json,sys,subprocess,hashlib
from pathlib import Path
B=Path('artifacts/scratch/resume-20261006-owner-continuation22');root=Path.cwd()
d=json.loads((B/'task17456-source9.json').read_text(encoding='utf-8'))
sources=[B/'task17455-observer.slg',*[Path(p) for p in d['reusableCheckedProducer']['additionalSources']]]
compiler=B/'managed17430/compiler/Sollang.Compiler.exe'
pins={p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in [*sources,compiler,compiler.with_suffix('.dll')]}
out=B/'task17458-observation';out.mkdir(exist_ok=False)
bridge=[sys.executable,'scripts/verification_process_bridge.py','--repo',str(root)]
build=[str(compiler),'build',*[str(p) for p in sources],'-o',str(out/'observer.exe'),'--target','windows-x64','--keep-temps','-O0','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')]
subprocess.run([*bridge,'--output',str(out/'build'),'--timeout-seconds','180','--',*build],check=True)
build_result=json.loads((out/'build/result.json').read_text(encoding='utf-8'))
assert build_result['programExit']==0 and build_result['inputsStable'] and build_result['processesStopped'], 'OBSERVER_BUILD_FAILED'
subprocess.run([*bridge,'--output',str(out/'run'),'--timeout-seconds','180','--',str(out/'observer.exe')],check=True)
r=json.loads((out/'run/result.json').read_text(encoding='utf-8'))
assert r['programExit']==0 and r['inputsStable'] and r['processesStopped']
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()==v for p,v in pins.items())
s=(out/'run/command.stdout').read_text(encoding='utf-8')
assert s.strip().endswith('observer-complete') and 'observer-overflow' not in s
(out/'observation.json').write_text(json.dumps(dict(status='observed-not-qualified',scope='minimal direct Task binding AST and final TypedIR; no full stdlib; distinguishes Task call source AST, flags, value repair and binding edges',inputHashes=pins,inputsStable=True,processesStopped=True,claimsGoalComplete=False),indent=2),encoding='utf-8')
print(s)
