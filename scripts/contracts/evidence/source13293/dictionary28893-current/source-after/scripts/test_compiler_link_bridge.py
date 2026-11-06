"""Exercise the real bridge's ABI and hash checks before any linker work."""
import argparse
import hashlib
import json
from pathlib import Path

from completed_artifact_plan import initialize_output, cleanup_output
from verification_execution import VerificationExecution

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('bridge', 'compiler', 'llvm', 'sample', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--slg-sample', type=Path)
    parser.add_argument('--emission-source', type=Path)
    parser.add_argument('--semantic-invalid-source', type=Path)
    parser.add_argument('--reusable-directory', type=Path, action='append')
    args = parser.parse_args()
    bridge, compiler, llvm, sample, output = [p.resolve() for p in
        (args.bridge, args.compiler, args.llvm, args.sample, args.output)]
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('LINK_BRIDGE_TEST_FRESH_OUTPUT_REQUIRED')
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir(parents=True)
    target = output / 'wrong-target.ll.fixture.txt'
    target.write_text('target triple = "x86_64-unknown-linux-gnu"\n')
    entry = output / 'missing-entry.ll.fixture.txt'
    entry.write_text('target triple = "x86_64-pc-windows-msvc"\n')
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest().upper()
    paths = [bridge, compiler, sample, target, entry, Path(__file__).resolve(),
             ROOT / 'scripts/verification_execution.py']
    slg_sample = args.slg_sample.resolve() if args.slg_sample else None
    if slg_sample is not None:
        paths.append(slg_sample)
    emission_rows = []
    if args.emission_source is not None:
        if args.semantic_invalid_source is None:
            raise ValueError('EMISSION_TEST_NEGATIVE_SOURCE_REQUIRED')
        source = args.emission_source.resolve()
        invalid = args.semantic_invalid_source.resolve()
        stdlib = sorted((ROOT / 'stdlib').rglob('*.slg'))
        paths.extend([source, invalid, *stdlib, llvm / 'bin/llvm-as.exe'])
        base = dict(schemaVersion=1, target='windows-x64', outputKind='executable',
                    sourcePaths=[str(source)], inputHashes={str(p): sha(p) for p in [source, *stdlib]})
        collision = output / 'existing-output.fixture.txt'
        collision.write_text('preserve existing output\n', encoding='utf-8')
        paths.append(collision)
        for name, failure in [('emit-normal', None),
                ('emit-bad-compiler', 'COMPILER_LINK_BRIDGE_ASSEMBLY_DRIFT'),
                ('emit-source-drift', 'COMPILER_EMISSION_INPUT_DRIFT'),
                ('emit-undeclared', 'COMPILER_EMISSION_UNDECLARED_LOADED_INPUT'),
                ('emit-existing-output', 'COMPILER_EMISSION_OUTPUT_INVALID'),
                ('emit-semantic-invalid', 'semantic error')]:
            manifest = json.loads(json.dumps(base))
            if name == 'emit-source-drift':
                manifest['inputHashes'][str(source)] = '0' * 64
            if name == 'emit-undeclared':
                del manifest['inputHashes'][str(stdlib[0])]
            if name == 'emit-semantic-invalid':
                manifest['sourcePaths'] = [str(invalid)]
                manifest['inputHashes'] = {str(p): sha(p) for p in [invalid, *stdlib]}
            path = output / (name + '.json')
            path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
            paths.append(path)
            emission_rows.append((name, path, collision if name == 'emit-existing-output'
                                  else output / (name + '.ll'), failure))
    fixtures = {}
    for name, body in {
            'legacy-main': 'define i32 @main() { ret i32 0 }',
            'duplicate-entry': 'define i32 @sollang_start() { ret i32 0 }\ndefine i32 @sollang_start() { ret i32 0 }',
            'declaration-only': 'declare i32 @sollang_start()'}.items():
        path = output / (name + '.ll.fixture.txt')
        path.write_text('target triple = "x86_64-pc-windows-msvc"\n' + body + '\n')
        fixtures[name] = path
        paths.append(path)
    pins = {str(p): sha(p) for p in paths}
    stable = lambda: all(Path(p).is_file() and sha(Path(p)) == digest for p, digest in pins.items())
    result = dict(schemaVersion=1, scope='compiler-link-bridge-input-contract', status='running',
                  completed=0, total=6, cases=[], inputHashes=pins)
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        rows = [('normal-O0', sha(compiler), sample, '-O0', None),
                ('normal-O1', sha(compiler), sample, '-O1', None),
                ('invalid-optimization', sha(compiler), sample, '-O9', 'COMPILER_LINK_BRIDGE_OPTIMIZATION_INVALID'),
                ('assembly-drift', '0' * 64, sample, '-O1', 'COMPILER_LINK_BRIDGE_ASSEMBLY_DRIFT'),
                ('wrong-target', sha(compiler), target, '-O1', 'COMPILER_LINK_BRIDGE_TARGET_ABI_MISMATCH'),
                ('missing-entry', sha(compiler), entry, '-O1', 'COMPILER_LINK_BRIDGE_ENTRY_REQUIRED')]
        if slg_sample is not None:
            rows.append(('native-normal', sha(compiler), slg_sample, '-O1', None))
        rows.extend((name, sha(compiler), path, '-O1', 'COMPILER_LINK_BRIDGE_ENTRY_REQUIRED')
                    for name, path in fixtures.items())
        rows.append(('legacy-mode', sha(compiler), sample, '-O1',
                     'COMPILER_LINK_BRIDGE_LEGACY_ENTRY_UNSUPPORTED'))
        result['total'] = len(rows)
        result['total'] += len(emission_rows)
        for name, manifest, generated, failure in emission_rows:
            digest = '0' * 64 if name == 'emit-bad-compiler' else sha(compiler)
            run = runner.run(['dotnet', str(bridge), 'emit', str(compiler), digest,
                              str(manifest), str(generated)], output / name, timeout=30)
            observation = json.loads(run.stdout)
            if failure is None:
                valid = (run.returncode == 0 and not run.stderr.strip()
                         and observation.get('status') == 'passed'
                         and observation.get('scope') == 'llvm-generation-only-not-compiler-acceptance'
                         and observation.get('outputSha256') == sha(generated)
                         and observation.get('warnings') == [])
                grammar = runner.run([str(llvm / 'bin/llvm-as.exe'), str(generated), '-o',
                                      str(output / (name + '.bc'))], output / (name + '-grammar'), timeout=30)
                valid = valid and grammar.returncode == 0 and not grammar.stderr.strip()
            else:
                valid = (run.returncode != 0 and observation.get('status') == 'failed'
                         and failure in run.stderr
                         and (name == 'emit-existing-output' or not generated.exists()))
            if not valid:
                raise ValueError('EMISSION_BRIDGE_TEST_MISMATCH: ' + name + ': ' + run.stderr)
            result['cases'].append(dict(id=name, status='passed'))
            result['completed'] += 1
            runner.save()
        for name, digest, source, optimization, failure in rows:
            exe = output / (name + '.exe')
            mode = 'probe-slg-main' if name == 'legacy-mode' else 'probe'
            run = runner.run(['dotnet', str(bridge), mode, str(compiler), digest,
                              str(llvm), str(source), str(exe), str(output), optimization], output / name, timeout=30)
            valid = (run.returncode == 0 and not run.stderr.strip()
                     and json.loads(run.stdout).get('status') == 'passed'
                     and json.loads(run.stdout).get('optimization') == optimization) if failure is None else (
                     run.returncode != 0 and failure in run.stderr)
            if not valid or exe.exists():
                raise ValueError('LINK_BRIDGE_TEST_MISMATCH: ' + name)
            result['cases'].append(dict(id=name, status='passed'))
            result['completed'] += 1
            runner.save()
        result['status'] = 'passed'
        print(f"COMPILER_LINK_BRIDGE_INPUT_TESTS_PASSED {result['completed']}/{result['total']}")
    except BaseException as exc:
        error = exc
        raise
    finally:
        runner.finalize(error, cleanup=False)
    if result['status'] == 'passed' and result['inputsStable'] and result['processesStopped']:
        cleanup_output(ROOT, output, execute=True, reusable_directories=args.reusable_directory)


if __name__ == '__main__':
    main()
