from pathlib import Path
import hashlib, json, sys

root = Path.cwd()
base = root / 'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0, str(root / 'scripts'))
from verification_execution import VerificationExecution

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()

prior = json.loads((base/'grouped13295-source/result.json').read_text(encoding='utf-8-sig'))
assert prior['status'] == 'failed' and prior['inputsStable'] and prior['processesStopped']
out = base/'interpolation13297-observe'
out.mkdir(exist_ok=False)
source = root/'selfhost/llvm/text/entry_expressions.slg'
private = out/'entry_expressions.slg'
text = source.read_text(encoding='utf-8-sig')
anchor = '                                                    entryExpressionRootTypeSymbol! -> integerSigned(context, state) => entryExpressionRootSigned'
assert text.count(anchor) == 1
probe = '''                                                    "; observed root=$(entryExpressionRootSearch!),kind=$(entryExpressionRoot.kind),symbol=$(entryExpressionRootTypeSymbol!),typeId=$(entryExpressionRootTypeId!),binding=$(entryExpressionRootBinding!),stream=$(entryExpressionRootStreamValue!)" -> println
                                                    entryExpressionRootTypeId! >= 0 -> if {
                                                        context.types[entryExpressionRootTypeId!] => observedType
                                                        "; observed typeKind=$(observedType.kind),origin=$(observedType.origin),symbol=$(observedType.symbol),first=$(observedType.first)" -> println
                                                    }
'''
private.write_text(text.replace(anchor, probe+anchor), encoding='utf-8')
plan = dict(scope='One private LLVM-comment observation of failed1712; no language changes or acceptance credit.', prior=str(base/'grouped13295-source/result.json'), hypotheses=['committed type is missing/reference rather than scalar','raw IR overwrite persists','alternate interpolation path bypasses restoration'], budget=dict(builds=1, buildSeconds=180, emitSeconds=180, retries=0), claimsAcceptance=False)
(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8')
command = list(prior['processes'][1]['command'])
command[command.index(str(source))] = str(private)
command[command.index('-o')+1] = str(out/'probe.exe')
pins = {p:h for p,h in prior['inputHashes'].items() if Path(p) != source}
assert all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
for path in [source, private, out/'plan.json', Path(__file__)]: pins[str(path)] = sha(path)
result = dict(schemaVersion=1,status='running',scope=plan['scope'],inputHashes=pins,claimsAcceptance=False)
execution = VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
error = None
try:
    built = execution.run(command,out/'build',timeout=180)
    assert built.returncode == 0, built.stderr
    emitted = execution.run([str(out/'probe.exe'),'examples/regression/1712-algorithm-in-place-ordering.slg'],out/'emission',timeout=180)
    assert emitted.returncode == 0 and not emitted.stderr, emitted.stderr
    observations = [line for line in emitted.stdout.splitlines() if line.startswith('; observed')]
    assert observations
    (out/'observations.json').write_text(json.dumps(observations,indent=2)+'\n',encoding='utf-8')
    result.update(status='observed',observations=observations)
    print('\n'.join(observations),flush=True)
except BaseException as caught:
    error = caught
finally:
    execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','failure','inputsStable','processesStopped']}),flush=True)
sys.exit(0 if result['status']=='observed' else 1)
