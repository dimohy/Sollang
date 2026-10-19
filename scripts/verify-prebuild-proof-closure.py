"""Pin completed execution proofs and their shared current inputs before a build."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    plan_path, output = args.plan.resolve(), args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('PREBUILD_CLOSURE_FRESH_OUTPUT_REQUIRED')
    plan = json.loads(plan_path.read_text(encoding='utf-8-sig'))
    names = plan['proofs']
    if not names or len(names) != len(set(names)):
        raise ValueError('PREBUILD_CLOSURE_PROOF_SCOPE_INVALID')
    pins = {}
    rows = []
    for name in names:
        path = (ROOT / name).resolve()
        proof = json.loads(path.read_text(encoding='utf-8-sig'))
        if (proof.get('status') != 'passed' or not proof.get('inputsStable')
                or not proof.get('processesStopped') or type(proof.get('total')) is not int
                or proof['total'] <= 0 or proof.get('completed') != proof['total']
                or not proof.get('inputHashes')):
            raise ValueError('PREBUILD_CLOSURE_PROOF_INCOMPLETE: ' + name)
        for source, digest in proof['inputHashes'].items():
            source_path = Path(source)
            if not source_path.is_absolute() or sha(source_path) != digest:
                raise ValueError('PREBUILD_CLOSURE_INPUT_DRIFT: ' + source)
            if source in pins and pins[source] != digest:
                raise ValueError('PREBUILD_CLOSURE_INPUT_CONFLICT: ' + source)
            pins[source] = digest
        pins[str(path)] = sha(path)
        rows.append(dict(proof=str(path), completed=proof['completed'], total=proof['total']))
    for name in plan.get('evidenceInputs', []):
        path = (ROOT / name).resolve()
        pins[str(path)] = sha(path)
    pins.update({str(path): sha(path) for path in (plan_path, Path(__file__).resolve())})
    if any(sha(Path(name)) != digest for name, digest in pins.items()):
        raise ValueError('PREBUILD_CLOSURE_FINAL_INPUT_DRIFT')
    result = dict(schemaVersion=1, status='passed', scope='verified-prebuild-proof-closure',
                  completed=len(rows), total=len(rows), countMeaning='completed execution proof records',
                  inputsStable=True, processesStopped=True, inputHashes=pins, proofs=rows,
                  nativeBuildVerified=False, compilerStabilizationPromoted=False)
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('PREBUILD_PROOF_CLOSURE_PASSED', len(rows), '/', len(rows))


if __name__ == '__main__':
    main()
