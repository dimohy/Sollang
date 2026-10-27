"""Plan cleanup of verified outputs. Deletion is performed by the native PowerShell executor."""
from __future__ import annotations

import argparse
import collections
import copy
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import shutil
import time

POLICY = Path(__file__).parent / 'contracts/artifact-lifecycle.json'
GENERATED = re.compile(r'\.(?:ll|bc\d*|obj|o|exe|dll|pdb|lib|a|wasm)$', re.I)


def load_policy() -> dict:
    policy = json.loads(POLICY.read_text(encoding='utf-8'))
    if policy['schemaVersion'] != 1 or policy['maximumReusableCompilers'] != 3:
        raise ValueError('ARTIFACT_POLICY_INVALID')
    if policy.get('externalOutputRoot') != 'LOCALAPPDATA/Sollang' or len(policy.get('reusableCompilers', [])) > 3:
        raise ValueError('ARTIFACT_POLICY_INVALID')
    if policy.get('ownedGeneratedDirectoryKinds') != ['private-cache', 'partition-temporary']:
        raise ValueError('ARTIFACT_POLICY_INVALID')
    return policy


def initialize_output(repo: Path, output: Path, *, reusable_directories: list[Path] | None = None) -> None:
    load_policy()
    assert_artifact_path(repo, output)
    declared = default_reusable_directories(repo) if reusable_directories is None else reusable_directories
    if len({str(assert_artifact_path(repo, Path(p))) for p in declared}) > load_policy()['maximumReusableCompilers']:
        raise ValueError('ARTIFACT_REUSABLE_COMPILER_LIMIT_EXCEEDED')
    if shutil.which('pwsh') is None or not (Path(__file__).parent / 'Invoke-CompletedArtifactCleanup.ps1').is_file():
        raise ValueError('ARTIFACT_CLEANUP_EXECUTOR_MISSING')
    ensure_compiler_capacity(repo, output, declared)


def assert_build_space(output: Path) -> None:
    """Check the actual output volume before starting a costly compiler build."""
    location = output.resolve()
    while not location.exists():
        location = location.parent
    if shutil.disk_usage(location).free < load_policy()['minimumFreeBytesBeforeCompilerBuild']:
        raise ValueError('ARTIFACT_BUILD_SPACE_INSUFFICIENT')


def compiler_capacity_inventory(repo: Path, root: Path, output: Path, reusable: list[Path],
                                *, active: set[str] | None = None) -> list[dict]:
    """Count verified reusable products; retained failures are protected, not reusable."""
    root = assert_artifact_path(repo, root, allow_root=True)
    output = assert_artifact_path(repo, output)
    active = windows_active_directories(root) if active is None else active
    declared = {str(assert_artifact_path(repo, path)).casefold() for path in reusable}
    rows = []
    products = [path for path in sorted(root.iterdir()) if (path / 'compiler.exe').exists()]
    product_paths = {str(path).casefold() for path in products}
    for path in reusable:
        if str(path).casefold() not in product_paths and path != output:
            raise ValueError('ARTIFACT_CAPACITY_DECLARED_PRODUCT_MISSING: ' + str(path))
    for directory in products:
        directory = assert_artifact_path(repo, directory)
        binary = assert_artifact_path(repo, directory / 'compiler.exe')
        record_path = assert_artifact_path(repo, directory / 'result.json')
        if not binary.is_file() or not record_path.is_file():
            raise ValueError('ARTIFACT_CAPACITY_PROTECTED_OR_UNVERIFIED: ' + str(directory))
        try:
            record = json.loads(record_path.read_text(encoding='utf-8-sig'))
        except (OSError, ValueError) as error:
            raise ValueError('ARTIFACT_CAPACITY_PROTECTED_OR_UNVERIFIED: ' + str(directory)) from error
        if not isinstance(record, dict) or active_record(record) or str(directory).casefold() in active:
            raise ValueError('ARTIFACT_CAPACITY_PROTECTED_OR_UNVERIFIED: ' + str(directory))
        expected = record.get('compilerSha256')
        if expected is None:
            artifacts = record.get('generatedArtifactHashes', [])
            artifacts = artifacts if isinstance(artifacts, list) else []
            matches = [row.get('sha256') for row in artifacts if isinstance(row, dict)
                       and isinstance(row.get('path'), str)
                       and str(Path(row['path'])).casefold() == str(binary).casefold()]
            if len(matches) == 1:
                expected = matches[0]
        if not isinstance(expected, str) or re.fullmatch(r'[0-9a-fA-F]{64}', expected) is None:
            raise ValueError('ARTIFACT_CAPACITY_BINARY_HASH_MISSING: ' + str(directory))
        if (hashlib.sha256(binary.read_bytes()).hexdigest().casefold() != expected.casefold()
                or binary.stat().st_mtime_ns > record_path.stat().st_mtime_ns):
            raise ValueError('ARTIFACT_CAPACITY_PRODUCT_CHANGED: ' + str(directory))
        if completed(record):
            if record.get('processesStopped', record.get('processShutdownConfirmed', True)) is not True:
                raise ValueError('ARTIFACT_CAPACITY_SHUTDOWN_UNCONFIRMED: ' + str(directory))
            category = 'reusable'
        elif record.get('status') in load_policy()['terminalRetentionStatuses']:
            if record.get('processesStopped', record.get('processShutdownConfirmed')) is not True:
                raise ValueError('ARTIFACT_CAPACITY_SHUTDOWN_UNCONFIRMED: ' + str(directory))
            if str(directory).casefold() in declared:
                raise ValueError('ARTIFACT_CAPACITY_RETAINED_NOT_REUSABLE: ' + str(directory))
            category = 'terminal-retained'
        else:
            raise ValueError('ARTIFACT_CAPACITY_PROTECTED_OR_UNVERIFIED: ' + str(directory))
        rows.append({'output': str(directory), 'category': category, 'recordStatus': record['status'],
                     'recordSha256': hashlib.sha256(record_path.read_bytes()).hexdigest(),
                     'compilerSha256': expected.casefold()})
    return rows


def ensure_compiler_capacity(repo: Path, output: Path, reusable: list[Path]) -> None:
    if os.name != 'nt' or not os.environ.get('LOCALAPPDATA'):
        return
    root = Path(os.path.abspath(os.environ['LOCALAPPDATA'])) / 'Sollang'
    if output.parent != root or output not in reusable or not root.is_dir():
        return
    inventory = compiler_capacity_inventory(repo, root, output, reusable)
    products = [Path(row['output']) for row in inventory if row['category'] == 'reusable']
    reserved = {str(p).casefold() for p in reusable}
    if len({str(p).casefold() for p in products} | reserved) > load_policy()['maximumReusableCompilers']:
        plan = create_plan(repo, root, 0, reusable_directories=reusable, retention_terminal=True)
        plan_path = Path(repo) / 'artifacts/scratch' / ('artifact-capacity-' + str(time.time_ns()) + '.json')
        plan_path.parent.mkdir(parents=True, exist_ok=True)
        plan_path.write_text(json.dumps(plan, indent=2)+'\n', encoding='utf-8')
        deleted = {str(Path(row['path'])).casefold() for row in plan['targets']}
        remaining = {str(p).casefold() for p in products if str(p / 'compiler.exe').casefold() not in deleted}
        if len(remaining | reserved) > load_policy()['maximumReusableCompilers']:
            raise ValueError('ARTIFACT_CAPACITY_PROTECTED_OR_UNVERIFIED: ' + str(plan_path))
        validate_plan(plan)
        subprocess.run([shutil.which('pwsh'), '-NoProfile', '-File', str(Path(__file__).parent / 'Invoke-CompletedArtifactCleanup.ps1'), '-Plan', str(plan_path), '-Execute'], check=True)
        actual = {row['output'].casefold() for row in compiler_capacity_inventory(repo, root, output, reusable)
                  if row['category'] == 'reusable'}
        if len(actual | reserved) > load_policy()['maximumReusableCompilers']:
            raise ValueError('ARTIFACT_CAPACITY_NOT_ESTABLISHED')
    assert_build_space(root)


def prepare_output(repo: Path, output: Path, *, keep_compiler: bool = False,
                   temporary_only: bool = False, retention_terminal: bool = False,
                   reusable_directories: list[Path] | None = None) -> Path:
    initialize_output(repo, output, reusable_directories=reusable_directories)
    output = assert_artifact_path(repo, output)
    reusable = reusable_directories
    if keep_compiler:
        reusable = list(reusable if reusable is not None else default_reusable_directories(repo))
        if output not in reusable:
            reusable.append(output)
    plan = create_plan(repo, output.parent, 0, selected_outputs={str(output)},
                       reusable_directories=reusable, retention_terminal=retention_terminal)
    if len(plan['completionRecords']) != 1:
        raise ValueError('ARTIFACT_COMPLETION_NOT_VERIFIED')
    if temporary_only:
        plan['targets'] = [r for r in plan['targets'] if any(part.endswith('.slg-tmp') for part in Path(r['path']).parts)]
        plan['directoryTargets'] = [r for r in plan['directoryTargets'] if any(part.endswith('.slg-tmp') for part in Path(r['path']).parts)]
        plan['directories'] = len(plan['directoryTargets'])
        plan['files'] = len(plan['targets'])
        plan['logicalBytes'] = sum(r['bytes'] for r in plan['targets'])
    plan_path = output / 'artifact-cleanup-plan.json'
    plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    return plan_path


def cleanup_output(repo: Path, output: Path, *, execute: bool = True, **options) -> Path:
    plan_path = prepare_output(repo, output, **options)
    command = [shutil.which('pwsh'), '-NoProfile', '-File', str(Path(__file__).parent / 'Invoke-CompletedArtifactCleanup.ps1'), '-Plan', str(plan_path)]
    if execute:
        command.append('-Execute')
    subprocess.run(command, check=True)
    return plan_path


def allowed_roots(repo: Path) -> list[Path]:
    load_policy()
    roots = [Path(os.path.abspath(repo)) / 'artifacts']
    if os.name == 'nt' and os.environ.get('LOCALAPPDATA'):
        roots.append(Path(os.path.abspath(os.environ['LOCALAPPDATA'])) / 'Sollang')
    return roots


def default_reusable_directories(repo: Path) -> list[Path]:
    policy = load_policy()
    if os.name != 'nt' or not os.environ.get('LOCALAPPDATA'):
        return []
    root = Path(os.path.abspath(os.environ['LOCALAPPDATA'])) / 'Sollang'
    return [root / row['directory'] for row in policy.get('reusableCompilers', [])]


def reparse(path: Path) -> bool:
    return bool(getattr(path.lstat(), 'st_file_attributes', 0) & 0x400) or path.is_symlink()


def assert_artifact_path(repo: Path, path: Path, *, allow_root: bool = False) -> Path:
    repo = Path(os.path.abspath(repo))
    path = Path(os.path.abspath(path))
    if not any(root in path.parents or (allow_root and path == root) for root in allowed_roots(repo)):
        raise ValueError('ARTIFACT_PATH_OUTSIDE_ROOT')
    for parent in (path, *path.parents):
        if parent.exists() and reparse(parent):
            raise ValueError('ARTIFACT_REPARSE_POINT')
        if parent == repo:
            break
    return path


def expected_build_exit(record: dict, row: dict, *, default: int | None = 0) -> int | None:
    for path_text, digest in record.get('inputHashes', {}).items():
        path = Path(path_text)
        if path.suffix != '.json' or not path.is_file() or reparse(path):
            continue
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest().casefold() != str(digest).casefold():
            continue
        try:
            contract = json.loads(data)
        except ValueError:
            continue
        if not isinstance(contract, dict):
            continue
        for case in [*contract.get('cases', []), *contract.get('probeMatrix', [])]:
            if isinstance(case, dict) and case.get('id') == row.get('id'):
                for key in ('exit', 'expected_exit', 'expectedBuildExit', 'expectedExit'):
                    if type(case.get(key)) is int:
                        return case[key]
    return default


def expected_runtime_exit(record: dict, row: dict) -> int | None:
    """Nonzero runtime success requires a unique, unchanged input contract."""
    expected = set()
    for name, digest in record.get('inputHashes', {}).items():
        path = Path(name)
        if path.suffix != '.json' or not path.is_file() or reparse(path):
            continue
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest().casefold() != str(digest).casefold():
            continue
        try:
            contract = json.loads(data)
        except ValueError:
            continue
        if not isinstance(contract, dict) or not isinstance(contract.get('cases'), list):
            continue
        for case in contract['cases']:
            if isinstance(case, dict) and case.get('id') == row.get('id'):
                value = case.get('expectedRuntimeExit')
                if type(value) is int:
                    expected.add(value)
                elif 'expectedRuntimeExit' in case:
                    return None
    return next(iter(expected)) if len(expected) == 1 else (0 if not expected else None)


def runtime_exit_matches(actual, expected: int | None) -> bool:
    if type(actual) is not int or expected is None:
        return False
    # Python and PowerShell expose the same Windows DWORD with different signs.
    return actual == expected or (-2**31 <= expected < 0 and actual == expected + 2**32)


def step_values(value) -> list | None:
    if isinstance(value, dict):
        return list(value.values())
    if isinstance(value, list):
        return value
    return None


def failed_steps(value, expected: dict | None = None) -> bool:
    values = step_values(value)
    if values is None:
        return True
    expected = expected or {}
    return any(failed_step(step, expected.get(step.get('id'), 0) if isinstance(step, dict) else 0) for step in values)


def failed_step(value, expected_exit: int = 0) -> bool:
    if type(value) is int:
        return value != expected_exit
    if isinstance(value, list):
        return failed_steps(value)
    if isinstance(value, dict):
        if any(k in value and (type(value[k]) is not int or value[k] != expected_exit) for k in ('exitCode', 'exit')):
            return True
        if any(value.get(k) for k in ('failureId', 'failureIds', 'timeout', 'timedOut', 'cancelled', 'canceled')):
            return True
        status = value.get('status', 'passed')
        if status not in ('passed', 'skipped', 'exited') or (status == 'exited' and 'exit' not in value and 'exitCode' not in value):
            return True
        return failed_steps(value.get('steps', {}))
    return value not in ('passed', 'skipped')


def active_record(record) -> bool:
    if isinstance(record, list):
        return any(active_record(row) for row in record)
    if not isinstance(record, dict):
        return False
    if record.get('status') == 'running' or any(record.get(k) for k in ('activeProcess', 'activeProcessIds', 'running', 'orphanProcessIds')):
        return True
    steps = step_values(record.get('steps', {}))
    cases = step_values(record.get('cases', []))
    return any(active_record(row) for row in (steps or []) + (cases or []))


def preflight_step_expectations(record: dict) -> dict | None:
    contract = load_policy()['semanticPreflight']
    if record.get('scope') not in (contract['scope'], contract['controlsScope']):
        return {}
    verifier = Path(__file__).resolve().parents[1] / contract['verifier']
    inputs = record.get('inputHashes', {})
    if not verifier.is_file() or str(inputs.get(str(verifier), '')).casefold() != hashlib.sha256(verifier.read_bytes()).hexdigest():
        return None
    if str(inputs.get(str(POLICY.resolve()), '')).casefold() != hashlib.sha256(POLICY.read_bytes()).hexdigest():
        return None
    cases = record.get('cases')
    controls_only = record['scope'] == contract['controlsScope']
    expected_cases = {k:v for k,v in contract['expectedCases'].items() if not (controls_only and k == 'focused-selfhost')}
    if not isinstance(cases, list) or record.get('completed') != len(expected_cases) or record.get('total') != len(expected_cases) or len(cases) != len(expected_cases):
        return None
    if any(not isinstance(row, dict) for row in cases) or {row.get('id') for row in cases} != set(expected_cases):
        return None
    if any(row.get('passed') is not True or type(row.get('exit')) is not int or row['exit'] != expected_cases[row['id']] for row in cases):
        return None
    steps = step_values(record.get('steps'))
    expected_steps = {k:v for k,v in contract['expectedSteps'].items()
                      if not (controls_only and k in contract['fullScopeOnlySteps'])}
    if not controls_only:
        formatting = record.get('formatPreflight')
        if (not isinstance(formatting, dict) or formatting.get('status') != 'passed'
                or type(formatting.get('exit')) is not int or formatting['exit'] != 0
                or formatting.get('codegenInvoked') is not False
                or type(formatting.get('sourceCount')) is not int or formatting['sourceCount'] <= 0):
            return None
    if steps is None or len(steps) != len(expected_steps) or any(not isinstance(row, dict) for row in steps) or {row.get('id') for row in steps} != set(expected_steps):
        return None
    return expected_steps


def completed(record: dict) -> bool:
    if active_record(record) or record.get('status') != 'passed' or any(record.get(k) for k in ('failure', 'failureId', 'error', 'failureIds', 'orphanProcessIds', 'activeProcess', 'activeProcessIds', 'running', 'timeout', 'timedOut', 'cancelled', 'canceled')):
        return False
    if 'exitCode' in record and record['exitCode'] != 0:
        return False
    expected_steps = preflight_step_expectations(record)
    if expected_steps is None or failed_steps(record.get('steps', {}), expected_steps):
        return False
    stable = record.get('inputsStable', record.get('inputStable'))
    if stable is not True:
        return False
    if 'inputFingerprint' in record and record.get('finalInputFingerprint', record['inputFingerprint']) != record['inputFingerprint']:
        return False
    if 'inputHashesStart' in record and record.get('inputHashesEnd') != record['inputHashesStart']:
        return False
    if 'total' in record:
        if type(record['total']) is not int or type(record.get('completed')) is not int or record['total'] <= 0 or record.get('completed') != record['total']:
            return False
    cases = record.get('cases', [])
    if isinstance(cases, dict):
        cases = list(cases.values())
    if not isinstance(cases, list):
        return False
    if 'cases' in record and 'total' in record and len(cases) != record['total']:
        return False
    for row in cases:
        if not isinstance(row, dict) or row.get('passed', row.get('status') == 'passed') is not True or row.get('status', 'passed') != 'passed':
            return False
        if failed_steps(row.get('steps', {})) or row.get('timeout') or row.get('timedOut'):
            return False
        expected_exit = expected_build_exit(record, row)
        runtime_expected = expected_runtime_exit(record, row)
        if runtime_expected is None or (runtime_expected != 0 and record.get('processesStopped') is not True):
            return False
        if any(row.get(k, 0) != 0 for k in ('exitCode',)) or any(k in row and not runtime_exit_matches(row[k], runtime_expected) and not (row[k] is None and expected_exit != 0 and runtime_expected == 0) for k in ('runExit', 'runExitCode')) or any(k in row and row[k] != expected_exit for k in ('buildExit', 'buildExitCode', 'compileExit')):
            return False
        if runtime_expected != 0 and not any(k in row for k in ('runExit', 'runExitCode')):
            return False
        if any(row.get(k) for k in ('activeProcess', 'activeProcessIds', 'running')):
            return False
        if row.get('failureId') or row.get('failureIds') or row.get('cancelled') or row.get('canceled') or row.get('orphanProcessIds'):
            return False
    return True


def windows_active_directories(root: Path) -> set[str]:
    # Read command lines only in memory; emit/store only derived paths, never credentials.
    if os.name != 'nt':
        return set()
    script = ("[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); "
              "Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,CommandLine | ConvertTo-Json -Compress")
    run = subprocess.run(['pwsh', '-NoProfile', '-Command', script], capture_output=True, check=True, encoding='utf-8')
    processes = json.loads(run.stdout)
    if isinstance(processes, dict):
        processes = [processes]
    excluded = {os.getpid()}
    parents = {p['ProcessId']: p['ParentProcessId'] for p in processes}
    cursor = os.getpid()
    while cursor in parents and parents[cursor] not in excluded:
        cursor = parents[cursor]
        excluded.add(cursor)
    pattern = re.compile(re.escape(str(root).replace('/', '\\').rstrip('\\')) + r'\\([^\\\s\"\x27;]+)', re.I)
    active = set()
    for process in processes:
        if process['ProcessId'] in excluded:
            continue
        for match in pattern.finditer((process.get('CommandLine') or '').replace('/', '\\')):
            active.add(str(root / match.group(1)).casefold())
    return active


def assert_output_shutdown(repo: Path, output: Path) -> None:
    output = assert_artifact_path(repo, output)
    if str(output).casefold() in windows_active_directories(output.parent):
        raise ValueError('ARTIFACT_OUTPUT_ACTIVE')


def has_nested_output_owner(path: Path, output: Path) -> bool:
    for parent in path.parents:
        if parent == output:
            return False
        if (parent / 'result.json').exists():
            return True
    return False


def generated_targets(repo: Path, directory: Path, preserve_compiler: bool) -> list[dict]:
    targets = []
    stack = [directory]
    while stack:
        parent = stack.pop()
        with os.scandir(parent) as entries:
            for entry in entries:
                path = Path(entry.path)
                st = entry.stat(follow_symlinks=False)
                if getattr(st, 'st_file_attributes', 0) & 0x400 or entry.is_symlink():
                    raise ValueError('ARTIFACT_REPARSE_POINT')
                if entry.is_dir(follow_symlinks=False):
                    # A nested result owns its subtree independently. A passed
                    # wrapper must not close the build's pending consumers.
                    if (path / 'result.json').exists():
                        continue
                    stack.append(path)
                    continue
                if st.st_nlink > 1:
                    raise ValueError('ARTIFACT_HARDLINK_SHARED')
                in_cache = '.sollang-cache' in path.parts
                if path.suffix.lower() in load_policy()['preservedExtensions']:
                    continue
                if not in_cache and not GENERATED.search(entry.name):
                    continue
                if preserve_compiler and (path == directory / 'compiler.exe' or in_cache):
                    continue
                assert_artifact_path(repo, path)
                targets.append({'path': str(path), 'bytes': st.st_size, 'modifiedNs': st.st_mtime_ns,
                                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'output': str(directory)})
    return targets


def owned_directory_targets(repo: Path, output: Path, files: list[dict], preserve_compiler: bool, temporary_only: bool) -> list[dict]:
    owned_files = {str(Path(row['path'])) for row in files}
    directories = []
    existing_files = []
    stack = [output]
    while stack:
        parent = stack.pop()
        for path in parent.iterdir():
            assert_artifact_path(repo, path)
            if path.is_dir():
                if (path / 'result.json').exists():
                    existing_files.append(path / 'result.json')
                    continue
                stack.append(path)
                directories.append(path)
            else:
                existing_files.append(path)
    planned = []
    for path in directories:
        relative = path.relative_to(output)
        in_cache = '.sollang-cache' in relative.parts
        in_temporary = any(part.endswith('.slg-tmp') for part in relative.parts)
        if not (in_cache or in_temporary) or (temporary_only and not in_temporary) or (preserve_compiler and in_cache):
            continue
        if any(path in file.parents and str(file) not in owned_files for file in existing_files):
            continue
        planned.append({'path': str(path), 'output': str(output), 'kind': 'private-cache' if in_cache else 'partition-temporary'})
    return sorted(planned, key=lambda row: (-len(Path(row['path']).parts), row['path']))


def linked_retention_evidence(repo: Path, output: Path, paths: list[Path], retention_terminal: bool, expected_compiler_sha: str | None = None) -> dict | None:
    binary = output / 'compiler.exe'
    if binary.exists() and (not binary.is_file() or reparse(binary)):
        return None
    digest = hashlib.sha256(binary.read_bytes()).hexdigest() if binary.exists() else expected_compiler_sha
    if not digest:
        return None
    for path in paths:
        path = assert_artifact_path(repo, path)
        record = json.loads(path.read_text(encoding='utf-8-sig'))
        if not isinstance(record, dict) or record.get('inputStable', record.get('inputsStable')) is not True:
            continue
        if record.get('inputHashesStart') != record.get('inputHashesEnd') or active_record(record):
            continue
        hashes = record.get('inputHashesStart', {})
        if not any(Path(k) == binary and str(v).casefold() == digest for k,v in hashes.items()):
            continue
        terminal = record.get('status') in load_policy()['terminalRetentionStatuses']
        if not completed(record) and not (retention_terminal and terminal):
            continue
        return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'compilerSha256': digest, 'recordStatus': record['status'], 'purpose': 'reusable-product-retirement-only'}
    return None


def terminal_consumer_process(repo: Path, output: Path, row: dict) -> bool:
    if not isinstance(row, dict) or active_record(row) or type(row.get('exit', row.get('exitCode'))) is not int:
        return False
    if row.get('status') in (None, 'exited', 'terminal'):
        return True
    # Supervised captures describe the process outcome as passed/failed. Accept
    # this form only with its durable journal and drained streams, never by label.
    if row.get('status') not in ('passed', 'failed') or row.get('schemaVersion') != 1 or row.get('processesStopped') is not True:
        return False
    if type(row.get('pid')) is not int or row['pid'] <= 0 or not row.get('startedAtUtc') or not row.get('finishedAtUtc'):
        return False
    if not isinstance(row.get('command'), list) or not row['command']:
        return False
    stdout = assert_artifact_path(repo, Path(row.get('stdoutPath', '')))
    stderr = assert_artifact_path(repo, Path(row.get('stderrPath', '')))
    output = output.resolve()
    if not stdout.is_relative_to(output) or not stderr.is_relative_to(output) or not stdout.is_file() or not stderr.is_file():
        return False
    if not str(stdout).endswith('.stdout.log') or str(stderr) != str(stdout)[:-len('.stdout.log')] + '.stderr.log':
        return False
    journal = assert_artifact_path(repo, Path(str(stdout)[:-len('.stdout.log')]))
    if not journal.is_file():
        return False
    persisted = json.loads(journal.read_text(encoding='utf-8-sig'))
    compared = dict(row)
    # Older PowerShell readers deserialize ISO timestamps into local DateTime
    # values. Require the same aware instant, preserving every other field.
    for key in ('startedAtUtc', 'finishedAtUtc'):
        for record in (persisted, compared):
            value = dt.datetime.fromisoformat(record[key])
            if value.tzinfo is None:
                return False
            record[key] = value.astimezone(dt.timezone.utc).isoformat()
    return persisted == compared



def legacy_paired_processes(repo: Path, path: Path, record: dict, compiler: Path) -> list[dict] | None:
    """Read existing paired-runner journals for retirement only; do not rewrite receipts."""
    if ('processes' in record or 'cases' in record
            or record.get('schemaVersion') != 1 or record.get('status') != 'passed'
            or record.get('inputStable') is not True
            or type(record.get('total')) is not int or record['total'] <= 0
            or record.get('completed') != record['total']
            or not isinstance(record.get('inputHashesStart'), dict) or not record['inputHashesStart']
            or record.get('inputHashesStart') != record.get('inputHashesEnd')
            or not isinstance(record.get('runs'), list) or not record['runs']):
        return None
    processes = []
    for journal in sorted(path.parent.glob('*.execution.json')):
        if journal.name == 'artifact-cleanup-plan.json.execution.json':
            continue
        try:
            assert_artifact_path(repo, journal)
            capture = json.loads(journal.read_text(encoding='utf-8-sig'))
            # A known nonzero exit also ends a consumer's lease. This bridge
            # grants no case credit; runtime traps remain original observations.
            if (capture.get('status') not in ('passed', 'failed')
                    or type(capture.get('exit')) is not int
                    or (capture['exit'] == 0) != (capture['status'] == 'passed')
                    or not terminal_consumer_process(repo, path.parent, capture)):
                return None
        except (OSError, ValueError, KeyError, TypeError):
            return None
        processes.append(capture)
    if not any(capture['command'][:2] == [str(compiler), 'build'] for capture in processes):
        return None
    return processes


def canceled_consumer_shutdown(repo: Path, path: Path, record: dict) -> dict:
    """Accept an audited stopped cancellation for retirement, never completion."""
    reference = record.get('processShutdownAuditReference')
    if not isinstance(reference, str) or not reference:
        raise ValueError('ARTIFACT_CANCELED_CONSUMER_AUDIT_MISSING')
    audit_path = assert_artifact_path(repo, repo / reference)
    if audit_path.parent != path.parent or not audit_path.is_file():
        raise ValueError('ARTIFACT_CANCELED_CONSUMER_AUDIT_BOUNDARY_INVALID')
    audit = json.loads(audit_path.read_text(encoding='utf-8-sig'))
    processes = record.get('processes')
    if (audit.get('schemaVersion') != 1 or audit.get('rootExists') is not False
            or audit.get('activeOwnedProcesses') != []
            or type(audit.get('toolSessionTerminalExit')) is not int
            or audit['toolSessionTerminalExit'] == 0
            or type(audit.get('rootPid')) is not int or audit['rootPid'] <= 0
            or not isinstance(processes, list) or not processes
            or record.get('completed') != 0 or type(record.get('total')) is not int
            or record['total'] <= 0 or record.get('cases') != []):
        raise ValueError('ARTIFACT_CANCELED_CONSUMER_AUDIT_INVALID')
    roots = [row for row in processes if isinstance(row, dict) and row.get('pid') == audit['rootPid']]
    if len(roots) != 1:
        raise ValueError('ARTIFACT_CANCELED_CONSUMER_ROOT_MISMATCH')
    root = roots[0]
    if (root.get('shutdownConfirmed') is not True or root.get('shutdownScope') != 'owned-windows-job'
            or not isinstance(root.get('command'), list) or not root['command']):
        raise ValueError('ARTIFACT_CANCELED_CONSUMER_SHUTDOWN_MISSING')
    try:
        started = dt.datetime.fromisoformat(root['startedAtUtc'])
        observed = dt.datetime.fromisoformat(audit['observedAtUtc'])
        stopped = dt.datetime.fromisoformat(root['shutdownObservedAtUtc'])
        if any(value.tzinfo is None for value in (started, observed, stopped)) or not started <= observed == stopped:
            raise ValueError()
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError('ARTIFACT_CANCELED_CONSUMER_TIME_INVALID') from error
    if not all(row is root or terminal_consumer_process(repo, path.parent, row) for row in processes):
        raise ValueError('ARTIFACT_CANCELED_CONSUMER_PROCESS_NOT_TERMINAL')
    assert_output_shutdown(repo, path.parent)
    return {'path': str(audit_path), 'sha256': hashlib.sha256(audit_path.read_bytes()).hexdigest()}


def recovered_interruption_shutdown(repo: Path, path: Path, record: dict) -> dict | None:
    """Authenticate canonical recovery bytes for retirement, never acceptance."""
    if record.get('status') != 'canceled' or 'cancellationShutdownEvidence' not in record:
        return None
    audit_path = assert_artifact_path(repo, path.with_name('interrupt-shutdown-result.json'))
    original_path = assert_artifact_path(repo, path.with_name('interrupted-running-result.json'))
    if (record['cancellationShutdownEvidence'] != str(audit_path)
            or not audit_path.is_file() or not original_path.is_file()):
        raise ValueError('ARTIFACT_RECOVERED_INTERRUPTION_FILES_INVALID')
    original_bytes = original_path.read_bytes()
    original = json.loads(original_bytes)
    audit = json.loads(audit_path.read_text(encoding='utf-8-sig'))
    processes, cases = original.get('processes'), original.get('cases')
    done, total = original.get('completed'), original.get('total')
    if (original.get('status') != 'running' or type(done) is not int or type(total) is not int
            or not 0 <= done < total or not isinstance(processes, list) or not processes
            or any(not isinstance(row, dict) or type(row.get('pid')) is not int or row['pid'] <= 0 for row in processes)
            or original.get('claimsGoalComplete') is True or original.get('claimsAcceptancePassed') is True
            or (cases is None and done != 0)
            or (cases is not None and (not isinstance(cases, list) or len(cases) != done + 1
                or not all(isinstance(case, dict) and case.get('status') == 'passed'
                           and case.get('passed') is True for case in cases[:-1])
                or not isinstance(cases[-1], dict) or cases[-1].get('status') != 'running'
                or cases[-1].get('passed') is not False))):
        raise ValueError('ARTIFACT_RECOVERED_INTERRUPTION_ORIGINAL_INVALID')
    if (audit.get('schemaVersion') != 1 or audit.get('status') != 'shutdown-confirmed'
            or audit.get('activeProcessIds') != [] or type(audit.get('inputsStable')) is not bool
            or audit.get('originalResultSha256', '').casefold() != hashlib.sha256(original_bytes).hexdigest()
            or audit.get('processIds') != [row['pid'] for row in processes]
            or audit.get('exitCodesUnavailable') != [row['pid'] for row in processes if row.get('exit') is None]
            or audit.get('outputDisposition') != 'preserve-canceled-unverified-output'
            or not isinstance(audit.get('reason'), str) or not audit['reason']):
        raise ValueError('ARTIFACT_RECOVERED_INTERRUPTION_AUDIT_INVALID')
    expected = copy.deepcopy(original)
    expected.update(status='canceled', inputsStable=audit['inputsStable'], processesStopped=True,
                    cancellationReason=audit['reason'], cancellationShutdownEvidence=str(audit_path))
    expected.pop('activeProcess', None)
    for case in expected.get('cases', []):
        if case.get('status') == 'running':
            case.update(status='canceled', passed=False)
    for row in expected['processes']:
        if row.get('exit') is None:
            row.update(terminationVerified=True, exitCodeUnavailable=True)
    if record != expected:
        raise ValueError('ARTIFACT_RECOVERED_INTERRUPTION_RECORD_CHANGED')
    try:
        observed = dt.datetime.fromisoformat(audit['observedAtUtc'])
        if observed.tzinfo is None:
            raise ValueError()
        for row in processes:
            started = dt.datetime.fromisoformat(row['startedAtUtc'])
            if started.tzinfo is None or observed < started or row.get('shutdownScope') != 'owned-windows-job':
                raise ValueError()
            if row.get('exit') is not None and (not terminal_consumer_process(repo, path.parent, row)
                    or row.get('shutdownConfirmed') is not True):
                raise ValueError()
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError('ARTIFACT_RECOVERED_INTERRUPTION_SHUTDOWN_INVALID') from error
    assert_output_shutdown(repo, path.parent)
    return {'path': str(audit_path), 'sha256': hashlib.sha256(audit_path.read_bytes()).hexdigest(),
            'originalPath': str(original_path), 'originalSha256': hashlib.sha256(original_bytes).hexdigest(),
            'observedCompleted': done, 'claimsTestPassed': False, 'processesStopped': True}


def terminal_input_drift(record: dict, consumer_directory: Path) -> bool:
    if record.get('status') != 'failed' or record.get('inputsStable', record.get('inputStable')) is not False:
        return False
    failure = record.get('failure')
    if not isinstance(failure, str):
        return False
    match = re.fullmatch(r'(?:ValueError: )?INPUT_DRIFT (?:(before) (.+)|(after cases))', failure)
    if not match:
        return False
    if match.group(1):
        operation = Path(match.group(2))
        return operation.is_absolute() and operation.resolve().is_relative_to(consumer_directory.resolve())
    return True


def missing_negative_consumer_expectations(record: dict) -> list[str]:
    """Classify incomplete old evidence without making it accepted evidence.

    Only a missing pinned negative-exit oracle is tolerated for retiring an
    independently verified product. All other completion invariants must hold.
    The original consumer, its outcome, and its generated outputs stay intact.
    """
    cases = record.get('cases')
    if not isinstance(cases, list) or not all(isinstance(row, dict) for row in cases):
        return []
    missing = [row['id'] for row in cases if isinstance(row.get('id'), str)
               and type(row.get('buildExit')) is int and row['buildExit'] != 0
               and expected_build_exit(record, row, default=None) is None]
    if not missing:
        return []
    control = copy.deepcopy(record)
    for row in control['cases']:
        if row.get('id') in missing:
            row['buildExit'] = 0
            for key in ('runExit', 'runExitCode'):
                if row.get(key, 0) is None:
                    row.pop(key)
    return missing if completed(control) else []


def failed_legacy_diagnostic_pairs(record: dict) -> bool:
    """Recognize terminal legacy parity captures without certifying their oracle."""
    cases = record.get('cases')
    if record.get('status') != 'failed' or not isinstance(cases, list) or not cases:
        return False
    if type(record.get('completed')) is not int or type(record.get('total')) is not int:
        return False
    if not 0 < len(cases) <= record['total']:
        return False
    for case in cases:
        if not isinstance(case, dict) or 'status' in case or type(case.get('passed')) is not bool:
            return False
        source_hash = case.get('sourceSha256')
        if not isinstance(case.get('id'), str) or not case['id'] or not isinstance(source_hash, str):
            return False
        if len(source_hash) != 64 or any(c not in '0123456789abcdefABCDEF' for c in source_hash):
            return False
        for role in ('managed', 'selfhost'):
            result = case.get(role)
            if not isinstance(result, dict) or type(result.get('exitCode')) is not int:
                return False
            if not isinstance(result.get('stdout'), str) or not isinstance(result.get('stderr'), str):
                return False
            if 'productExists' in result and type(result['productExists']) is not bool:
                return False
        if case['passed'] is not (case['managed'] == case['selfhost']):
            return False
    observed = sum(case['passed'] for case in cases)
    return observed == record['completed'] and observed < len(cases)



def equal_legacy_role_capture(repo: Path, record: dict) -> bool:
    """Recognize stopped role captures for product retirement, never oracle proof."""
    cases = record.get('cases')
    if (record.get('status') != 'passed' or not isinstance(cases, list) or not cases
            or type(record.get('total')) is not int or type(record.get('completed')) is not int
            or record['completed'] != record['total'] or len(cases) != record['total']):
        return False
    ids = set()
    for case in cases:
        if (not isinstance(case, dict) or 'status' in case or case.get('passed') is not True
                or not isinstance(case.get('id'), str) or not case['id'] or case['id'] in ids):
            return False
        ids.add(case['id'])
        source_hash = case.get('sourceSha256')
        sources = case.get('sources')
        if source_hash is not None:
            if (not isinstance(source_hash, str) or len(source_hash) != 64
                    or any(c not in '0123456789abcdefABCDEF' for c in source_hash)):
                return False
        elif (not isinstance(sources, list) or not sources
                or any(not isinstance(name, str) or not name for name in sources)):
            return False
        else:
            for name in sources:
                path = (repo / name).resolve()
                if not path.is_relative_to(repo.resolve()) or not path.is_file() or path.suffix != '.slg':
                    return False
        for role in ('managed', 'selfhost'):
            result = case.get(role)
            if (not isinstance(result, dict) or type(result.get('exitCode')) is not int
                    or result['exitCode'] not in (0, 1)
                    or not isinstance(result.get('stdout'), str) or not isinstance(result.get('stderr'), str)
                    or ('productExists' in result and type(result['productExists']) is not bool)):
                return False
        if case['managed'] != case['selfhost']:
            return False
    return True


def accepted_build_capture_failure(repo: Path, path: Path, record: dict, producer: dict) -> dict | None:
    """Authenticate an independently accepted build; never repair a failed capture."""
    acceptance = assert_artifact_path(repo, path.parent / 'build-acceptance-result.json')
    if not acceptance.is_file():
        return None
    stage = assert_artifact_path(repo, path.parent / 'compiler-build01' / 'result.json')
    if not stage.is_file():
        raise ValueError('ARTIFACT_CONSUMER_CAPTURE_FAILURE_EVIDENCE_INVALID')
    witness = json.loads(acceptance.read_text(encoding='utf-8-sig'))
    build = json.loads(stage.read_text(encoding='utf-8-sig'))
    pins = witness.get('inputHashes', {})
    source_pins = build.get('inputHashesStart', {})
    compiler_path = str(stage.parent / 'compiler.exe')
    compiler_hash = build.get('compilerSha256')
    wrapper_hash = hashlib.sha256(path.read_bytes()).hexdigest()
    stage_hash = hashlib.sha256(stage.read_bytes()).hexdigest()
    if (not completed(witness) or active_record(witness) or not completed(build) or active_record(build)
            or witness.get('processesStopped') is not True or witness.get('scriptExit') != 0
            or witness.get('knownWrapperFailurePreserved') != str(path)
            or not isinstance(pins, dict) or not isinstance(source_pins, dict)
            or not isinstance(compiler_hash, str) or len(compiler_hash) != 64
            or str(pins.get(str(path), '')).casefold() != wrapper_hash.casefold()
            or str(pins.get(str(stage), '')).casefold() != stage_hash.casefold()
            or str(pins.get(compiler_path, '')).casefold() != compiler_hash.casefold()
            or str(witness.get('compilerSha256', '')).casefold() != compiler_hash.casefold()
            or str(source_pins.get(producer['compilerPath'], '')).casefold() != producer['compilerSha256'].casefold()):
        raise ValueError('ARTIFACT_CONSUMER_CAPTURE_FAILURE_EVIDENCE_INVALID')
    return {'acceptancePath': str(acceptance), 'acceptanceSha256': hashlib.sha256(acceptance.read_bytes()).hexdigest(),
            'wrapperPath': str(path), 'wrapperSha256': wrapper_hash,
            'buildPath': str(stage), 'buildSha256': stage_hash, 'compilerSha256': compiler_hash,
            'purpose': 'terminal-consumption-only; original capture remains failed and unverified'}


def stopped_unsealed_capture(repo: Path, path: Path, record: dict, product: Path) -> bool:
    """Retire a producer after a drained capture assertion; certify no test result."""
    processes = record.get('processes')
    if (record.get('status') != 'failed' or record.get('completed') != 0
            or type(record.get('total')) is not int or record['total'] <= 0
            or record.get('cases') != []
            or not isinstance(record.get('failure'), str)
            or not record['failure'].startswith('AssertionError: ')
            or not isinstance(processes, list) or not processes):
        return False
    for row in processes:
        observation = row.get('naturalShutdownObservation', {}) if isinstance(row, dict) else {}
        if (not terminal_consumer_process(repo, path.parent, row)
                or row.get('exit') != 0 or row.get('shutdownConfirmed') is not True
                or row.get('shutdownScope') != 'owned-windows-job'
                or type(row.get('pid')) is not int or row['pid'] <= 0
                or not isinstance(row.get('command'), list) or not row['command']
                or str(row['command'][0]).casefold() != str(product).casefold()
                or not isinstance(observation, dict)
                or observation.get('rootPid') != row['pid']
                or observation.get('outcome') != 'drained'
                or observation.get('samples') != [{'activeProcesses': 0, 'ownedPids': []}]):
            return False
        try:
            started = dt.datetime.fromisoformat(row['startedAtUtc'])
            finished = dt.datetime.fromisoformat(row['finishedAtUtc'])
        except (KeyError, TypeError, ValueError):
            return False
        if started.tzinfo is None or finished.tzinfo is None or finished < started:
            return False
    assert_output_shutdown(repo, path.parent)
    return True


def stopped_partial_rejection_capture(repo: Path, path: Path, record: dict, product: Path) -> dict | None:
    """Observe a drained legacy assertion failure; grant no test completion."""
    cases, done, total = record.get('cases'), record.get('completed'), record.get('total')
    if (record.get('status') != 'failed' or type(done) is not int or type(total) is not int
            or not 0 < done < total or not isinstance(cases, list) or len(cases) != done + 1
            or not isinstance(record.get('failure'), str)
            or not record['failure'].startswith('AssertionError: ')
            or not isinstance(cases[-1], dict) or cases[-1].get('status') != 'running'
            or cases[-1].get('passed') is not False
            or cases[-1].get('expectedBuildExit') != 1 or cases[-1].get('buildExit') != 1):
        return None
    if (record.get('inputsStable') is not True or record.get('processesStopped') is not True
            or any(record.get(key) for key in ('activeProcess', 'activeProcessIds', 'running', 'orphanProcessIds'))
            or any(not isinstance(case, dict) or not isinstance(case.get('id'), str)
                   or not re.fullmatch(r'[A-Za-z0-9_.-]+', case['id'])
                   or any(case.get(key) for key in ('activeProcess', 'activeProcessIds', 'running', 'orphanProcessIds'))
                   for case in cases)
            or len({case['id'] for case in cases}) != len(cases)
            or not all(case.get('status') == 'passed' and case.get('passed') is True for case in cases[:-1])
            or record.get('claimsAcceptancePassed') is True or record.get('claimsGoalComplete') is True):
        raise ValueError('ARTIFACT_PARTIAL_REJECTION_CAPTURE_INVALID')
    processes = record.get('processes')
    if not isinstance(processes, list) or not processes:
        raise ValueError('ARTIFACT_PARTIAL_REJECTION_PROCESSES_MISSING')
    for row in processes:
        if (not terminal_consumer_process(repo, path.parent, row)
                or row.get('shutdownConfirmed') is not True or row.get('shutdownScope') != 'owned-windows-job'
                or type(row.get('pid')) is not int or row['pid'] <= 0
                or row.get('naturalShutdownObservation', {}).get('outcome') != 'drained'
                or row.get('naturalShutdownObservation', {}).get('rootPid') != row['pid']):
            raise ValueError('ARTIFACT_PARTIAL_REJECTION_PROCESS_NOT_TERMINAL')
        try:
            start, finish = (dt.datetime.fromisoformat(row[key]) for key in ('startedAtUtc', 'finishedAtUtc'))
            if start.tzinfo is None or finish.tzinfo is None or finish < start:
                raise ValueError()
        except (KeyError, TypeError, ValueError) as error:
            raise ValueError('ARTIFACT_PARTIAL_REJECTION_PROCESS_TIME_INVALID') from error
    last = processes[-1]
    if (last.get('exit', last.get('exitCode')) != 1
            or not isinstance(last.get('command'), list) or len(last['command']) < 2
            or last['command'][0] != str(product) or last['command'][1] not in ('build', 'wasm-stdlib')):
        raise ValueError('ARTIFACT_PARTIAL_REJECTION_PRODUCER_INVALID')
    streams = []
    for name in ('build.stdout', 'build.stderr'):
        capture = assert_artifact_path(repo, path.parent / cases[-1]['id'] / name)
        if not capture.is_file():
            raise ValueError('ARTIFACT_PARTIAL_REJECTION_STREAM_MISSING')
        streams.append({'path': str(capture), 'sha256': hashlib.sha256(capture.read_bytes()).hexdigest()})
    assert_output_shutdown(repo, path.parent)
    return {'observedCompleted': done, 'unsealedCaseId': cases[-1]['id'], 'streams': streams,
            'processesStopped': True, 'claimsTestPassed': False}


def passed_timeout_case(case: dict) -> bool:
    """Read either command or managed/native build-run case records strictly."""
    if case.get('passed') is not True or case.get('status') != 'passed':
        return False
    if 'exit' in case:
        return type(case['exit']) is int and case['exit'] == 0
    return (all(type(case.get(key)) is int and case[key] == 0
                for key in ('expectedBuildExit', 'buildExit', 'runExit'))
            and case.get('buildStderr') == '' and case.get('runStderr') == '')


def captured_symbols_observations(repo: Path, path: Path, record: dict, product: Path) -> bool:
    """Read stopped symbol captures without treating observations as tests."""
    cases, processes, pins = record.get('cases'), record.get('processes'), record.get('inputHashes')
    if (record.get('claimsAcceptancePassed') is not False or record.get('status') != 'passed'
            or type(record.get('total')) is not int or type(record.get('completed')) is not int
            or not isinstance(cases, list) or not cases or len(cases) != record['total']
            or record['completed'] != record['total'] or not isinstance(processes, list)
            or len(processes) != len(cases) or not isinstance(pins, dict)):
        return False
    for index, (case, process) in enumerate(zip(cases, processes)):
        if (not isinstance(case, dict) or not isinstance(process, dict)
                or set(case) != {'source', 'status', 'durationMilliseconds', 'exit', 'stdoutLines', 'stdoutBytes', 'stderr'}
                or case['status'] != 'observed' or not isinstance(case['source'], str)
                or any(type(case[key]) is not int or case[key] < 0
                       for key in ('durationMilliseconds', 'stdoutLines', 'stdoutBytes'))
                or type(case['exit']) is not int or case['exit'] != 0 or case['stderr'] != ''):
            return False
        source = (repo / case['source']).resolve()
        if (not source.is_relative_to(repo.resolve()) or source.suffix != '.slg'
                or process.get('command') != [str(product), 'symbols', str(source)]
                or not isinstance(pins.get(str(source)), str)
                or re.fullmatch(r'[0-9a-fA-F]{64}', pins[str(source)]) is None
                or type(process.get('exit')) is not int or process['exit'] != 0
                or process.get('shutdownConfirmed') is not True or process.get('shutdownScope') != 'owned-windows-job'):
            return False
        stdout, stderr = (path.parent / f'source{index}.{stream}' for stream in ('stdout', 'stderr'))
        if not stdout.is_file() or not stderr.is_file():
            return False
        text = stdout.read_text(encoding='utf-8-sig')
        if (len(text.splitlines()) != case['stdoutLines'] or len(text.encode('utf-8')) != case['stdoutBytes']
                or stderr.read_text(encoding='utf-8-sig') != ''):
            return False
    return True


def captured_validate_timeout_prefix(path: Path, record: dict, product: Path) -> bool:
    """Recognize legacy diagnostic observations for retirement, never completion."""
    completed, total = record.get('completed'), record.get('total')
    cases, processes, pins = record.get('cases'), record.get('processes'), record.get('inputHashes')
    if (type(completed) is not int or type(total) is not int or not 0 <= completed < total
            or not isinstance(cases, list) or len(cases) != completed + 1
            or not isinstance(processes, list) or len(processes) != len(cases)
            or not isinstance(pins, dict)):
        return False
    ids = set()
    for index, (case, process) in enumerate(zip(cases, processes)):
        if (not isinstance(case, dict) or not isinstance(case.get('id'), str)
                or not case['id'] or case['id'] in ids or not isinstance(process, dict)):
            return False
        ids.add(case['id'])
        command = process.get('command')
        if (not isinstance(command, list) or len(command) != 3
                or str(command[0]).casefold() != str(product).casefold() or command[1] != 'validate'
                or not isinstance(command[2], str)):
            return False
        source = Path(command[2])
        if (not source.is_absolute() or not source.is_file()
                or str(pins.get(str(source), '')).casefold() != hashlib.sha256(source.read_bytes()).hexdigest()):
            return False
        if index == completed:
            if set(case) != {'id', 'status'} or case['status'] != 'timed-out':
                return False
            continue
        if (set(case) != {'id', 'status', 'durationMilliseconds', 'exit', 'stdout', 'stderr'}
                or case['status'] != 'passed' or type(case['exit']) is not int or case['exit'] != 0
                or type(case['durationMilliseconds']) is not int or case['durationMilliseconds'] < 0
                or case['stdout'] != 'checked diagnostics = 0\n' or case['stderr'] != ''
                or type(process.get('exit')) is not int or process['exit'] != 0):
            return False
        for stream in ('stdout', 'stderr'):
            capture = path.parent / f'case{index}.{stream}'
            if not capture.is_file() or capture.read_text(encoding='utf-8-sig') != case[stream]:
                return False
    return True


def partial_catalog_timeout_shutdown(repo: Path, path: Path, record: dict, product: Path) -> dict:
    """Audit a completed prefix and the final timeout without crediting any test."""
    cases, total, done = record.get('cases'), record.get('total'), record.get('completed')
    if (record.get('status') != 'timed-out' or type(total) is not int or total <= 1
            or type(done) is not int or done != total - 1
            or not isinstance(cases, list) or len(cases) != total
            or any(not isinstance(case, dict) for case in cases)
            or record.get('selectedCatalog') != [case.get('id') for case in cases]
            or len(set(record['selectedCatalog'])) != total):
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_PREFIX_INVALID')
    prefix = []
    for case in cases[:-1]:
        case_id = case.get('id')
        if (not isinstance(case_id, str) or not case_id or case.get('status') != 'passed'
                or case.get('processesStopped') is not True):
            raise ValueError('ARTIFACT_CATALOG_TIMEOUT_PREFIX_CASE_INVALID')
        case_root = path.parent / 'cases' / hashlib.sha256(case_id.encode()).hexdigest()[:20]
        inner_path = assert_artifact_path(repo, case_root / 'runner/result.json')
        supervisor_path = assert_artifact_path(repo, case_root / 'result.json')
        if case.get('resultPath') != str(inner_path):
            raise ValueError('ARTIFACT_CATALOG_TIMEOUT_PREFIX_PATH_INVALID')
        inner = json.loads(inner_path.read_text(encoding='utf-8-sig'))
        supervisor = json.loads(supervisor_path.read_text(encoding='utf-8-sig'))
        for observed in (inner, supervisor):
            if (observed.get('status') != 'passed' or type(observed.get('completed')) is not int
                    or type(observed.get('total')) is not int
                    or observed['completed'] != 1 or observed['total'] != 1
                    or observed.get('inputsStable') is not True
                    or observed.get('processesStopped') is not True or active_record(observed)):
                raise ValueError('ARTIFACT_CATALOG_TIMEOUT_PREFIX_SHUTDOWN_INVALID')
        digest = hashlib.sha256(inner_path.read_bytes()).hexdigest()
        rows = supervisor.get('processes')
        expected = [record.get('runner'), '--compiler', str(product), '--skip-bootstrap', '--suite', 'full',
                    '--target', 'windows-x64', '--jobs', '1', '--output-directory', str(inner_path.parent),
                    '--exact', case_id]
        if isinstance(rows, list) and len(rows) == 1 and '--selfhost-driver-build' in rows[0].get('command', []):
            expected += ['--selfhost-driver-build', str(product.parent)]
        if (supervisor.get('authoritativeRunnerResult') != str(inner_path)
                or str(supervisor.get('authoritativeRunnerResultSha256', '')).casefold() != digest
                or inner.get('selectedCatalog') != [case_id] or inner.get('compiler') != str(product)
                or inner.get('inputHashes', {}).get(str(product)) != record.get('inputHashes', {}).get(str(product))
                or not isinstance(rows, list) or len(rows) != 1
                or not terminal_consumer_process(repo, case_root, rows[0])
                or rows[0].get('exit') != 0 or rows[0].get('shutdownConfirmed') is not True
                or rows[0].get('shutdownScope') != 'owned-windows-job'
                or not rows[0].get('command')
                or Path(rows[0]['command'][0]).name.casefold() not in ('dotnet', 'dotnet.exe')
                or rows[0]['command'][1:] != expected):
            raise ValueError('ARTIFACT_CATALOG_TIMEOUT_PREFIX_RUNNER_INVALID')
        assert_output_shutdown(repo, case_root)
        prefix.append({'caseId': case_id, 'runnerResult': str(inner_path), 'runnerSha256': digest,
                       'supervisorResult': str(supervisor_path),
                       'supervisorSha256': hashlib.sha256(supervisor_path.read_bytes()).hexdigest()})
    # The existing strict single-case audit authenticates the same final job and
    # original nested paths. The immutable multi-case catalog is never rewritten.
    final = dict(record, completed=0, total=1, selectedCatalog=[cases[-1].get('id')], cases=[cases[-1]])
    audit = catalog_timeout_shutdown(repo, path, final, product)
    audit.update(completedPrefix=prefix, observedCompleted=done, claimsTestPassed=False)
    return audit


def catalog_timeout_shutdown(repo: Path, path: Path, record: dict, product: Path) -> dict:
    """Authenticate one catalog timeout through its stopped runner's owned job.

    The catalog owns fingerprints; its nested supervisor owns process lifetime.
    This retires the verified producer only and never completes the failed test.
    """
    if type(record.get('total')) is int and record['total'] > 1:
        return partial_catalog_timeout_shutdown(repo, path, record, product)
    cases = record.get('cases')
    if (record.get('status') != 'timed-out' or type(record.get('completed')) is not int
            or type(record.get('total')) is not int or record.get('completed') != 0
            or record.get('total') != 1 or not isinstance(record.get('processes'), list)
            or any(not terminal_consumer_process(repo, path.parent, row)
                   or row.get('exit') != 0 or row.get('shutdownConfirmed') is not True
                   for row in record['processes'])
            or record.get('retryPolicy') != 'no-automatic-retry'
            or record.get('executionOrder') != 'sequential'
            or record.get('compiler') != str(product)
            or record.get('managedReference') is not False
            or not isinstance(cases, list) or len(cases) != 1):
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_INVALID')
    case = cases[0]
    case_id = case.get('id')
    if (not isinstance(case_id, str) or not case_id
            or record.get('selectedCatalog') != [case_id]
            or case.get('status') != 'timed-out' or case.get('processesStopped') is not True):
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_CASE_INVALID')
    case_root = path.parent / 'cases' / hashlib.sha256(case_id.encode()).hexdigest()[:20]
    inner_path = assert_artifact_path(repo, case_root / 'runner' / 'result.json')
    supervisor_path = assert_artifact_path(repo, case_root / 'result.json')
    if case.get('resultPath') != str(inner_path):
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_PATH_INVALID')
    child = json.loads(supervisor_path.read_text(encoding='utf-8-sig'))
    inner = json.loads(inner_path.read_text(encoding='utf-8-sig'))
    processes = child.get('processes')
    if (child.get('status') != 'timed-out' or type(child.get('completed')) is not int
            or type(child.get('total')) is not int or child.get('completed') != 0
            or child.get('total') != 1 or child.get('inputsStable') is not True
            or child.get('processesStopped') is not True
            or child.get('failure') != record.get('failure')
            or not str(child.get('failure', '')).startswith('TimeoutExpired: ')
            or active_record({k: v for k, v in child.items() if k != 'cases'})
            or not isinstance(child.get('cases'), list) or len(child['cases']) != 1
            or child['cases'][0].get('id') != case_id
            or child['cases'][0].get('status') != 'running'
            or not isinstance(processes, list) or len(processes) != 1):
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_SUPERVISOR_INVALID')
    runner = assert_artifact_path(repo, Path(record.get('runner', '')))
    pins = record.get('inputHashes', {})
    if (not runner.is_file()
            or str(pins.get(str(runner), '')).casefold() != hashlib.sha256(runner.read_bytes()).hexdigest()
            or inner.get('compiler') != str(product)
            or inner.get('status') != 'running' or type(inner.get('completed')) is not int
            or type(inner.get('total')) is not int or inner.get('completed') != 0
            or inner.get('total') != 1 or inner.get('selectedCatalog') != [case_id]
            or inner.get('inputHashes', {}).get(str(product)) != pins.get(str(product))):
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_RUNNER_LINK_INVALID')
    row = processes[0]
    command = row.get('command', [])
    expected = [str(runner), '--compiler', str(product), '--skip-bootstrap', '--suite', 'full',
                '--target', 'windows-x64', '--jobs', '1', '--output-directory', str(inner_path.parent),
                '--exact', case_id]
    if '--selfhost-driver-build' in command:
        expected += ['--selfhost-driver-build', str(product.parent)]
    if (not terminal_consumer_process(repo, case_root, row)
            or not command or Path(command[0]).name.casefold() not in ('dotnet', 'dotnet.exe')
            or command[1:] != expected or row.get('exit') == 0
            or row.get('shutdownConfirmed') is not True or row.get('shutdownScope') != 'owned-windows-job'
            or type(row.get('pid')) is not int or row['pid'] <= 0
            or not row.get('startedAtUtc') or not row.get('finishedAtUtc')
            or child.get('terminatedProcesses') != [{'pid': row['pid'], 'reason': 'TimeoutExpired',
                                                     'exit': 0, 'scope': 'owned-windows-job'}]):
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_JOB_SHUTDOWN_MISSING')
    try:
        started, finished = (dt.datetime.fromisoformat(row[key])
                             for key in ('startedAtUtc', 'finishedAtUtc'))
        if (started.tzinfo is None or finished.tzinfo is None or finished < started
                or type(child['terminatedProcesses'][0]['exit']) is not int):
            raise ValueError()
    except (TypeError, ValueError) as error:
        raise ValueError('ARTIFACT_CATALOG_TIMEOUT_JOB_TIME_INVALID') from error
    assert_output_shutdown(repo, case_root)
    return {'terminatedRunnerPids': [row['pid']], 'processesStopped': True,
            'supervisorResult': str(supervisor_path),
            'supervisorSha256': hashlib.sha256(supervisor_path.read_bytes()).hexdigest(),
            'unfinishedRunnerResult': str(inner_path),
            'unfinishedRunnerSha256': hashlib.sha256(inner_path.read_bytes()).hexdigest(),
            'claimsTestPassed': False}


def timed_out_consumer_shutdown(repo: Path, path: Path, record: dict, product: Path) -> dict:
    """Prove terminal consumption only; never complete or clean the timed-out run."""
    if (record.get('retryPolicy') == 'no-automatic-retry'
            and 'runner' in record and 'selectedCatalog' in record):
        return catalog_timeout_shutdown(repo, path, record, product)
    # Diagnostic command runs may time out before a case row is created.
    # Empty case evidence can retire the stopped producer, never pass the run.
    cases = record.get('cases', [])
    processes = record.get('processes')
    terminated = record.get('terminatedProcesses')
    captured_prefix = captured_validate_timeout_prefix(path, record, product)
    if (type(record.get('completed')) is not int or type(record.get('total')) is not int
            or not 0 <= record['completed'] < record['total']
            or not isinstance(record.get('failure'), str) or not record['failure'].startswith('TimeoutExpired: ')
            or active_record({k: v for k, v in record.items() if k != 'cases'})
            or not isinstance(cases, list) or not 0 <= len(cases) <= record['total']
            or (not captured_prefix and any(not isinstance(case, dict)
                   or not ((case.get('passed') is False and case.get('status') in ('running', 'pending', 'timed-out'))
                           or passed_timeout_case(case))
                   or any(case.get(k) for k in ('activeProcess', 'activeProcessIds', 'running', 'orphanProcessIds'))
                   for case in cases))
            or not isinstance(processes, list) or not processes
            or not isinstance(terminated, list) or not terminated
            or (not captured_prefix and record['completed'] != sum(case.get('passed') is True for case in cases))):
        raise ValueError('ARTIFACT_TIMED_OUT_CONSUMER_EVIDENCE_INVALID')
    for row in processes:
        if (not terminal_consumer_process(repo, path.parent, row)
                or row.get('shutdownConfirmed') is not True or row.get('shutdownScope') != 'owned-windows-job'
                or type(row.get('pid')) is not int or row['pid'] <= 0
                or not row.get('startedAtUtc') or not row.get('finishedAtUtc')):
            raise ValueError('ARTIFACT_TIMED_OUT_CONSUMER_SHUTDOWN_MISSING')
    timed = [row for row in processes if row.get('command') and
             str(row['command'][0]).casefold() == str(product).casefold()
             and row.get('exit', row.get('exitCode')) != 0
             and any(isinstance(end, dict) and end.get('pid') == row['pid']
                     and end.get('reason') == 'TimeoutExpired' and end.get('scope') == 'owned-windows-job'
                     and type(end.get('exit')) is int and end['exit'] == 0 for end in terminated)]
    if not timed:
        raise ValueError('ARTIFACT_TIMED_OUT_CONSUMER_TERMINATION_MISSING')
    if sum(row.get('exit', row.get('exitCode')) == 0 for row in processes) < record['completed']:
        raise ValueError('ARTIFACT_TIMED_OUT_CONSUMER_PARTIAL_EXIT_MISSING')
    assert_output_shutdown(repo, path.parent)
    return {'terminatedCompilerPids': [row['pid'] for row in timed], 'processesStopped': True}


def controller_lost_consumer_shutdown(repo: Path, path: Path, record: dict, product: Path) -> dict | None:
    """Retire a stopped producer without inventing the lost controller's outcome."""
    audit_path = path.parent / 'controller-loss-terminal-audit.json'
    if record.get('status') != 'running' or not audit_path.is_file():
        return None
    audit_path = assert_artifact_path(repo, audit_path)
    audit = json.loads(audit_path.read_text(encoding='utf-8-sig'))
    processes, cases = record.get('processes'), record.get('cases')
    if (not isinstance(audit, dict) or audit.get('schemaVersion') != 1
            or audit.get('status') != 'controller-handle-missing-original-exit-unsealed'
            or not isinstance(audit.get('originalResultSha256'), str)
            or audit.get('originalResultSha256', '').casefold() != hashlib.sha256(path.read_bytes()).hexdigest()
            or audit.get('recordedCompilerPidExists') is not False
            or audit.get('matchingCompilerClangPythonProcessesObserved') != []
            or audit.get('inputsStableNow') is not True
            or audit.get('claimsBuildExitKnown') is not False or audit.get('claimsCasePassed') is not False
            or type(audit.get('toolSession')) is not int or audit['toolSession'] <= 0
            or record.get('completed') != 0 or type(record.get('total')) is not int or record['total'] <= 0
            or audit.get('completed') != 0 or audit.get('total') != record['total']
            or record.get('orphanProcessIds')
            or not isinstance(processes, list) or len(processes) != 1
            or not isinstance(cases, list) or not 0 < len(cases) <= record['total']
            or any(not isinstance(case, dict) or case.get('status') != 'running'
                   or case.get('passed') is not False for case in cases)):
        raise ValueError('ARTIFACT_CONTROLLER_LOST_AUDIT_INVALID')
    root = processes[0]
    if (not isinstance(root, dict) or type(root.get('pid')) is not int or root['pid'] <= 0
            or audit.get('recordedCompilerPid') != root['pid'] or root.get('exit') is not None
            or root.get('shutdownScope') != 'owned-windows-job'
            or not isinstance(root.get('command'), list) or not root['command']
            or root['command'][0] != str(product)):
        raise ValueError('ARTIFACT_CONTROLLER_LOST_ROOT_INVALID')
    try:
        started, observed = (dt.datetime.fromisoformat(value) for value in
                             (root['startedAtUtc'], audit['observedAtUtc']))
        if started.tzinfo is None or observed.tzinfo is None or observed < started:
            raise ValueError()
    except (KeyError, TypeError, ValueError) as error:
        raise ValueError('ARTIFACT_CONTROLLER_LOST_TIME_INVALID') from error
    # Recheck current processes too; a historical empty observation is insufficient.
    assert_output_shutdown(repo, path.parent)
    return {'path': str(audit_path), 'sha256': hashlib.sha256(audit_path.read_bytes()).hexdigest()}


def stopped_diagnostic_observation(repo: Path, path: Path, record: dict, product: Path) -> bool:
    """Authenticate one rejected build observation without certifying its diagnostic."""
    processes = record.get('processes')
    if (record.get('status') != 'observed-not-qualified'
            or any(key in record for key in ('completed', 'total', 'cases'))
            or record.get('claimsGoalComplete') is not False
            or record.get('claimsTestPassed', False) is not False
            or type(record.get('observedExit')) is not int or record['observedExit'] != 1
            or not isinstance(record.get('diagnostic'), str) or not record['diagnostic'].strip()
            or not isinstance(processes, list) or len(processes) != 1):
        return False
    process = processes[0]
    if (not terminal_consumer_process(repo, path.parent, process)
            or process.get('command', [])[:2] != [str(product), 'build']
            or process.get('exit') != 1 or process.get('shutdownConfirmed') is not True
            or process.get('shutdownScope') != 'owned-windows-job'
            or type(process.get('pid')) is not int or process['pid'] <= 0
            or process.get('naturalShutdownObservation', {}).get('rootPid') != process['pid']
            or process.get('naturalShutdownObservation', {}).get('outcome') != 'drained'):
        return False
    try:
        started = dt.datetime.fromisoformat(process['startedAtUtc'])
        finished = dt.datetime.fromisoformat(process['finishedAtUtc'])
        if started.tzinfo is None or finished.tzinfo is None or finished < started:
            return False
    except (KeyError, TypeError, ValueError):
        return False
    logs = list(path.parent.glob('*.stderr'))
    if len(logs) != 1:
        return False
    stderr = assert_artifact_path(repo, logs[0])
    stdout = assert_artifact_path(repo, stderr.with_suffix('.stdout'))
    return (stdout.is_file() and stdout.stat().st_size == 0
            and stderr.read_text(encoding='utf-8-sig').strip() == record['diagnostic'].strip())


def terminal_diagnostic_capture(record: dict) -> bool:
    """Recognize terminal mismatch captures for retirement only, never acceptance."""
    cases = record.get('cases')
    total, done = record.get('total'), record.get('completed')
    if (type(total) is not int or total <= 0 or type(done) is not int
            or not 0 <= done < total or not isinstance(cases, list) or not cases
            or any(not isinstance(case, dict) or not isinstance(case.get('id'), str)
                   or not case['id'] or any(case.get(key) for key in
                       ('activeProcess', 'running', 'timedOut', 'canceled', 'cancelled'))
                   for case in cases)):
        return False
    if record.get('status') == 'failed' and len(cases) == total:
        return (len({case['id'] for case in cases}) == total
            and done == sum(case.get('status') == 'passed' for case in cases)
            and any(case.get('status') == 'mismatch' for case in cases)
            and all(case.get('status') in ('passed', 'mismatch')
                    and type(case.get('observedExit')) is int
                    and isinstance(case.get('observedStdout'), str)
                    and isinstance(case.get('observedStderr'), str) for case in cases))
    if record.get('status') != 'mismatch' or len(cases) != 2 * total:
        return False
    by_role = {role: [case for case in cases if case.get('mode') == role]
               for role in ('managed', 'native')}
    return (all(len(rows) == total and len({case['id'] for case in rows}) == total
                for rows in by_role.values())
        and {case['id'] for case in by_role['managed']} == {case['id'] for case in by_role['native']}
        and all(type(case.get('exitCode')) is int
                and isinstance(case.get('actualStderr'), str)
                and isinstance(case.get('expectedStderr'), str) and bool(case['expectedStderr'])
                and type(case.get('matchesManagedDecision')) is bool
                and case['matchesManagedDecision'] is (case['actualStderr'] == case['expectedStderr'])
                for case in cases)
        and all(case['matchesManagedDecision'] for case in by_role['managed'])
        and done == sum(case['matchesManagedDecision'] for case in by_role['native']))


def terminal_attempted_runner_capture(repo: Path, path: Path, record: dict) -> bool:
    """Recognize attempted-count example results for retirement, never acceptance."""
    cases, processes = record.get('cases'), record.get('processes')
    if (record.get('status') != 'failed' or not isinstance(cases, list) or not cases
            or type(record.get('completed')) is not int or record['completed'] != len(cases)
            or type(record.get('total')) is not int or not len(cases) <= record['total']
            or not isinstance(processes, list) or not processes
            or any(not isinstance(case, dict) for case in cases)
            or any(not isinstance(process, dict) for process in processes)
            or not any(case.get('status') == 'failed' for case in cases)):
        return False
    ids, used = set(), []
    for case in cases:
        case_id, indices = case.get('id'), case.get('processes')
        if (not isinstance(case_id, str) or not case_id or case_id in ids
                or case.get('status') not in ('passed', 'failed')
                or not isinstance(indices, list) or not indices
                or any(type(index) is not int or not 0 <= index < len(processes) for index in indices)
                or not isinstance(case.get('resultPath'), str)
                or not isinstance(case.get('resultSha256'), str)):
            return False
        ids.add(case_id)
        used.extend(indices)
        try:
            detail_path = assert_artifact_path(repo, Path(case['resultPath']))
            detail_path.relative_to(path.parent)
            raw = detail_path.read_bytes()
            if hashlib.sha256(raw).hexdigest().casefold() != case['resultSha256'].casefold():
                return False
            detail = json.loads(raw.decode('utf-8-sig'))
        except (OSError, ValueError):
            return False
        if (not isinstance(detail, dict)
                or any(detail.get(key) != case.get(key) for key in
                       ('id', 'status', 'oracle', 'requiresSelfHostCompiler'))
                or not isinstance(detail.get('processes'), list)
                or len(detail['processes']) != len(indices)):
            return False
        for nested, index in zip(detail['processes'], indices):
            outer = processes[index]
            if (not isinstance(nested, dict)
                    or any(nested.get(key) != value for key, value in outer.items())
                    or any(value is not None for key, value in nested.items() if key not in outer)):
                return False
    return sorted(used) == list(range(len(processes)))


def observed_cli_case_completed(row: dict) -> bool:
    """Read legacy CLI oracles for product retirement without rewriting results."""
    if ('status' in row or row.get('passed') is not True
            or type(row.get('observedBuildExit')) is not int
            or any(key in row for key in ('roles', 'managed', 'selfhost',
                'buildExit', 'buildExitCode', 'compileExit', 'runExit', 'runExitCode'))
            or any(row.get(key) for key in ('timedOut', 'timeout', 'failureId',
                'failureIds', 'canceled', 'cancelled', 'activeProcess', 'running'))):
        return False
    if row['observedBuildExit'] == 0:
        return (type(row.get('observedRunExit')) is int and row['observedRunExit'] == 0
            and isinstance(row.get('actualStdout'), str)
            and isinstance(row.get('expectedStdout'), str)
            and row['actualStdout'] == row['expectedStdout']
            and row.get('actualStderr', '') == ''
            and not any(key in row for key in ('observedExit', 'expectedExit', 'formatControl')))
    if not (row['observedBuildExit'] == 1 and row.get('commandKind') == 'public-cli-negative'
            and type(row.get('observedExit')) is int and row['observedExit'] == 1
            and type(row.get('expectedExit')) is int and row['expectedExit'] == 1
            and row.get('observedRunExit') is None
            and isinstance(row.get('expectedStderr'), str) and bool(row['expectedStderr'])
            and row.get('actualStderr') == row['expectedStderr']):
        return False
    if 'formatControl' not in row:
        return True
    control = row['formatControl']
    return (isinstance(control, dict) and type(control.get('observedExit')) is int
        and control['observedExit'] == 1
        and not any(control.get(key) for key in ('timedOut', 'timeout', 'canceled',
            'cancelled', 'failureId', 'failureIds', 'activeProcess', 'running'))
        and isinstance(control.get('expectedStderr'), str) and bool(control['expectedStderr'])
        and control.get('actualStderr') == control['expectedStderr'])


def partial_comparison_shutdown(repo: Path, path: Path, record: dict, product: Path) -> dict | None:
    """Retire a producer when the canonical comparer stopped before sealing a mismatch."""
    processes = record.get('processes')
    if (record.get('status') != 'failed' or not isinstance(processes, list) or not processes
            or not all(isinstance(row, dict) and isinstance(row.get('command'), list)
                       and len(row['command']) == 5 and row['command'][2] == '--compare-results'
                       for row in processes)):
        return None
    cases, done, total = record.get('cases'), record.get('completed'), record.get('total')
    if (type(done) is not int or type(total) is not int or not 0 <= done < total
            or not isinstance(cases, list) or len(cases) != done or len(processes) != done + 1
            or not all(isinstance(case, dict) and case.get('status') == 'passed'
                       and isinstance(case.get('id'), str) and case['id'] for case in cases)
            or len({case['id'] for case in cases}) != done
            or not isinstance(record.get('failure'), str)):
        raise ValueError('ARTIFACT_PARTIAL_COMPARISON_COUNTS_INVALID')
    pins = record.get('inputHashes', {})
    references = []
    runner = None
    for index, row in enumerate(processes):
        command = row['command']
        tool = assert_artifact_path(repo, Path(command[1]))
        if (Path(command[0]).name.casefold() not in ('dotnet', 'dotnet.exe')
                or tool.name != 'Sollang.ExampleTests.dll' or not tool.is_file()
                or (runner is not None and runner != tool)
                or str(pins.get(str(tool), '')).casefold() != hashlib.sha256(tool.read_bytes()).hexdigest()
                or not terminal_consumer_process(repo, path.parent, row)
                or row.get('exit') != (1 if index == done else 0)
                or row.get('shutdownConfirmed') is not True or row.get('shutdownScope') != 'owned-windows-job'
                or row.get('naturalShutdownObservation', {}).get('outcome') != 'drained'):
            raise ValueError('ARTIFACT_PARTIAL_COMPARISON_PROCESS_INVALID')
        runner = tool
        pair = []
        for name in command[3:]:
            result_path = assert_artifact_path(repo, Path(name))
            digest = hashlib.sha256(result_path.read_bytes()).hexdigest()
            child = json.loads(result_path.read_text(encoding='utf-8-sig'))
            if (result_path.name != 'result.json' or str(pins.get(str(result_path), '')).casefold() != digest
                    or not completed(child) or child.get('processesStopped') is not True
                    or child.get('total') != 1 or child.get('completed') != 1
                    or not isinstance(child.get('selectedCatalog'), list) or len(child['selectedCatalog']) != 1):
                raise ValueError('ARTIFACT_PARTIAL_COMPARISON_RESULT_INVALID')
            references.append({'path': str(result_path), 'sha256': digest})
            pair.append(child)
        if (pair[0]['selectedCatalog'] != pair[1]['selectedCatalog']
                or pair[1].get('compiler') != str(product)
                or str(pair[1].get('compilerSha256', '')).casefold() != str(pins.get(str(product), '')).casefold()
                or index < done and pair[1]['selectedCatalog'] != [cases[index]['id']]
                or index == done and record['failure'] != 'AssertionError: ' + pair[1]['selectedCatalog'][0]):
            raise ValueError('ARTIFACT_PARTIAL_COMPARISON_LINK_INVALID')
    assert_output_shutdown(repo, path.parent)
    return {'processesStopped': True, 'pairedResultReferences': references,
            'claimsTestPassed': False, 'observedCompleted': done}


def consumer_closure_record(repo: Path, output: Path, consumers: list[Path], replacement: Path,
                            *, allow_missing_product: bool = False, legacy_terminal: bool = False,
                            retired_replacement_chain: frozenset[Path] | None = None) -> dict:
    """Retire consumers without changing a build's immutable completion record."""
    output = assert_artifact_path(repo, output)
    replacement = assert_artifact_path(repo, replacement)
    if retired_replacement_chain is not None and replacement in retired_replacement_chain:
        raise ValueError('ARTIFACT_CONSUMER_REPLACEMENT_CYCLE')
    if output == replacement or not consumers or len(set(map(str, consumers))) != len(consumers):
        raise ValueError('ARTIFACT_CONSUMER_CLOSURE_INPUT_INVALID')
    references = []
    for directory in (output, replacement):
        path = assert_artifact_path(repo, directory / 'result.json')
        record = json.loads(path.read_text(encoding='utf-8-sig'))
        binary = assert_artifact_path(repo, directory / 'compiler.exe')
        if not completed(record) or active_record(record):
            raise ValueError('ARTIFACT_CONSUMER_BUILD_NOT_STABLE')
        if directory == output and not record.get('pendingConsumerProtection'):
            raise ValueError('ARTIFACT_CONSUMER_BUILD_NOT_PENDING')
        expected = record.get('compilerSha256')
        if not isinstance(expected, str) or len(expected) != 64:
            raise ValueError('ARTIFACT_CONSUMER_BINARY_HASH_MISSING')
        if binary.exists():
            if hashlib.sha256(binary.read_bytes()).hexdigest().casefold() != expected.casefold():
                raise ValueError('ARTIFACT_CONSUMER_BINARY_CHANGED')
        elif directory == output:
            if not allow_missing_product:
                raise ValueError('ARTIFACT_CONSUMER_BINARY_MISSING')
        elif retired_replacement_chain is not None:
            # A sealed closure outlives its replacement binary. Revalidate that
            # replacement's own immutable retirement proof, ending at a live
            # verified product. New registrations still require a live binary.
            verified_consumer_closure(repo, directory, allow_missing_product=True,
                                      retirement_chain=retired_replacement_chain)
        else:
            raise ValueError('ARTIFACT_CONSUMER_BINARY_MISSING')
        references.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                           'compilerPath': str(binary), 'compilerSha256': expected})
    assert_output_shutdown(repo, output)
    rows = []
    for path in consumers:
        path = assert_artifact_path(repo, path)
        if path.name != 'result.json' or path.parent == output or path.parent == replacement:
            raise ValueError('ARTIFACT_CONSUMER_RESULT_BOUNDARY_INVALID')
        record = json.loads(path.read_text(encoding='utf-8-sig'))
        lost = controller_lost_consumer_shutdown(repo, path, record, Path(references[0]['compilerPath'])) if legacy_terminal else None
        if lost is not None:
            producer = references[0]
            pins = record.get('inputHashes', {})
            if (not isinstance(pins, dict)
                    or str(pins.get(producer['compilerPath'], '')).casefold() != producer['compilerSha256'].casefold()
                    or str(pins.get(producer['path'], '')).casefold() != producer['sha256'].casefold()):
                raise ValueError('ARTIFACT_CONSUMER_BUILD_LINK_INVALID')
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': 'controller-lost', 'completed': 0, 'total': record['total'],
                         'executed': 0, 'failed': 0, 'unexecuted': record['total'],
                         'disposition': 'terminal-controller-lost', 'shutdownAudit': lost,
                         'unprovenReasons': ['controller-exit-unsealed']})
            continue
        canceled = legacy_terminal and record.get('status') == 'canceled'
        timed_out = legacy_terminal and record.get('status') == 'timed-out'
        partial_rejection = (stopped_partial_rejection_capture(repo, path, record, Path(references[0]['compilerPath']))
                             if legacy_terminal else None)
        recovered_interruption = recovered_interruption_shutdown(repo, path, record) if legacy_terminal else None
        mismatch_capture = legacy_terminal and terminal_diagnostic_capture(record)
        diagnostic_observation = legacy_terminal and stopped_diagnostic_observation(
            repo, path, record, Path(references[0]['compilerPath']))
        if ((record.get('status') not in ('passed', 'failed') and not canceled and not timed_out
                and not mismatch_capture and not diagnostic_observation)
                or (active_record(record) and not timed_out and partial_rejection is None) or record.get('orphanProcessIds')):
            raise ValueError('ARTIFACT_CONSUMER_NOT_TERMINAL')
        stable_inputs = record.get('inputsStable', record.get('inputStable'))
        input_drift = terminal_input_drift(record, path.parent)
        if (record.get('processesStopped', record.get('processShutdownConfirmed')) is not True
                or (stable_inputs is not True and not input_drift and recovered_interruption is None)):
            raise ValueError('ARTIFACT_CONSUMER_SHUTDOWN_OR_STABILITY_MISSING')
        pins = record.get('inputHashes', record.get('inputSha256', {}))
        unpaired_start_pins = False
        # Owned executions also preserve paired start/end fingerprints.
        # Admit that explicit format only when the immutable snapshots agree.
        if 'inputHashes' not in record and 'inputSha256' not in record and 'inputHashesStart' in record:
            pins = record['inputHashesStart']
            unpaired_start_pins = legacy_terminal and 'inputHashesEnd' not in record
            if not isinstance(pins, dict) or not pins or (not unpaired_start_pins and record.get('inputHashesEnd') != pins):
                raise ValueError('ARTIFACT_CONSUMER_FINGERPRINT_PAIR_INVALID')
        producer = references[0]
        missing_producer_pin = isinstance(pins, dict) and producer['path'] not in pins
        binary_pinned = isinstance(pins, dict) and str(pins.get(producer['compilerPath'], '')).casefold() == producer['compilerSha256'].casefold()
        producer_pinned = isinstance(pins, dict) and str(pins.get(producer['path'], '')).casefold() == producer['sha256'].casefold()
        if not binary_pinned or not (producer_pinned or legacy_terminal and missing_producer_pin):
            raise ValueError('ARTIFACT_CONSUMER_BUILD_LINK_INVALID')
        if diagnostic_observation:
            assert_output_shutdown(repo, path.parent)
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': record['status'], 'completed': 0, 'total': None,
                         'executed': 1, 'failed': None, 'unexecuted': None,
                         'disposition': 'terminal-unqualified-diagnostic-observation',
                         'unprovenReasons': ['diagnostic-oracle-unverified']})
            continue
        if recovered_interruption is not None:
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': 'canceled', 'completed': 0, 'total': record['total'],
                         'executed': 0, 'failed': 0, 'unexecuted': record['total'],
                         'disposition': 'terminal-recovered-interruption', 'shutdownAudit': recovered_interruption,
                         'unprovenReasons': ['interrupted-verification']})
            continue
        if partial_rejection is not None:
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': 'failed', 'completed': 0, 'total': record['total'],
                         'executed': 0, 'failed': 0, 'unexecuted': record['total'],
                         'disposition': 'terminal-partial-rejection-capture', 'shutdownAudit': partial_rejection,
                         'unprovenReasons': ['assertion-before-case-sealing']})
            continue
        if mismatch_capture:
            processes = record.get('processes')
            if not isinstance(processes, list) or not processes or not all(
                    terminal_consumer_process(repo, path.parent, row) for row in processes):
                raise ValueError('ARTIFACT_CONSUMER_PROCESS_EXIT_MISSING')
            assert_output_shutdown(repo, path.parent)
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': record['status'], 'completed': 0, 'total': None,
                         'executed': None, 'failed': None, 'unexecuted': None,
                         'disposition': 'terminal-diagnostic-mismatch-capture',
                         'observedCompleted': record['completed'], 'observedTotal': record['total'],
                         'producerRecordPinMissing': missing_producer_pin,
                         'unprovenReasons': ['diagnostic-mismatch-retirement-only']})
            continue
        if timed_out:
            audit = timed_out_consumer_shutdown(repo, path, record, Path(producer['compilerPath']))
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': 'timed-out', 'completed': 0, 'total': record['total'],
                         'executed': 0, 'failed': 0, 'unexecuted': record['total'],
                         'disposition': 'terminal-timed-out', 'shutdownAudit': audit,
                         'unprovenReasons': ['timed-out-verification'] +
                         (['producer-record-unpinned'] if missing_producer_pin else [])})
            continue
        partial_comparison = partial_comparison_shutdown(repo, path, record, Path(producer['compilerPath'])) if legacy_terminal else None
        if partial_comparison is not None:
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': 'failed', 'completed': 0, 'total': record['total'],
                         'executed': record['completed'], 'failed': 0,
                         'unexecuted': record['total'] - record['completed'],
                         'disposition': 'terminal-partial-comparison', 'shutdownAudit': partial_comparison,
                         'unprovenReasons': ['comparison-mismatch-unsealed'] +
                         (['producer-record-unpinned'] if missing_producer_pin else [])})
            continue
        if legacy_terminal and stopped_unsealed_capture(repo, path, record, Path(producer['compilerPath'])):
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': 'failed', 'completed': 0, 'total': record['total'],
                         'executed': 0, 'failed': 0, 'unexecuted': record['total'],
                         'disposition': 'terminal-unsealed-capture',
                         'unprovenReasons': ['capture-assertion-before-case-sealing']})
            continue
        if canceled:
            audit = canceled_consumer_shutdown(repo, path, record)
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': 'canceled', 'completed': 0, 'total': record['total'],
                         'executed': 0, 'failed': 0, 'unexecuted': record['total'],
                         'disposition': 'terminal-canceled', 'shutdownAudit': audit,
                         'unprovenReasons': ['canceled-verification'] +
                         (['producer-record-unpinned'] if missing_producer_pin else [])})
            continue
        # Old diagnostic and build captures have no case-level evidence. Their terminal
        # execution permits retiring the separately verified compiler, never
        # deleting the capture's output or counting it as a passed test.
        declared_counts = (type(record.get('completed')) is int and type(record.get('total')) is int
                           and 0 <= record['completed'] <= record['total'] and record['total'] > 0)
        uncounted_scope = (isinstance(record.get('scope'), str) and bool(record['scope'].strip())
                           and all(key not in record for key in ('completed', 'total')))
        cases = record.get('cases', [] if legacy_terminal else None)
        cases = list(cases.values()) if isinstance(cases, dict) else cases
        processes = record.get('processes')
        if processes is None and legacy_terminal:
            processes = legacy_paired_processes(repo, path, record, Path(producer['compilerPath']))
        # A paired runner can abort before sealing a case while retaining a
        # terminal role capture. Retire only the pinned compiler whose process
        # actually failed; never infer full case outcomes from those roles.
        incomplete_roles = (legacy_terminal and record['status'] == 'failed'
                            and declared_counts and record['completed'] == 0
                            and isinstance(record.get('failure'), str) and bool(record['failure'])
                            and isinstance(cases, list) and 0 < len(cases) <= record['total']
                            and all(isinstance(case, dict) and case.get('status') == 'pending'
                                    and case.get('passed', False) is False
                                    and isinstance(case.get('roles'), dict) and bool(case['roles'])
                                    and all(isinstance(role, dict) and not active_record(role)
                                            and not role.get('orphanProcessIds')
                                            and role.get('status') in ('passed', 'failed')
                                            and type(role.get('exit')) is int
                                            and (role['exit'] == 0) is (role['status'] == 'passed')
                                            for role in case['roles'].values()) for case in cases)
                            and isinstance(processes, list) and any(
                                isinstance(process, dict) and isinstance(process.get('command'), list)
                                and process['command']
                                and str(process['command'][0]).casefold() == producer['compilerPath'].casefold()
                                and type(process.get('exit', process.get('exitCode'))) is int
                                and process.get('exit', process.get('exitCode')) != 0
                                for process in processes))
        # Boolean-only legacy rows do not prove their test oracles. They can
        # retire a separately verified compiler after every owned process stops;
        # the consumer remains unverified and its generated output is protected.
        boolean_observation = (legacy_terminal and declared_counts
            and isinstance(cases, list) and 0 < len(cases) <= record['total']
            and isinstance(processes, list) and bool(processes)
            and all(isinstance(process, dict) and process.get('shutdownConfirmed') is True
                    and process.get('shutdownScope') == 'owned-windows-job'
                    and process.get('naturalShutdownObservation', {}).get('outcome') == 'drained'
                    for process in processes)
            and record.get('claimsAcceptancePassed') is not True
            and record.get('claimsGoalComplete') is not True
            and all(isinstance(case, dict) and {'id', 'passed'} <= set(case)
                    and set(case) <= {'id', 'passed', 'rawRecord', 'cache'}
                    and isinstance(case['id'], str) and bool(case['id'])
                    and type(case['passed']) is bool
                    and ('rawRecord' not in case or isinstance(case['rawRecord'], str))
                    and ('cache' not in case
                         or isinstance(case['cache'], dict) and not active_record(case['cache'])
                         or isinstance(case['cache'], list) and bool(case['cache'])
                            and all(type(value) is int and value >= 0 for value in case['cache']))
                    for case in cases)
            and len({case['id'] for case in cases}) == len(cases)
            and record['completed'] == sum(case['passed'] for case in cases)
            and (record['status'] == 'passed' and record['completed'] == record['total'] == len(cases)
                 or record['status'] == 'failed' and isinstance(record.get('failure'), str) and bool(record['failure'])))
        observation_only = legacy_terminal and (boolean_observation or
            'cases' not in record and (declared_counts or uncounted_scope)
            or captured_symbols_observations(repo, path, record, Path(producer['compilerPath'])))
        capture_failure = None
        if (legacy_terminal and record['status'] == 'failed' and record.get('completed') == 0
                and record.get('total') == 1 and cases == []
                and isinstance(record.get('failure'), str) and bool(record['failure'])
                and isinstance(processes, list) and bool(processes)
                and all(isinstance(row, dict) and type(row.get('exit', row.get('exitCode'))) is int
                        and row.get('exit', row.get('exitCode')) == 0 for row in processes)):
            capture_failure = accepted_build_capture_failure(repo, path, record, producer)
        diagnostic_pairs = legacy_terminal and failed_legacy_diagnostic_pairs(record)
        equal_roles = legacy_terminal and equal_legacy_role_capture(repo, record)
        # A log reader can fail after a successful command but before any case
        # is sealed. This proves terminal consumption only, not test success.
        pre_case_log_failure = (legacy_terminal and record['status'] == 'failed'
            and declared_counts and record['completed'] == 0 and cases == []
            and isinstance(record.get('failure'), str)
            and record['failure'].startswith('FileNotFoundError: ')
            and isinstance(processes, list) and bool(processes)
            and all(isinstance(row, dict) and type(row.get('exit')) is int and row['exit'] == 0
                and row.get('shutdownConfirmed') is True
                and row.get('shutdownScope') == 'owned-windows-job'
                and row.get('naturalShutdownObservation', {}).get('outcome') == 'drained'
                and isinstance(row.get('command'), list) and bool(row['command'])
                and str(row['command'][0]).casefold() == producer['compilerPath'].casefold()
                for row in processes))
        if observation_only or incomplete_roles or capture_failure or diagnostic_pairs or equal_roles or pre_case_log_failure:
            if not isinstance(processes, list) or not processes or not all(
                    terminal_consumer_process(repo, path.parent, row) for row in processes):
                raise ValueError('ARTIFACT_CONSUMER_PROCESS_EXIT_MISSING')
            assert_output_shutdown(repo, path.parent)
            rows.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                         'status': record['status'], 'completed': 0, 'total': None,
                         'executed': None, 'failed': None, 'unexecuted': None,
                          'disposition': ('terminal-boolean-case-observation' if boolean_observation else 'terminal-pre-case-log-read-failure' if pre_case_log_failure else 'terminal-equal-role-capture' if equal_roles else 'terminal-failed-diagnostic-pairs' if diagnostic_pairs else
                                          'terminal-accepted-build-capture-failure' if capture_failure else
                                          'terminal-incomplete-role-scope' if incomplete_roles else 'terminal-observation-without-test-scope'),
                         'observedCompleted': record.get('completed'), 'observedTotal': record.get('total'),
                         'producerRecordPinMissing': missing_producer_pin,
                          'unprovenReasons': ['case-oracles-unrecorded' if boolean_observation else 'case-results-unrecorded' if pre_case_log_failure else 'legacy-diagnostic-oracle-unverified' if diagnostic_pairs or equal_roles else
                                              'build-capture-failed' if capture_failure else
                                              'paired-case-incomplete' if incomplete_roles else 'test-scope-missing'] +
                          (['producer-record-unpinned'] if missing_producer_pin else []),
                          **({'captureFailureEvidence': capture_failure} if capture_failure else {})})
            continue
        pre_case_failure = (legacy_terminal and record['status'] == 'failed' and record.get('completed') == 0
                            and cases == [] and isinstance(record.get('failure'), str) and bool(record['failure'])
                            and isinstance(processes, list) and any(type(row.get('exit', row.get('exitCode'))) is int
                                and row.get('exit', row.get('exitCode')) != 0 for row in processes if isinstance(row, dict)))
        if not isinstance(cases, list) or (not cases and not pre_case_failure) or not all(isinstance(row, dict) for row in cases) or type(record.get('total')) is not int or type(record.get('completed')) is not int or record['total'] < 0:
            raise ValueError('ARTIFACT_CONSUMER_CASE_COVERAGE_INVALID')
        done = sum(row.get('passed', row.get('status') == 'passed') is True for row in cases)
        legacy_failed_cases = [row for row in cases if legacy_terminal and record['status'] == 'failed'
                               and row.get('status') is None and row.get('passed') is False
                               and any(type(row.get(key)) is int and row[key] != 0 for key in ('buildExit', 'runExit'))]
        # Source diagnostic observers can record exact string oracles and boolean
        # outcomes without case-level process exits. Their owned processes must
        # all have exited successfully. Admit only retirement of the separately
        # verified compiler; preserve the observer and its original result.
        diagnostic_observation_cases = cases if (legacy_terminal and len(cases) == record['total']
            and cases and record['completed'] == done
            and (record['status'] == 'passed') == (done == record['total'])
            and isinstance(record.get('processes'), list) and record['processes']
            and all(isinstance(process, dict) and type(process.get('exit')) is int
                    and process['exit'] == 0 for process in record['processes'])
            and all('status' not in case and type(case.get('passed')) is bool
                    and isinstance(case.get('actualDiagnostic'), str)
                    and isinstance(case.get('expectedDiagnostic'), str) and bool(case['expectedDiagnostic'])
                    and case['passed'] is (case['actualDiagnostic'] == case['expectedDiagnostic'])
                    and not any(key in case for key in ('roles', 'managed', 'selfhost',
                        'buildExit', 'runExit', 'buildExitCode', 'runExitCode', 'compileExit'))
                    and not any(case.get(key) for key in ('timedOut', 'timeout', 'failureId',
                        'failureIds', 'canceled', 'cancelled', 'activeProcess', 'activeProcessIds', 'running'))
                    for case in cases)) else []
        failed = sum(row.get('status') == 'failed' or row in legacy_failed_cases
                     or row in diagnostic_observation_cases and row['passed'] is False for row in cases)
        # The shared completion contract also accepts explicit passed=True cases.
        # Preserve that representation without rewriting immutable consumer records;
        # this path requires the entire record, including negative oracles, to pass.
        fully_completed = completed(record)
        attempted_runner = legacy_terminal and terminal_attempted_runner_capture(repo, path, record)
        if not all((row.get('status') in ('passed', 'failed') and row.get('passed', row['status'] == 'passed') is (row['status'] == 'passed'))
                   or (fully_completed and 'status' not in row and row.get('passed') is True
                       and type(row.get('buildExit', row.get('buildExitCode', row.get('compileExit')))) is int
                       and not any(key in row for key in ('roles', 'managed', 'selfhost')))
                   or (legacy_terminal and fully_completed and observed_cli_case_completed(row))
                   or row in legacy_failed_cases or row in diagnostic_observation_cases for row in cases) or record['completed'] != (len(cases) if attempted_runner else done) or not (0 <= len(cases) <= record['total'] if pre_case_failure else 0 < len(cases) <= record['total']):
            raise ValueError('ARTIFACT_CONSUMER_CASE_COVERAGE_INVALID')
        missing_expectations = missing_negative_consumer_expectations(record) if record['status'] == 'passed' and not completed(record) else []
        if record['status'] == 'passed' and not completed(record) and not missing_expectations and not unpaired_start_pins or record['status'] == 'failed' and not failed and not input_drift and not pre_case_failure:
            raise ValueError('ARTIFACT_CONSUMER_CASE_OUTCOME_INVALID')
        processes = record.get('processes')
        if processes is None and legacy_terminal:
            processes = legacy_paired_processes(repo, path, record, Path(producer['compilerPath']))
        if not isinstance(processes, list) or not processes or not all(terminal_consumer_process(repo, path.parent, row) for row in processes):
            raise ValueError('ARTIFACT_CONSUMER_PROCESS_EXIT_MISSING')
        assert_output_shutdown(repo, path.parent)
        row = {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
               'status': record['status'], 'completed': 0 if input_drift else done, 'total': record['total'],
               'executed': len(cases), 'failed': failed, 'unexecuted': record['total'] - len(cases)}
        if input_drift:
            # Retire only the independently verified compiler product. The
            # consumer's changed inputs prove no completed verification; its
            # result and failed output remain owned by the consumer directory.
            row.update(disposition='terminal-input-drift', observedPassed=done)
        if missing_expectations:
            row.update(completed=0, disposition='terminal-unproven-negative-expectations',
                       observedPassed=done, missingExpectedExitCaseIds=missing_expectations)
        if missing_producer_pin:
            row.update(completed=0, disposition='terminal-producer-record-unpinned', observedPassed=done,
                       producerRecordPinMissing=True)
        if pre_case_failure:
            row.update(completed=0, disposition='terminal-pre-case-failure', observedPassed=0)
        if legacy_failed_cases:
            row.update(completed=0, disposition='terminal-unstructured-failed-case', observedPassed=done)
        if diagnostic_observation_cases:
            row.update(completed=0, disposition='terminal-flat-diagnostic-observation', observedPassed=done)
        if attempted_runner:
            row.update(completed=0, disposition='terminal-attempted-count-runner',
                       observedPassed=done, observedAttempted=len(cases))
        if unpaired_start_pins:
            # Legacy start-only snapshots prove terminal binary consumption,
            # never successful verification or eligibility of consumer outputs.
            row.update(completed=0, disposition='terminal-unpaired-input-fingerprint', observedPassed=done)
        if legacy_terminal:
            row['unprovenReasons'] = [reason for condition, reason in (
                (unpaired_start_pins, 'input-end-fingerprint-missing'),
                (input_drift, 'input-drift'), (bool(missing_expectations), 'negative-expectations-missing'),
                (missing_producer_pin, 'producer-record-unpinned'), (pre_case_failure, 'pre-case-failure'),
                (bool(legacy_failed_cases), 'unstructured-failed-case'),
                (bool(diagnostic_observation_cases), 'diagnostic-observation-retirement-only')) if condition]
            if attempted_runner:
                row['unprovenReasons'].append('attempted-count-runner-retirement-only')
        rows.append(row)
    return {'schemaVersion': 1, 'status': 'retiredCompleted', 'verificationFailed': any(row['status'] in ('failed', 'timed-out', 'mismatch') for row in rows),
            'pipelineAborted': any(row['unexecuted'] is None or row['unexecuted'] > 0 or row.get('disposition') in ('terminal-input-drift', 'terminal-unproven-negative-expectations', 'terminal-producer-record-unpinned', 'terminal-pre-case-failure', 'terminal-unstructured-failed-case', 'terminal-flat-diagnostic-observation', 'terminal-attempted-count-runner') for row in rows), 'retiredCompleted': True,
            'build': references[0], 'replacementBuild': references[1], 'consumers': rows,
            **({'evidenceMode': 'legacy-binary-pinned-terminal'} if legacy_terminal else {}),
            'purpose': 'compiler-product-retirement-only; incomplete verification is not completion'}


def protect_legacy_consumer_outputs(repo: Path, closure: Path, record: dict) -> None:
    """Keep consumer outputs unverified; do not rewrite their result records."""
    closure_hash = hashlib.sha256(closure.read_bytes()).hexdigest()
    for row in record['consumers']:
        if row['completed'] != 0:
            continue
        result = assert_artifact_path(repo, Path(row['path']))
        marker = assert_artifact_path(repo, result.parent / 'consumer-retirement-protection.json')
        expected_consumer = {'path': str(result), 'sha256': row['sha256']}
        protection = {'schemaVersion': 1, 'purpose': 'preserve-unverified-consumer-output',
                      'consumerResult': expected_consumer, 'closures': {}}
        if marker.exists():
            protection = json.loads(marker.read_text(encoding='utf-8-sig'))
            if protection.get('schemaVersion') != 1 or protection.get('consumerResult') != expected_consumer or not isinstance(protection.get('closures'), dict):
                raise ValueError('ARTIFACT_CONSUMER_PROTECTION_CONFLICT')
        protection['closures'][str(closure)] = closure_hash
        pending = assert_artifact_path(repo, marker.with_suffix('.json.pending'))
        pending.write_text(json.dumps(protection, indent=2) + '\n', encoding='utf-8')
        pending.replace(marker)


def unverified_consumer_protected(output: Path) -> bool:
    return any((output / name).exists() for name in
               ('consumer-retirement-protection.json', 'consumer-retirement-protection.json.pending'))


def close_compiler_consumers(repo: Path, output: Path, consumers: list[Path], replacement: Path, *, legacy_terminal: bool = False) -> Path:
    record = consumer_closure_record(repo, output, consumers, replacement, legacy_terminal=legacy_terminal)
    path = assert_artifact_path(repo, output / 'consumer-closure.json')
    if path.exists():
        if json.loads(path.read_text(encoding='utf-8-sig')) != record:
            raise ValueError('ARTIFACT_CONSUMER_CLOSURE_ALREADY_DIFFERENT')
    else:
        with path.open('x', encoding='utf-8') as stream:
            stream.write(json.dumps(record, indent=2) + '\n')
    if legacy_terminal:
        protect_legacy_consumer_outputs(repo, path, record)
    return path


def verified_consumer_closure(repo: Path, output: Path, *, allow_missing_product: bool = False,
                              retirement_chain: frozenset[Path] = frozenset()) -> dict:
    output = assert_artifact_path(repo, output)
    if output in retirement_chain:
        raise ValueError('ARTIFACT_CONSUMER_REPLACEMENT_CYCLE')
    retirement_chain = retirement_chain | {output}
    path = assert_artifact_path(repo, output / 'consumer-closure.json')
    record = json.loads(path.read_text(encoding='utf-8-sig'))
    current = consumer_closure_record(repo, output, [Path(row['path']) for row in record['consumers']],
                                      Path(record['replacementBuild']['path']).parent,
                                      allow_missing_product=allow_missing_product,
                                      legacy_terminal=record.get('evidenceMode') == 'legacy-binary-pinned-terminal',
                                      retired_replacement_chain=retirement_chain)
    if record != current:
        raise ValueError('ARTIFACT_CONSUMER_CLOSURE_CHANGED')
    if record.get('evidenceMode') == 'legacy-binary-pinned-terminal':
        closure_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        for row in record['consumers']:
            if row['completed'] != 0:
                continue
            marker = assert_artifact_path(repo, Path(row['path']).parent / 'consumer-retirement-protection.json')
            if not marker.is_file():
                raise ValueError('ARTIFACT_CONSUMER_PROTECTION_MISSING')
            protection = json.loads(marker.read_text(encoding='utf-8-sig'))
            if (protection.get('schemaVersion') != 1
                    or protection.get('consumerResult') != {'path': row['path'], 'sha256': row['sha256']}
                    or protection.get('closures', {}).get(str(path)) != closure_hash):
                raise ValueError('ARTIFACT_CONSUMER_PROTECTION_CHANGED')
    return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def create_plan(repo: Path, root: Path, minimum_age_hours: float = 1, active: set[str] | None = None, preserve_all_compilers: bool = False, selected_outputs: set[str] | None = None,
                reusable_directories: list[Path] | None = None, retention_terminal: bool = False, temporary_only: bool = False, linked_evidence_paths: list[Path] | None = None) -> dict:
    policy = load_policy()
    root = assert_artifact_path(repo, root, allow_root=True)
    active = windows_active_directories(root) if active is None else active
    eligible = []
    inventory = []
    excluded = collections.Counter()
    for directory in sorted(root.iterdir()):
        if selected_outputs is not None and str(directory) not in selected_outputs:
            continue
        if not directory.is_dir():
            continue
        if unverified_consumer_protected(directory):
            excluded['unverified-consumer'] += 1
            inventory.append({'output': str(directory), 'category': 'unverified-consumer-protected'})
            continue
        if reparse(directory):
            excluded['reparse'] += 1
            continue
        if str(directory).casefold() in active:
            excluded['active'] += 1
            inventory.append({'output': str(directory), 'category': 'active-protected'})
            continue
        record_path = directory / 'result.json'
        if not record_path.is_file():
            excluded['no-completion-record'] += 1
            if (directory / 'compiler.exe').is_file():
                inventory.append({'output': str(directory), 'category': 'missing-record-protected'})
            continue
        if reparse(record_path):
            excluded['reparse'] += 1
            continue
        try:
            record = json.loads(record_path.read_text(encoding='utf-8-sig'))
        except (OSError, ValueError):
            excluded['invalid-record'] += 1
            continue
        linked = linked_retention_evidence(repo, directory, linked_evidence_paths or [], retention_terminal) if isinstance(record, dict) and not record.get('status') else None
        terminal_retention = (isinstance(record, dict) and retention_terminal
                              and record.get('status') in policy['terminalRetentionStatuses']
                              and not terminal_input_drift(record, directory)
                              and not active_record(record))
        if not isinstance(record, dict) or (not completed(record) and not terminal_retention and not linked):
            excluded['not-verified-complete'] += 1
            inventory.append({'output': str(directory), 'category': 'unverified-protected', 'recordStatus': record.get('status') if isinstance(record,dict) else None})
            continue
        if minimum_age_hours > 0 and time.time() - record_path.stat().st_mtime < minimum_age_hours * 3600:
            excluded['recent'] += 1
            continue
        if linked:
            record = dict(record, _linkedRetentionEvidence=linked)
        if retention_terminal and record.get('pendingConsumerProtection') and (directory / 'consumer-closure.json').is_file():
            try:
                closure = verified_consumer_closure(repo, directory)
                record = dict(record, _consumerClosureEvidence=closure)
            except (ValueError, OSError, KeyError, TypeError):
                excluded['consumer-closure-invalid'] += 1
        eligible.append((directory, record_path, record))
        inventory.append({'output': str(directory), 'category': 'consumer-retired' if record.get('_consumerClosureEvidence') else ('terminal-retention' if terminal_retention else 'verified-complete'), 'recordStatus': record.get('status')})
    declared = default_reusable_directories(repo) if reusable_directories is None else reusable_directories
    protected = {str(assert_artifact_path(repo, Path(path))) for path in declared}
    if any(str(directory) in protected and record.get('status') in policy['terminalRetentionStatuses']
           for directory, _, record in eligible):
        raise ValueError('ARTIFACT_CAPACITY_RETAINED_NOT_REUSABLE')
    for directory, _, record in eligible:
        if record.get('_consumerClosureEvidence'):
            closure = json.loads((directory / 'consumer-closure.json').read_text(encoding='utf-8-sig'))
            protected.add(str(Path(closure['replacementBuild']['compilerPath']).parent))
    if preserve_all_compilers:
        protected.update(str(row[0]) for row in eligible if completed(row[2]) and (row[0] / 'compiler.exe').is_file())
    if len(protected) > policy['maximumReusableCompilers']:
        raise ValueError('ARTIFACT_REUSABLE_COMPILER_LIMIT_EXCEEDED')
    targets = []
    directory_targets = []
    records = []
    for directory, record_path, record in eligible:
        try:
            # Terminal output retention is evidence preservation, never permission to
            # delete failed/cancelled artifacts. Only an independently passed build's
            # verified consumer closure authorizes product retirement.
            retained = record.get('status') in policy['terminalRetentionStatuses'] or bool(record.get('_linkedRetentionEvidence')
                                                   and not completed(record))
            generated = [] if retained else generated_targets(repo, directory, str(directory) in protected)
            if temporary_only or record.get('pendingConsumerProtection') and not record.get('_consumerClosureEvidence'):
                generated = [r for r in generated if any(part.endswith('.slg-tmp') for part in Path(r['path']).parts)]
        except ValueError:
            excluded['reparse-subtree'] += 1
            continue
        # Do not remove a product written after the successful completion record.
        if any(row['modifiedNs'] > record_path.stat().st_mtime_ns for row in generated):
            excluded['changed-after-completion'] += 1
            continue
        targets.extend(generated)
        if not retained:
            directory_targets.extend(owned_directory_targets(repo, directory, generated, str(directory) in protected, temporary_only or bool(record.get('pendingConsumerProtection') and not record.get('_consumerClosureEvidence'))))
        records.append({'path': str(record_path), 'sha256': hashlib.sha256(record_path.read_bytes()).hexdigest(), 'output': str(directory),
                        'disposition': 'consumer-retired' if record.get('_consumerClosureEvidence') else ('linked-retention' if record.get('_linkedRetentionEvidence') else ('verified-complete' if completed(record) else 'terminal-retention')), 'consumerClosure': record.get('_consumerClosureEvidence'), 'linkedEvidence': record.get('_linkedRetentionEvidence'), 'recordStatus': record.get('status'), 'pendingConsumerProtection': bool(record.get('pendingConsumerProtection'))})
    return {'schemaVersion': 1, 'status': 'prepared', 'repoRoot': str(repo), 'root': str(root),
            'createdAt': dt.datetime.now().astimezone().isoformat(), 'completionRecords': records,
            'protectedCompilerDirectories': sorted(protected), 'excluded': dict(excluded), 'outputInventory': inventory,
            'maximumReusableCompilers': policy['maximumReusableCompilers'], 'policySha256': hashlib.sha256(POLICY.read_bytes()).hexdigest(),
            'directories': len(directory_targets), 'directoryTargets': directory_targets, 'files': len(targets), 'logicalBytes': sum(row['bytes'] for row in targets), 'targets': targets}


def validate_plan(plan: dict) -> None:
    if plan.get('schemaVersion') != 1 or plan.get('status') != 'prepared':
        raise ValueError('ARTIFACT_PLAN_INVALID')
    if plan.get('policySha256') != hashlib.sha256(POLICY.read_bytes()).hexdigest():
        raise ValueError('ARTIFACT_POLICY_CHANGED')
    repo = Path(plan['repoRoot'])
    root = assert_artifact_path(repo, Path(plan['root']), allow_root=True)
    protected = {str(assert_artifact_path(repo, Path(p))) for p in plan['protectedCompilerDirectories']}
    if len(protected) > load_policy()['maximumReusableCompilers']:
        raise ValueError('ARTIFACT_REUSABLE_COMPILER_LIMIT_EXCEEDED')
    outputs = {}
    active = windows_active_directories(root)
    for receipt in plan['completionRecords']:
        output = assert_artifact_path(repo, Path(receipt['output']))
        if unverified_consumer_protected(output):
            raise ValueError('ARTIFACT_UNVERIFIED_CONSUMER_PROTECTED')
        path = assert_artifact_path(repo, Path(receipt['path']))
        if root not in output.parents or path != output / 'result.json' or str(output).casefold() in active:
            raise ValueError('ARTIFACT_OUTPUT_OWNERSHIP_OR_ACTIVE')
        if hashlib.sha256(path.read_bytes()).hexdigest() != receipt['sha256']:
            raise ValueError('ARTIFACT_COMPLETION_RECORD_CHANGED')
        record = json.loads(path.read_text(encoding='utf-8-sig'))
        if receipt['disposition'] == 'consumer-retired':
            if not record.get('pendingConsumerProtection') or verified_consumer_closure(repo, output, allow_missing_product=True) != receipt.get('consumerClosure'):
                raise ValueError('ARTIFACT_CONSUMER_CLOSURE_INVALID')
        elif receipt['disposition'] == 'verified-complete':
            if not completed(record):
                raise ValueError('ARTIFACT_NOT_COMPLETED')
        elif receipt['disposition'] == 'linked-retention':
            evidence = receipt.get('linkedEvidence')
            if not evidence or linked_retention_evidence(repo, output, [Path(evidence['path'])], True, evidence['compilerSha256']) != evidence:
                raise ValueError('ARTIFACT_LINKED_EVIDENCE_INVALID')
        elif receipt['disposition'] == 'terminal-retention':
            if (record.get('status') not in load_policy()['terminalRetentionStatuses'] or active_record(record)
                    or terminal_input_drift(record, output)):
                raise ValueError(json.dumps({'failureId': 'ARTIFACT_RETENTION_NOT_TERMINAL', 'output': str(output), 'recordPath': str(path), 'disposition': receipt['disposition']}, ensure_ascii=False))
        else:
            raise ValueError('ARTIFACT_DISPOSITION_INVALID')
        outputs[str(output)] = output
    if plan['files'] != len(plan['targets']) or plan['logicalBytes'] != sum(x['bytes'] for x in plan['targets']):
        raise ValueError('ARTIFACT_PLAN_COUNTS_INVALID')
    for target in plan['targets']:
        path = assert_artifact_path(repo, Path(target['path']))
        output = outputs.get(target['output'])
        if output is None or output not in path.parents:
            raise ValueError('ARTIFACT_TARGET_WITHOUT_VERIFIED_OWNER')
        if has_nested_output_owner(path, output):
            raise ValueError('ARTIFACT_TARGET_NESTED_OUTPUT_OWNER')
        if any(row['output'] == str(output) and row['disposition'] in ('terminal-retention', 'linked-retention') for row in plan['completionRecords']):
            raise ValueError('ARTIFACT_TERMINAL_OUTPUT_PROTECTED')
        if json.loads((output / 'result.json').read_text(encoding='utf-8-sig')).get('pendingConsumerProtection') and not any(part.endswith('.slg-tmp') for part in path.parts) and not any(row['output'] == str(output) and row['disposition'] == 'consumer-retired' for row in plan['completionRecords']):
            raise ValueError('ARTIFACT_PENDING_CONSUMER_PROTECTED')
        in_cache = '.sollang-cache' in path.parts
        if path.suffix.lower() in load_policy()['preservedExtensions'] or (not in_cache and not GENERATED.search(path.name)):
            raise ValueError('ARTIFACT_TARGET_NOT_GENERATED')
        if str(output) in protected and (path == output / 'compiler.exe' or in_cache):
            raise ValueError('ARTIFACT_TARGET_REUSABLE_PROTECTED')
        if not path.exists():
            continue  # Idempotent resume retains the original hashes in the immutable plan.
        st = path.stat()
        if st.st_nlink > 1:
            raise ValueError('ARTIFACT_HARDLINK_SHARED')
        if st.st_size != target['bytes'] or st.st_mtime_ns != target['modifiedNs'] or hashlib.sha256(path.read_bytes()).hexdigest() != target['sha256']:
            raise ValueError('ARTIFACT_TARGET_CHANGED')

    directories = plan.get('directoryTargets', [])
    if plan.get('directories', 0) != len(directories):
        raise ValueError('ARTIFACT_DIRECTORY_COUNTS_INVALID')
    owned_files = {str(Path(row['path'])) for row in plan['targets']}
    owned_directories = {str(Path(row['path'])) for row in directories}
    for target in directories:
        path = assert_artifact_path(repo, Path(target['path']))
        output = outputs.get(target['output'])
        if output is None or output not in path.parents:
            raise ValueError('ARTIFACT_DIRECTORY_WITHOUT_VERIFIED_OWNER')
        if has_nested_output_owner(path, output) or (path / 'result.json').exists():
            raise ValueError('ARTIFACT_DIRECTORY_NESTED_OUTPUT_OWNER')
        if any(row['output'] == str(output) and row['disposition'] in ('terminal-retention', 'linked-retention') for row in plan['completionRecords']):
            raise ValueError('ARTIFACT_TERMINAL_OUTPUT_PROTECTED')
        relative = path.relative_to(output)
        in_cache = '.sollang-cache' in relative.parts
        in_temporary = any(part.endswith('.slg-tmp') for part in relative.parts)
        if not (in_cache or in_temporary) or target.get('kind') not in load_policy()['ownedGeneratedDirectoryKinds'] or target.get('kind') != ('private-cache' if in_cache else 'partition-temporary'):
            raise ValueError('ARTIFACT_DIRECTORY_NOT_PRIVATE_GENERATED')
        if str(output) in protected and in_cache:
            raise ValueError('ARTIFACT_DIRECTORY_REUSABLE_PROTECTED')
        record = json.loads((output / 'result.json').read_text(encoding='utf-8-sig'))
        if record.get('pendingConsumerProtection') and not in_temporary and not any(row['output'] == str(output) and row['disposition'] == 'consumer-retired' for row in plan['completionRecords']):
            raise ValueError('ARTIFACT_PENDING_CONSUMER_PROTECTED')
        if not path.exists():
            continue
        if not path.is_dir():
            raise ValueError('ARTIFACT_DIRECTORY_CHANGED')
        for child in path.iterdir():
            assert_artifact_path(repo, child)
            if str(child) not in (owned_directories if child.is_dir() else owned_files):
                raise ValueError('ARTIFACT_DIRECTORY_UNOWNED_CONTENT')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--root', type=Path)
    parser.add_argument('--output-directory', type=Path)
    parser.add_argument('--plan', type=Path)
    parser.add_argument('--validate-output', type=Path)
    parser.add_argument('--minimum-age-hours', type=float, default=1)
    parser.add_argument('--preserve-all-compilers', action='store_true')
    parser.add_argument('--temporary-only', action='store_true')
    parser.add_argument('--keep-compiler', action='store_true')
    parser.add_argument('--retention-terminal', action='store_true')
    parser.add_argument('--reusable-directory', type=Path, action='append')
    parser.add_argument('--validate-plan', type=Path)
    parser.add_argument('--linked-evidence', type=Path, action='append')
    parser.add_argument('--close-consumers', type=Path)
    parser.add_argument('--consumer-result', type=Path, action='append')
    parser.add_argument('--replacement-build', type=Path)
    parser.add_argument('--legacy-terminal-consumers', action='store_true')
    parser.add_argument('--validate-consumer-closure', type=Path)
    args = parser.parse_args()
    repo = Path(os.path.abspath(args.repo))
    if args.legacy_terminal_consumers and not args.close_consumers:
        parser.error('--legacy-terminal-consumers requires --close-consumers')
    if args.validate_consumer_closure:
        print(json.dumps(verified_consumer_closure(repo, args.validate_consumer_closure, allow_missing_product=True)))
        return 0
    if args.close_consumers:
        if not args.consumer_result or not args.replacement_build:
            parser.error('--close-consumers requires --consumer-result and --replacement-build')
        print(close_compiler_consumers(repo, args.close_consumers, args.consumer_result, args.replacement_build,
                                      legacy_terminal=args.legacy_terminal_consumers))
        return 0
    if args.validate_plan:
        validate_plan(json.loads(args.validate_plan.read_text(encoding='utf-8-sig')))
        print('ARTIFACT_PLAN_VALIDATED')
        return 0
    if args.validate_output:
        initialize_output(repo, args.validate_output, reusable_directories=args.reusable_directory)
        return 0
    if args.plan is None:
        parser.error('--plan is required when preparing cleanup')
    if args.output_directory:
        output = assert_artifact_path(repo, args.output_directory)
        if args.keep_compiler:
            args.reusable_directory = list(args.reusable_directory if args.reusable_directory is not None else default_reusable_directories(repo))
            if output not in args.reusable_directory:
                args.reusable_directory.append(output)
        plan = create_plan(repo, output.parent, 0, preserve_all_compilers=args.preserve_all_compilers, selected_outputs={str(output)},
                           reusable_directories=args.reusable_directory, retention_terminal=args.retention_terminal, linked_evidence_paths=args.linked_evidence)
        plan['completionRecords'] = [r for r in plan['completionRecords'] if Path(r['output']) == output]
        plan['targets'] = [r for r in plan['targets'] if output in Path(r['path']).parents]
        plan['directoryTargets'] = [r for r in plan['directoryTargets'] if output in Path(r['path']).parents]
        plan['directories'] = len(plan['directoryTargets'])
        plan['files'] = len(plan['targets'])
        plan['logicalBytes'] = sum(r['bytes'] for r in plan['targets'])
    else:
        plan = create_plan(repo, args.root or repo / 'artifacts/scratch', args.minimum_age_hours,
                           preserve_all_compilers=args.preserve_all_compilers, reusable_directories=args.reusable_directory,
                           retention_terminal=args.retention_terminal, linked_evidence_paths=args.linked_evidence)
    if args.temporary_only:
        plan['targets'] = [r for r in plan['targets'] if any(part.endswith('.slg-tmp') for part in Path(r['path']).parts)]
        plan['directoryTargets'] = [r for r in plan['directoryTargets'] if any(part.endswith('.slg-tmp') for part in Path(r['path']).parts)]
        plan['directories'] = len(plan['directoryTargets'])
        plan['files'] = len(plan['targets'])
        plan['logicalBytes'] = sum(r['bytes'] for r in plan['targets'])
    args.plan.parent.mkdir(parents=True, exist_ok=True)
    args.plan.write_text(json.dumps(plan, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: plan[k] for k in ('status','files','logicalBytes','excluded')}, ensure_ascii=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
