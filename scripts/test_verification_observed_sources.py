"""Prove runtime-loaded inputs are validated, pinned and held during execution."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
import uuid

from verification_observed_sources import observed_source_paths

ROOT = Path(__file__).resolve().parent.parent
RUNNER = ROOT / 'scripts/verify-c385-preir-call-numeric.py'
SPEC = importlib.util.spec_from_file_location('observed_runner', RUNNER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ObservedSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = ROOT / 'artifacts/scratch' / ('observed-source-tests-' + uuid.uuid4().hex)
        cls.folder.mkdir()
        cls.loaded = cls.folder / 'loaded.slg'
        cls.loaded.write_text('main { }\n', encoding='utf-8')
        cls.relative = cls.loaded.relative_to(ROOT).as_posix()

    def contract(self, name, order):
        source = self.folder / (name + '.slg')
        source.write_text('import sys.file as file\n\nmain {\n'
                          f'    "{self.relative}" -> file.mapText => input\n'
                          '    input -> slice(UIntSize(0), UIntSize(8)) -> println\n}\n', encoding='utf-8')
        contract = self.folder / (name + '.json')
        contract.write_text(json.dumps({'schemaVersion': 1, 'observedSourceOrder': order,
                                       'cases': [{'id': name, 'source': source.relative_to(ROOT).as_posix(),
                                                  'exit': 0, 'stdout': 'main { }', 'stderr': ''}]}), encoding='utf-8')
        return contract

    def test_optional_contract_preserves_existing_inputs(self):
        self.assertEqual(observed_source_paths(ROOT, {}), [])

    def test_declared_order_is_preserved(self):
        self.assertEqual(observed_source_paths(ROOT, {'observedSourceOrder': [self.relative]}),
                         [self.loaded.resolve()])

    def test_invalid_inputs_fail_before_output_or_compiler(self):
        for index, order in enumerate([[], None, [None], ['../outside.slg'],
                                       ['missing.slg'], [self.relative, self.relative]]):
            with self.subTest(order=order):
                contract = self.contract('invalid-' + str(index), order)
                output = self.folder / ('invalid-output-' + str(index))
                run = subprocess.run([sys.executable, str(RUNNER), '--mode', 'managed',
                                      '--contract', str(contract), '--output', str(output)],
                                     cwd=ROOT, capture_output=True, text=True)
                self.assertNotEqual(run.returncode, 0)
                self.assertIn('OBSERVED_SOURCE_', run.stderr)
                self.assertFalse(output.exists())

    @unittest.skipUnless(os.name == 'nt', 'Windows sharing contract')
    def test_main_holds_loaded_source_read_lease_through_execution(self):
        contract = self.contract('lease', [self.relative])
        original = self.loaded.read_bytes()
        def execute(args, parser, mode, observed, stdlib_proof_inputs, runtime_inputs):
            self.assertEqual(observed, [self.loaded.resolve()])
            self.assertEqual(stdlib_proof_inputs, [])
            self.assertEqual(runtime_inputs, [])
            self.assertEqual(mode, 'windows-read-share')
            with self.assertRaises(OSError):
                self.loaded.write_bytes(b'changed')
        with patch.object(sys, 'argv', [str(RUNNER), '--mode', 'managed', '--contract', str(contract),
                                       '--output', str(self.folder / 'unused-lease-output')]), \
                patch.object(MODULE, 'execute', side_effect=execute):
            MODULE.main()
        self.assertEqual(self.loaded.read_bytes(), original)

    def test_real_file_read_records_the_loaded_input_hash(self):
        contract = self.contract('actual-file-read', [self.relative])
        output = self.folder / 'actual-file-read-output'
        run = subprocess.run([sys.executable, str(RUNNER), '--mode', 'managed',
                              '--contract', str(contract), '--output', str(output)],
                             cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        record = json.loads((output / 'result.json').read_text(encoding='utf-8'))
        self.assertEqual(record['inputHashes'][str(self.loaded.resolve())], MODULE.sha(self.loaded))
        self.assertEqual(record['observedSourceOrder'], [str(self.loaded.resolve())])
        self.assertTrue(record['inputsStable'])
        self.assertTrue(record['processesStopped'])
        self.assertEqual(record['completed'], 1)


if __name__ == '__main__':
    unittest.main()
