"""Native build admission must consume the actual current CSharp proof."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest


admit = runpy.run_path(str(Path(__file__).with_name('build-focused-source-emitter.py')))[
    'managed_reference_inputs']


class ManagedReferenceAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.producer = self.root / 'scripts/verify-managed-first-fixture.py'
        self.producer.parent.mkdir()
        self.producer.write_text('test producer identity', encoding='utf-8')
        self.contract = self.root / 'contract.json'
        source = 'main {\n    "one" -> println\n}\n'
        self.source = self.root / 'one.slg'
        self.source.write_bytes(source.encode())
        expected = dict(exitCode=0, stdout=source, stderr='')
        self.contract.write_text(json.dumps(dict(schemaVersion=1, cases=[dict(
            id='one', mode='format-stdin', source=source, expected=expected)])))
        pins = {str(p.resolve()): hashlib.sha256(p.read_bytes()).hexdigest().upper()
                for p in (self.producer, self.contract, self.source)}
        self.record = dict(status='passed', phase='managed-first', inputsStable=True,
                           contract=str(self.contract), inputHashesStart=pins,
                           inputHashesEnd=copy.deepcopy(pins), cases=[dict(
                               id='one', passed=True, observed=expected,
                               sourceSha256=pins[str(self.source.resolve())])])
        self.path = self.root / 'result.json'

    def check(self, record=None):
        self.path.write_text(json.dumps(record or self.record), encoding='utf-8')
        return admit(self.path, self.root)

    def test_legacy_formatter_proof_uses_actual_oracles_and_pins(self):
        record, inputs = self.check()
        self.assertEqual(record['cases'][0]['observed']['exitCode'], 0)
        self.assertIn(self.producer, inputs)

    def test_canonical_proof_remains_supported(self):
        record = dict(status='passed', inputsStable=True, processesStopped=True,
                      completed=1, total=1, inputHashes=self.record['inputHashesStart'])
        self.assertEqual(self.check(record)[0]['completed'], 1)
        for key, value in [('processesStopped', False), ('total', True), ('completed', 0)]:
            with self.subTest(key=key):
                changed = dict(record, **{key: value})
                with self.assertRaisesRegex(ValueError, 'INCOMPLETE'):
                    self.check(changed)

    def test_passed_flag_cannot_override_changed_oracle(self):
        self.record['cases'][0]['observed'] = dict(exitCode=0, stdout='wrong', stderr='')
        with self.assertRaisesRegex(ValueError, 'ORACLE_MISMATCH'):
            self.check()

    def test_stale_source_and_different_end_pins_are_rejected(self):
        self.source.write_text('changed', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'INPUT_CHANGED'):
            self.check()
        self.record['inputHashesEnd'] = {}
        with self.assertRaisesRegex(ValueError, 'INPUT_CHANGED'):
            self.check()

    def test_missing_producer_is_not_a_fallback_to_unverified_results(self):
        for key in ('inputHashesStart', 'inputHashesEnd'):
            self.record[key].pop(str(self.producer.resolve()))
        with self.assertRaisesRegex(ValueError, 'PRODUCER_MISSING'):
            self.check()

    def test_contract_source_must_match_the_materialized_proof_input(self):
        contract = json.loads(self.contract.read_text())
        source = contract['cases'][0]['source'] + '# changed source\n'
        contract['cases'][0]['source'] = source
        self.contract.write_text(json.dumps(contract))
        for key in ('inputHashesStart', 'inputHashesEnd'):
            self.record[key][str(self.contract.resolve())] = hashlib.sha256(
                self.contract.read_bytes()).hexdigest().upper()
        self.record['cases'][0]['sourceSha256'] = hashlib.sha256(source.encode()).hexdigest().upper()
        with self.assertRaisesRegex(ValueError, 'ORACLE_MISMATCH'):
            self.check()

    def test_duplicate_or_incomplete_case_sets_are_rejected(self):
        self.record['cases'].append(copy.deepcopy(self.record['cases'][0]))
        with self.assertRaisesRegex(ValueError, 'CASES_INVALID'):
            self.check()

    def test_failed_or_unknown_producer_protocol_is_rejected(self):
        self.record['status'] = 'failed'
        with self.assertRaisesRegex(ValueError, 'PROOF_FAILED'):
            self.check()
        self.record.update(status='passed', phase='other')
        with self.assertRaisesRegex(ValueError, 'UNSUPPORTED'):
            self.check()


if __name__ == '__main__':
    unittest.main()
