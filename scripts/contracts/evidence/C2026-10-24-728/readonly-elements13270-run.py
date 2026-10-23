from pathlib import Path
import hashlib, json, sys

root = Path.cwd()
base = root / 'artifacts/scratch/resume-20261006-owner-continuation22'
sys.path.insert(0, str(root / 'scripts'))
from verification_execution import VerificationExecution

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()

prior = json.loads((base / 'readonly-elements13268-types/result.json').read_text(encoding='utf-8-sig'))
assert prior['status'] == 'observed' and prior['inputsStable'] and prior['processesStopped']
assert all(Path(p).is_file() and sha(p) == h for p, h in prior['inputHashes'].items())
source = (base / 'readonly-elements13268-types.slg').read_text(encoding='utf-8-sig')
source = source.replace('main {', 'import sollang.compiler.semantic.library_imports as libraryImports\nimport sollang.compiler.semantic.diagnostics as semanticDiagnostics\nimport sys.path as path\n\nmain {', 1)
source = source.replace('    [\n', '    [\n', 1).replace('    ] -> semanticContext.prepareFiles => initial!', '    ] => paths\n    paths -> semanticContext.prepareFiles => initial!')
source = source.replace('    initial! -> freeze -> expressionTypeIds.resolveCallContext => resolved', '''    initial! -> freeze => initial
    initial.package -> libraryImports.load(paths, "windows-x64", path.Style.Windows) => libraries
    initial.package -> libraryImports.resolveQualified(libraries) => libraryCalls
    initial.package -> libraryImports.callResultTypes(initial.semantic.types, libraries, libraryCalls) => externalResults
    "libraries=$(libraries.bindings -> len),libraryCalls=$(libraryCalls -> len),externalResults=$(externalResults -> len)" -> println
    initial -> expressionTypeIds.resolveCallContextWithExternalResults(externalResults) => resolved''')
source = source.replace('    prepared.package.ranges[144] => range', '''    typeIds.enumPayloadEdges(types.types, types.references, prepared.package.ranges, prepared.package.symbols, types.referenceIndexByTypeAst) => payloadEdges
    prepared -> semanticContext.ownedResourceSeeds(types.types) => resourceSeeds
    typeIds.classifyWithResources(types.types, types.fields, payloadEdges, resourceSeeds) => traits
    prepared -> semanticDiagnostics.firstBindingDeclarationDiagnostic(types, traits, libraryCalls) => diagnostic
    "diagnostic=$(diagnostic.code),module=$(diagnostic.sourceModule),value=$(diagnostic.valueAst),expected=$(diagnostic.expectedTypeId),actual=$(diagnostic.actualTypeId)" -> println
    prepared.package.ranges[144] => range''')
probe = base / 'readonly-elements13270-diagnostic.slg'
assert not probe.exists()
probe.write_text(source, encoding='utf-8', newline='\n')
plan_path = base / 'readonly-elements13270-plan.json'
plan = dict(scope='One actual library load/external-results/binding-diagnostic query; preserve original language oracles and active Native inputs.',
            priorEvidence=str(base / 'readonly-elements13268-types/result.json'),
            hypothesis='The actual external-result resolution or binding-diagnostic selection differs from the earlier raw type query.',
            alternative='If this query rejects with correct operand read types, inspect exact diagnostic selection rather than broad-unwrapping reference values.',
            budget=dict(builds=1, buildSeconds=180, runSeconds=60, retries=0), claimsAcceptance=False)
assert not plan_path.exists()
plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
out = base / 'readonly-elements13270-diagnostic'
out.mkdir(exist_ok=False)
command = list(prior['processes'][0]['command'])
command[2] = str(probe)
command[command.index('-o')+1] = str(out / 'probe.exe')
pins = dict(prior['inputHashes'])
for p in [probe, plan_path, Path(__file__), root / 'scripts/verification_execution.py']:
    pins[str(p)] = sha(p)
result = dict(schemaVersion=1, status='running', scope=plan['scope'], inputHashes=pins, claimsGoalComplete=False)
execution = VerificationExecution(root, out, result, lambda: all(Path(p).is_file() and sha(p)==h for p,h in pins.items()), sha)
error = None
try:
    compiled = execution.run(command, out / 'build', timeout=180)
    assert compiled.returncode == 0, compiled.stderr
    observed = execution.run([str(out/'probe.exe')], out/'run', timeout=60)
    assert observed.returncode == 0 and not observed.stderr, observed.stderr
    result.update(status='observed', stdout=observed.stdout)
    print(observed.stdout, flush=True)
except BaseException as caught:
    error = caught
finally:
    execution.finalize(error, cleanup=False)
print(json.dumps({k:result.get(k) for k in ('status','failure','inputsStable','processesStopped')}),flush=True)
sys.exit(0 if result['status']=='observed' else 1)
