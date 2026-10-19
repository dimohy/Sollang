"""Exercise compiler retirement checks against real supervised process records."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--consumer', type=Path, required=True)
    parser.add_argument('--paired-consumer', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    producer = ROOT / 'scripts/completed_artifact_plan.py'
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest().upper()
    paths = [producer, Path(__file__), args.consumer, args.paired_consumer]
    hashes = {str(p.resolve()): sha(p) for p in paths}
    spec = importlib.util.spec_from_file_location('artifact_plan', producer)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    actual = json.loads(args.consumer.read_text(encoding='utf-8-sig'))['processes']
    legacy = json.loads(args.paired_consumer.read_text(encoding='utf-8-sig'))['processes'][0]
    base = actual[0]
    changes = [
        ('running', {'status': 'running'}, False),
        ('missing-exit', {'exit': None}, False),
        ('shutdown-unconfirmed', {'processesStopped': False}, False),
        ('journal-content-drift', {'finishedAtUtc': 'modified'}, False),
        ('journal-missing', {'stdoutPath': str(args.consumer.parent.resolve() / 'missing.json.stdout.log'),
                             'stderrPath': str(args.consumer.parent.resolve() / 'missing.json.stderr.log')}, False),
        ('output-boundary', {'stdoutPath': str(args.paired_consumer.resolve()),
                             'stderrPath': str(args.paired_consumer.resolve())}, False),
    ]
    rows = []

    def check(name, row, expected, output):
        try:
            accepted = module.terminal_consumer_process(ROOT, output, row)
        except ValueError:
            accepted = False
        rows.append({'id': name, 'expectedAccepted': expected, 'accepted': accepted,
                     'passed': accepted is expected})

    for index, row in enumerate(actual):
        check(f'actual-process-{index}', row, True, args.consumer.parent)
    check('existing-paired-record', legacy, True, args.paired_consumer.parent)
    check('label-without-journal', {'status': 'passed', 'exit': 0}, False, args.consumer.parent)
    for name, delta, expected in changes:
        row = copy.deepcopy(base)
        row.update(delta)
        check(name, row, expected, args.consumer.parent)
    stable = hashes == {str(p.resolve()): sha(p) for p in paths}
    completed = sum(row['passed'] for row in rows)
    result = {'schemaVersion': 1, 'status': 'passed' if stable and completed == len(rows) else 'failed',
              'completed': completed, 'total': len(rows), 'inputsStable': stable,
              'inputHashes': hashes, 'scope': 'real-process-journals-and-retirement-rejection-controls',
              'cases': rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print(f"Consumer process journals: {result['status']} {completed}/{len(rows)}")
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
