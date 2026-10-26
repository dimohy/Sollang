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
        allocator = output / 'invalid-allocator.ll.fixture.txt'
        allocator.write_text('target triple = "x86_64-pc-windows-msvc"\n'
                             'define i32 @main() {\n  ret i32 0\n}\n'
                             'declare ptr @malloc(i32)\n')
        paths.append(allocator)
        crt = output / 'invalid-crt.ll.fixture.txt'
        crt.write_text('target triple = "x86_64-pc-windows-msvc"\n'
                       'define i32 @main() {\n  ret i32 0\n}\n'
                       'declare i32 @_get_osfhandle(i32)\n')
        paths.append(crt)
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
            rows.extend([
                ('native-normal', sha(compiler), slg_sample, '-O1', None),
                ('managed-reject-native', sha(compiler), slg_sample, '-O1', 'COMPILER_LINK_BRIDGE_ENTRY_REQUIRED'),
                ('native-reject-managed', sha(compiler), sample, '-O1', 'COMPILER_LINK_BRIDGE_ENTRY_REQUIRED'),
                ('native-wrong-target', sha(compiler), target, '-O1', 'COMPILER_LINK_BRIDGE_TARGET_ABI_MISMATCH'),
                ('native-missing-entry', sha(compiler), entry, '-O1', 'COMPILER_LINK_BRIDGE_ENTRY_REQUIRED'),
                ('native-invalid-allocator', sha(compiler), allocator, '-O1', 'COMPILER_LINK_BRIDGE_ALLOCATOR_ABI_MISMATCH'),
                ('native-invalid-crt', sha(compiler), crt, '-O1', 'COMPILER_LINK_BRIDGE_CRT_ABI_MISMATCH')])
        result['total'] = len(rows)
        for name, digest, source, optimization, failure in rows:
            exe = output / (name + '.exe')
            mode = 'probe-slg-main' if name.startswith('native-') else 'probe'
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
        print(f"COMPILER_LINK_BRIDGE_INPUT_TESTS_PASSED {len(rows)}/{len(rows)}")
    except BaseException as exc:
        error = exc
        raise
    finally:
        runner.finalize(error, cleanup=False)
    if result['status'] == 'passed' and result['inputsStable'] and result['processesStopped']:
        cleanup_output(ROOT, output, execute=True, reusable_directories=args.reusable_directory)


if __name__ == '__main__':
    main()
