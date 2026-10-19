"""Current evidence reuse must preserve exact sources, oracles and execution settings."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).with_name('verify-focused-case-projection.py')
SPEC = importlib.util.spec_from_file_location('focused_projection', MODULE)
projection = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(projection)


class ManagedSubsetTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.source = root / 'program.slg'
        self.source.write_text('main {}', encoding='utf-8')
        self.frozen = root / 'original.json'
        self.contract = root / 'selected.json'
        self.proof = root / 'managed.json'
        cases = [dict(id=name, source=name + '.slg', exit=0, stderr='', stdout=name)
                 for name in ('a', 'b')]
        self.original = dict(schemaVersion=1, scope='original', cases=cases,
                             formatCheckSources=['a.slg', 'b.slg'])
        self.selected = dict(self.original, scope='selected', cases=[cases[1]],
                             formatCheckSources=['b.slg'])
        self.save(self.frozen, self.original)
        self.managed = dict(status='passed', mode='managed', completed=2, total=2,
                            inputsStable=True, processesStopped=True,
                            inputHashes={str(self.frozen): projection.sha(self.frozen),
                                         str(self.source): projection.sha(self.source)},
                            cases=[dict(id=case['id'], passed=True, buildExit=0, buildStderr='',
                                        runExit=0, runStdout=case['stdout'], runStderr='')
                                   for case in cases])

    @staticmethod
    def save(path, value):
        path.write_text(json.dumps(value), encoding='utf-8')

    def verify(self):
        self.save(self.contract, self.selected)
        self.save(self.proof, self.managed)
        return projection.verify_managed_subset(self.contract, self.proof)

    def test_current_exact_subset_reuses_without_execution(self):
        result = self.verify()
        self.assertEqual(result['cases'], ['b'])
        self.assertEqual(result['parentTotal'], 2)
        self.assertFalse(result['executionRepeated'])

    def test_projected_proof_keeps_parent_lineage_and_exact_case(self):
        self.verify()
        result = projection.project_managed_subset(self.contract, self.proof)
        self.assertEqual(result['mode'], 'managed')
        self.assertEqual(result['completed'], result['total'])
        self.assertEqual(result['cases'], [self.managed['cases'][1]])
        self.assertEqual(result['inputHashes'][str(self.proof)], projection.sha(self.proof))
        self.assertEqual(result['inputHashes'][str(self.contract)], projection.sha(self.contract))
        self.assertEqual(result['executionEvidenceMode'], 'projected-current-parent')
        self.assertFalse(result['executionRepeated'])

    def test_changed_expected_output_rejected(self):
        self.selected = copy.deepcopy(self.selected)
        self.selected['cases'][0]['stdout'] = 'different'
        with self.assertRaisesRegex(ValueError, 'EXACT_CONTRACT_NOT_COVERED'):
            self.verify()

    def test_changed_runtime_inputs_rejected(self):
        self.selected['runtimeInputFiles'] = ['different.txt']
        with self.assertRaisesRegex(ValueError, 'EXACT_CONTRACT_NOT_COVERED'):
            self.verify()

    def test_partial_parent_rejected(self):
        self.managed.update(status='timed-out', completed=1)
        with self.assertRaisesRegex(ValueError, 'INCOMPLETE_PARENT'):
            self.verify()

    def test_changed_source_rejected(self):
        self.source.write_text('main { 1 -> println }', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'PARENT_INPUT_DRIFT'):
            self.verify()

    def test_removed_required_format_check_rejected(self):
        self.selected['formatCheckSources'] = []
        with self.assertRaisesRegex(ValueError, 'EXACT_CONTRACT_NOT_COVERED'):
            self.verify()


if __name__ == '__main__':
    unittest.main()
