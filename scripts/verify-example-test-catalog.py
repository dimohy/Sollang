"""Execute a frozen ExampleTests catalog with owned, immediately closed case outputs.

The existing C# runner owns every oracle. This controller supplies process ownership,
durable case results, and the existing artifact lifecycle; it never bootstraps a compiler.
Preparation is the default. Execution requires an explicit case and total time budget.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from verification_json_records import write_json_atomic
import shutil
import subprocess
import time
from pathlib import Path

from completed_artifact_plan import initialize_output, cleanup_output
from verification_execution import VerificationExecution


def sha(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest().upper()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding='utf-8-sig'))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preflight', required=True, type=Path)
    parser.add_argument('--runner', required=True, type=Path)
    parser.add_argument('--compiler', required=True, type=Path)
    parser.add_argument('--selfhost-driver-build', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--source-closure-result', type=Path,
                        help='Fresh receipt under repository artifacts; allows case outputs on another approved volume')
    parser.add_argument('--exact', action='append', default=[])
    parser.add_argument('--managed-reference', action='store_true')
    parser.add_argument('--stage-baselines', type=Path,
                        help='Stage non-mutating linked LLVM candidates after runtime/reference checks; not regression acceptance')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--case-budget-seconds', type=int)
    parser.add_argument('--total-budget-seconds', type=int)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    proof_path, runner, compiler, driver, output = (
        path.resolve() for path in (args.preflight, args.runner, args.compiler,
                                   args.selfhost_driver_build, args.output))
    closure_result = (args.source_closure_result or output / 'source-closure.json').resolve()
    proof = read(proof_path)
    if (proof.get('status') != 'validated' or proof.get('completed') != 0
            or proof.get('verificationScope', 'regression') != 'regression'
            or proof.get('inputsStable') is not True or proof.get('processesStopped') is not True
            or proof.get('target') != 'windows-x64'):
        raise ValueError('CATALOG_PREFLIGHT_NOT_VALIDATED')
    rows = proof.get('cases', [])
    ids = [row['id'] for row in rows]
    if (not ids or len(ids) != proof.get('total') or len(set(ids)) != len(ids)
            or any(type(row.get('requiresSelfHostCompiler')) is not bool for row in rows)):
        raise ValueError('CATALOG_SELECTION_INVALID')
    if args.exact:
        if len(set(args.exact)) != len(args.exact) or not set(args.exact).issubset(ids):
            raise ValueError('CATALOG_EXACT_SELECTION_INVALID')
        rows = [row for row in rows if row['id'] in args.exact]
    scope = 'regression'
    candidate_plan = None
    if args.stage_baselines is not None:
        if not args.managed_reference:
            raise ValueError('BASELINE_CANDIDATES_REQUIRE_MANAGED_REFERENCE')
        candidate_plan = args.stage_baselines.resolve()
        plan = read(candidate_plan)
        candidates = plan.get('candidates', [])
        if (plan.get('schemaVersion') != 1 or not candidates
                or len(candidates) != len(set(candidates)) or not set(candidates).issubset(ids)):
            raise ValueError('BASELINE_CANDIDATE_SCOPE_INVALID')
        rows = [row for row in rows if row['id'] in candidates]
        if not rows:
            raise ValueError('BASELINE_CANDIDATE_SELECTION_EMPTY')
        scope = 'linked-llvm-baseline-candidates'
    if args.managed_reference != (compiler.suffix.lower() == '.dll'):
        raise ValueError('CATALOG_REFERENCE_MODE_MISMATCH')
    dotnet = shutil.which('dotnet')
    if dotnet is None or not runner.is_file() or not compiler.is_file():
        raise ValueError('CATALOG_EXECUTOR_MISSING')
    pins = dict(proof['inputHashes'])
    if candidate_plan is not None:
        pins[str(candidate_plan)] = sha(candidate_plan)
    closure_tool = repo / 'scripts/update-example-source-manifests.ps1'
    for path in (proof_path, runner, compiler, Path(__file__).resolve(),
                 repo / 'scripts/verification_execution.py',
                 repo / 'scripts/completed_artifact_plan.py', closure_tool,
                 repo / 'scripts/source-module-header.ps1',
                 repo / 'scripts/verification_json_records.py'):
        pins[str(path)] = sha(path)

    def stable() -> bool:
        return all(Path(path).is_file() and sha(Path(path)) == value.upper()
                   for path, value in pins.items())

    if not stable():
        raise ValueError('CATALOG_PREFLIGHT_INPUT_DRIFT')
    if args.execute and (not args.case_budget_seconds or not args.total_budget_seconds
                         or args.case_budget_seconds <= 0 or args.total_budget_seconds <= 0):
        raise ValueError('CATALOG_EXECUTION_BUDGET_REQUIRED')
    if output.exists():
        raise ValueError('CATALOG_OUTPUT_ALREADY_EXISTS')
    initialize_output(repo, output)
    output.mkdir(parents=True)
    result = dict(status='prepared', verificationScope=scope,
                  completed=0, total=len(rows), fullCatalogTotal=len(ids),
                  selectedCatalog=[row['id'] for row in rows],
                  sourceManifests=[str(path) for row in rows
                                   if not row['requiresSelfHostCompiler']
                                   and not row['id'].startswith('diagnostic/')
                                   and (path := repo / 'examples/regression/expected'
                                        / (row['id'] + '.sources.txt')).is_file()],
                  compiler=str(compiler), runner=str(runner), selfHostDriverBuild=str(driver),
                  managedReference=args.managed_reference,
                  inputHashes=pins, inputsStable=True, processesStopped=True, cases=[],
                  retryPolicy='no-automatic-retry', executionOrder='sequential',
                  caseBudgetSeconds=args.case_budget_seconds,
                  totalBudgetSeconds=args.total_budget_seconds)
    record = output / 'result.json'

    def save() -> None:
        write_json_atomic(record, result)

    save()
    # The input-only C# catalog proves file identity. Check actual compiler
    # provider closure separately before any fixture compilation; never repair
    # sources or bootstrap products as a side effect of verification.
    preflight_execution = VerificationExecution(repo, output, result, stable, sha)
    preflight_error = None
    try:
        if result['sourceManifests']:
            result['sourceClosureResult'] = str(closure_result)
            pwsh = shutil.which('pwsh')
            if pwsh is None:
                raise ValueError('CATALOG_SOURCE_CLOSURE_EXECUTOR_MISSING')
            checked = preflight_execution.run(
                [pwsh, '-NoProfile', '-File', str(closure_tool), '-Mode', 'Check',
                 '-SelectionFile', str(record), '-ResultPath', str(closure_result)],
                output / 'source-closure', timeout=30)
            if checked.returncode != 0:
                raise ValueError('CATALOG_SOURCE_CLOSURE_NOT_CURRENT')
            result['sourceClosureResultSha256'] = sha(closure_result)
    except BaseException as error:
        preflight_error = error
        raise
    finally:
        preflight_execution.finalize(preflight_error, cleanup=False)
    if not args.execute:
        return
    result['status'] = 'running'
    started = time.monotonic()
    try:
        for row in rows:
            remaining = args.total_budget_seconds - (time.monotonic() - started)
            if remaining <= 0:
                raise ValueError('CATALOG_TOTAL_BUDGET_EXHAUSTED')
            case_root = output / 'cases' / hashlib.sha256(row['id'].encode()).hexdigest()[:20]
            case_root.mkdir(parents=True)
            inner_path = case_root / 'runner/result.json'
            case = dict(id=row['id'], status='running', resultPath=str(inner_path))
            result['cases'].append(case)
            save()
            command = [dotnet, str(runner), '--compiler', str(compiler), '--skip-bootstrap',
                       '--suite', 'full', '--target', 'windows-x64', '--jobs', '1',
                       '--output-directory', str(inner_path.parent), '--exact', row['id']]
            if args.managed_reference:
                command.append('--compare-compilers')
            if candidate_plan is not None:
                command.extend(['--stage-linked-llvm-baselines', str(candidate_plan)])
            if row['requiresSelfHostCompiler']:
                command.extend(['--selfhost-driver-build', str(driver)])
            case_result = dict(status='running', verificationScope=scope, completed=0, total=1,
                               cases=[dict(id=row['id'], status='running', expectedBuildExit=0)])
            execution = VerificationExecution(repo, case_root, case_result, stable, sha)
            error = None
            try:
                exit_code = execution.run(command, case_root / 'execution',
                                          timeout=min(args.case_budget_seconds, remaining)).returncode
                if not inner_path.is_file():
                    raise ValueError('CATALOG_RUNNER_RESULT_MISSING: ' + row['id']
                                     + f' (exit={exit_code}); child diagnostic: '
                                     + str(case_root / 'execution.stderr'))
                inner = read(inner_path)
                if (exit_code != 0 or inner.get('status') != 'passed'
                        or inner.get('verificationScope', 'regression') != scope
                        or inner.get('completed') != 1 or inner.get('total') != 1
                        or inner.get('inputsStable') is not True
                        or inner.get('processesStopped') is not True
                        or [item['id'] for item in inner['cases']] != [row['id']]):
                    raise ValueError('CATALOG_CASE_NOT_PASSED: ' + row['id'])
                case_result.update(status='passed', completed=1,
                                   authoritativeRunnerResult=str(inner_path),
                                   authoritativeRunnerResultSha256=sha(inner_path))
                case_result['cases'][0].update(status='passed', buildExit=0)
                # The C# result owns this nested output tree. Cleaning only the
                # supervisor deliberately leaves nested owners untouched.
                cleanup_output(repo, inner_path.parent, execute=True)
            except BaseException as caught:
                error = caught
                raise
            finally:
                execution.finalize(error, cleanup=True)
                case.update(status=case_result['status'],
                            processesStopped=case_result['processesStopped'])
                save()
            if case_result['status'] != 'passed':
                raise ValueError('CATALOG_CASE_CLOSURE_FAILED: ' + row['id'])
            result['completed'] += 1
            save()
        result['status'] = 'passed'
    except BaseException as error:
        result.update(status='canceled' if isinstance(error, KeyboardInterrupt)
                      else 'timed-out' if isinstance(error, subprocess.TimeoutExpired) else 'failed',
                      failure=f'{type(error).__name__}: {error}')
        raise
    finally:
        result['inputsStable'] = stable()
        result['processesStopped'] = (all(row.get('processesStopped') is True
                                         for row in result['cases'])
                                      and all(row.get('shutdownConfirmed') is True
                                              for row in result['processes']))
        if not result['inputsStable'] or not result['processesStopped']:
            result['status'] = 'failed'
        save()


if __name__ == '__main__':
    main()
