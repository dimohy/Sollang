"""Build one source emitter after focused CSharp and canonical semantic proof."""
from pathlib import Path
import argparse
import hashlib
import json

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('compiler', 'output', 'semantic-result', 'source-comparison'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    compiler, output = args.compiler.resolve(), args.output.resolve()
    comparison = json.loads(args.source_comparison.read_text(encoding='utf-8'))
    budget = comparison['sourceEmitterBudget']
    assert output == (ROOT / budget['output']).resolve()
    assert budget['maximumBuilds'] == 1 and budget['timeoutSeconds'] == 180
    assert not output.exists(), 'SOURCE_EMITTER_BUILD_BUDGET_ALREADY_USED'
    reference_path = ROOT / comparison['csharpFirst']
    reference = json.loads(reference_path.read_text(encoding='utf-8'))
    semantic = json.loads(args.semantic_result.read_text(encoding='utf-8'))
    for result in (reference, semantic):
        assert result['status'] == 'passed' and result['completed'] == result['total']
        assert result['inputsStable'] and result['processesStopped']
    assert semantic['total'] == 4
    manifest = ROOT / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
    sources = [ROOT / line for line in manifest.read_text(encoding='utf-8-sig').splitlines()
               if line and not line.endswith('selfhost-sollangc-driver.slg')]
    for source in [manifest, *sources]:
        assert semantic['inputHashes'][str(source.resolve())] == sha(source)
    wrapper = ROOT / 'scripts/probes/codegen-unit-stream/emitter.slg'
    llvm = ROOT / '.tools/llvm-22.1.8'
    assert (llvm / 'bin/clang.exe').is_file() and (llvm / 'bin/llvm-as.exe').is_file()
    paths = [Path(__file__), compiler, *managed_runtime_inputs(compiler), args.semantic_result,
             args.source_comparison, reference_path, manifest, wrapper, *sources,
             *sorted((ROOT / 'stdlib').rglob('*.slg'))]
    inputs = {str(path.resolve()): sha(path) for path in paths}
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    with VerificationContractLease(list(map(Path, inputs))):
        result = dict(schemaVersion=1, status='running', completed=0, total=1,
                      inputHashes=inputs, claimsGoalComplete=False,
                      scope='Current source emitter for pending focused consumers; no Stage or cache reuse claim.')
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in inputs.items()), sha)
        error = None
        try:
            done = execution.run([str(compiler), 'build', str(wrapper), *map(str, sources),
                                  '-o', str(output / 'emitter.exe'), '--target', 'windows-x64',
                                  '--llvm', str(llvm), '--jobs', '24', '-O2'],
                                 output / 'build', timeout=budget['timeoutSeconds'])
            assert done.returncode == 0 and not done.stderr, done.stdout[-2000:] + done.stderr
            result.update(status='passed', completed=1,
                          cases=[dict(id='current-source-emitter-build', passed=True)])
        except BaseException as exc:
            error = exc
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
