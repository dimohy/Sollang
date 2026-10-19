"""Reject partial, reordered, drifting, or live-process focused receipts."""
import json
import tempfile
import unittest
from pathlib import Path
from verification_focused_proof import generic_proof, sha


class FocusedProof(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / 'source.slg'
        self.source.write_text('main {}')
        self.contract = self.root / 'contract.json'
        self.contract.write_text(json.dumps({'cases': [{'id': 'a'}, {'id': 'b'}]}))
        self.proof = {'status': 'passed', 'completed': 2, 'total': 2, 'mode': 'paired',
                      'inputsStable': True, 'processesStopped': True,
                      'cases': [{'id': 'a', 'passed': True}, {'id': 'b', 'passed': True}],
                      'inputHashes': {str(p.resolve()): sha(p) for p in (self.contract, self.source)}}
        self.path = self.root / 'proof.json'

    def verify(self):
        self.path.write_text(json.dumps(self.proof))
        return generic_proof(self.path, self.contract, 2, 'paired')

    def test_complete(self):
        self.assertEqual(self.verify()['completed'], 2)

    def test_partial(self):
        self.proof['completed'] = 1
        with self.assertRaisesRegex(ValueError, 'INCOMPLETE'):
            self.verify()

    def test_reordered(self):
        self.proof['cases'].reverse()
        with self.assertRaisesRegex(ValueError, 'CASE_COVERAGE'):
            self.verify()

    def test_source_drift(self):
        self.source.write_text('main { 1 -> println }')
        with self.assertRaisesRegex(ValueError, 'INPUT_DRIFT'):
            self.verify()

    def test_live_process(self):
        self.proof['processesStopped'] = False
        with self.assertRaisesRegex(ValueError, 'INCOMPLETE'):
            self.verify()


if __name__ == '__main__':
    unittest.main()
