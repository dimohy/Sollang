"""Compare request composition with facts and keys exported by actual CSharp Open."""
from pathlib import Path
import argparse
import hashlib
import json

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def source_facts(observation):
    quote = lambda value: json.dumps(value, ensure_ascii=False)
    field = lambda value: f'keys.textField({quote(value)})'
    number = lambda value: str(value)
    lines = ['namespace sollang.test.codegen.request.facts',
             'import sollang.compiler.llvm.codegen_cache_keys as keys',
             'public catalog: -> keys.CompilationModules {',
             '    [keys.CompilationModule; ~] => modules!']
    for index, module in enumerate(observation['modules']):
        imports = ', '.join(field(name) for name in module['imports'])
        order = ', '.join(str(i) for i in range(len(module['imports'])))
        imports_value = f'[{imports}; ~]' if imports else '[keys.Field; ~]'
        order_value = f'[{order}; ~]' if order else '[Int; ~]'
        lines += ['    modules! -> push(keys.CompilationModule {',
                  f'        sourceModule: {index}',
                  f'        identity: {field(module["name"])}',
                  f'        stableIdentity: {number(module["stableHash"])}',
                  f'        implementationHash: {number(module["implementationHash"])}',
                  f'        interfaceHash: {number(module["interfaceHash"])}',
                  f'        isStandardLibrary: {str(module["isStandardLibrary"]).lower()}',
                  f'        imports: {imports_value}', f'        importOrder: {order_value}', '    })']
    order = ', '.join(str(i) for i in range(len(observation['modules'])))
    lines += [f'    keys.CompilationModules {{ modules: modules!, order: [{order}; ~] }}', '}',
              'public emissions: -> [keys.ModuleEmission; ~] {', '    [keys.ModuleEmission; ~] => values!']
    for emission in observation['emissions']:
        lines += [f'    values! -> push(keys.ModuleEmission {{ identity: {field(emission["name"])}, hash: {number(emission["hash"])} }})']
    lines += ['    values!', '}', f'public universe: -> UInt64 => {number(observation["typeUniverseHash"])}']
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('compiler', 'reference-result', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    reference = json.loads(args.reference_result.read_text(encoding='utf-8-sig'))
    assert reference['status'] == 'passed' and reference['completed'] == reference['total'] == 1
    assert reference['inputsStable'] and reference['processesStopped']
    observation = reference['cases'][0]['observation']
    assert len(observation['modules']) > 1 and observation['emissions'], 'control fixtures require multiple source modules and an emission'
    manifest = ROOT / 'scripts/probes/codegen-request/sources.txt'
    sources = [ROOT / entry for entry in manifest.read_text().splitlines() if entry]
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    fixture = output / 'facts.slg'
    fixture.write_text(source_facts(observation), encoding='utf-8', newline='\n')
    paths = [Path(__file__), compiler, *managed_runtime_inputs(compiler), args.reference_result,
             manifest, *sources, fixture, *sorted((ROOT / 'stdlib').rglob('*.slg'))]
    pins = {str(path.resolve()): sha(path) for path in paths}
    with VerificationContractLease(list(map(Path, pins))):
        result = dict(schemaVersion=1, status='running', completed=0, total=3, inputHashes=pins,
                      claimsGoalComplete=False, cases=[], scope='Actual CSharp request facts and complete key composition; native fact discovery and production cache consumption remain pending.')
        execution = VerificationExecution(ROOT, output, result, lambda: all(sha(p) == h for p, h in pins.items()), sha)
        error = None
        try:
            built = execution.run([str(compiler), 'build', *map(str, sources), str(fixture), '-o', str(output / 'probe.exe'),
                                   '--target', 'windows-x64', '--llvm', str(ROOT / '.tools/llvm-22.1.8'), '--jobs', '24', '-O2'],
                                  output / 'build', timeout=60)
            assert built.returncode == 0 and not built.stderr, built.stdout[-1500:] + built.stderr
            ran = execution.run([str(output / 'probe.exe')], output / 'run', timeout=30)
            assert ran.returncode == 0 and not ran.stderr, ran.stdout + ran.stderr
            expected = [f'{part}:{observation[part]["interfaceHash"]}:{observation[part]["implementationHash"]}' for part in ('prefix', 'suffix')]
            expected += [f'module:{entry["name"]}:{entry["key"]["interfaceHash"]}:{entry["key"]["implementationHash"]}' for entry in observation['moduleKeys']]
            expected += ['control:duplicate-emission', 'control:invalid-catalog']
            assert ran.stdout.splitlines() == expected, 'CODEGEN_REQUEST_KEYS_DIFFER'
            result.update(status='passed', completed=3, cases=[dict(id='actual-csharp-request-keys', passed=True,
                          sourceModules=len(observation['modules']), emissionModules=len(observation['emissions']), moduleKeys=len(observation['moduleKeys']), boundaryKeys=2),
                          dict(id='duplicate-emission-rejected', passed=True), dict(id='invalid-catalog-rejected', passed=True)])
        except BaseException as exc:
            error = exc
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
