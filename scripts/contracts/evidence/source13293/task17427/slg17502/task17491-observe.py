import json,sys,subprocess,hashlib
from pathlib import Path
B=Path('artifacts/scratch/resume-20261006-owner-continuation22');root=Path.cwd();d=json.loads((B/'task17490-source3.json').read_text(encoding='utf-8'))
sources=[B/'task17487-observer.slg',*[Path(p) for p in d['reusableCheckedProducer']['additionalSources']]]
programs=[Path('scripts/probes/async-coroutine')/('c748-'+n+'-rejected.slg') for n in ['await-argument','nonasync-await']]
compiler=B/'managed17430/compiler/Sollang.Compiler.exe'
pins={p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in [*sources,*programs,compiler,compiler.with_suffix('.dll')]}
out=B/'task17491-observation';out.mkdir(exist_ok=False);bridge=[sys.executable,'scripts/verification_process_bridge.py','--repo',str(root)]
build=[str(compiler),'build',*[str(p) for p in sources],'-o',str(out/'observer.exe'),'--target','windows-x64','--keep-temps','-O0','--jobs','4','--llvm',str(root/'.tools/llvm-22.1.8')]
subprocess.run([*bridge,'--output',str(out/'build'),'--timeout-seconds','180','--',*build],check=True)
r=json.loads((out/'build/result.json').read_text(encoding='utf-8'));assert r['programExit']==0 and r['inputsStable'] and r['processesStopped'],'OBSERVER_BUILD_FAILED'
for p in programs:
    case=out/p.stem
    subprocess.run([*bridge,'--output',str(case),'--timeout-seconds','180','--',str(out/'observer.exe'),p.as_posix()],check=True)
    r=json.loads((case/'result.json').read_text(encoding='utf-8'));assert r['programExit']==0 and r['inputsStable'] and r['processesStopped']
    text=(case/'command.stdout').read_text(encoding='utf-8');assert text.strip().endswith('observer-complete') and 'observer-overflow' not in text
    print(p.as_posix());print(text)
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()==v for p,v in pins.items())
(out/'observation.json').write_text(json.dumps(dict(status='observed-not-qualified',scope='Exact rejected source files2, no stdlib: AST and final TypedIR plus selected source diagnostic. Distinguishes target path shape, source identity and Task classification; not qualification of full package.',inputHashes=pins,inputsStable=True,processesStopped=True,claimsGoalComplete=False),indent=2),encoding='utf-8')
