"""Qualify the frozen async capability cases and real semantic-cache restoration.

The common compiler runner owns the six cold cases. This consumer checks that
proof and adds one warm condition using an unrelated private declaration change,
so neither frontend nor product-cache hits can stand in for semantic restoration.
"""
import argparse
import importlib.util
import json
import shutil
import sys
from pathlib import Path

from focused_verification_output import sha
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

ROOT = Path(__file__).resolve().parent.parent
CONTRACT = ROOT / 'scripts/contracts/zero-input-generic-async.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--compiler-kind', choices=('managed', 'native'), required=True)
    parser.add_argument('--cold-proof', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    compiler, proof_path, output = (p.resolve() for p in
                                    (args.compiler, args.cold_proof, args.output))
    contract = json.loads(CONTRACT.read_text(encoding='utf-8-sig'))
    cold = json.loads(proof_path.read_text(encoding='utf-8-sig'))
    if (cold.get('status') != 'passed' or cold.get('completed') != 6
            or cold.get('total') != 6 or not cold.get('inputsStable')
            or not cold.get('processesStopped')):
        raise ValueError('GENERIC_ASYNC_COLD_PROOF_INCOMPLETE')
    cold_pins = cold['inputHashes']
    if any(not Path(p).is_file() or sha(p) != h for p, h in cold_pins.items()):
        raise ValueError('GENERIC_ASYNC_COLD_PROOF_INPUT_DRIFT')
    if cold_pins.get(str(CONTRACT)) != sha(CONTRACT):
        raise ValueError('GENERIC_ASYNC_COLD_CONTRACT_MISMATCH')
    if cold_pins.get(str(compiler)) != sha(compiler):
        raise ValueError('GENERIC_ASYNC_COLD_COMPILER_MISMATCH')
    for case in contract['cases']:
        case_dir = proof_path.parent / case['id']
        if case['exit'] == 0:
            # The common runner stores untrimmed process output separately.
            raw = case_dir / 'run.stdout'
            if raw.read_text(encoding='utf-8-sig') != case['expectedRawStdout']:
                raise ValueError('GENERIC_ASYNC_RAW_OUTPUT_MISMATCH: ' + case['id'])
        elif case.get('requireNoLlvm') and any(case_dir.glob('*.ll')):
            raise ValueError('GENERIC_ASYNC_REJECTION_EMITTED_LLVM: ' + case['id'])
    versions = [ROOT / 'scripts/probes/numeric-context-cache' / name
                for name in ('generic-unrelated-a.slg', 'generic-unrelated-b.slg')]
    runtime = managed_runtime_inputs(compiler) if args.compiler_kind == 'managed' else [compiler]
    inputs = [*map(Path, cold_pins), proof_path, *runtime, *versions,
              Path(__file__), ROOT / 'scripts/verification_execution.py',
              ROOT / 'scripts/verify-contextual-numeric-cache.py']
    pins = {str(p.resolve()): sha(p) for p in inputs}
    output.mkdir(parents=True, exist_ok=False)
    result = dict(schemaVersion=1, status='running', completed=6, total=7,
                  scope=contract['capability'], inputHashes=pins,
                  coldProof=str(proof_path), compilerKind=args.compiler_kind,
                  claimsGoalComplete=False,
                  cases=[dict(id=case['id'], status='passed', passed=True,
                              proof=str(proof_path), proofCaseId=case['id'])
                         for case in contract['cases']], warmExecutions=[])
    warm_condition = dict(id='semantic-cache-restoration', status='running', passed=False)
    result['cases'].append(warm_condition)
    execution = VerificationExecution(ROOT, output, result,
        lambda: all(Path(p).is_file() and sha(p) == h for p, h in pins.items()), sha)
    error = None
    try:
        source = ROOT / next(c['source'] for c in contract['cases']
                             if c['id'] == contract['warmCacheCase'])
        helper, executable = output / 'unrelated.slg', output / 'probe.exe'
        for label, version in zip(('setup', 'warm'), versions):
            shutil.copyfile(version, helper)
            helper_hash = sha(helper)
            command = [str(compiler), 'build', str(source), str(helper), '-o', str(executable),
                       '--llvm', str(ROOT / '.tools/llvm-22.1.8'), '--target', 'windows-x64',
                       contract['harnessBuildOptimization'], '--jobs',
                       str(contract['harnessBuildJobs'])]
            built = execution.run(command, output / (label + '-build'), timeout=180)
            if built.returncode or built.stderr.strip() or sha(helper) != helper_hash:
                raise ValueError('GENERIC_ASYNC_CACHE_BUILD_FAILED: ' + label + ': ' + built.stderr)
            ran = execution.run([str(executable)], output / (label + '-run'), timeout=180)
            if ran.returncode or ran.stdout != '7\n7\n' or ran.stderr:
                raise ValueError('GENERIC_ASYNC_CACHE_RUNTIME_CHANGED: ' + label)
            if label == 'warm':
                if args.compiler_kind == 'managed':
                    restored = ('[semantic-cache] loaded;' in built.stdout
                                and '; main reused;' in built.stdout)
                else:
                    spec = importlib.util.spec_from_file_location('numeric_cache_verifier',
                        ROOT / 'scripts/verify-contextual-numeric-cache.py')
                    module = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(module)
                    restored = module.native_cache_reused(output)
                if not restored:
                    raise ValueError('GENERIC_ASYNC_SEMANTIC_RESTORATION_NOT_EXERCISED')
            result['warmExecutions'].append(dict(id=label, status='passed',
                helperSha256=helper_hash, buildStdout=built.stdout,
                generatedOutputHashes={str(p): sha(p) for p in output.rglob('*')
                                       if p.is_file() and (p.suffix in ('.exe', '.ll', '.semantic'))}))
        warm_condition.update(status='passed', passed=True)
        result.update(status='passed', completed=7)
    except BaseException as failure:
        warm_condition.update(status='failed', passed=False)
        error = failure
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({k: result.get(k) for k in
                      ('status', 'completed', 'total', 'failure', 'inputsStable', 'processesStopped')}))
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
