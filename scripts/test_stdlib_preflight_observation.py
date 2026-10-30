"""Keep diagnostic evidence separate from the preflight acceptance counters."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "stdlib_preflight", Path(__file__).with_name("verify-owned-index-full-stdlib-source-preflight.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
SEMANTIC_SPEC = importlib.util.spec_from_file_location(
    "semantic_preflight", Path(__file__).with_name("verify-focused-selfhost-semantic-preflight.py"))
SEMANTIC = importlib.util.module_from_spec(SEMANTIC_SPEC)
SEMANTIC_SPEC.loader.exec_module(SEMANTIC)


class InputLeaseTests(unittest.TestCase):
    def workspace(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name).resolve()
        for name in (
                'compiler.exe', 'compiler.dll', 'compiler.deps.json', 'compiler.runtimeconfig.json',
                'dotnet.exe', 'source.slg', 'stdlib/library.slg',
                'src/Sollang.Compiler/Cli/CompilerApp.cs', 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs',
                'scripts/contracts/fixtures/focused-selfhost-semantic-preflight-harness.cs',
                'scripts/contracts/fixtures/semantic-preflight-positive.slg',
                'scripts/contracts/fixtures/semantic-preflight-deferred-text.slg',
                'scripts/contracts/fixtures/semantic-preflight-rebound-owner.slg',
                'scripts/completed_artifact_plan.py', 'scripts/ArtifactLifecycle.ps1',
                'scripts/Invoke-CompletedArtifactCleanup.ps1', 'scripts/contracts/artifact-lifecycle.json',
                'scripts/verification_fingerprints.py', 'scripts/verification_contract_lease.py',
                'scripts/verification_json_records.py',
                'scripts/verification_stdlib_source_preflight.py', 'scripts/verify-c385-preir-call-numeric.py',
                'scripts/verification_execution.py', 'scripts/verification_step_diagnostics.py',
                'llvm/bin/clang.exe', 'llvm/bin/llvm-as.exe', 'llvm/bin/llvm-link.exe',
                'llvm/bin/opt.exe', 'llvm/bin/llc.exe'):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('unchanged fixture\n', encoding='utf-8')
        (root / 'sources.txt').write_text('source.slg\n', encoding='utf-8')
        canonical_manifest = root / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
        canonical_manifest.parent.mkdir(parents=True, exist_ok=True)
        canonical_manifest.write_text('source.slg\n', encoding='utf-8')
        return root

    def assert_writer_denied(self, paths):
        # A separate process tests real OS sharing/locking, not a mocked lease.
        script = '''
import os,sys
from pathlib import Path
for name in sys.argv[1:]:
    p=Path(name)
    if os.name == 'nt':
        try:
            with p.open('r+b') as f: f.write(b'changed')
        except OSError: pass
        else: raise SystemExit('write admitted: '+name)
        replacement=p.with_name(p.name+'.replacement')
        replacement.write_bytes(p.read_bytes())
        try: os.replace(replacement,p)
        except OSError: replacement.unlink()
        else: raise SystemExit('replacement admitted: '+name)
    else:
        import fcntl
        with p.open('r+b') as f:
            try: fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError: pass
            else: raise SystemExit('cooperating writer admitted: '+name)
'''
        child = self.real_popen([sys.executable, '-c', script, *map(str, paths)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = child.communicate(timeout=10)
        self.assertEqual(child.returncode, 0, (stdout + stderr).decode())

    def test_semantic_inputs_block_writer_and_release_after_terminal_failure(self):
        root = self.workspace()
        self.real_popen = subprocess.Popen
        owner = self
        inspected = []

        class FakeExecution:
            def __init__(self, _root, output, record, stable, _sha):
                self.output, self.record, self.stable = output, record, stable
                self.record['processes'] = []

            def run(self, command, prefix, **kwargs):
                targets = [root / 'source.slg', root / 'sources.txt', root / 'compiler.dll',
                           root / 'stdlib/library.slg', root / 'dotnet.exe']
                owner.assert_writer_denied(targets)
                inspected.append(command)
                code = 1 if 'build' in command else 0
                prefix.with_suffix('.stdout').write_text('fixture-version\n' if command[-1] == '--version' else '')
                prefix.with_suffix('.stderr').write_text('deliberate fake build failure' if code else '')
                self.record['processes'].append({'pid': 12345, 'exit': code, 'shutdownConfirmed': True})
                return SimpleNamespace(returncode=code)

            def finalize(self, *args, **kwargs):
                self.record.update(inputsStable=self.stable(), processesStopped=True)

        argv = ['semantic', '--output', str(root / 'output'), '--compiler', str(root / 'compiler.exe'),
                '--manifest', str(root / 'sources.txt')]
        with patch.object(SEMANTIC, 'ROOT', root), patch.object(SEMANTIC, 'FIXTURES', root / 'scripts/contracts/fixtures'), \
                patch.object(SEMANTIC, 'initialize_output'), patch.object(SEMANTIC, 'cleanup_output') as cleanup, \
                patch.object(SEMANTIC.shutil, 'which', return_value=str(root / 'dotnet.exe')), \
                patch.object(SEMANTIC, 'VerificationExecution', FakeExecution), patch.object(sys, 'argv', argv):
            self.assertEqual(SEMANTIC.main(), 1)
        record = json.loads((root / 'output/result.json').read_text())
        self.assertTrue(record['inputsStable'] and record['processesStopped'])
        self.assertEqual(len(inspected), 3)
        self.assertEqual(cleanup.call_count, 0)
        (root / 'source.slg').write_text('released\n')
        replacement = root / 'replacement'
        replacement.write_text('replacement\n')
        os.replace(replacement, root / 'source.slg')

    def test_manifest_change_between_discovery_and_lease_stops_before_snapshot(self):
        root = self.workspace()
        lease_type = SEMANTIC.VerificationContractLease

        class DiscoveryRaceLease(lease_type):
            def __enter__(self):
                (root / 'sources.txt').write_text('stdlib/library.slg\n')
                return super().__enter__()

        argv = ['semantic', '--output', str(root / 'output'), '--compiler', str(root / 'compiler.exe'),
                '--manifest', str(root / 'sources.txt')]
        with patch.object(SEMANTIC, 'ROOT', root), patch.object(SEMANTIC, 'FIXTURES', root / 'scripts/contracts/fixtures'), \
                patch.object(SEMANTIC, 'VerificationContractLease', DiscoveryRaceLease), \
                patch.object(SEMANTIC.shutil, 'which', return_value=str(root / 'dotnet.exe')), \
                patch.object(SEMANTIC.subprocess, 'Popen') as launch, patch.object(sys, 'argv', argv):
            with self.assertRaisesRegex(ValueError, 'DISCOVERY_INPUT_DRIFT'):
                SEMANTIC.main()
        launch.assert_not_called()
        self.assertFalse((root / 'output').exists())
        (root / 'sources.txt').write_text('released\n')

    def test_stdlib_original_and_generated_inputs_block_writer_until_final_result(self):
        root = self.workspace()
        self.real_popen = subprocess.Popen
        (root / 'template.slg').write_text('main {\n    # ACTIVE_PROBE_PATH\n    # STDLIB_SOURCE_PATHS\n}\n')
        contract = {'schemaVersion': 1, 'scope': 'owned-index-full-stdlib-source',
                    'template': 'template.slg', 'compilerManifest': 'sources.txt', 'activeProbe': 'main {}'}
        (root / 'contract.json').write_text(json.dumps(contract))
        owner = self
        inspected = []

        class FakeSupervisor:
            def __init__(self, _root, output, record, stable, _sha, record_path):
                self.output, self.record, self.stable, self.record_path = output, record, stable, record_path

            def save(self):
                self.record_path.write_text(json.dumps(self.record))

            def run(self, command, prefix, **kwargs):
                owner.assertLessEqual(kwargs['timeout'], 180)
                owner.assertEqual(kwargs['diagnostics'].hard_timeout_seconds, kwargs['timeout'])
                owner.assert_writer_denied([root / 'source.slg', root / 'contract.json', root / 'sources.txt',
                    root / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt',
                    root / 'template.slg', root / 'compiler.dll', root / 'stdlib/library.slg',
                    root / 'llvm/bin/clang.exe', self.output / 'driver.slg', self.output / 'active-probe.slg',
                    self.output / 'stdlib.sources.json'])
                inspected.append(command)
                prefix.with_suffix('.stdout').write_text('')
                prefix.with_suffix('.stderr').write_text('deliberate fake build failure')
                self.record['processes'].append({'exit': 1, 'shutdownConfirmed': True})
                return SimpleNamespace(returncode=1)

            def finalize(self, **kwargs):
                self.record.update(inputsStable=self.stable(), processesStopped=True)
                self.save()

        def format_under_lease(command, **kwargs):
            owner.assert_writer_denied([root / 'source.slg', root / 'contract.json',
                                       root / 'template.slg', root / 'compiler.dll'])
            return SimpleNamespace(stdout=kwargs['input'], stderr='', returncode=0)

        diagnostic_plan = root / 'diagnostics.json'
        diagnostic_plan.write_text(json.dumps(dict(stage='stdlib', softLimitSeconds=30,
            hardTimeoutSeconds=180, sampleIntervalSeconds=2, maxSamples=92)))
        argv = ['stdlib', '--output', str(root / 'output'), '--compiler', str(root / 'compiler.exe'),
                '--llvm', str(root / 'llvm'), '--contract', str(root / 'contract.json'),
                '--timeout-seconds', '180', '--diagnostics-plan', str(diagnostic_plan)]
        with patch.object(MODULE, 'ROOT', root), patch.object(MODULE, 'initialize_output'), \
                patch.object(MODULE, 'cleanup_output') as cleanup, \
                patch.object(MODULE, 'VerificationExecution', FakeSupervisor), \
                patch.object(MODULE.subprocess, 'run', side_effect=format_under_lease), patch.object(sys, 'argv', argv):
            with self.assertRaises(SystemExit):
                MODULE.main()
        record = json.loads((root / 'output/result.json').read_text())
        self.assertTrue(record['inputsStable'] and record['processesStopped'])
        self.assertEqual(len(inspected), 1)
        self.assertEqual(cleanup.call_count, 0)
        for path in [root / 'source.slg', root / 'output/driver.slg']:
            path.write_text('released\n')


class ObservationTests(unittest.TestCase):
    def test_diagnostic_plan_matches_selected_whole_case_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'diagnostics.json'
            plan = dict(stage='stdlib', softLimitSeconds=30, hardTimeoutSeconds=180,
                        sampleIntervalSeconds=2, maxSamples=92)
            path.write_text(json.dumps(plan), encoding='utf-8')
            self.assertEqual(MODULE.load_diagnostics_plan(path, 180), plan)
            with self.assertRaisesRegex(ValueError, 'HARD_TIMEOUT_MISMATCH'):
                MODULE.load_diagnostics_plan(path, 600)

    def test_success_has_no_diagnostics(self):
        metadata = {"checkedSemanticDiagnosticCount": 0}
        self.assertEqual(MODULE.parse_observation(json.dumps(metadata)), (metadata, []))

    def test_failure_preserves_exact_diagnostic(self):
        diagnostic = "; sollang compiler error S053: invalid match (source 4, byte 12)"
        metadata = {"checkedSemanticDiagnosticCount": 1}
        self.assertEqual(MODULE.parse_observation(diagnostic + "\n" + json.dumps(metadata)),
                         (metadata, [diagnostic]))

    def test_diagnostic_cannot_be_reported_as_success(self):
        with self.assertRaisesRegex(ValueError, "UNEXPECTED_DIAGNOSTIC_OUTPUT"):
            MODULE.parse_observation('; sollang compiler error S053\n{"checkedSemanticDiagnosticCount":0}')

    def test_canonical_user_diagnostic_is_preserved(self):
        diagnostic = "sollang: semantic error at 6:5: [module '<main>'] function 'push' expects 1 additional argument(s)"
        metadata = {"checkedSemanticDiagnosticCount": 1}
        self.assertEqual(MODULE.parse_observation(diagnostic + "\n" + json.dumps(metadata)),
                         (metadata, [diagnostic]))

    def test_user_diagnostic_cannot_be_reported_as_success(self):
        with self.assertRaisesRegex(ValueError, "UNEXPECTED_DIAGNOSTIC_OUTPUT"):
            MODULE.parse_observation('sollang: semantic error at 6:5: bad call\n{"checkedSemanticDiagnosticCount":0}')

    def test_unknown_output_is_not_silently_ignored(self):
        with self.assertRaisesRegex(ValueError, "UNEXPECTED_DIAGNOSTIC_OUTPUT"):
            MODULE.parse_observation('unexpected output\n{"checkedSemanticDiagnosticCount":1}')


if __name__ == "__main__":
    unittest.main()
