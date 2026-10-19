"""Check current, exact-case evidence emitted by the focused compiler runner."""
import hashlib
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def generic_proof(path, contract, total, mode, prefix='FOCUSED_UNIT_'):
    def require(condition, failure):
        if not condition:
            raise ValueError(prefix + failure)
    proof = read(path)
    require(proof.get('status') == 'passed' and proof.get('completed') == total
            and proof.get('total') == total and proof.get('mode') == mode
            and proof.get('inputsStable') is True and proof.get('processesStopped') is True
            and len(proof.get('cases', [])) == total
            and all(case.get('passed') is True for case in proof['cases']), 'INCOMPLETE')
    pins = proof.get('inputHashes', {})
    require(pins.get(str(contract.resolve())) == sha(contract), 'CONTRACT_LINK')
    for name, expected in pins.items():
        source = Path(name)
        require(source.is_file() and sha(source) == expected, 'INPUT_DRIFT: ' + name)
    require([case['id'] for case in proof['cases']]
            == [case['id'] for case in read(contract)['cases']], 'CASE_COVERAGE')
    return proof
