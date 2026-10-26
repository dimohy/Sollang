from pathlib import Path
import subprocess,sys,json
r=Path.cwd();b=r/'artifacts/scratch/resume-20261006-owner-continuation22';f=b/'frozen16132'
for mode in ['remaining']:
 command=[sys.executable,str(r/'scripts/verify-example-test-catalog.py'),'--preflight',str(b/'catalog16449-preflight/result.json'),'--runner',str(f/'tests/Sollang.ExampleTests/bin/Release/net11.0/Sollang.ExampleTests.dll'),'--compiler',str(b/'managed16362/compiler/Sollang.Compiler.dll'),'--selfhost-driver-build',str(b/'v16382/compiler-build01'),'--selfhost-production-root',str(r),'--fixture-root',str(f),'--source-closure-result',str(f/f'artifacts/source-closure16492-{mode}.json'),'--output',str(b/f'catalog16494-{mode}'),'--managed-reference','--execute','--case-budget-seconds','180','--total-budget-seconds',str(2388*180),'--selection-file',str(b/'catalog16494-selection.json')]
 if mode=='remaining':command+=['--continue-on-assertion-failure']
 for name in ['v12432','v16219','v16382']:command+=['--reusable-compiler-directory',str(b/name/'compiler-build01')]
 with (b/f'catalog16494-{mode}.stdout').open('wb') as out,(b/f'catalog16494-{mode}.stderr').open('wb') as err:exit=subprocess.run(command,stdout=out,stderr=err).returncode
 print('remaining-catalog-exit',exit,flush=True)
