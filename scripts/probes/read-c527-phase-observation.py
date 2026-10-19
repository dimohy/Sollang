"""Read ordered diagnostic call returns; never promote compiler acceptance."""
import argparse
import hashlib
import json
from pathlib import Path


def summarize(plan, trace, owner):
    prefix = owner + '->'
    expected = [row['label'][len('before:'):] for row in plan['markers']
                if row['label'].startswith('before:' + prefix)]
    if not expected:
        raise ValueError('C527_PHASE_OWNER_HAS_NO_CALL_BOUNDARIES')
    completed, pending = 0, False
    for line in trace.splitlines(keepends=True):
        if not line.endswith('\n'):
            continue  # A live writer can be between the label and newline writes.
        line = line.rstrip('\r\n')
        if not (line.startswith('before:' + prefix) or line.startswith('after:' + prefix)):
            continue
        if completed >= len(expected):
            raise ValueError('C527_PHASE_OWNER_REENTERED_OR_EXTRA_EVENT')
        wanted = ('after:' if pending else 'before:') + expected[completed]
        if line != wanted:
            raise ValueError('C527_PHASE_CALL_ORDER_MISMATCH')
        if pending:
            completed += 1
        pending = not pending
    return dict(scope='diagnostic-only-not-acceptance', owner=owner,
                completed=completed, total=len(expected),
                percent=round(100 * completed / len(expected), 2),
                currentCall=expected[completed].split('->', 1)[1] if pending else None,
                allObservedCallsReturned=completed == len(expected))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--owner', required=True)
    args = parser.parse_args()
    result = json.loads((args.directory / 'result.json').read_text(encoding='utf-8-sig'))
    manifests = [Path(p) for p in result['inputHashes'] if p.endswith('.trace.json')]
    if len(manifests) != 1:
        raise ValueError('C527_PHASE_SINGLE_PINNED_MANIFEST_REQUIRED')
    manifest = manifests[0]
    digest = hashlib.sha256(manifest.read_bytes()).hexdigest().upper()
    if digest != result['inputHashes'][str(manifest)]:
        raise ValueError('C527_PHASE_MANIFEST_DRIFT')
    plan = json.loads(manifest.read_text())
    trace = (args.directory / 'worker.stderr').read_text(encoding='utf-8-sig')
    summary = summarize(plan, trace, args.owner)
    summary.update(executionStatus=result['status'],
                   traceBudgetExhausted=len(trace.splitlines()) >= plan['maximumRecords'])
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
