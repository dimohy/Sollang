"""Trace a derived P1206 fixture without modifying its canonical acceptance output."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('managed', 'selfhost'), required=True)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--compiler-sha256', required=True)
    parser.add_argument('--managed-proof', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--error-detail', action='store_true',
                        help='Trace the exact canonical QuicError kind through an exhaustive enum match')
    args = parser.parse_args()
    fixture = ROOT / 'examples/regression/1206-quic-bidirectional-multi-stream-routing.slg'
    proof_path = args.managed_proof.resolve()
    proof = json.loads(proof_path.read_text(encoding='utf-8-sig'))
    if (proof.get('status') != 'passed' or proof.get('completed') != 6
            or not proof.get('inputStable') or not proof.get('processesStopped')
            or proof['inputHashes'].get('source:P1206') != sha(fixture)):
        raise ValueError('P1206_STAGE_OBSERVER_MANAGED_FIRST_INVALID')
    compiler = args.compiler.resolve()
    if not compiler.is_file() or sha(compiler) != args.compiler_sha256.upper():
        raise ValueError('P1206_STAGE_OBSERVER_COMPILER_MISMATCH')
    source = fixture.read_text(encoding='utf-8')
    signature = 'uses Network, Random, Clock {'
    if source.count(signature) != 1:
        raise ValueError('P1206_STAGE_OBSERVER_EFFECT_SCOPE_CHANGED')
    lines = source.replace(signature, 'uses Network, Random, Clock, Console {').splitlines()
    steps = [(index, line.strip()) for index, line in enumerate(lines)
             if '?' in line and not line.lstrip().startswith('#')]
    if len(steps) != 21 or any('"' in line for _, line in steps):
        raise ValueError('P1206_STAGE_OBSERVER_PROPAGATION_PLAN_CHANGED')
    step_by_line = {index: ordinal for ordinal, (index, _) in enumerate(steps, 1)}
    traced = []
    for index, line in enumerate(lines):
        if index in step_by_line:
            traced.append(f'    "trace-before={step_by_line[index]}" -> println')
        if line.strip() == 'Result<Bool, quic.QuicError>.Ok(routed)':
            traced.append('    "trace-complete=$routed" -> println')
        traced.append(line)
    if args.error_detail:
        kind_source = ROOT / 'stdlib/std/net/quic/error.slg'
        import re
        match = re.search(r'public enum Kind \{([^}]+)\}', kind_source.read_text(encoding='utf-8'))
        if match is None:
            raise ValueError('P1206_STAGE_OBSERVER_KIND_CONTRACT_MISSING')
        kinds = [line.strip() for line in match.group(1).splitlines() if line.strip()]
        if len(kinds) != 17 or any(not re.fullmatch(r'[A-Za-z]+', kind) for kind in kinds):
            raise ValueError('P1206_STAGE_OBSERVER_KIND_CONTRACT_CHANGED')
        original = '        Err(error) { "quic-multi-stream-error=$(error.code)" -> println }'
        if traced.count(original) != 1:
            raise ValueError('P1206_STAGE_OBSERVER_ERROR_ARM_CHANGED')
        replacement = ['        Err(error) {',
                       '            "quic-multi-stream-error=$(error.code)" -> println',
                       '            error.kind -> when {']
        replacement += [f'                {kind} {{ "trace-error-kind={kind}" -> println }}' for kind in kinds]
        replacement += ['            }', '        }']
        index = traced.index(original)
        traced[index:index + 1] = replacement
    output = args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('P1206_STAGE_OBSERVER_FRESH_OUTPUT_REQUIRED')
    llvm = ROOT / '.tools/llvm-22.1.8'
    stdlib = sorted((ROOT / 'stdlib').rglob('*.slg'))
    tools = [llvm / 'bin/clang.exe', llvm / 'bin/llvm-as.exe']
    runtime = managed_runtime_inputs(compiler) if args.mode == 'managed' else [compiler]
    if any(not path.is_file() for path in [fixture, proof_path, *tools, *runtime]):
        raise ValueError('P1206_STAGE_OBSERVER_INPUT_MISSING')
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    derived = output / 'trace.slg'
    derived.write_bytes(('\n'.join(traced) + '\n').encode('utf-8'))
    plan = output / 'trace-plan.json'
    plan.write_text(json.dumps(dict(source=str(fixture), sourceSha256=sha(fixture),
                                   steps=[dict(ordinal=i, line=index + 1, expression=line)
                                          for i, (index, line) in enumerate(steps, 1)]), indent=2) + '\n', encoding='utf-8')
    inputs = [fixture, proof_path, derived, plan, Path(__file__).resolve(), *stdlib, *tools, *runtime]
    pins = {str(path): sha(path) for path in inputs}
    result = dict(schemaVersion=1, status='running', mode=args.mode, inputHashes=pins,
                  scope='Derived fixture execution observation; no P1206 acceptance or allocation audit completion',
                  originalFixtureUnchanged=True, stepTotal=21, errorDetail=args.error_detail)
    stable = lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in inputs)
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        command = (['dotnet', str(compiler)] if args.mode == 'managed' else [str(compiler)])
        command += ['build', str(derived), '-o', str(output / 'trace.exe'), '--target', 'windows-x64',
                    '--llvm', str(llvm), '-O1', '--keep-temps']
        if args.mode == 'selfhost':
            command += ['--stdlib', str(ROOT / 'stdlib')]
        build = runner.run(command, output / 'build', 1200)
        if build.returncode or build.stderr.strip():
            raise ValueError('P1206_STAGE_OBSERVER_BUILD_FAILED')
        run = runner.run([str(output / 'trace.exe')], output / 'run', 120)
        if run.returncode or run.stderr.strip():
            raise ValueError('P1206_STAGE_OBSERVER_RUN_FAILED')
        markers = [int(line.partition('=')[2]) for line in run.stdout.splitlines() if line.startswith('trace-before=')]
        if not markers or markers != list(range(1, markers[-1] + 1)):
            raise ValueError('P1206_STAGE_OBSERVER_TRACE_ORDER_INVALID')
        result.update(status='observed', lastAttemptedStep=markers[-1],
                      routeCompleted=any(line.startswith('trace-complete=') for line in run.stdout.splitlines()),
                      stdout=run.stdout)
        print(json.dumps({key: result[key] for key in ('mode', 'status', 'lastAttemptedStep', 'routeCompleted', 'stdout')}))
    except BaseException as exc:
        error = exc
        raise
    finally:
        runner.finalize(error)


if __name__ == '__main__':
    main()
