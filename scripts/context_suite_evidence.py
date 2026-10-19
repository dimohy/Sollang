"""Consume existing focused suite executions without compiling them again."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from verification_source_proof import current_build_inputs
from completed_artifact_plan import assert_artifact_path


SUITE = '1999-selfhost-context-fixture-suite'
FIXTURES = ('1000-selfhost-partition-route-type-invariant',
            '1100-selfhost-enum-match-variant-invariant',
            '1126-selfhost-console-emission-invariant',
            '1290-selfhost-provisional-unit-match-invariant')


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError('CONTEXT_SUITE_' + code)


def suite_required_inputs(repo: Path, fixture_sources, fixture_manifests) -> list[Path]:
    paths = [f'examples/regression/{SUITE}.slg',
             f'examples/regression/expected/{SUITE}.sources.txt',
             f'examples/regression/expected/{SUITE}.stdout.txt',
             'scripts/generate-context-fixture-suite.py',
             'selfhost/llvm/emitter/context.slg', 'selfhost/llvm/text/foundation.slg',
             'selfhost/llvm/text/context_prepare.slg', 'selfhost/semantic/diagnostics.slg',
             'selfhost/llvm/emitter/diagnostics.slg',
             *fixture_sources, *fixture_manifests,
             *(f'examples/regression/expected/{Path(source).stem}.stdout.txt'
               for source in fixture_sources)]
    return list(dict.fromkeys((repo / path).resolve() for path in paths))


def validate_focused_suite(repo: Path, references: dict, compiler: Path,
                           required_paths: list[Path]) -> dict:
    """Validate explicit managed, paired and producer records for the original suite."""
    require(set(references) == {'managed', 'paired', 'build'}, 'REFERENCES')
    records, paths = {}, {}
    for role, reference in references.items():
        require(isinstance(reference, dict) and set(reference) == {'path', 'sha256'}, 'REFERENCE')
        path = (repo / reference['path']).resolve()
        if role == 'build':
            # Native products share the lifecycle's configured workspace/external
            # roots. Execution records remain repository-owned below.
            try:
                assert_artifact_path(repo, path)
            except ValueError as error:
                raise ValueError('CONTEXT_SUITE_RECORD_PATH') from error
        else:
            require(path.is_relative_to(repo / 'artifacts'), 'RECORD_PATH')
        require(path.is_file(), 'RECORD_PATH')
        require(sha(path) == reference['sha256'].upper(), 'RECORD_CHANGED')
        paths[role] = path
        records[role] = json.loads(path.read_text(encoding='utf-8-sig'))
    for role in ('managed', 'paired'):
        record = records[role]
        require(record.get('status') == 'passed' and record.get('mode') == role
                and record.get('completed') == record.get('total') == 1
                and record.get('inputsStable') is True
                and record.get('processesStopped') is True, 'EXECUTION_NOT_COMPLETE')
        require(len(record.get('cases', [])) == 1, 'CASE_COUNT')
        case = record['cases'][0]
        require(case.get('id') == SUITE and case.get('status') == 'passed'
                and case.get('passed') is True
                and case.get('expectedBuildExit') == case.get('buildExit') == 0
                and case.get('runExit') == 0
                and case.get('buildStderr') == case.get('runStderr') == '', 'CASE_OUTCOME')
    expected_path = repo / f'examples/regression/expected/{SUITE}.stdout.txt'
    expected = expected_path.read_text(encoding='utf-8-sig').strip()
    require(all(records[role]['cases'][0].get('runStdout') == expected
                for role in ('managed', 'paired')), 'EXACT_OUTPUT')
    lines = expected.splitlines()
    require(all(lines.count(f'{fixture}:begin') == lines.count(f'{fixture}:end') == 1
                for fixture in FIXTURES), 'FOUR_FIXTURE_MARKERS')
    compiler = compiler.resolve()
    build = records['build']
    require(compiler == paths['build'].parent / 'compiler.exe'
            and compiler.is_file() and build.get('status') == 'passed'
            and build.get('inputsStable') is True
            and build.get('compilerSha256') == sha(compiler)
            and all(build.get('steps', {}).get(step) == 0
                    for step in ('build', 'llvmAs', 'v004')), 'PRODUCER')
    current_build_inputs(repo, build)
    managed = Path(records['managed'].get('managedCompiler', '')).resolve()
    managed_dll = managed.with_suffix('.dll')
    require(managed.is_file() and managed_dll.is_file()
            and records['paired'].get('managedCompiler') == str(managed)
            and all(record.get('managedCompilerDllSha256') == sha(managed_dll)
                    and record['inputHashes'].get(str(managed)) == sha(managed)
                    and record['inputHashes'].get(str(managed_dll)) == sha(managed_dll)
                    for record in (records['managed'], records['paired']))
            and build.get('seedCompilerSha256') == sha(managed), 'MANAGED_IDENTITY')
    paired_pins = records['paired']['inputHashes']
    require(paired_pins.get(str(paths['managed'])) == sha(paths['managed'])
            and paired_pins.get(str(paths['build'])) == sha(paths['build'])
            and paired_pins.get(str(compiler)) == sha(compiler), 'PRODUCER_LINK')
    native_builds = [p for p in records['paired'].get('processes', [])
                     if p.get('command', [])[:2] == [str(compiler), 'build']]
    require(len(native_builds) == 1 and native_builds[0].get('exit') == 0
            and native_builds[0].get('shutdownConfirmed') is True, 'NATIVE_PROCESS')
    for role in ('managed', 'paired'):
        record = records[role]
        require(not record.get('activeProcess')
                and all(p.get('shutdownConfirmed') is True
                        for p in record.get('processes', [])), 'PROCESS_SHUTDOWN')
        for name, digest in record['inputHashes'].items():
            path = Path(name)
            require(path.is_file() and sha(path) == digest.upper(), 'LEASE_INPUT_DRIFT')
    checked = {}
    for path in [*required_paths, expected_path]:
        path = path.resolve()
        require(path.is_relative_to(repo) and path.is_file(), 'INPUT_PATH')
        digest = sha(path)
        require(all(records[role]['inputHashes'].get(str(path)) == digest
                    for role in ('managed', 'paired')), 'CURRENT_INPUT')
        checked[str(path)] = digest
    return {'fixtures': list(FIXTURES), 'currentInputHashes': checked,
            'compilerSha256': sha(compiler), 'references': references}
