import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('verify-focused-case-projection.py')
spec = importlib.util.spec_from_file_location('focused_projection', SCRIPT)
projection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(projection)


class ProjectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.contract = self.root / 'contract.json'
        self.managed = self.root / 'managed.json'
        self.paired = self.root / 'paired.json'
        self.case = dict(id='control', source='control.slg', exit=0, stdout='expected', stderr='')
        self.write(self.contract, dict(cases=[self.case]))
        row = dict(id='control', passed=True, buildExit=0, buildStderr='', runExit=0, runStdout='expected', runStderr='')
        parent = dict(status='passed', completed=1, total=1, inputsStable=True, processesStopped=True,
                      cases=[row], inputHashes={str(self.contract): projection.sha(self.contract)})
        self.write(self.managed, dict(parent, mode='managed'))
        self.write(self.paired, dict(parent, mode='paired', inputHashes={**parent['inputHashes'], str(self.managed): projection.sha(self.managed)}))

    @staticmethod
    def write(path, value):
        path.write_text(json.dumps(value), encoding='utf-8')

    def verify(self):
        return projection.verify(self.contract, self.paired, self.managed)

    def test_exact_existing_execution(self):
        result = self.verify()
        self.assertEqual((result['completed'], result['total']), (1, 1))
        self.assertFalse(result['executionRepeated'])
        self.assertFalse(result['fullUnitClosure'])

    def test_false_pass_output_rejected(self):
        proof = projection.read(self.paired)
        proof['cases'][0]['runStdout'] = 'different'
        self.write(self.paired, proof)
        with self.assertRaisesRegex(ValueError, 'OUTPUT_MISMATCH'):
            self.verify()

    def test_unexecuted_contract_case_rejected(self):
        uncovered = self.root / 'uncovered.json'
        self.write(uncovered, dict(cases=[dict(self.case, id='missing')]))
        with self.assertRaisesRegex(ValueError, 'EXACT_CONTRACT_NOT_COVERED'):
            projection.verify(uncovered, self.paired, self.managed)

    def test_shared_noncontract_json_preserves_exact_contract_check(self):
        for value in ([1, 2], None, 3, {'cases': 'not-a-contract'}):
            with self.subTest(value=value):
                extra = self.root / 'unrelated.json'
                self.write(extra, value)
                managed = projection.read(self.managed)
                managed['inputHashes'][str(extra)] = projection.sha(extra)
                self.write(self.managed, managed)
                paired = projection.read(self.paired)
                paired['inputHashes'][str(extra)] = projection.sha(extra)
                paired['inputHashes'][str(self.managed)] = projection.sha(self.managed)
                self.write(self.paired, paired)
                self.assertEqual(self.verify()['completed'], 1)
                uncovered = self.root / 'uncovered-with-extra.json'
                self.write(uncovered, dict(cases=[dict(self.case, id='missing')]))
                with self.assertRaisesRegex(ValueError, 'EXACT_CONTRACT_NOT_COVERED'):
                    projection.verify(uncovered, self.paired, self.managed)

    def test_input_drift_rejected(self):
        self.write(self.contract, dict(cases=[dict(self.case, stdout='changed')]))
        with self.assertRaisesRegex(ValueError, 'PARENT_INPUT_DRIFT'):
            self.verify()


if __name__ == '__main__':
    unittest.main()
