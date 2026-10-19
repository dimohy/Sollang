"""Compare a private compiler source candidate using two shared observers."""
import argparse
import hashlib
import json
import shutil
import subprocess
import time
from pathlib import Path

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from verification_stdlib_source_preflight import compiler_manifest_inputs

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def parse_observation(stdout, kind):
    prefixes = {'call-context': ('t=', 'e=', 'a='),
                'scheduled-core': ('diagnostic=', 'schedule=', 'order=', 'scheduled=')}
    if kind not in prefixes:
        raise ValueError('SOURCE_CANDIDATE_OBSERVATION_KIND_INVALID')
    lines = stdout.splitlines()
    if not lines or not lines[0].startswith('timing='):
        raise ValueError('CALL_CONTEXT_CANDIDATE_TIMING_MISSING')
    durations = list(map(int, lines[0][7:].split(',')))
    rows = lines[1:]
    if (len(durations) != 2 or any(value < 0 for value in durations) or not rows
            or not all(line.startswith(prefixes[kind]) for line in rows)):
        raise ValueError('CALL_CONTEXT_CANDIDATE_FACTS_INVALID')
    if kind == 'scheduled-core' and (rows[0] != 'diagnostic=0'
            or not any(line.startswith('schedule=') and line.split(',')[1:2] == ['11']
                       for line in rows)):
        raise ValueError('SOURCE_CANDIDATE_ENTRY_SCHEDULE_COVERAGE_REQUIRED')
    return durations, '\n'.join(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--llvm', type=Path, required=True)
    args = parser.parse_args()
    plan_path, output, compiler, llvm = [p.resolve() for p in (
        args.plan, args.output, args.compiler, args.llvm)]
    plan = json.loads(plan_path.read_text(encoding='utf-8-sig'))
    if (plan.get('schemaVersion') != 1 or plan.get('maximumBuilds') != 2
            or plan.get('maximumTotalSeconds') != 180 or plan.get('maximumWorkers') != 1
            or plan.get('optimization') != '-O1'
            or plan.get('performanceRunOrder') != ['baseline', 'candidate', 'candidate', 'baseline']):
        raise ValueError('CALL_CONTEXT_CANDIDATE_PLAN_INVALID')
    closure = [Path(p).resolve() for p in plan['buildClosure']]
    _, canonical_sources, manifest_inputs = compiler_manifest_inputs(ROOT)
    admitted_sources = set(canonical_sources) | set((ROOT / 'stdlib').rglob('*.slg'))
    if any(path not in admitted_sources for path in closure):
        raise ValueError('SOURCE_CANDIDATE_NONCANONICAL_COMPONENT_SOURCE')
    observer, baseline, candidate, comparison, scaling = [Path(plan[k]).resolve() for k in (
        'observer', 'baselineSource', 'candidateSource', 'sourceComparison', 'scalingSource')]
    controls = [Path(p).resolve() for p in plan['controls']]
    observation_kind = plan.get('observationKind', 'call-context')
    if observation_kind not in ('call-context', 'scheduled-core'):
        raise ValueError('SOURCE_CANDIDATE_OBSERVATION_KIND_INVALID')
    scaling_limit = plan.get('scalingTimeoutSeconds', 20)
    if (type(scaling_limit) is not int or scaling_limit < 1
            or scaling_limit > (30 if observation_kind == 'scheduled-core' else 20)):
        raise ValueError('SOURCE_CANDIDATE_SCALING_TIMEOUT_INVALID')
    runtime_inputs = [Path(p).resolve() for p in plan.get('runtimeInputFiles', [])]
    scaling_arguments = []
    if plan.get('scalingStdlibRoot') is not None:
        stdlib_root = Path(plan['scalingStdlibRoot']).resolve()
        if (stdlib_root != ROOT / 'stdlib' or len(runtime_inputs) != len(set(runtime_inputs))
                or set(runtime_inputs) != set(stdlib_root.rglob('*.slg'))):
            raise ValueError('SOURCE_CANDIDATE_RUNTIME_STDLIB_CLOSURE_REQUIRED')
        scaling_arguments.append(str(stdlib_root))
    if (baseline not in closure or len(closure) != len(set(closure)) or not controls
            or len(controls) != len(set(controls)) or baseline == candidate):
        raise ValueError('CALL_CONTEXT_CANDIDATE_SOURCE_CONTRACT_INVALID')
    proofs = [Path(plan[k]).resolve() for k in ('managedControlsProof', 'managedScalingProof')]
    proof_inputs = []
    for path in proofs:
        record = json.loads(path.read_text(encoding='utf-8-sig'))
        if (record.get('status') != 'passed' or record.get('completed') != record.get('total')
                or record.get('inputsStable') is not True or record.get('processesStopped') is not True):
            raise ValueError('CALL_CONTEXT_CANDIDATE_MANAGED_FIRST_REQUIRED')
        for name, digest in record['inputHashes'].items():
            dependency = Path(name)
            if not dependency.is_file() or sha(dependency) != digest.upper():
                raise ValueError('CALL_CONTEXT_CANDIDATE_MANAGED_PROOF_DRIFT:' + name)
            proof_inputs.append(dependency)
    source_comparison = json.loads(comparison.read_text(encoding='utf-8-sig'))
    if source_comparison.get('status') != 'compared-before-private-slg-edit':
        raise ValueError('CALL_CONTEXT_CANDIDATE_SOURCE_COMPARISON_REQUIRED')
    for name, digest in source_comparison['inputHashes'].items():
        if sha(Path(name)) != digest.upper():
            raise ValueError('CALL_CONTEXT_CANDIDATE_COMPARISON_DRIFT:' + name)
    reuse_path, reused_baseline = None, None
    if plan.get('baselineReuseRecord') is not None:
        reuse_path = Path(plan['baselineReuseRecord']).resolve()
        previous = json.loads(reuse_path.read_text(encoding='utf-8-sig'))
        rows = previous.get('processes', [])
        if previous.get('processesStopped') is not True or not rows:
            raise ValueError('CALL_CONTEXT_BASELINE_REUSE_NOT_STOPPED')
        build = rows[0]
        command = build['command']
        boundary = command.index('-o')
        if (build.get('exit') != 0 or build.get('shutdownConfirmed') is not True
                or command[:boundary] != list(map(str, [compiler, 'build', observer, *closure]))
                or command[boundary + 2:] != ['--target', 'windows-x64', '--llvm', str(llvm),
                    '--jobs', '1', '-O1', '--keep-temps']
                or (reuse_path.parent / 'baseline-build.stderr').read_text(encoding='utf-8-sig')):
            raise ValueError('CALL_CONTEXT_BASELINE_REUSE_COMMAND_MISMATCH')
        reused_baseline = Path(command[boundary + 1])
        if sha(reused_baseline) != previous['generatedOutputHashes'].get(str(reused_baseline)):
            raise ValueError('CALL_CONTEXT_BASELINE_REUSE_BINARY_DRIFT')
        # This script orchestrates the recorded compiler command; it is not a
        # compiler input. Every other old dependency must remain identical.
        for name, digest in previous['inputHashes'].items():
            if Path(name).resolve() != Path(__file__).resolve() and sha(Path(name)) != digest.upper():
                raise ValueError('CALL_CONTEXT_BASELINE_REUSE_INPUT_DRIFT:' + name)
    prior_records = [Path(p).resolve() for p in plan.get('priorExecutionRecords', [])]
    prior_seconds = 0
    for path in prior_records:
        previous = json.loads(path.read_text(encoding='utf-8-sig'))
        if previous.get('processesStopped') is not True:
            raise ValueError('SOURCE_CANDIDATE_PRIOR_EXECUTION_NOT_STOPPED')
        for row in previous['processes']:
            if (row.get('shutdownConfirmed') is not True or type(row.get('exit')) is not int
                    or type(row.get('durationMilliseconds')) is not int
                    or row['durationMilliseconds'] < 0):
                raise ValueError('SOURCE_CANDIDATE_PRIOR_COST_UNVERIFIED')
            prior_seconds += row['durationMilliseconds'] / 1000
    if prior_seconds >= 180:
        raise ValueError('SOURCE_CANDIDATE_CUMULATIVE_BUDGET_EXHAUSTED')
    inputs = list(dict.fromkeys([plan_path, *proofs, *proof_inputs, comparison, *closure,
        observer, candidate, *controls, scaling, *runtime_inputs, *prior_records, *manifest_inputs,
        *managed_runtime_inputs(compiler), Path(__file__),
        *[llvm / 'bin' / name for name in ('clang.exe', 'llvm-split.exe', 'lld-link.exe', 'llvm-lib.exe')],
        *[ROOT / 'scripts' / name for name in ('verification_execution.py',
            'verification_contract_lease.py', 'completed_artifact_plan.py', 'ArtifactLifecycle.ps1',
            'Invoke-CompletedArtifactCleanup.ps1', 'contracts/artifact-lifecycle.json')]]))
    if reused_baseline is not None:
        inputs.extend([reuse_path, reused_baseline])
    if not all(p.is_file() for p in inputs):
        raise ValueError('CALL_CONTEXT_CANDIDATE_INPUT_MISSING')
    free_kib = int(subprocess.check_output(['pwsh', '-NoProfile', '-Command',
        '(Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory'], text=True).strip())
    if free_kib < 2 * 1024 * 1024 or shutil.disk_usage(output.parent).free < 512 * 1024 * 1024:
        raise ValueError('CALL_CONTEXT_CANDIDATE_RESOURCE_PREFLIGHT')
    initialize_output(ROOT, output)
    output.mkdir(exist_ok=False)
    with VerificationContractLease(inputs):
        pins = {str(p): sha(p) for p in inputs}
        stable = lambda: all(p.is_file() and sha(p) == pins[str(p)] for p in inputs)
        record = dict(schemaVersion=1, status='running', completed=0, total=len(controls) + 2,
            cases=[], inputHashes=pins, plan=str(plan_path), scope=plan['scope'], maximumBuilds=2,
            maximumTotalSeconds=180, canonicalIntegration=False, claimsGoalComplete=False,
            claimsPerformanceImprovement=False, observationKind=observation_kind,
            priorChildSeconds=prior_seconds, priorExecutionRecords=list(map(str, prior_records)))
        if reused_baseline is not None:
            record['baselineReuse'] = dict(record=str(reuse_path), executable=str(reused_baseline),
                scope='successful-baseline-build-only', sourceResultStatus=previous['status'],
                sourceCompilerCommandAndDependenciesUnchanged=True)
        execution = VerificationExecution(ROOT, output, record, stable, sha)
        started, error, facts, timings = time.monotonic(), None, {}, []

        def run(command, name, limit):
            remaining = 180 - prior_seconds - (time.monotonic() - started)
            if remaining <= 0:
                raise ValueError('CALL_CONTEXT_CANDIDATE_TOTAL_BUDGET_EXHAUSTED')
            result = execution.run(list(map(str, command)), output / name, timeout=min(limit, remaining))
            if result.returncode != 0 or result.stderr:
                raise ValueError('CALL_CONTEXT_CANDIDATE_STEP_FAILED:' + name)
            return result

        def observation(result):
            return parse_observation(result.stdout, observation_kind)

        try:
            for variant in ('baseline', 'candidate'):
                dependencies = [candidate if p == baseline and variant == 'candidate' else p for p in closure]
                executable = reused_baseline if variant == 'baseline' and reused_baseline is not None else output / (variant + '.exe')
                if variant != 'baseline' or reused_baseline is None:
                    run([compiler, 'build', observer, *dependencies, '-o', executable,
                        '--target', 'windows-x64', '--llvm', llvm, '--jobs', '1', '-O1', '--keep-temps'],
                        variant + '-build', 90)
                for index, source in enumerate(controls):
                    _, rows = observation(run([executable, source], variant + f'-control{index}', 10))
                    facts[(variant, index)] = rows
                    if variant == 'candidate':
                        if facts[('baseline', index)] != rows:
                            raise ValueError('CALL_CONTEXT_CANDIDATE_EXACT_FACT_MISMATCH:' + str(source))
                        record['cases'].append(dict(id=source.stem, passed=True,
                            factRows=len(rows.splitlines()), factSha256=hashlib.sha256(rows.encode()).hexdigest().upper()))
                        record['completed'] += 1
                        execution.save()
            scaling_facts = None
            for index, variant in enumerate(plan['performanceRunOrder']):
                executable = reused_baseline if variant == 'baseline' and reused_baseline is not None else output / (variant + '.exe')
                duration, rows = observation(run([executable, scaling, *scaling_arguments],
                    f'scaling-{index}-{variant}', scaling_limit))
                if scaling_facts is None:
                    scaling_facts = rows
                if rows != scaling_facts:
                    raise ValueError('CALL_CONTEXT_CANDIDATE_SCALING_FACT_MISMATCH')
                timings.append(dict(variant=variant, initialCoreMilliseconds=duration[0],
                    completionMilliseconds=duration[1]))
            record.update(scalingFactRows=len(scaling_facts.splitlines()), timings=timings,
                scalingFactSha256=hashlib.sha256(scaling_facts.encode()).hexdigest().upper())
            base = [row['completionMilliseconds'] for row in timings if row['variant'] == 'baseline']
            selected = [row['completionMilliseconds'] for row in timings if row['variant'] == 'candidate']
            record['promotionSupported'] = max(selected) < min(base) and min(base) > 0
            record['cases'].extend([dict(id='scaling-exact-facts', passed=True),
                dict(id='same-condition-measurement', passed=True, promotionSupported=record['promotionSupported'])])
            record['completed'] += 2
            record['status'] = 'passed'
        except BaseException as caught:
            error = caught
        finally:
            execution.finalize(error, cleanup=error is None)
        print(json.dumps({k: record.get(k) for k in ('status', 'completed', 'total',
            'timings', 'promotionSupported', 'inputsStable', 'processesStopped')}))
        if error:
            raise error


if __name__ == '__main__':
    main()
