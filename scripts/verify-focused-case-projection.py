"""Prove exact focused-contract coverage from an existing current paired execution."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def verify_managed_subset(contract_path, managed_path):
    """Reuse completed current managed cases without changing their execution contract."""
    contract, managed = map(read, (contract_path, managed_path))
    total = managed.get('total')
    rows = managed.get('cases', [])
    if (managed.get('status') != 'passed' or managed.get('mode') != 'managed'
            or type(total) is not int or total <= 0 or managed.get('completed') != total
            or len(rows) != total or len({row['id'] for row in rows}) != total
            or not managed.get('inputsStable') or not managed.get('processesStopped')):
        raise ValueError('MANAGED_PROJECTION_INCOMPLETE_PARENT')
    for name, expected in managed['inputHashes'].items():
        source = Path(name)
        if not source.is_file() or sha(source) != expected:
            raise ValueError('MANAGED_PROJECTION_PARENT_INPUT_DRIFT: ' + name)
    cases = contract.get('cases', [])
    ids = [case['id'] for case in cases]
    if not ids or len(set(ids)) != len(ids):
        raise ValueError('MANAGED_PROJECTION_EMPTY_OR_DUPLICATE_CASES')
    selected_sources = {name for case in cases for name in
                        [case['source'], *case.get('additionalSources', [])]}
    execution_contract = lambda value: {key: item for key, item in value.items()
                                        if key not in ('scope', 'cases', 'formatCheckSources')}
    frozen_path = None
    for name in managed['inputHashes']:
        path = Path(name)
        if path.suffix != '.json':
            continue
        frozen = read(path)
        frozen_cases = frozen.get('cases', []) if isinstance(frozen, dict) else []
        if (frozen_cases and all(isinstance(case, dict) and 'source' in case for case in frozen_cases)
                and all(case in frozen_cases for case in cases)
                and execution_contract(frozen) == execution_contract(contract)
                and contract.get('formatCheckSources', []) == [name for name in
                    frozen.get('formatCheckSources', []) if name in selected_sources]):
            frozen_path = path
            break
    if frozen_path is None:
        raise ValueError('MANAGED_PROJECTION_EXACT_CONTRACT_NOT_COVERED')
    by_id = {row['id']: row for row in rows}
    for case in cases:
        row = by_id.get(case['id'])
        if (row is None or row.get('passed') is not True
                or row.get('buildExit') != case['exit'] or row.get('buildStderr') != case['stderr']
                or (case['exit'] == 0 and (row.get('runExit') != 0
                    or row.get('runStdout') != case['stdout']
                    or row.get('runStderr') != case.get('runStderr', '')))):
            raise ValueError('MANAGED_PROJECTION_CASE_NOT_PASSED: ' + case['id'])
    return dict(mode='exact-current-managed-subset', completed=len(ids), total=len(ids),
                parentTotal=total, cases=ids, executionRepeated=False,
                frozenContract=str(frozen_path), managedProof=str(managed_path))


def project_managed_subset(contract_path, managed_path):
    coverage = verify_managed_subset(contract_path, managed_path)
    parent = read(managed_path)
    rows = {row['id']: row for row in parent['cases']}
    return dict(schemaVersion=1, status='passed', mode='managed',
                scope=read(contract_path).get('scope', 'Exact managed subset'),
                completed=coverage['completed'], total=coverage['total'],
                cases=[rows[name] for name in coverage['cases']],
                inputsStable=True, processesStopped=True, processes=[],
                executionEvidenceMode='projected-current-parent', executionRepeated=False,
                managedCompiler=parent.get('managedCompiler'),
                managedCompilerDllSha256=parent.get('managedCompilerDllSha256'),
                parentCoverage=coverage, fullUnitClosure=False,
                inputHashes={**parent['inputHashes'], **{str(path): sha(path) for path in
                             (contract_path, managed_path, Path(__file__).resolve())}})


def verify(contract_path, paired_path, managed_path):
    contract, paired, managed = map(read, (contract_path, paired_path, managed_path))
    for proof, mode in ((paired, 'paired'), (managed, 'managed')):
        if (proof.get('status') != 'passed' or proof.get('mode') != mode
                or proof.get('completed') != proof.get('total')
                or not proof.get('inputsStable') or not proof.get('processesStopped')):
            raise ValueError('FOCUSED_PROJECTION_INCOMPLETE_PARENT: ' + mode)
        for path, expected in proof['inputHashes'].items():
            source = Path(path)
            if not source.is_file() or sha(source) != expected:
                raise ValueError('FOCUSED_PROJECTION_PARENT_INPUT_DRIFT: ' + path)
    if paired['inputHashes'].get(str(managed_path)) != sha(managed_path):
        raise ValueError('FOCUSED_PROJECTION_MANAGED_LINEAGE_MISSING')
    shared_contracts = [Path(path) for path in paired['inputHashes']
                       if Path(path).suffix == '.json' and path in managed['inputHashes']
                       and Path(path).is_file()]
    candidates = []
    for path in shared_contracts:
        value = read(path)
        if (isinstance(value, dict) and isinstance(value.get('cases'), list)
                and value['cases']):
            candidates.append(path)
    frozen = None
    for candidate in candidates:
        rows = read(candidate)['cases']
        if all(isinstance(row, dict) and 'source' in row for row in rows):
            if all(case in rows for case in contract['cases']):
                frozen = candidate
                break
    if frozen is None:
        raise ValueError('FOCUSED_PROJECTION_EXACT_CONTRACT_NOT_COVERED')
    ids = [case['id'] for case in contract['cases']]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError('FOCUSED_PROJECTION_EMPTY_OR_DUPLICATE_CASES')
    for proof in (paired, managed):
        rows = {case['id']: case for case in proof['cases']}
        for case in contract['cases']:
            row = rows.get(case['id'])
            if row is None or not row.get('passed') or row.get('buildExit') != case['exit']:
                raise ValueError('FOCUSED_PROJECTION_CASE_NOT_PASSED: ' + case['id'])
            if row.get('buildStderr') != case['stderr']:
                raise ValueError('FOCUSED_PROJECTION_DIAGNOSTIC_MISMATCH: ' + case['id'])
            if case['exit'] == 0 and (row.get('runExit') != 0
                    or row.get('runStdout') != case['stdout'] or row.get('runStderr') != case.get('runStderr', '')):
                raise ValueError('FOCUSED_PROJECTION_OUTPUT_MISMATCH: ' + case['id'])
    return dict(schemaVersion=1, status='passed', mode='projected-focused-proof',
                completed=len(ids), total=len(ids), cases=ids,
                scope=contract.get('scope', 'Exact focused contract only'),
                executionRepeated=False, fullUnitClosure=False,
                inputHashes={str(path): sha(path) for path in
                             (contract_path, paired_path, managed_path, frozen, Path(__file__).resolve())})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contract', type=Path, required=True)
    parser.add_argument('--paired', type=Path)
    parser.add_argument('--managed-only', action='store_true',
                        help='Project exact completed current managed cases for an existing paired runner')
    parser.add_argument('--managed', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.managed_only == (args.paired is not None):
        parser.error('select exactly one of --paired or --managed-only')
    output = args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts') or output.suffix != '.json':
        raise ValueError('FOCUSED_PROJECTION_FRESH_ARTIFACT_JSON_REQUIRED')
    if args.managed_only:
        from verification_contract_lease import VerificationContractLease
        contract, managed = args.contract.resolve(), args.managed.resolve()
        parent_inputs = read(managed)['inputHashes']
        with VerificationContractLease([contract, managed, *map(Path, parent_inputs)]):
            if read(managed)['inputHashes'] != parent_inputs:
                raise ValueError('MANAGED_PROJECTION_PARENT_CHANGED')
            result = project_managed_subset(contract, managed)
            output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('MANAGED_PROJECTION_VERIFIED: ' + str(result['completed']) + '/' + str(result['total']))
        return
    result = verify(args.contract.resolve(), args.paired.resolve(), args.managed.resolve())
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('FOCUSED_PROJECTION_VERIFIED: ' + str(result['completed']) + '/' + str(result['total']))


if __name__ == '__main__':
    main()
