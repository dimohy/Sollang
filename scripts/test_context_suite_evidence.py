"""Exercise admission rules without compiling a compiler or a fixture."""
import copy
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from context_suite_evidence import FIXTURES, SUITE, sha, validate_focused_suite

_refresh_spec = importlib.util.spec_from_file_location(
    'refresh_context_fixture_source_closure',
    Path(__file__).with_name('refresh-context-fixture-source-closure.py'))
refresh = importlib.util.module_from_spec(_refresh_spec)
_refresh_spec.loader.exec_module(refresh)


class ContextSuiteEvidence(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        self.output = self.root / 'artifacts'
        self.output.mkdir()
        self.compiler = self.output / 'compiler.exe'
        self.compiler.write_bytes(b'native')
        self.managed = self.output / 'managed.exe'
        self.managed.write_bytes(b'managed')
        self.dll = self.managed.with_suffix('.dll')
        self.dll.write_bytes(b'dll')
        self.source = self.root / 'source.slg'
        self.source.write_text('main {}')
        self.expected = self.root / f'examples/regression/expected/{SUITE}.stdout.txt'
        self.expected.parent.mkdir(parents=True)
        self.expected.write_text('\n'.join(f'{f}:{marker}' for f in FIXTURES
                                           for marker in ('begin', 'end')))
        pins = {str(p): sha(p) for p in (self.source, self.expected, self.managed, self.dll)}
        base = {'status': 'passed', 'completed': 1, 'total': 1,
                'inputsStable': True, 'processesStopped': True,
                'managedCompiler': str(self.managed), 'managedCompilerDllSha256': sha(self.dll),
                'inputHashes': pins, 'cases': [{
                    'id': SUITE, 'status': 'passed', 'passed': True,
                    'expectedBuildExit': 0, 'buildExit': 0, 'runExit': 0,
                    'buildStderr': '', 'runStderr': '',
                    'runStdout': self.expected.read_text()}]}
        self.records = {role: copy.deepcopy(base) for role in ('managed', 'paired')}
        for role in self.records:
            self.records[role]['mode'] = role
        self.records['paired']['processes'] = [{
            'command': [str(self.compiler), 'build'], 'exit': 0, 'shutdownConfirmed': True}]
        self.records['build'] = {'status': 'passed', 'inputsStable': True,
                                 'compilerSha256': sha(self.compiler),
                                 'seedCompilerSha256': sha(self.managed),
                                 'steps': dict.fromkeys(('build', 'llvmAs', 'v004'), 0)}
        self.paths = {role: self.output / f'{role}.json' for role in ('managed', 'paired')}
        self.paths['build'] = self.output / 'result.json'

    def references(self):
        for role in ('managed', 'build'):
            self.paths[role].write_text(json.dumps(self.records[role]))
        self.records['paired']['inputHashes'].update({
            str(self.paths[role]): sha(self.paths[role]) for role in ('managed', 'build')})
        self.records['paired']['inputHashes'][str(self.compiler)] = sha(self.compiler)
        self.paths['paired'].write_text(json.dumps(self.records['paired']))
        return {role: {'path': str(path.relative_to(self.root)), 'sha256': sha(path)}
                for role, path in self.paths.items()}

    def verify(self, references=None):
        references = references or self.references()
        # Producer validation has its own tests; only isolate that dependency here.
        with patch('context_suite_evidence.current_build_inputs') as producer_check:
            result = validate_focused_suite(self.root, references, self.compiler, [self.source])
            producer_check.assert_called_once()
            return result

    def test_complete(self):
        self.assertEqual(self.verify()['fixtures'], list(FIXTURES))

    def move_build(self, directory):
        directory.mkdir(parents=True)
        self.compiler = directory / 'compiler.exe'
        self.compiler.write_bytes(b'native')
        self.paths['build'] = directory / 'result.json'
        self.records['paired']['processes'][0]['command'][0] = str(self.compiler)

    @unittest.skipUnless(os.name == 'nt', 'External lifecycle root is Windows-specific')
    def test_lifecycle_external_build(self):
        local = self.root / 'local-appdata'
        self.move_build(local / 'Sollang' / 'candidate' / 'compiler-build01')
        with patch.dict(os.environ, {'LOCALAPPDATA': str(local)}):
            self.assertEqual(self.verify()['fixtures'], list(FIXTURES))

    def test_build_outside_lifecycle_roots(self):
        self.move_build(self.root / 'unowned-build')
        with self.assertRaisesRegex(ValueError, 'RECORD_PATH'):
            self.verify()

    @unittest.skipUnless(os.name == 'nt', 'External lifecycle root is Windows-specific')
    def test_refresh_external_build_reference(self):
        local = self.root / 'local-appdata'
        self.move_build(local / 'Sollang' / 'candidate' / 'compiler-build01')
        self.paths['build'].write_text(json.dumps(self.records['build']))
        with patch.object(refresh, 'ROOT', self.root), patch.dict(
                os.environ, {'LOCALAPPDATA': str(local)}):
            reference = refresh.focused_record_reference('build', str(self.paths['build']))
            self.assertEqual(reference['sha256'], sha(self.paths['build']))
            with self.assertRaisesRegex(ValueError, 'external repository input'):
                refresh.focused_record_reference('managed', str(self.paths['build']))

    def test_refresh_rejects_unowned_build_reference(self):
        self.move_build(self.root / 'unowned-build')
        self.paths['build'].write_text(json.dumps(self.records['build']))
        with patch.object(refresh, 'ROOT', self.root), self.assertRaises(ValueError):
            refresh.focused_record_reference('build', str(self.paths['build']))

    def test_managed_record_outside_repository_artifacts(self):
        self.paths['managed'] = self.root / 'managed.json'
        with self.assertRaisesRegex(ValueError, 'RECORD_PATH'):
            self.verify()

    def test_partial(self):
        self.records['paired']['status'] = 'running'
        with self.assertRaisesRegex(ValueError, 'EXECUTION_NOT_COMPLETE'):
            self.verify()

    def test_canceled(self):
        self.records['paired']['status'] = 'canceled'
        with self.assertRaisesRegex(ValueError, 'EXECUTION_NOT_COMPLETE'):
            self.verify()

    def test_timed_out(self):
        self.records['paired']['status'] = 'timed-out'
        self.records['paired']['cases'][0]['status'] = 'timed-out'
        with self.assertRaisesRegex(ValueError, 'EXECUTION_NOT_COMPLETE'):
            self.verify()

    def test_record_changed(self):
        references = self.references()
        self.paths['paired'].write_text('{}')
        with self.assertRaisesRegex(ValueError, 'RECORD_CHANGED'):
            self.verify(references)

    def test_source_changed(self):
        self.source.write_text('changed')
        with self.assertRaisesRegex(ValueError, 'LEASE_INPUT_DRIFT'):
            self.verify()

    def test_wrong_output(self):
        self.records['paired']['cases'][0]['runStdout'] += '\nextra'
        with self.assertRaisesRegex(ValueError, 'EXACT_OUTPUT'):
            self.verify()

    def test_wrong_native_command(self):
        self.records['paired']['processes'][0]['command'][0] = str(self.managed)
        with self.assertRaisesRegex(ValueError, 'NATIVE_PROCESS'):
            self.verify()

    def test_live_native_process(self):
        self.records['paired']['processes'][0]['shutdownConfirmed'] = False
        with self.assertRaisesRegex(ValueError, 'NATIVE_PROCESS'):
            self.verify()

    def test_managed_identity(self):
        self.records['paired']['managedCompilerDllSha256'] = 'wrong'
        with self.assertRaisesRegex(ValueError, 'MANAGED_IDENTITY'):
            self.verify()

    def test_active_process(self):
        self.records['paired']['activeProcess'] = {'pid': 123}
        with self.assertRaisesRegex(ValueError, 'PROCESS_SHUTDOWN'):
            self.verify()

    def test_unlisted_contract_input_drift(self):
        contract = self.root / 'contract.json'
        contract.write_text('original')
        for role in ('managed', 'paired'):
            self.records[role]['inputHashes'][str(contract)] = sha(contract)
        contract.write_text('changed')
        with self.assertRaisesRegex(ValueError, 'LEASE_INPUT_DRIFT'):
            self.verify()

    def test_native_producer_dependency_rejection(self):
        references = self.references()
        with patch('context_suite_evidence.current_build_inputs', side_effect=ValueError('SOURCE_DRIFT')):
            with self.assertRaisesRegex(ValueError, 'SOURCE_DRIFT'):
                validate_focused_suite(self.root, references, self.compiler, [self.source])


if __name__ == '__main__':
    unittest.main()
