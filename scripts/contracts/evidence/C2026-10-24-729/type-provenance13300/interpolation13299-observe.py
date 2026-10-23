from pathlib import Path
import hashlib, json, sys
root = Path.cwd()
base = root/'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0,str(root/'scripts'))
from verification_execution import VerificationExecution
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
prior=json.loads((base/'grouped13295-source/result.json').read_text(encoding='utf-8-sig'))
previous=json.loads((base/'interpolation13297-observe/result.json').read_text(encoding='utf-8-sig'))
assert previous['status']=='failed' and previous['inputsStable'] and previous['processesStopped']
out=base/'interpolation13299-observe'
out.mkdir(exist_ok=False)
command=list(prior['processes'][1]['command'])
private_sources=[]
for stem in ['function_calls','control_region_expressions']:
    source=root/f'selfhost/llvm/text/{stem}.slg'
    private=out/f'{stem}.slg'
    text=source.read_text(encoding='utf-8-sig')
    prefix='functionExpression' if stem=='function_calls' else 'regionExpression'
    idx='functionExpressionRootIndex' if stem=='function_calls' else 'regionExpressionRootSearch!'
    module='runtimeArgument.sourceModule' if stem=='function_calls' else 'regionArgument.sourceModule'
    owner='functionIndex' if stem=='function_calls' else 'ownerIndex'
    before='expressionIndex' if stem=='function_calls' else 'regionNodeIndex'
    anchor='                                            '+prefix+'RootTypeSymbol! -> integerSigned(context, state) => '+prefix+'RootSigned'
    assert text.count(anchor)==1
    probe=(f'                                            {idx} -> interpolationNodeTypeId({prefix}Interpolation, {module}, {owner}, {before}, context, state) => observedId\n'
           f'                                            "; observed {stem} root=$({idx}),symbol=$({prefix}RootTypeSymbol!),typeId=$observedId" -> println\n'
           '                                            observedId >= 0 -> if {\n'
           '                                                context.types[observedId] => observedType\n'
           '                                                "; observed kind=$(observedType.kind),origin=$(observedType.origin),symbol=$(observedType.symbol),first=$(observedType.first)" -> println\n'
           '                                            }\n')
    private.write_text(text.replace(anchor,probe+anchor),encoding='utf-8')
    private_sources.extend([source,private])
    command[command.index(str(source))]=str(private)
command[command.index('-o')+1]=str(out/'probe.exe')
plan=dict(scope='Observe alternative function/control-region interpolation paths on unchanged1712; no acceptance or canonical edit.',priorObservation=str(base/'interpolation13297-observe/result.json'),reason='Entry-path instrumentation emitted no comments; emitted LLVM print templates also exist in function_calls and control_region_expressions.',budget=dict(builds=1,buildSeconds=180,emitSeconds=180,retries=0),claimsAcceptance=False)
(out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8')
pins=dict(prior['inputHashes'])
assert all(Path(p).is_file() and sha(p)==h for p,h in pins.items())
for p in private_sources+[out/'plan.json',Path(__file__)]: pins[str(p)]=sha(p)
result=dict(schemaVersion=1,status='running',scope=plan['scope'],inputHashes=pins,claimsAcceptance=False)
execution=VerificationExecution(root,out,result,lambda:all(Path(p).is_file() and sha(p)==h for p,h in pins.items()),sha)
error=None
try:
    built=execution.run(command,out/'build',timeout=180)
    assert built.returncode==0,built.stderr
    emitted=execution.run([str(out/'probe.exe'),'examples/regression/1712-algorithm-in-place-ordering.slg'],out/'emission',timeout=180)
    assert emitted.returncode==0 and not emitted.stderr,emitted.stderr
    observations=[line for line in emitted.stdout.splitlines() if line.startswith('; observed')]
    assert observations
    (out/'observations.json').write_text(json.dumps(observations,indent=2)+'\n',encoding='utf-8')
    result.update(status='observed',observations=observations)
    print('\n'.join(observations),flush=True)
except BaseException as caught: error=caught
finally: execution.finalize(error,cleanup=False)
print(json.dumps({k:result.get(k) for k in ['status','failure','inputsStable','processesStopped']}),flush=True)
sys.exit(0 if result['status']=='observed' else 1)
