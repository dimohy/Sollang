"""Reject stale or unsupported consumers before running the checked producer."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest

api = runpy.run_path(str(Path(__file__).with_name('verify-prebuilt-checked-emitter.py')))


class PrebuiltCheckedAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.artifacts = self.root / 'artifacts'
        self.artifacts.mkdir()
        self.product = self.artifacts / 'producer.exe'
        self.product.write_bytes(b'product')
        self.contract = self.root / 'contract.json'
        self.contract.write_text('{}')
        self.compiler = self.root / 'compiler.dll'
        self.compiler.write_bytes(b'compiler')
        sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper()
        self.proof = dict(status='passed', completed=1, total=1, inputsStable=True,
            processesStopped=True, product=str(self.product), productSha256=sha(self.product),
            inputHashes={str(path): sha(path) for path in [self.contract, self.compiler]})
        self.record = self.root / 'result.json'

    def admit(self, proof=None):
        self.record.write_text(json.dumps(proof or self.proof))
        return api['source_build_inputs'](self.record, self.contract, self.compiler, self.root)

    def test_current_product_and_exact_consumer_inputs_are_admitted(self):
        self.assertEqual(self.admit()[1], self.product)

    def test_failed_incomplete_or_live_source_build_is_rejected(self):
        for key, value in [('status','failed'), ('completed',0), ('processesStopped',False), ('inputsStable',False)]:
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'PROOF_INCOMPLETE'):
                self.admit(dict(self.proof, **{key:value}))

    def test_changed_product_is_rejected(self):
        self.product.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'PRODUCT_CHANGED'):
            self.admit()

    def test_changed_or_uncovered_contract_cannot_reuse_the_product(self):
        changed = copy.deepcopy(self.proof)
        del changed['inputHashes'][str(self.contract)]
        with self.assertRaisesRegex(ValueError, 'INPUT_NOT_COVERED'):
            self.admit(changed)
        self.contract.write_text('{"changed":true}')
        with self.assertRaisesRegex(ValueError, 'INPUT_NOT_COVERED'):
            self.admit()

    def test_changed_other_source_is_rejected(self):
        source = self.root / 'input.slg'
        source.write_bytes(b'changed')
        self.proof['inputHashes'][str(source)] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'SOURCE_INPUT_CHANGED'):
            self.admit()

    def test_unknown_checks_are_rejected_instead_of_ignored(self):
        contract = dict(schemaVersion=1, cases=[dict(stdout='30')])
        api['validate_consumer_contract'](contract)
        for unsupported in [dict(contract, runtimeInputFiles=['input']),
                            dict(schemaVersion=1, cases=[dict(stdout='30', runtimeSelection={})])]:
            with self.assertRaisesRegex(ValueError, 'UNSUPPORTED'):
                api['validate_consumer_contract'](unsupported)


if __name__ == '__main__':
    unittest.main()
