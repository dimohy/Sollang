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

from completed_artifact_plan import initialize_output, cleanup_output, assert_output_shutdown
from verification_execution import VerificationExecution


def sha(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest().upper()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding='utf-8-sig'))


def is_collectable_failure(exit_code: int, inner: dict, scope: str, case_id: str) -> bool:
    """Only a completed, closed single-case runner failure may be collected."""
    cases = inner.get('cases')
    return (exit_code == 1 and inner.get('status') == 'failed'
            and inner.get('verificationScope', 'regression') == scope
            and inner.get('completed') == 1 and inner.get('total') == 1
            and inner.get('inputsStable') is True and inner.get('processesStopped') is True
            and isinstance(cases, list) and len(cases) == 1
            and cases[0].get('id') == case_id and cases[0].get('status') == 'failed')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preflight', required=True, type=Path)
    parser.add_argument('--runner', required=True, type=Path)
    parser.add_argument('--compiler', required=True, type=Path)
    parser.add_argument('--selfhost-driver-build', required=True, type=Path)
    parser.add_argument('--selfhost-production-root', type=Path,
                        help='Explicit source root of the reused product when fixtures are a frozen snapshot')
    parser.add_argument('--fixture-root', type=Path,
                        help='Frozen fixture tree hosting the runner; artifact ownership remains with this repository')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--source-closure-result', type=Path,
                        help='Fresh receipt under repository artifacts; allows case outputs on another approved volume')
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--exact', action='append', default=[])
    selection.add_argument('--selection-file', type=Path,
                           help='JSON selectedCatalog subset; preserves preflight order')
    parser.add_argument('--continue-on-assertion-failure', action='store_true',
                        help='Collect completed closed failures; any failure still makes this run fail')
    parser.add_argument('--managed-reference', action='store_true')
    parser.add_argument('--stage-baselines', type=Path,
                        help='Stage non-mutating linked LLVM candidates after runtime/reference checks; not regression acceptance')
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--case-budget-seconds', type=int)
    parser.add_argument('--total-budget-seconds', type=int)
    parser.add_argument('--reusable-compiler-directory', type=Path, action='append',
                        help='Explicit retained compiler roots for initialization and cleanup; maximum three')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    fixture_repo = args.fixture_root.resolve() if args.fixture_root is not None else repo
    proof_path, runner, compiler, driver, output = (
        path.resolve() for path in (args.preflight, args.runner, args.compiler,
                                   args.selfhost_driver_build, args.output))
    # Preserve path components for the lifecycle's reparse-point validation.
    reusable = ([path.absolute() for path in args.reusable_compiler_directory]
                if args.reusable_compiler_directory is not None else None)
    closure_result = (args.source_closure_result or output / 'source-closure.json').resolve()
    proof = read(proof_path)
    if args.fixture_root is not None:
        fixture_pins = proof.get('fixtureInputHashes', {})
        runner_root = next((parent for parent in runner.parents
                            if (parent / 'Sollang.slnx').is_file()), None)
        if (not fixture_pins or not (fixture_repo / 'Sollang.slnx').is_file()
                or any(not Path(path).is_relative_to(fixture_repo) for path in fixture_pins)
                or runner_root != fixture_repo):
            raise ValueError('CATALOG_FIXTURE_ROOT_MISMATCH')
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
    selection_path = args.selection_file.resolve() if args.selection_file is not None else None
    selected = read(selection_path).get('selectedCatalog') if selection_path is not None else args.exact
    if selection_path is not None or selected:
        if (not isinstance(selected, list) or not selected
                or any(not isinstance(name, str) for name in selected)
                or len(set(selected)) != len(selected) or not set(selected).issubset(ids)):
            raise ValueError('CATALOG_EXACT_SELECTION_INVALID')
        selected_ids = set(selected)
        rows = [row for row in rows if row['id'] in selected_ids]
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
    if selection_path is not None:
        pins[str(selection_path)] = sha(selection_path)
    if candidate_plan is not None:
        pins[str(candidate_plan)] = sha(candidate_plan)
    closure_tool = fixture_repo / 'scripts/update-example-source-manifests.ps1'
    for path in (proof_path, runner, compiler, Path(__file__).resolve(),
                 repo / 'scripts/verification_execution.py',
                 repo / 'scripts/completed_artifact_plan.py', closure_tool,
                 fixture_repo / 'scripts/source-module-header.ps1',
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
    initialize_output(repo, output, reusable_directories=reusable)
    output.mkdir(parents=True)
    result = dict(status='prepared', verificationScope=scope,
                  completed=0, attempted=0, failedCases=[], total=len(rows), fullCatalogTotal=len(ids),
                  selectedCatalog=[row['id'] for row in rows],
                  sourceManifests=[str(path) for row in rows
                                   if not row['requiresSelfHostCompiler']
                                   and not row['id'].startswith('diagnostic/')
                                   and (path := fixture_repo / 'examples/regression/expected'
                                        / (row['id'] + '.sources.txt')).is_file()],
                  compiler=str(compiler), runner=str(runner), selfHostDriverBuild=str(driver),
                  fixtureRoot=str(fixture_repo), artifactRepositoryRoot=str(repo),
                  selfHostProductionRoot=str(args.selfhost_production_root.resolve())
                      if args.selfhost_production_root is not None else None,
                  managedReference=args.managed_reference,
                  inputHashes=pins, inputsStable=True, processesStopped=True, cases=[],
                  retryPolicy='no-automatic-retry', executionOrder='sequential',
                  continueOnAssertionFailure=args.continue_on_assertion_failure,
                  caseBudgetSeconds=args.case_budget_seconds,
                  totalBudgetSeconds=args.total_budget_seconds)
    if reusable is not None:
        result['reusableCompilerDirectories'] = [str(path) for path in reusable]
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
                if args.selfhost_production_root is not None:
                    command.extend(['--selfhost-production-root',
                                    str(args.selfhost_production_root.resolve())])
            case_result = dict(status='running', verificationScope=scope, completed=0, total=1,
                               cases=[dict(id=row['id'], status='running', expectedBuildExit=0)])
            execution = VerificationExecution(repo, case_root, case_result, stable, sha)
            error = None
            collect_failure = False
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
                    if not (args.continue_on_assertion_failure
                            and is_collectable_failure(exit_code, inner, scope, row['id'])):
                        raise ValueError('CATALOG_CASE_NOT_PASSED: ' + row['id'])
                    collect_failure = True
                    error = ValueError('CATALOG_CASE_NOT_PASSED: ' + row['id'])
                case_result.update(status='failed' if collect_failure else 'passed', completed=1,
                                   authoritativeRunnerResult=str(inner_path),
                                   authoritativeRunnerResultSha256=sha(inner_path))
                case_result['cases'][0].update(status='failed' if collect_failure else 'passed',
                                             buildExit=exit_code)
                # The C# result owns this nested output tree. Cleaning only the
                # supervisor deliberately leaves nested owners untouched.
                if not collect_failure:
                    cleanup_output(repo, inner_path.parent, execute=True,
                                   reusable_directories=reusable)
            except BaseException as caught:
                error = caught
                raise
            finally:
                execution.finalize(error, cleanup=False)
                try:
                    if (case_result['status'] == 'passed' and case_result['inputsStable']
                            and case_result['processesStopped']):
                        assert_output_shutdown(repo, case_root)
                        cleanup_output(repo, case_root, execute=True,
                                       reusable_directories=reusable)
                except BaseException as cleanup_error:
                    case_result.update(status='failed',
                                       failure=f'{type(cleanup_error).__name__}: {cleanup_error}')
                    execution.save()
                    raise
                finally:
                    case.update(status=case_result['status'],
                                inputsStable=case_result['inputsStable'],
                                processesStopped=case_result['processesStopped'])
                    result['attempted'] = sum(item['status'] != 'running' for item in result['cases'])
                    save()
            if (collect_failure and case_result['status'] == 'failed'
                    and case_result['inputsStable'] is True
                    and case_result['processesStopped'] is True):
                result['failedCases'].append(row['id'])
                save()
                continue
            if case_result['status'] != 'passed':
                raise ValueError('CATALOG_CASE_CLOSURE_FAILED: ' + row['id'])
            result['completed'] += 1
            save()
        if result['failedCases']:
            raise ValueError(f"CATALOG_ASSERTION_FAILURES_COLLECTED: {len(result['failedCases'])}")
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
