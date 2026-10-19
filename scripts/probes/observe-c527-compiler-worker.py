"""Observe the terminated C527 worker with bounded call traces, without promotion."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from completed_artifact_plan import initialize_output, assert_output_shutdown
from verification_execution import VerificationExecution
from verification_c527_enclosing_trace import validate as validate_enclosing_trace
from verification_diagnostic_continuation import check_c527_plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--observer-directory', type=Path, required=True)
    parser.add_argument('--original', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--observation-seconds', type=int, choices=(60, 300, 1200), default=60)
    parser.add_argument('--purpose', default='')
    parser.add_argument('--diagnostic-plan', type=Path)
    args = parser.parse_args()
    if args.diagnostic_plan is None:
        raise ValueError('AS-DC-001-PLAN-REQUIRED')
    if args.observation_seconds > 60 and not args.purpose.strip():
        raise ValueError('C527_OBSERVATION_EXTENDED_WINDOW_PURPOSE_REQUIRED')
    folder, original, output = [p.resolve() for p in (args.observer_directory, args.original, args.output)]
    old_path = original / 'result.json'
    old = json.loads(old_path.read_text(encoding='utf-8-sig'))
    if (old.get('status') != 'failed' or old.get('inputStable') is not True
            or 'exceeded the configured verification limit' not in old.get('failure', '')):
        raise ValueError('C527_OBSERVATION_TERMINAL_STABLE_TIMEOUT_REQUIRED')
    assert_output_shutdown(ROOT, original)
    prepared = json.loads((folder / 'result.json').read_text())
    if prepared.get('status') != 'prepared' or prepared.get('observationStarted') is not False:
        raise ValueError('C527_OBSERVATION_PREPARED_PRODUCT_REQUIRED')
    trace_manifests = [Path(p) for p in prepared['inputHashes'] if p.endswith('.trace.json')]
    if len(trace_manifests) != 1:
        raise ValueError('C527_OBSERVATION_SINGLE_TRACE_MANIFEST_REQUIRED')
    trace_plan = json.loads(trace_manifests[0].read_text())
    trace_contract = None
    if trace_plan.get('root') == 'sollang_fn_sollang_compiler_llvm_text_prepareNative':
        trace_contract = validate_enclosing_trace(trace_plan)
    arguments_path = folder / 'native-worker-arguments.json'
    command = json.loads(arguments_path.read_text())['arguments']
    manifest = ROOT / 'examples/regression/expected/2489-preir-propagated-display-invariant.sources.txt'
    sources = [(ROOT / line.strip()).resolve() for line in manifest.read_text().splitlines() if line.strip()]
    stdlib_sources = list((ROOT / 'stdlib').rglob('*.slg'))
    traces_source_loop = any(
        ('resolveModulesTypedWithReceiverTypes->' in row['label']
         and row['label'].endswith('_resolveSourceTyped'))
        or ('lowerResolvedContextWithMode->' in row['label']
            and row['label'].endswith('_lowerSource'))
        for row in trace_plan['markers'])
    minimum_records = 2 * (len(sources) + len(stdlib_sources)) + len(trace_plan['markers'])
    if traces_source_loop and trace_plan['maximumRecords'] < minimum_records:
        raise ValueError('C527_OBSERVATION_SOURCE_LOOP_TRACE_BUDGET_TOO_SMALL')
    reference_path = Path(prepared.get('referenceCompilerBuildRecord', ''))
    if not reference_path.is_file() or str(reference_path) not in prepared['inputHashes']:
        raise ValueError('C527_OBSERVATION_REFERENCE_BUILD_REQUIRED')
    reference = json.loads(reference_path.read_text(encoding='utf-8-sig'))
    if (reference.get('status') != 'passed' or reference.get('inputsStable') is not True
            or prepared.get('optimization') != reference.get('optimization')):
        raise ValueError('C527_OBSERVATION_OPTIMIZATION_MISMATCH')
    if (len(sources) != 111 or command[1] != 'windows-stdlib'
            or Path(command[2]).resolve() != ROOT / 'stdlib'
            or command[3:] != [str(p) for p in sources]):
        raise ValueError('C527_OBSERVATION_CAPTURED_INPUT_SCOPE_INVALID')
    command[0] = str(folder / 'observer.exe')
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest().upper()
    pins = dict(prepared['inputHashes'])
    paths = [old_path, arguments_path, manifest, Path(__file__).resolve(),
             ROOT / 'scripts/verification_execution.py',
             ROOT / 'scripts/verification_c527_enclosing_trace.py', *sources, *stdlib_sources]
    pins.update({str(p): sha(p) for p in paths})
    stable = lambda: all(Path(p).is_file() and sha(Path(p)) == digest for p, digest in pins.items())
    if not stable() or output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('C527_OBSERVATION_INPUT_OR_OUTPUT_CONTRACT_INVALID')
    continuation = check_c527_plan(args.diagnostic_plan, command,
                                   args.observation_seconds * 1000,
                                   output.with_suffix('.continuation.json'))
    pins[str(args.diagnostic_plan.resolve())] = sha(args.diagnostic_plan)
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    result = dict(schemaVersion=1, status='running', scope='diagnostic-only-not-acceptance',
                  inputHashes=pins, observationTimeoutSeconds=args.observation_seconds,
                  observationPurpose=args.purpose, originalFixtureSources=111,
                  maximumTraceRecords=trace_plan['maximumRecords'], optimization=prepared['optimization'])
    result['traceContractValidation'] = trace_contract
    result['diagnosticContinuation'] = continuation
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        run = runner.run(command, output / 'worker', timeout=args.observation_seconds)
        result.update(status='observed', exit=run.returncode)
    except subprocess.TimeoutExpired as exc:
        error = exc
        result['boundedObservationExpired'] = True
    except BaseException as exc:
        error = exc
        raise
    finally:
        trace = output / 'worker.stderr'
        lines = trace.read_text(encoding='utf-8-sig').splitlines() if trace.exists() else []
        result['traceRecordCount'] = len(lines)
        result['traceBudgetExhausted'] = len(lines) >= trace_plan['maximumRecords']
        result['lastTraceRecords'] = lines[-5:]
        runner.finalize(error)
        print(json.dumps({key: result.get(key) for key in
            ('status', 'inputsStable', 'processesStopped', 'traceRecordCount', 'lastTraceRecords')}))


if __name__ == '__main__':
    main()
