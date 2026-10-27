"""Behavioral contract for cleanup; uses only fresh isolated fixture repositories."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import completed_artifact_plan as policy


class ArtifactLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sollang-artifact-fixtures-')
        self.repo = Path(self.temp.name)
        self.root = self.repo / 'artifacts/scratch'
        self.root.mkdir(parents=True)

    def tearDown(self):
        self.temp.cleanup()

    def output(self, name='case', record=None):
        output = self.root / name
        (output / '.sollang-cache').mkdir(parents=True)
        for relative in ['compiler.exe', 'compiler.ll', '.sollang-cache/compiler.cgu', 'source.slg', 'result.log']:
            (output / relative).write_text('fixture', encoding='utf-8')
        result = {'schemaVersion': 1, 'status': 'passed', 'inputsStable': True, 'completed': 1, 'total': 1,
                  'compilerSha256': hashlib.sha256((output / 'compiler.exe').read_bytes()).hexdigest(),
                  'processesStopped': True,
                  'inputHashesStart': {'source': 'same'}, 'inputHashesEnd': {'source': 'same'}}
        if record is not None:
            result.update(record)
        (output / 'result.json').write_text(json.dumps(result), encoding='utf-8')
        stamp = max(p.stat().st_mtime_ns for p in output.rglob('*') if p.is_file()) + 1000
        os.utime(output / 'result.json', ns=(stamp,stamp))
        return output

    def plan(self, **options):
        return policy.create_plan(self.repo, self.root, minimum_age_hours=0, active=set(), reusable_directories=options.pop("reusable_directories", []), **options)

    def execute(self, plan):
        path = self.repo / 'plan.json'
        path.write_text(json.dumps(plan), encoding='utf-8')
        return subprocess.run(['pwsh', '-NoProfile', '-File', str(Path(__file__).parent / 'Invoke-CompletedArtifactCleanup.ps1'),
                               '-Plan', str(path), '-Execute'], capture_output=True, text=True, encoding='utf-8')

    def test_completed_stable_output(self):
        self.output()
        self.assertEqual(self.plan()['files'], 3)  # Reuse requires explicit ownership.

    def test_parent_completion_does_not_own_nested_result(self):
        for status in ('passed', 'failed', 'running', 'cancelled'):
            with self.subTest(status=status):
                parent = self.output('parent-' + status)
                nested = parent / 'compiler-build01'
                nested.mkdir()
                (nested / 'compiler.exe').write_text('protected')
                (nested / 'result.json').write_text(json.dumps({
                    'status': status, 'pendingConsumerProtection': True}))
                stamp = max(path.stat().st_mtime_ns for path in nested.iterdir()) + 1000
                os.utime(parent / 'result.json', ns=(stamp, stamp))
                plan = self.plan()
                self.assertFalse(any(nested in Path(row['path']).parents
                                     for row in plan['targets']))

    def test_parent_plan_cannot_cross_new_nested_result_boundary(self):
        parent = self.output()
        nested = parent / 'compiler-build01'
        nested.mkdir()
        (nested / 'compiler.exe').write_text('protected')
        stamp = (nested / 'compiler.exe').stat().st_mtime_ns + 1000
        os.utime(parent / 'result.json', ns=(stamp, stamp))
        plan = self.plan()
        self.assertTrue(any(nested in Path(row['path']).parents for row in plan['targets']))
        (nested / 'result.json').write_text('{"status":"running"}')
        with patch.object(policy, 'windows_active_directories', return_value=set()):
            with self.assertRaisesRegex(ValueError, 'NESTED_OUTPUT_OWNER'):
                policy.validate_plan(plan)

    def test_failed_output(self):
        self.output(record={'status': 'failed'})
        self.assertEqual(self.plan()['files'], 0)

    def test_running_output(self):
        self.output(record={'status': 'running'})
        self.assertEqual(self.plan()['files'], 0)

    @unittest.skipUnless(os.name == 'nt', 'Windows process command line encoding')
    def test_active_unicode_command_protects_output(self):
        output = self.output(name='한글🌱')
        child = subprocess.Popen(
            ['pwsh', '-NoProfile', '-Command',
             "[void]'" + str(output).replace("'", "''") + "'; Start-Sleep -Seconds 30"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            active = policy.windows_active_directories(self.root)
            self.assertIn(str(output).casefold(), active)
            plan = policy.create_plan(self.repo, self.root, minimum_age_hours=0,
                                      active=active, reusable_directories=[])
            self.assertEqual(plan['files'], 0)
            self.assertTrue((output / 'compiler.exe').exists())
        finally:
            child.kill()
            child.wait(timeout=10)

    def test_cancelled_output(self):
        self.output(record={'status': 'cancelled'})
        self.assertEqual(self.plan()['files'], 0)

    def test_timed_out_output(self):
        self.output(record={'status': 'timed-out'})
        self.assertEqual(self.plan()['files'], 0)

    def test_missing_completion(self):
        output = self.output()
        (output / 'result.json').unlink()
        self.assertEqual(self.plan()['files'], 0)

    def test_input_drift(self):
        self.output(record={'inputHashesEnd': {'source': 'changed'}})
        self.assertEqual(self.plan()['files'], 0)

    def test_incomplete_case_count(self):
        self.output(record={'completed': 0})
        self.assertEqual(self.plan()['files'], 0)

    def test_reparse_output(self):
        output = self.output()
        link = self.root / 'linked'
        if os.name == 'nt':
            subprocess.run(['pwsh','-NoProfile','-Command', f"New-Item -ItemType Junction -Path '{link}' -Target '{output}' | Out-Null"], check=True, capture_output=True)
        else:
            link.symlink_to(output, target_is_directory=True)
        self.assertEqual(self.plan()['excluded'].get('reparse'), 1)
        if os.name == 'nt':
            os.rmdir(link)

    def test_active_output(self):
        output = self.output()
        plan = policy.create_plan(self.repo, self.root, 0, active={str(output).casefold()},
                                  reusable_directories=[])
        self.assertEqual(plan['files'], 0)

    def test_outside_artifacts(self):
        with self.assertRaisesRegex(ValueError, 'OUTSIDE_ROOT'):
            policy.assert_artifact_path(self.repo, self.repo / 'sources')

    def test_preserve_source_and_record(self):
        output = self.output()
        result = self.execute(self.plan())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((output / 'compiler.ll').exists())
        self.assertFalse((output / '.sollang-cache/compiler.cgu').exists())
        self.assertTrue((output / 'source.slg').exists())
        self.assertTrue((output / 'result.json').exists())
        self.assertTrue((output / 'result.log').exists())

    def test_preserve_three_reusable_compilers(self):
        for i in range(5):
            output = self.output(str(i))
            for path in output.rglob('*'):
                if path.is_file():
                    stamp = time.time()-100+i
                    os.utime(path, (stamp, stamp))
            stamp = time.time()-50+i
            os.utime(output / 'result.json', (stamp, stamp))
        plan = self.plan(reusable_directories=[self.root / str(i) for i in (2,3,4)])
        self.assertEqual(len(plan['protectedCompilerDirectories']), 3)
        self.assertEqual(sum(Path(row['path']).name == 'compiler.exe' for row in plan['targets']), 2)

    def test_changed_target(self):
        output = self.output()
        plan = self.plan()
        (output / 'compiler.ll').write_text('changed after planning', encoding='utf-8')
        self.assertNotEqual(self.execute(plan).returncode, 0)
        self.assertTrue((output / '.sollang-cache/compiler.cgu').exists())

    def test_idempotent_cleanup(self):
        self.output()
        plan = self.plan()
        self.assertEqual(self.execute(plan).returncode, 0)
        second = self.execute(plan)
        self.assertEqual(second.returncode, 0, second.stderr)

    def test_invalid_case_schema(self):
        self.output(record={'cases': {'unexpected': 'shape'}})
        self.assertEqual(self.plan()['files'], 0)


    def test_terminal_retention_preserves_failure(self):
        output = self.output(record={'status': 'failed', 'inputsStable': False})
        plan = self.plan(retention_terminal=True)
        self.assertEqual(plan['completionRecords'][0]['disposition'], 'terminal-retention')
        self.assertEqual(self.execute(plan).returncode, 0)
        self.assertEqual(json.loads((output / 'result.json').read_text())['status'], 'failed')
        self.assertTrue((output / 'compiler.exe').exists())
        self.assertTrue((output / 'compiler.ll').exists())

    def test_terminal_cancelled_retention(self):
        self.output(record={'status': 'cancelled', 'inputsStable': False})
        self.assertEqual(self.plan(retention_terminal=True)['files'], 0)

    def test_terminal_orphan_is_protected(self):
        self.output(record={'status': 'failed', 'orphanProcessIds': [123]})
        self.assertEqual(self.plan(retention_terminal=True)['files'], 0)

    def test_maximum_explicit_reuse(self):
        with self.assertRaisesRegex(ValueError, 'LIMIT_EXCEEDED'):
            self.plan(reusable_directories=[self.root / str(i) for i in range(4)])

    def test_same_size_hash_change_before_deletion(self):
        output = self.output()
        plan = self.plan()
        path = output / 'compiler.ll'
        stamp = path.stat().st_mtime_ns
        path.write_text('changed', encoding='utf-8')
        os.utime(path, ns=(stamp,stamp))
        self.assertNotEqual(self.execute(plan).returncode, 0)
        self.assertTrue((output / 'compiler.exe').exists())

    def test_failed_build_step_is_not_success(self):
        self.output(record={'steps': {'build': {'exitCode': 1}}})
        self.assertEqual(self.plan()['files'], 0)

    def test_failed_case_exit_is_not_success(self):
        self.output(record={'cases': [{'passed': True, 'buildExit': 1}]})
        self.assertEqual(self.plan()['files'], 0)

    def test_singular_failure_is_not_success(self):
        self.output(record={'failureId': 'SEMANTIC_FAILURE'})
        self.assertEqual(self.plan()['files'], 0)

    def test_pending_consumer_protected(self):
        output = self.output(record={'pendingConsumerProtection': {'purpose': 'pending tests'}})
        self.assertEqual(self.plan()['files'], 0)
        self.assertTrue((output / 'compiler.exe').exists())

    def test_expected_exit_contract_alias_requires_exact_pinned_outcome(self):
        contract = self.repo / 'negative-expected-exit.json'
        contract.write_text(json.dumps({'cases': [{'id': 'negative', 'expectedExit': 1}]}))
        digest = hashlib.sha256(contract.read_bytes()).hexdigest()
        record = {'status': 'passed', 'inputsStable': True, 'completed': 1, 'total': 1,
                  'inputHashes': {str(contract): digest},
                  'cases': [{'id': 'negative', 'status': 'passed', 'compileExit': 1}]}
        self.assertTrue(policy.completed(record))
        wrong = copy.deepcopy(record)
        wrong['cases'][0]['compileExit'] = 0
        self.assertFalse(policy.completed(wrong))
        unpinned = copy.deepcopy(record)
        unpinned['inputHashes'] = {}
        self.assertFalse(policy.completed(unpinned))
        contract.write_text(json.dumps({'cases': [{'id': 'negative', 'expectedExit': 0}]}))
        self.assertFalse(policy.completed(record))

    def test_probe_matrix_exit_requires_literal_pinned_authority(self):
        contract = self.repo / 'probe-matrix.json'
        contract.write_text(json.dumps({'probeMatrix': [
            {'id': 'rejected', 'expectation': 'compiler-rejected', 'expectedBuildExit': 1}]}))
        record = {'status': 'passed', 'inputsStable': True, 'completed': 1, 'total': 1,
                  'inputHashes': {str(contract): hashlib.sha256(contract.read_bytes()).hexdigest()},
                  'cases': [{'id': 'rejected', 'status': 'passed', 'compileExit': 1}]}
        self.assertTrue(policy.completed(record))
        for actual in (0, 2):
            wrong = copy.deepcopy(record)
            wrong['cases'][0]['compileExit'] = actual
            self.assertFalse(policy.completed(wrong))
        unpinned = copy.deepcopy(record)
        unpinned['inputHashes'] = {}
        self.assertFalse(policy.completed(unpinned))
        contract.write_text(json.dumps({'probeMatrix': [
            {'id': 'rejected', 'expectation': 'compiler-rejected'}]}))
        self.assertFalse(policy.completed(record))
        record['inputHashes'][str(contract)] = hashlib.sha256(contract.read_bytes()).hexdigest()
        self.assertFalse(policy.completed(record))

    def test_expected_runtime_exit_requires_pinned_exact_outcome_and_shutdown(self):
        contract = self.repo / 'runtime-trap.json'
        contract.write_text(json.dumps({'cases': [{'id': 'trap', 'expectedRuntimeExit': -1073741795}]}))
        record = {'status': 'passed', 'inputsStable': True, 'processesStopped': True,
                  'completed': 1, 'total': 1,
                  'inputHashes': {str(contract): hashlib.sha256(contract.read_bytes()).hexdigest()},
                  'cases': [{'id': 'trap', 'status': 'passed', 'buildExit': 0, 'runExit': -1073741795}]}
        self.assertTrue(policy.completed(record))
        unsigned = copy.deepcopy(record)
        unsigned['cases'][0]['runExit'] = 3221225501
        self.assertTrue(policy.completed(unsigned))
        for value in [0, 1, -1, None, True]:
            wrong = copy.deepcopy(record)
            wrong['cases'][0]['runExit'] = value
            self.assertFalse(policy.completed(wrong))
        for mutation in ['unpinned', 'shutdown', 'missing-run', 'build-failed']:
            wrong = copy.deepcopy(record)
            if mutation == 'unpinned': wrong['inputHashes'] = {}
            if mutation == 'shutdown': wrong['processesStopped'] = False
            if mutation == 'missing-run': del wrong['cases'][0]['runExit']
            if mutation == 'build-failed': wrong['cases'][0]['buildExit'] = 1
            self.assertFalse(policy.completed(wrong), mutation)
        conflict = self.repo / 'conflict.json'
        conflict.write_text(json.dumps({'cases': [{'id': 'trap', 'expectedRuntimeExit': 1}]}))
        wrong = copy.deepcopy(record)
        wrong['inputHashes'][str(conflict)] = hashlib.sha256(conflict.read_bytes()).hexdigest()
        self.assertFalse(policy.completed(wrong))
        contract.write_text(json.dumps({'cases': [{'id': 'trap', 'expectedRuntimeExit': 0}]}))
        self.assertFalse(policy.completed(record))
        self.assertTrue(policy.completed({'status': 'passed', 'inputsStable': True,
            'cases': [{'status': 'passed', 'buildExit': 0, 'runExit': 0}]}))

    def test_expected_negative_contract_is_completed(self):
        import hashlib
        contract = self.repo / 'negative.json'
        contract.write_text(json.dumps({'cases': [{'id': 'negative', 'exit': 1}]}))
        digest = hashlib.sha256(contract.read_bytes()).hexdigest()
        self.output(record={'inputHashes': {str(contract): digest}, 'cases': [{'id': 'negative', 'status': 'passed', 'buildExit': 1, 'runExit': None}]})
        self.assertEqual(self.plan()['files'], 3)

    def test_none_step_is_not_completed(self):
        self.output(record={'steps': {'clang': None}})
        self.assertEqual(self.plan()['files'], 0)

    def test_case_timeout_is_not_completed(self):
        self.output(record={'cases': [{'status': 'passed', 'timeout': True}]})
        self.assertEqual(self.plan()['files'], 0)

    def test_case_nested_exit_is_not_completed(self):
        self.output(record={'cases': [{'status': 'passed', 'steps': {'clang': {'exit': 1}}}]})
        self.assertEqual(self.plan()['files'], 0)

    @patch.object(policy.shutil, 'disk_usage', new=lambda _: SimpleNamespace(free=1024 ** 3))
    def test_capacity_automatic_cleanup_of_isolated_outputs(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            self.root = self.repo / 'Sollang'
            self.root.mkdir()
            a = self.output('a'); b = self.output('b'); self.output('old')
            next_output = self.root / 'next'
            policy.initialize_output(self.repo, next_output, reusable_directories=[a,b,next_output])
            self.assertFalse((self.root / 'old/compiler.exe').exists())
            self.assertTrue((a / 'compiler.exe').exists())

    def test_capacity_unverified_products_fail_before_build(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            self.root = self.repo / 'Sollang'
            self.root.mkdir()
            a = self.output('a'); b = self.output('b'); self.output('old', {'status': 'running'})
            next_output = self.root / 'next'
            with self.assertRaisesRegex(ValueError, 'CAPACITY_PROTECTED_OR_UNVERIFIED'):
                policy.initialize_output(self.repo, next_output, reusable_directories=[a,b,next_output])
            self.assertTrue((self.root / 'old/compiler.exe').exists())

    def capacity_fixture(self):
        self.root = self.repo / 'Sollang'
        self.root.mkdir()
        first = self.output('first')
        second = self.output('second')
        output = self.root / 'next'
        return output, [first, second, output]

    @patch.object(policy.shutil, 'disk_usage', new=lambda _: SimpleNamespace(free=1024 ** 3))
    def test_capacity_three_reusable_allowed_without_cleanup(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            output, reusable = self.capacity_fixture()
            with patch.object(policy.subprocess, 'run') as execute, patch.object(policy, 'windows_active_directories', return_value=set()):
                policy.ensure_compiler_capacity(self.repo, output, reusable)
            execute.assert_not_called()

    def test_capacity_four_declared_reusable_rejected(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            output, reusable = self.capacity_fixture()
            third = self.output('third')
            with patch.object(policy.subprocess, 'run') as execute:
                with self.assertRaisesRegex(ValueError, 'REUSABLE_COMPILER_LIMIT_EXCEEDED'):
                    policy.initialize_output(self.repo, output, reusable_directories=[*reusable, third])
            execute.assert_not_called()

    @patch.object(policy.shutil, 'disk_usage', new=lambda _: SimpleNamespace(free=1024 ** 3))
    def test_capacity_failed_and_cancelled_preserved_with_three_reusable(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            output, reusable = self.capacity_fixture()
            for status in ('failed', 'cancelled', 'canceled'):
                self.output(status, {'status': status, 'inputsStable': False})
            before = {str(path): path.read_bytes() for path in self.root.rglob('*') if path.is_file()}
            with patch.object(policy.subprocess, 'run') as execute, patch.object(policy, 'windows_active_directories', return_value=set()):
                policy.ensure_compiler_capacity(self.repo, output, reusable)
                inventory = policy.compiler_capacity_inventory(self.repo, self.root, output, reusable)
            execute.assert_not_called()
            self.assertEqual(3, sum(row['category'] == 'terminal-retained' for row in inventory))
            self.assertEqual(before, {str(path): path.read_bytes() for path in self.root.rglob('*') if path.is_file()})

    def test_capacity_recovered_failed_hash_receipt_is_not_reusable(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            output, reusable = self.capacity_fixture()
            failed = self.output('failed', {'status': 'failed', 'inputsStable': False, 'compilerSha256': None,
                'generatedArtifactHashes': [{'path': str(self.root / 'failed/compiler.exe'),
                                            'sha256': hashlib.sha256(b'fixture').hexdigest()}]})
            with patch.object(policy, 'windows_active_directories', return_value=set()):
                inventory = policy.compiler_capacity_inventory(self.repo, self.root, output, reusable)
                self.assertEqual('terminal-retained', next(row['category'] for row in inventory if row['output'] == str(failed)))
                with self.assertRaisesRegex(ValueError, 'RETAINED_NOT_REUSABLE'):
                    policy.compiler_capacity_inventory(self.repo, self.root, output, [failed, output])

    def test_capacity_bad_product_proofs_fail_before_cleanup(self):
        from unittest.mock import patch
        for mutation, failure in [('missing', 'PROTECTED_OR_UNVERIFIED'), ('invalid', 'PROTECTED_OR_UNVERIFIED'),
                                  ('unverified', 'PROTECTED_OR_UNVERIFIED'), ('changed', 'PRODUCT_CHANGED'),
                                  ('stale', 'PRODUCT_CHANGED'), ('hash-missing', 'BINARY_HASH_MISSING'),
                                  ('live', 'PROTECTED_OR_UNVERIFIED'), ('physical-live', 'PROTECTED_OR_UNVERIFIED'),
                                  ('shutdown', 'SHUTDOWN_UNCONFIRMED')]:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temp:
                repo = Path(temp)
                root = repo / 'Sollang'
                root.mkdir()
                old_root = self.root
                self.root = root
                try:
                    failed = self.output('failed', {'status': 'failed'})
                finally:
                    self.root = old_root
                record_path = failed / 'result.json'
                record = json.loads(record_path.read_text())
                if mutation == 'missing':
                    record_path.unlink()
                elif mutation == 'invalid':
                    record_path.write_text('{')
                elif mutation in ('changed', 'stale'):
                    binary = failed / 'compiler.exe'
                    if mutation == 'changed':
                        binary.write_bytes(b'changed')
                    else:
                        stamp = record_path.stat().st_mtime_ns + 10000
                        os.utime(binary, ns=(stamp, stamp))
                elif mutation != 'physical-live':
                    record.update({'unverified': {'status': 'unknown'}, 'hash-missing': {'compilerSha256': None},
                                   'live': {'activeProcessIds': [123]}, 'shutdown': {'processesStopped': False}}[mutation])
                    record_path.write_text(json.dumps(record))
                active = {str(failed).casefold()} if mutation == 'physical-live' else set()
                with patch.dict(os.environ, {'LOCALAPPDATA': str(repo)}), patch.object(policy.subprocess, 'run') as execute, patch.object(policy, 'windows_active_directories', return_value=active):
                    with self.assertRaisesRegex(ValueError, failure):
                        policy.ensure_compiler_capacity(repo, root / 'next', [root / 'next'])
                execute.assert_not_called()
                self.assertTrue((failed / 'compiler.exe').exists())

    def test_capacity_missing_declared_product_rejected(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            output, reusable = self.capacity_fixture()
            with self.assertRaisesRegex(ValueError, 'DECLARED_PRODUCT_MISSING'):
                policy.compiler_capacity_inventory(self.repo, self.root, output, [*reusable, self.root / 'missing'], active=set())

    @patch.object(policy.shutil, 'disk_usage', new=lambda _: SimpleNamespace(free=1024 ** 3))
    def test_capacity_automatic_cleanup_never_deletes_failed_output(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            output, reusable = self.capacity_fixture()
            old = self.output('old')
            failed = self.output('failed', {'status': 'failed', 'inputsStable': False})
            before = {str(path): path.read_bytes() for path in failed.rglob('*') if path.is_file()}
            with patch.object(policy, 'windows_active_directories', return_value=set()):
                policy.ensure_compiler_capacity(self.repo, output, reusable)
            self.assertFalse((old / 'compiler.exe').exists())
            self.assertEqual(before, {str(path): path.read_bytes() for path in failed.rglob('*') if path.is_file()})

    def test_capacity_insufficient_space_rejected_without_cleanup(self):
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            output, reusable = self.capacity_fixture()
            with patch.object(policy.shutil, 'disk_usage', return_value=SimpleNamespace(free=0)), \
                    patch.object(policy, 'windows_active_directories', return_value=set()), \
                    patch.object(policy.subprocess, 'run') as execute:
                with self.assertRaisesRegex(ValueError, 'ARTIFACT_BUILD_SPACE_INSUFFICIENT'):
                    policy.ensure_compiler_capacity(self.repo, output, reusable)
            execute.assert_not_called()

    def test_build_space_checks_uncreated_output_volume_without_creating_it(self):
        output = self.root / 'uncreated' / 'nested'
        with patch.object(policy.shutil, 'disk_usage', return_value=SimpleNamespace(free=0)) as usage:
            with self.assertRaisesRegex(ValueError, 'ARTIFACT_BUILD_SPACE_INSUFFICIENT'):
                policy.assert_build_space(output)
            usage.assert_called_once_with(self.root.resolve())
        self.assertFalse(output.parent.exists())
        with patch.object(policy.shutil, 'disk_usage', return_value=SimpleNamespace(free=1024 ** 3)):
            policy.assert_build_space(output)

    def test_terminal_retention_does_not_authorize_generated_cleanup(self):
        output = self.output(record={'status': 'failed'})
        plan = self.plan(retention_terminal=True)
        self.assertEqual(0, plan['files'])
        self.assertEqual(0, plan['directories'])
        plan['targets'] = policy.generated_targets(self.repo, output, False)
        plan['files'] = len(plan['targets'])
        plan['logicalBytes'] = sum(row['bytes'] for row in plan['targets'])
        with self.assertRaisesRegex(ValueError, 'TERMINAL_OUTPUT_PROTECTED'):
            policy.validate_plan(plan)

    def test_top_timeout_is_not_completed(self):
        self.output(record={'timeout': True})
        self.assertEqual(self.plan()['files'], 0)

    def test_top_timed_out_is_not_completed(self):
        self.output(record={'timedOut': True})
        self.assertEqual(self.plan()['files'], 0)

    def test_nested_compile_step_failure_is_not_completed(self):
        self.output(record={'steps': {'compile': {'steps': {'llvm': {'exitCode': 1}}}}})
        self.assertEqual(self.plan()['files'], 0)

    def test_terminal_active_process_ids_is_protected(self):
        self.output(record={'status': 'failed', 'activeProcessIds': [123]})
        self.assertEqual(self.plan(retention_terminal=True)['files'], 0)

    def test_terminal_running_is_protected(self):
        self.output(record={'status': 'cancelled', 'running': True})
        self.assertEqual(self.plan(retention_terminal=True)['files'], 0)

    def test_terminal_nested_active_is_protected(self):
        self.output(record={'status': 'failed', 'steps': {'compile': {'activeProcess': True}}})
        self.assertEqual(self.plan(retention_terminal=True)['files'], 0)

    def test_failed_terminal_with_running_case_is_protected(self):
        self.output(record={'status': 'failed', 'cases': [{'id': 'unfinished', 'status': 'running'}]})
        self.assertEqual(self.plan(retention_terminal=True)['files'], 0)

    def test_retention_failure_has_exact_owner_diagnostic(self):
        import hashlib
        output = self.output(record={'status': 'failed'})
        plan = self.plan(retention_terminal=True)
        record_path = output / 'result.json'
        record = json.loads(record_path.read_text())
        record['cases'] = [{'id': 'unfinished', 'status': 'running'}]
        record_path.write_text(json.dumps(record))
        plan['completionRecords'][0]['sha256'] = hashlib.sha256(record_path.read_bytes()).hexdigest()
        with self.assertRaises(ValueError) as failure:
            policy.validate_plan(plan)
        detail = json.loads(str(failure.exception))
        self.assertEqual(detail['failureId'], 'ARTIFACT_RETENTION_NOT_TERMINAL')
        self.assertEqual(detail['output'], str(output))
        self.assertEqual(detail['recordPath'], str(record_path))

    def test_owned_empty_cache_and_partition_directories_removed(self):
        output = self.output()
        (output / 'compile.slg-tmp/empty').mkdir(parents=True)
        plan = self.plan()
        self.assertEqual(plan['directories'], 3)
        result = self.execute(plan)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((output / '.sollang-cache').exists())
        self.assertFalse((output / 'compile.slg-tmp').exists())
        self.assertTrue(output.exists())
        self.assertTrue((output / 'result.json').exists())

    def test_private_cache_with_source_is_retained(self):
        output = self.output()
        (output / '.sollang-cache/source.slg').write_text('preserved source')
        plan = self.plan()
        self.assertEqual(plan['directories'], 0)
        self.assertEqual(self.execute(plan).returncode, 0)
        self.assertTrue((output / '.sollang-cache/source.slg').exists())

    def test_explicit_reuse_protects_empty_cache(self):
        output = self.output()
        (output / '.sollang-cache/compiler.cgu').unlink()
        plan = self.plan(reusable_directories=[output])
        self.assertEqual(plan['directories'], 0)
        self.assertEqual(self.execute(plan).returncode, 0)
        self.assertTrue((output / '.sollang-cache').exists())

    def test_directory_path_escape_is_rejected(self):
        output = self.output()
        plan = self.plan()
        plan['directoryTargets'] = [{'path': str(self.repo / 'source.slg-tmp'), 'output': str(output), 'kind': 'partition-temporary'}]
        plan['directories'] = 1
        with self.assertRaisesRegex(ValueError, 'OUTSIDE_ROOT'):
            policy.validate_plan(plan)

    def test_directory_new_content_rejects_entire_execution(self):
        output = self.output()
        plan = self.plan()
        (output / '.sollang-cache/new-source.slg').write_text('preserved source')
        result = self.execute(plan)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((output / 'compiler.exe').exists())
        self.assertTrue((output / '.sollang-cache/new-source.slg').exists())

    def test_directory_cleanup_idempotent(self):
        output = self.output()
        plan = self.plan()
        self.assertEqual(self.execute(plan).returncode, 0)
        self.assertFalse((output / '.sollang-cache').exists())
        rerun = self.execute(plan)
        self.assertEqual(rerun.returncode, 0, rerun.stderr)

    def test_private_directory_reparse_rejected_and_original_retained(self):
        output = self.output()
        plan = self.plan()
        cache = output / '.sollang-cache'
        original = output / 'retained-original'
        cache.rename(original)
        if os.name == 'nt':
            subprocess.run(['pwsh', '-NoProfile', '-Command', f"New-Item -ItemType Junction -Path '{cache}' -Target '{original}' | Out-Null"], check=True, capture_output=True)
        else:
            cache.symlink_to(original, target_is_directory=True)
        try:
            with self.assertRaisesRegex(ValueError, 'REPARSE_POINT'):
                policy.validate_plan(plan)
            self.assertTrue((original / 'compiler.cgu').exists())
        finally:
            if os.name == 'nt':
                os.rmdir(cache)
            else:
                cache.unlink()

    def test_cli_single_output_includes_private_cache_directory(self):
        output = self.output()
        reusable = self.output('explicit-reusable')
        destination = self.repo / 'single-output-plan.json'
        run = subprocess.run(['python', str(Path(__file__).parent / 'completed_artifact_plan.py'), '--repo', str(self.repo), '--output-directory', str(output), '--plan', str(destination), '--reusable-directory', str(reusable)], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        plan = json.loads(destination.read_text())
        self.assertEqual(plan['directories'], 1)
        self.assertEqual(plan['directoryTargets'][0]['path'], str(output / '.sollang-cache'))

    def test_atomic_empty_directory_race_preserves_new_source(self):
        import shutil
        output = self.output()
        plan = self.plan()
        plan_path = self.repo / 'race-plan.json'
        plan_path.write_text(json.dumps(plan))
        executor_directory = self.repo / 'isolated-executor'
        (executor_directory / 'contracts').mkdir(parents=True)
        shutil.copy2(Path(__file__).parent / 'completed_artifact_plan.py', executor_directory)
        shutil.copy2(policy.POLICY, executor_directory / 'contracts/artifact-lifecycle.json')
        source = (Path(__file__).parent / 'Invoke-CompletedArtifactCleanup.ps1').read_text(encoding='utf-8')
        atomic_call = '[IO.Directory]::Delete($path, $false)'
        self.assertEqual(source.count(atomic_call), 1)
        source = source.replace(atomic_call, "[IO.File]::WriteAllText((Join-Path $path 'race-original.slg'), 'preserved original'); " + atomic_call)
        executor = executor_directory / 'Invoke-CompletedArtifactCleanup.ps1'
        executor.write_text(source, encoding='utf-8')
        run = subprocess.run(['pwsh', '-NoProfile', '-File', str(executor), '-Plan', str(plan_path), '-Execute'], capture_output=True, text=True, encoding='utf-8')
        self.assertNotEqual(run.returncode, 0)
        self.assertTrue((output / '.sollang-cache/race-original.slg').exists())
        self.assertTrue((output / 'result.json').exists())
        self.assertTrue((output / 'source.slg').exists())
        record = json.loads(Path(str(plan_path)+'.execution.json').read_text(encoding='utf-8-sig'))
        self.assertEqual(record['status'], 'protected')
        self.assertEqual(record['output'], str(output))

    def actual_preflight_record(self):
        import hashlib
        fixture = Path(__file__).parent / 'contracts/fixtures/artifact-lifecycle-format-preflight-record.json'
        record = json.loads(fixture.read_text())['record']
        verifier = Path(__file__).resolve().parents[1] / policy.load_policy()['semanticPreflight']['verifier']
        record['inputHashes'] = {str(path.resolve()): hashlib.sha256(path.read_bytes()).hexdigest() for path in (verifier, policy.POLICY)}
        return record

    def test_actual_preflight_list_record_and_dictionary_equivalent(self):
        record = self.actual_preflight_record()
        self.assertTrue(policy.completed(record))
        record['steps'] = {row['id']: row for row in record['steps']}
        self.assertTrue(policy.completed(record))

    def test_preflight_format_guard_is_required_and_cannot_fail_or_remain_running(self):
        original = self.actual_preflight_record()
        self.assertTrue(policy.completed(original))
        missing = copy.deepcopy(original)
        missing['steps'] = [row for row in missing['steps'] if row['id'] != 'compiler-source-format']
        self.assertFalse(policy.completed(missing))
        for update in ({'exit': 1}, {'status': 'running'}, {'exit': None}):
            altered = copy.deepcopy(original)
            next(row for row in altered['steps'] if row['id'] == 'compiler-source-format').update(update)
            self.assertFalse(policy.completed(altered))
        missing_metadata = copy.deepcopy(original)
        missing_metadata.pop('formatPreflight')
        self.assertFalse(policy.completed(missing_metadata))

    def test_controls_only_preflight_does_not_require_compiler_format_step(self):
        record = self.actual_preflight_record()
        record['scope'] = 'controls-only'
        record['completed'] = record['total'] = 3
        record['cases'] = [row for row in record['cases'] if row['id'] != 'focused-selfhost']
        record['steps'] = [row for row in record['steps'] if row['id'] not in ('focused-selfhost', 'compiler-source-format')]
        record.pop('formatPreflight')
        self.assertTrue(policy.completed(record))

    def test_step_collection_type_and_nested_fail_closed(self):
        base = {'status': 'passed', 'inputsStable': True}
        for steps in ({'compile': {'exit': 0}}, [{'status': 'exited', 'exit': 0}], [[{'exit': 0}]]):
            with self.subTest(valid=steps):
                self.assertTrue(policy.completed(dict(base, steps=steps)))
        for steps in (None, [None], [{'exit': None}], [[{'exit': 1}]], [{'status': 'exited'}], [{'exit': 0, 'timeout': True}], [{'exit': 0, 'activeProcess': True}]):
            with self.subTest(invalid=steps):
                self.assertFalse(policy.completed(dict(base, steps=steps)))

    def test_preflight_negative_steps_require_pinned_exact_contract(self):
        original = self.actual_preflight_record()
        changes = [lambda r: r['inputHashes'].clear(),
                   lambda r: r['inputHashes'].update({next(iter(r['inputHashes'])): 'BAD'}),
                   lambda r: next(row for row in r['steps'] if row['id'] == 'deferred-text').update({'id': 'arbitrary-negative'}),
                   lambda r: next(row for row in r['steps'] if row['id'] == 'deferred-text').update({'exit': None}),
                   lambda r: next(row for row in r['steps'] if row['id'] == 'deferred-text').update({'exit': 2}),
                   lambda r: r['cases'][1].update({'passed': False}),
                   lambda r: r.update({'completed': 3})]
        for change in changes:
            record = copy.deepcopy(original)
            change(record)
            with self.subTest(change=changes.index(change)):
                self.assertFalse(policy.completed(record))

    def run_absolute_cleanup_supervisor(self, output, consumer=False):
        wrapper = self.repo / 'cleanup-supervisor.py'
        wrapper.write_text(
            'import argparse, subprocess, sys\n'
            f'sys.path.insert(0, {str(Path(__file__).resolve().parent)!r})\n'
            'from pathlib import Path\n'
            'from completed_artifact_plan import cleanup_output\n'
            'parser=argparse.ArgumentParser()\n'
            'parser.add_argument("--repo", type=Path)\n'
            'parser.add_argument("--output", type=Path)\n'
            'parser.add_argument("--consumer", action="store_true")\n'
            'args=parser.parse_args()\n'
            'child=subprocess.Popen([sys.executable,"-c","import time; time.sleep(30)",str(args.output)]) if args.consumer else None\n'
            'try:\n'
            '    cleanup_output(args.repo,args.output)\n'
            'finally:\n'
            '    if child is not None:\n'
            '        child.terminate()\n'
            '        child.wait(timeout=5)\n', encoding='utf-8')
        command = ['python', str(wrapper), '--repo', str(self.repo), '--output', str(output)]
        if consumer:
            command.append('--consumer')
        return subprocess.run(command, capture_output=True, text=True, encoding='utf-8')

    def test_absolute_nested_output_supervisor_is_not_active_consumer(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            self.root = self.repo / 'Sollang/candidate'
            self.root.mkdir(parents=True)
            output = self.output('semantic-preflight')
            run = self.run_absolute_cleanup_supervisor(output)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertFalse((output / 'compiler.exe').exists())
            self.assertFalse((output / '.sollang-cache').exists())
            self.assertTrue((output / 'result.json').exists())

    def test_absolute_supervisor_sibling_consumer_is_protected(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            self.root = self.repo / 'Sollang/candidate'
            self.root.mkdir(parents=True)
            output = self.output('semantic-preflight')
            run = self.run_absolute_cleanup_supervisor(output, consumer=True)
            self.assertNotEqual(run.returncode, 0)
            self.assertTrue((output / 'compiler.exe').exists())
            self.assertTrue((output / '.sollang-cache/compiler.cgu').exists())

    def test_absolute_supervisor_orphan_record_is_protected(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {'LOCALAPPDATA': str(self.repo)}):
            self.root = self.repo / 'Sollang/candidate'
            self.root.mkdir(parents=True)
            output = self.output('semantic-preflight', {'orphanProcessIds': [999]})
            run = self.run_absolute_cleanup_supervisor(output)
            self.assertNotEqual(run.returncode, 0)
            self.assertTrue((output / 'compiler.exe').exists())

class CompilerConsumerClosureTests(unittest.TestCase):
    setUp = ArtifactLifecycleTests.setUp
    tearDown = ArtifactLifecycleTests.tearDown
    output = ArtifactLifecycleTests.output
    plan = ArtifactLifecycleTests.plan
    execute = ArtifactLifecycleTests.execute

    def partial_comparison(self):
        old, replacement, consumer = self.products(True)
        runner = self.root / 'Sollang.ExampleTests.dll'
        runner.write_bytes(b'canonical comparer fixture')
        record = json.loads(consumer.read_text())
        record.update(status='failed', completed=1, total=3,
                      failure='AssertionError: second', cases=[dict(id='first', status='passed')], processes=[])
        record['inputHashes'][str(runner)] = hashlib.sha256(runner.read_bytes()).hexdigest()
        for index, case_id in enumerate(('first', 'second')):
            pair = []
            for role in ('managed', 'native'):
                path = self.root / (case_id + '-' + role) / 'result.json'
                path.parent.mkdir()
                child = dict(status='passed', completed=1, total=1, inputsStable=True,
                             processesStopped=True, selectedCatalog=[case_id],
                             cases=[dict(id=case_id, status='passed', buildExit=0, runExit=0)],
                             compiler=str(old / 'compiler.exe') if role == 'native' else 'managed.dll',
                             compilerSha256=record['inputHashes'][str(old / 'compiler.exe')])
                path.write_text(json.dumps(child))
                record['inputHashes'][str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
                pair.append(str(path))
            record['processes'].append(dict(pid=123 + index, exit=index, shutdownConfirmed=True,
                shutdownScope='owned-windows-job', naturalShutdownObservation=dict(outcome='drained'),
                command=['dotnet.exe', str(runner), '--compare-results'] + pair))
        consumer.write_text(json.dumps(record))
        return old, replacement, consumer, record

    def test_partial_comparison_retires_producer_without_completing_failed_scope(self):
        old, replacement, consumer, record = self.partial_comparison()
        original = consumer.read_bytes()
        unfinished = consumer.parent / 'unfinished.exe'
        unfinished.write_bytes(b'preserve failed comparison')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        audit = json.loads(closure.read_text())
        self.assertTrue(audit['verificationFailed'])
        self.assertTrue(audit['pipelineAborted'])
        self.assertEqual('terminal-partial-comparison', audit['consumers'][0]['disposition'])
        self.assertEqual(0, audit['consumers'][0]['completed'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(unfinished), targets)

    def test_partial_comparison_rejects_unsealed_or_unlinked_process_evidence(self):
        old, replacement, consumer, original = self.partial_comparison()
        for kind in ('counts', 'boolean-count', 'case-id', 'exit', 'shutdown', 'runner-pin', 'result-pin', 'failure-id'):
            record = copy.deepcopy(original)
            if kind == 'counts': record['completed'] = 0
            elif kind == 'boolean-count': record['completed'] = True
            elif kind == 'case-id': record['cases'][0]['id'] = 'other'
            elif kind == 'exit': record['processes'][-1]['exit'] = 0
            elif kind == 'shutdown': record['processes'][-1]['shutdownConfirmed'] = False
            elif kind == 'runner-pin': record['inputHashes'][record['processes'][0]['command'][1]] = '0' * 64
            elif kind == 'result-pin': record['inputHashes'][record['processes'][-1]['command'][-1]] = '0' * 64
            else: record['failure'] = 'AssertionError: other'
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def catalog_timeout(self):
        old, replacement, consumer = self.products(True)
        runner = self.root / 'runner.dll'
        runner.write_bytes(b'runner fixture')
        record = json.loads(consumer.read_text())
        case_id = 'focused-original'
        case_root = consumer.parent / 'cases' / hashlib.sha256(case_id.encode()).hexdigest()[:20]
        inner_path = case_root / 'runner/result.json'
        inner_path.parent.mkdir(parents=True)
        record.update(status='timed-out', completed=0, total=1, processes=[],
                      retryPolicy='no-automatic-retry', executionOrder='sequential',
                      compiler=str(old / 'compiler.exe'), managedReference=False,
                      runner=str(runner), selectedCatalog=[case_id],
                      failure='TimeoutExpired: focused runner',
                      cases=[dict(id=case_id, status='timed-out', processesStopped=True,
                                  resultPath=str(inner_path))])
        record['inputHashes'][str(runner)] = hashlib.sha256(runner.read_bytes()).hexdigest()
        child = dict(status='timed-out', completed=0, total=1, inputsStable=True,
                     processesStopped=True, failure=record['failure'],
                     cases=[dict(id=case_id, status='running')],
                     processes=[dict(pid=123, exit=137, shutdownConfirmed=True,
                         shutdownScope='owned-windows-job', startedAtUtc='2026-10-16T19:21:18+00:00',
                         finishedAtUtc='2026-10-16T19:24:18+00:00', command=['dotnet.exe', str(runner),
                         '--compiler', str(old / 'compiler.exe'), '--skip-bootstrap', '--suite', 'full',
                         '--target', 'windows-x64', '--jobs', '1', '--output-directory', str(inner_path.parent),
                         '--exact', case_id])],
                     terminatedProcesses=[dict(pid=123, reason='TimeoutExpired', exit=0, scope='owned-windows-job')])
        inner = dict(status='running', completed=0, total=1, selectedCatalog=[case_id],
                     compiler=str(old / 'compiler.exe'), inputHashes=record['inputHashes'])
        consumer.write_text(json.dumps(record))
        (case_root / 'result.json').write_text(json.dumps(child))
        inner_path.write_text(json.dumps(inner))
        return old, replacement, consumer, child, inner_path

    def test_catalog_timeout_retires_only_verified_producer(self):
        old, replacement, consumer, child, inner_path = self.catalog_timeout()
        original = consumer.read_bytes(), inner_path.read_bytes()
        unfinished = inner_path.parent / 'unfinished.exe'
        unfinished.write_bytes(b'preserve failed consumer')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertTrue(result['verificationFailed'])
        self.assertFalse(result['consumers'][0]['shutdownAudit']['claimsTestPassed'])
        self.assertEqual(0, result['consumers'][0]['completed'])
        self.assertEqual(original, (consumer.read_bytes(), inner_path.read_bytes()))
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(unfinished), targets)
        changed = json.loads(inner_path.read_text())
        changed['completed'] = 1
        inner_path.write_text(json.dumps(changed))
        with self.assertRaises(ValueError):
            policy.verified_consumer_closure(self.repo, old)

    def partial_catalog_timeout(self):
        old, replacement, consumer, child, inner_path = self.catalog_timeout()
        record = json.loads(consumer.read_text())
        case_id = 'completed-prefix'
        case_root = consumer.parent / 'cases' / hashlib.sha256(case_id.encode()).hexdigest()[:20]
        prior = case_root / 'runner/result.json'
        prior.parent.mkdir(parents=True)
        observed = dict(status='passed', completed=1, total=1, inputsStable=True,
                        processesStopped=True, compiler=str(old / 'compiler.exe'),
                        selectedCatalog=[case_id], inputHashes=record['inputHashes'])
        prior.write_text(json.dumps(observed))
        process = copy.deepcopy(child['processes'][0])
        process.update(exit=0)
        process['command'][-3:] = [str(prior.parent), '--exact', case_id]
        supervisor = dict(status='passed', completed=1, total=1, inputsStable=True,
                          processesStopped=True, processes=[process],
                          authoritativeRunnerResult=str(prior),
                          authoritativeRunnerResultSha256=hashlib.sha256(prior.read_bytes()).hexdigest())
        (case_root / 'result.json').write_text(json.dumps(supervisor))
        record.update(completed=1, total=2, selectedCatalog=[case_id, *record['selectedCatalog']],
                      cases=[dict(id=case_id, status='passed', processesStopped=True,
                                  resultPath=str(prior)), *record['cases']])
        consumer.write_text(json.dumps(record))
        return old, replacement, consumer, prior, inner_path

    def test_partial_catalog_timeout_retires_product_and_preserves_original_failure(self):
        old, replacement, consumer, prior, unfinished = self.partial_catalog_timeout()
        before = {p: p.read_bytes() for p in (consumer, prior, unfinished)}
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        audit = result['consumers'][0]['shutdownAudit']
        self.assertTrue(result['verificationFailed'])
        self.assertFalse(audit['claimsTestPassed'])
        self.assertEqual(1, audit['observedCompleted'])
        self.assertEqual(0, result['consumers'][0]['completed'])
        self.assertEqual(before, {p: p.read_bytes() for p in before})
        policy.verified_consumer_closure(self.repo, old)
        self.assertIn(str(old / 'compiler.exe'), [row['path'] for row in self.plan(retention_terminal=True)['targets']])
        observed = json.loads(prior.read_text())
        observed['processesStopped'] = False
        prior.write_text(json.dumps(observed))
        with self.assertRaises(ValueError):
            policy.verified_consumer_closure(self.repo, old)

    def test_partial_catalog_timeout_rejects_unproven_prefix_and_missing_final_shutdown(self):
        old, replacement, consumer, prior, unfinished = self.partial_catalog_timeout()
        original, previous = json.loads(consumer.read_text()), json.loads(prior.read_text())
        final_path = unfinished.parent.parent / 'result.json'
        final = json.loads(final_path.read_text())
        for kind in ('count', 'boolean-count', 'order', 'prefix-status', 'prefix-path',
                     'prefix-drift', 'prefix-orphan', 'final-job'):
            record, observed, last = copy.deepcopy(original), copy.deepcopy(previous), copy.deepcopy(final)
            if kind == 'count': record['completed'] = 0
            elif kind == 'boolean-count': record['completed'] = True
            elif kind == 'order': record['selectedCatalog'].reverse()
            elif kind == 'prefix-status': record['cases'][0]['status'] = 'running'
            elif kind == 'prefix-path': record['cases'][0]['resultPath'] = str(self.root / 'other/result.json')
            elif kind == 'prefix-drift': observed['compiler'] = 'other.exe'
            elif kind == 'prefix-orphan': observed['orphanProcessIds'] = [456]
            else: last['processes'][0]['shutdownConfirmed'] = False
            consumer.write_text(json.dumps(record))
            prior.write_text(json.dumps(observed))
            final_path.write_text(json.dumps(last))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_catalog_timeout_rejects_missing_or_mismatched_shutdown(self):
        old, replacement, consumer, child, inner_path = self.catalog_timeout()
        original = json.loads(consumer.read_text())
        inner = json.loads(inner_path.read_text())
        for kind in ('path', 'compiler', 'runner-pin', 'completed', 'boolean-count', 'job', 'termination', 'command', 'orphan', 'inner-pin', 'job-time'):
            record, nested, partial = copy.deepcopy(original), copy.deepcopy(child), copy.deepcopy(inner)
            if kind == 'path': record['cases'][0]['resultPath'] = str(self.root / 'elsewhere/result.json')
            elif kind == 'compiler': record['compiler'] = 'other.exe'
            elif kind == 'runner-pin': record['inputHashes'][record['runner']] = '0' * 64
            elif kind == 'completed': record['completed'] = 1
            elif kind == 'boolean-count': record['completed'] = False
            elif kind == 'job': nested['processes'][0]['shutdownConfirmed'] = False
            elif kind == 'termination': nested['terminatedProcesses'] = []
            elif kind == 'command': nested['processes'][0]['command'][-1] = 'other-case'
            elif kind == 'orphan': nested['orphanProcessIds'] = [456]
            elif kind == 'job-time': nested['processes'][0]['finishedAtUtc'] = 'invalid'
            else: partial['inputHashes'][str(old / 'compiler.exe')] = '0' * 64
            consumer.write_text(json.dumps(record))
            (inner_path.parent.parent / 'result.json').write_text(json.dumps(nested))
            inner_path.write_text(json.dumps(partial))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def unpin_producer(self, old, consumer):
        record = json.loads(consumer.read_text())
        record['inputHashes'].pop(str(old / 'result.json'))
        consumer.write_text(json.dumps(record))
        return record

    def canceled_consumer(self, consumer):
        record = json.loads(consumer.read_text())
        record.update(status='canceled', completed=0, total=20, cases=[],
                      processShutdownAuditReference=str(consumer.parent / 'cancellation-process-audit.json'),
                      processes=[{'pid': 123, 'exit': None, 'command': ['owned-wrapper'],
                                  'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
                                  'startedAtUtc': '2026-10-05T19:44:49+00:00',
                                  'shutdownObservedAtUtc': '2026-10-05T19:47:19+00:00'}])
        audit = {'schemaVersion': 1, 'rootPid': 123, 'rootExists': False,
                 'activeOwnedProcesses': [], 'toolSessionTerminalExit': 1,
                 'observedAtUtc': '2026-10-05T19:47:19+00:00'}
        audit_path = Path(record['processShutdownAuditReference'])
        audit_path.write_text(json.dumps(audit))
        consumer.write_text(json.dumps(record))
        return record, audit_path, audit

    def test_timed_out_consumption_preserves_unfinished_cases_and_outputs(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(status='timed-out', completed=0, total=1, retryPolicy='no-automatic-retry',
                      failure='TimeoutExpired: compiler build exceeded original bound',
                      cases=[{'id': 'first', 'status': 'running', 'passed': False}],
                      processes=[{'pid': 123, 'command': [str(old / 'compiler.exe'), 'build'],
                                  'exit': 137, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
                                  'startedAtUtc': '2026-10-06T06:36:58+00:00',
                                  'finishedAtUtc': '2026-10-06T06:56:58+00:00'}],
                      terminatedProcesses=[{'pid': 123, 'reason': 'TimeoutExpired',
                                            'exit': 0, 'scope': 'owned-windows-job'}])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unfinished.exe'
        generated.write_bytes(b'preserve unfinished output')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertTrue(result['verificationFailed'])
        self.assertTrue(result['pipelineAborted'])
        self.assertEqual('terminal-timed-out', result['consumers'][0]['disposition'])
        self.assertEqual(0, result['consumers'][0]['completed'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for kind in ('live', 'boolean-exit', 'wrapper', 'wrong-pid', 'wrong-cause', 'passed-case', 'orphan'):
            invalid = copy.deepcopy(record)
            if kind == 'live': invalid['processes'][0]['shutdownConfirmed'] = False
            elif kind == 'boolean-exit': invalid['processes'][0]['exit'] = True
            elif kind == 'wrapper': invalid['processes'][0]['command'][0] = 'wrapper'
            elif kind == 'wrong-pid': invalid['terminatedProcesses'][0]['pid'] = 456
            elif kind == 'wrong-cause': invalid['failure'] = 'AssertionError: wrong output'
            elif kind == 'passed-case': invalid['cases'][0].update(status='passed', passed=True)
            else: invalid['orphanProcessIds'] = [456]
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_timed_out_diagnostic_without_cases_preserves_failure_and_outputs(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.pop('cases', None)
        record.update(status='timed-out', completed=0, total=1,
                      failure='TimeoutExpired: diagnostic prepare exceeded bound',
                      processes=[{'pid': 123, 'command': [str(old / 'compiler.exe'), 'prepare'],
                                  'exit': 137, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
                                  'startedAtUtc': '2026-10-06T06:36:58+00:00',
                                  'finishedAtUtc': '2026-10-06T06:37:58+00:00'}],
                      terminatedProcesses=[{'pid': 123, 'reason': 'TimeoutExpired',
                                            'exit': 0, 'scope': 'owned-windows-job'}])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unfinished.ll'
        generated.write_bytes(b'preserve diagnostic output')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertTrue(result['verificationFailed'])
        self.assertEqual('terminal-timed-out', result['consumers'][0]['disposition'])
        self.assertEqual(0, result['consumers'][0]['completed'])
        self.assertEqual(original, consumer.read_bytes())
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for kind in ('false-completion', 'live', 'missing-termination', 'orphan'):
            invalid = copy.deepcopy(record)
            if kind == 'false-completion': invalid['completed'] = 1
            elif kind == 'live': invalid['processes'][0]['shutdownConfirmed'] = False
            elif kind == 'missing-termination': invalid['terminatedProcesses'] = []
            else: invalid['orphanProcessIds'] = [456]
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_boolean_legacy_cases_retire_only_compiler_and_preserve_failed_scope(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(completed=2, total=3, failure='AssertionError: late diagnostic capture',
                      cases=[dict(id='first', passed=True), dict(id='second', passed=True)])
        record['processes'][0].update(shutdownConfirmed=True, shutdownScope='owned-windows-job',
                                      naturalShutdownObservation=dict(outcome='drained'))
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        unfinished = consumer.parent / 'unfinished.exe'
        unfinished.write_bytes(b'keep failed observer output')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        audit = json.loads(closure.read_text())
        row = audit['consumers'][0]
        self.assertEqual(0, row['completed'])
        self.assertIsNone(row['total'])
        self.assertEqual('terminal-boolean-case-observation', row['disposition'])
        self.assertEqual(['case-oracles-unrecorded'], row['unprovenReasons'])
        self.assertEqual((2, 3), (row['observedCompleted'], row['observedTotal']))
        self.assertTrue(audit['verificationFailed'])
        self.assertTrue(audit['pipelineAborted'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [item['path'] for item in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(unfinished), targets)
        for kind in ('count', 'duplicate', 'live', 'undrained', 'missing-pin', 'claim', 'roles', 'ordinary-mode'):
            invalid = copy.deepcopy(record)
            if kind == 'count': invalid['completed'] = 1
            elif kind == 'duplicate': invalid['cases'][1]['id'] = 'first'
            elif kind == 'live': invalid['processes'][0]['activeProcess'] = True
            elif kind == 'undrained': invalid['processes'][0]['naturalShutdownObservation']['outcome'] = 'running'
            elif kind == 'missing-pin': invalid['inputHashes'].pop(str(old / 'compiler.exe'))
            elif kind == 'claim': invalid['claimsAcceptancePassed'] = True
            elif kind == 'roles': invalid['cases'][0]['roles'] = {'native': {'status': 'running'}}
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                              legacy_terminal=kind != 'ordinary-mode')

    def test_complete_boolean_cache_observer_remains_unverified_for_cleanup(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        record['cases'] = [dict(id='cache-observation', passed=True, rawRecord='prior.json',
                                cache={'reused': 122})]
        record['processes'][0].update(shutdownConfirmed=True, shutdownScope='owned-windows-job',
                                      naturalShutdownObservation=dict(outcome='drained'))
        consumer.write_text(json.dumps(record))
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual(0, row['completed'])
        self.assertEqual('terminal-boolean-case-observation', row['disposition'])
        self.assertTrue(policy.unverified_consumer_protected(consumer.parent))

        record['cases'][0]['cache'] = [50, 0, 145, 0, 23]
        consumer.write_text(json.dumps(record))
        numeric = policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)
        self.assertEqual(0, numeric['consumers'][0]['completed'])
        for invalid_cache in ([True], [-1], ['running'], [], [{'activeProcess': True}]):
            record['cases'][0]['cache'] = invalid_cache
            consumer.write_text(json.dumps(record))
            with self.subTest(cache=invalid_cache), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_captured_symbol_observations_never_complete_consumer(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        source = consumer.parent / 'input.slg'
        source.write_text('main {}')
        record['inputHashes'][str(source)] = hashlib.sha256(source.read_bytes()).hexdigest()
        record.update(status='passed', completed=1, total=1, claimsAcceptancePassed=False,
                      cases=[{'source': source.relative_to(self.repo).as_posix(), 'status': 'observed',
                              'durationMilliseconds': 1, 'exit': 0, 'stdoutLines': 1,
                              'stdoutBytes': 7, 'stderr': ''}],
                      processes=[{'pid': 123, 'command': [str(old / 'compiler.exe'), 'symbols', str(source)],
                                  'exit': 0, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job'}])
        stdout = consumer.parent / 'source0.stdout'
        stderr = consumer.parent / 'source0.stderr'
        stdout.write_text('symbol\n')
        stderr.write_text('')
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unverified.exe'
        generated.write_bytes(b'preserve observed output')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual(0, row['completed'])
        self.assertEqual('terminal-observation-without-test-scope', row['disposition'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for kind in ('claim', 'count', 'boolean-exit', 'command', 'missing-pin', 'log', 'live', 'status'):
            invalid = copy.deepcopy(record)
            stdout.write_text('symbol\n')
            if kind == 'claim': invalid['claimsAcceptancePassed'] = True
            elif kind == 'count': invalid['cases'][0]['stdoutBytes'] = 6
            elif kind == 'boolean-exit': invalid['cases'][0]['exit'] = True
            elif kind == 'command': invalid['processes'][0]['command'][1] = 'build'
            elif kind == 'missing-pin': invalid['inputHashes'].pop(str(source))
            elif kind == 'log': stdout.write_text('changed length')
            elif kind == 'live': invalid['processes'][0]['shutdownConfirmed'] = False
            else: invalid['cases'][0]['status'] = 'running'
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_captured_validate_timeout_prefix_retires_only_producer(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        sources = [consumer.parent / f'input{index}.slg' for index in range(2)]
        for source in sources:
            source.write_text('main {}')
            record['inputHashes'][str(source)] = hashlib.sha256(source.read_bytes()).hexdigest()
        process = {'pid': 123, 'command': [str(old / 'compiler.exe'), 'validate', str(sources[0])],
                   'exit': 0, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
                   'startedAtUtc': '2026-10-09T07:00:00+00:00',
                   'finishedAtUtc': '2026-10-09T07:00:01+00:00'}
        record.update(status='timed-out', completed=1, total=2,
                      failure='TimeoutExpired: validate exceeded original bound',
                      cases=[{'id': 'first', 'status': 'passed', 'exit': 0, 'durationMilliseconds': 47,
                              'stdout': 'checked diagnostics = 0\n', 'stderr': ''},
                             {'id': 'next', 'status': 'timed-out'}],
                      processes=[process, dict(process, pid=124, exit=137,
                          command=[str(old / 'compiler.exe'), 'validate', str(sources[1])])],
                      terminatedProcesses=[{'pid': 124, 'reason': 'TimeoutExpired',
                                            'exit': 0, 'scope': 'owned-windows-job'}])
        stdout = consumer.parent / 'case0.stdout'
        stderr = consumer.parent / 'case0.stderr'
        stdout.write_text('checked diagnostics = 0\n')
        stderr.write_text('')
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unfinished.ll'
        generated.write_bytes(b'preserve failed consumer')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertEqual((0, 2), (result['consumers'][0]['completed'], result['consumers'][0]['unexecuted']))
        self.assertTrue(result['verificationFailed'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for kind in ('count', 'boolean-exit', 'command', 'product', 'source-pin', 'stdout', 'stderr',
                     'missing-log', 'live', 'orphan', 'promoted-timeout', 'duplicate-id'):
            invalid = copy.deepcopy(record)
            stdout.write_text('checked diagnostics = 0\n')
            stderr.write_text('')
            if kind == 'count': invalid['completed'] = 0
            elif kind == 'boolean-exit': invalid['cases'][0]['exit'] = True
            elif kind == 'command': invalid['processes'][0]['command'][1] = 'prepare'
            elif kind == 'product': invalid['processes'][0]['command'][0] = 'wrapper'
            elif kind == 'source-pin': invalid['inputHashes'][str(sources[0])] = '0' * 64
            elif kind == 'stdout': stdout.write_text('changed')
            elif kind == 'stderr': stderr.write_text('unexpected')
            elif kind == 'missing-log': stdout.unlink()
            elif kind == 'live': invalid['processes'][1]['shutdownConfirmed'] = False
            elif kind == 'orphan': invalid['orphanProcessIds'] = [456]
            elif kind == 'promoted-timeout': invalid['cases'][1].update(status='passed', passed=True)
            else: invalid['cases'][1]['id'] = 'first'
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_partial_timeout_retirement_preserves_passed_scope_and_unfinished_outputs(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        process = {'pid': 123, 'command': [str(old / 'compiler.exe'), 'prepare'],
                   'exit': 0, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
                   'startedAtUtc': '2026-10-06T06:00:00+00:00',
                   'finishedAtUtc': '2026-10-06T06:01:00+00:00'}
        timed = dict(process, pid=124, command=[str(old / 'compiler.exe'), 'typed-ir'], exit=137)
        record.update(status='timed-out', completed=1, total=2,
                      failure='TimeoutExpired: typed-ir exceeded its bound',
                      cases=[{'id': 'prepare', 'status': 'passed', 'passed': True, 'exit': 0}],
                      processes=[process, timed],
                      terminatedProcesses=[{'pid': 124, 'reason': 'TimeoutExpired', 'exit': 0,
                                            'scope': 'owned-windows-job'}])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unfinished.ll'
        generated.write_bytes(b'preserve partial timeout')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual((0, 2), (row['completed'], row['unexecuted']))
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for kind in ('count', 'boolean', 'exit', 'missing-exit', 'termination', 'orphan'):
            invalid = copy.deepcopy(record)
            if kind == 'count': invalid['completed'] = 0
            elif kind == 'boolean': invalid['completed'] = True
            elif kind == 'exit': invalid['processes'][0]['exit'] = 1
            elif kind == 'missing-exit': invalid['cases'][0].pop('exit')
            elif kind == 'termination': invalid['terminatedProcesses'][0]['pid'] = 999
            else: invalid['orphanProcessIds'] = [999]
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_partial_build_run_timeout_retirement_preserves_failed_consumer(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        process = {'pid': 123, 'command': [str(old / 'compiler.exe'), 'build'],
                   'exit': 0, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
                   'startedAtUtc': '2026-10-09T06:00:00+00:00',
                   'finishedAtUtc': '2026-10-09T06:01:00+00:00'}
        passed = {'id': 'first', 'status': 'passed', 'passed': True,
                  'expectedBuildExit': 0, 'buildExit': 0, 'buildStderr': '',
                  'runExit': 0, 'runStderr': '', 'runStdout': 'expected'}
        record.update(status='timed-out', completed=1, total=2,
                      failure='TimeoutExpired: next build exceeded original bound',
                      cases=[passed, {'id': 'next', 'status': 'timed-out', 'passed': False}],
                      processes=[process, dict(process, pid=124, exit=137)],
                      terminatedProcesses=[{'pid': 124, 'reason': 'TimeoutExpired',
                                            'exit': 0, 'scope': 'owned-windows-job'}])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unfinished.exe'
        generated.write_bytes(b'preserve failed consumer output')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement,
                                                 legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertTrue(result['verificationFailed'])
        self.assertTrue(result['pipelineAborted'])
        self.assertEqual(0, result['consumers'][0]['completed'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for key in ('expectedBuildExit', 'buildExit', 'runExit', 'buildStderr', 'runStderr'):
            for bad in (None, True, 1, '0') if key.endswith('Exit') else (None, 'unexpected'):
                invalid = copy.deepcopy(record)
                invalid['cases'][0][key] = bad
                consumer.write_text(json.dumps(invalid))
                with self.subTest(key=key, bad=bad), self.assertRaises(ValueError):
                    policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                                  legacy_terminal=True)
        invalid = copy.deepcopy(record)
        invalid['cases'][0]['exit'] = 1
        consumer.write_text(json.dumps(invalid))
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                          legacy_terminal=True)

    def test_controller_lost_retirement_preserves_unknown_original_outcome(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(status='running', completed=0, total=2,
                      cases=[{'id': 'first', 'status': 'running', 'passed': False}],
                      processes=[{'pid': 123, 'command': [str(old / 'compiler.exe'), 'build'],
                                  'shutdownConfirmed': False, 'shutdownScope': 'owned-windows-job',
                                  'startedAtUtc': '2026-10-06T06:00:00+00:00'}])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unsealed.exe'
        generated.write_bytes(b'preserve unknown output')
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)
        audit = {'schemaVersion': 1, 'status': 'controller-handle-missing-original-exit-unsealed',
                 'originalResultSha256': hashlib.sha256(original).hexdigest(),
                 'recordedCompilerPid': 123, 'recordedCompilerPidExists': False,
                 'matchingCompilerClangPythonProcessesObserved': [], 'inputsStableNow': True,
                 'claimsBuildExitKnown': False, 'claimsCasePassed': False,
                 'toolSession': 456, 'completed': 0, 'total': 2,
                 'observedAtUtc': '2026-10-06T06:05:00+00:00'}
        audit_path = consumer.parent / 'controller-loss-terminal-audit.json'
        audit_path.write_text(json.dumps(audit))
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertTrue(result['pipelineAborted'])
        self.assertEqual('terminal-controller-lost', result['consumers'][0]['disposition'])
        self.assertEqual((0, 2), (result['consumers'][0]['completed'], result['consumers'][0]['unexecuted']))
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for key, value in [('recordedCompilerPidExists', True), ('recordedCompilerPid', 999),
                           ('originalResultSha256', '0' * 64), ('claimsCasePassed', True),
                           ('claimsBuildExitKnown', True), ('matchingCompilerClangPythonProcessesObserved', [123]),
                           ('observedAtUtc', '2026-10-06T05:00:00+00:00')]:
            invalid = dict(audit, **{key: value})
            audit_path.write_text(json.dumps(invalid))
            with self.subTest(key=key), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)
        audit_path.write_text(json.dumps(audit))
        with patch.object(policy, 'assert_output_shutdown', side_effect=ValueError('active process')):
            with self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_drained_unsealed_capture_retires_only_verified_producer(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(status='failed', completed=0, total=1, cases=[],
                      failure='AssertionError: captured diagnostic bytes differ',
                      processes=[{'pid': 123, 'command': [str(old / 'compiler.exe'), 'diagnostic-counts'],
                                  'exit': 0, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
                                  'startedAtUtc': '2026-10-06T06:00:00+00:00',
                                  'finishedAtUtc': '2026-10-06T06:01:00+00:00',
                                  'naturalShutdownObservation': {'rootPid': 123, 'outcome': 'drained',
                                      'samples': [{'activeProcesses': 0, 'ownedPids': []}]}}])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'failed-capture.exe'
        generated.write_bytes(b'preserve unverified capture')
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertTrue(result['verificationFailed'])
        self.assertTrue(result['pipelineAborted'])
        self.assertEqual('terminal-unsealed-capture', result['consumers'][0]['disposition'])
        self.assertEqual(0, result['consumers'][0]['completed'])
        self.assertEqual(original, consumer.read_bytes())
        targets = [row['path'] for row in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(generated), targets)
        for kind in ('live', 'boolean-exit', 'wrapper', 'pid', 'streams', 'timezone', 'reversed-time'):
            invalid = copy.deepcopy(record)
            process = invalid['processes'][0]
            if kind == 'live': process['shutdownConfirmed'] = False
            elif kind == 'boolean-exit': process['exit'] = False
            elif kind == 'wrapper': process['command'][0] = 'wrapper'
            elif kind == 'pid': process['naturalShutdownObservation']['rootPid'] = 999
            elif kind == 'streams': process['naturalShutdownObservation']['outcome'] = 'live'
            elif kind == 'timezone': process['finishedAtUtc'] = '2026-10-06T06:01:00'
            else: process['finishedAtUtc'] = '2026-10-06T05:01:00+00:00'
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_canceled_retirement_preserves_outputs_and_cancellation(self):
        old, replacement, consumer = self.products()
        self.canceled_consumer(consumer)
        original = consumer.read_bytes()
        generated = consumer.parent / 'unfinished.ll'
        generated.write_bytes(b'canceled output')
        with self.assertRaisesRegex(ValueError, 'CONSUMER_NOT_TERMINAL'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        record = json.loads(closure.read_text())
        self.assertTrue(record['pipelineAborted'])
        self.assertFalse(record['verificationFailed'])
        self.assertEqual('canceled', record['consumers'][0]['status'])
        self.assertEqual(0, record['consumers'][0]['completed'])
        self.assertEqual(20, record['consumers'][0]['unexecuted'])
        run = self.execute(self.plan(retention_terminal=True))
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertTrue(generated.exists())
        self.assertEqual(original, consumer.read_bytes())

    def test_canceled_retirement_rejects_missing_active_or_mismatched_audit(self):
        old, replacement, consumer = self.products()
        record, audit_path, audit = self.canceled_consumer(consumer)
        for changes in ({'rootExists': True}, {'activeOwnedProcesses': [123]},
                        {'rootPid': 999}, {'toolSessionTerminalExit': None},
                        {'observedAtUtc': '2026-10-05T19:47:20+00:00'}):
            with self.subTest(changes=changes):
                audit_path.write_text(json.dumps(dict(audit, **changes)))
                with self.assertRaisesRegex(ValueError, 'CANCELED_CONSUMER'):
                    policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)
        audit_path.unlink()
        with self.assertRaisesRegex(ValueError, 'CANCELED_CONSUMER'):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_canceled_retirement_rejects_changed_audit_and_live_output(self):
        from unittest.mock import patch
        old, replacement, consumer = self.products()
        record, audit_path, audit = self.canceled_consumer(consumer)
        with patch.object(policy, 'windows_active_directories', return_value={str(consumer.parent).casefold()}):
            with self.assertRaisesRegex(ValueError, 'OUTPUT_ACTIVE'):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        audit_path.write_text(json.dumps(dict(audit, extra='changed')))
        with self.assertRaisesRegex(ValueError, 'CLOSURE_CHANGED'):
            policy.verified_consumer_closure(self.repo, old)

    def test_legacy_missing_producer_pin_requires_explicit_mode(self):
        old, replacement, consumer = self.products()
        self.unpin_producer(old, consumer)
        with self.assertRaisesRegex(ValueError, 'BUILD_LINK_INVALID'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_legacy_binary_pinned_retirement_preserves_unverified_consumer(self):
        old, replacement, consumer = self.products()
        self.unpin_producer(old, consumer)
        original_consumer = consumer.read_bytes()
        original_producer = (old / 'result.json').read_bytes()
        generated = consumer.parent / 'unverified.exe'
        generated.write_bytes(b'preserve legacy consumer')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        record = json.loads(closure.read_text())
        self.assertEqual('legacy-binary-pinned-terminal', record['evidenceMode'])
        self.assertEqual(0, record['consumers'][0]['completed'])
        self.assertEqual(1, record['consumers'][0]['observedPassed'])
        self.assertEqual('terminal-producer-record-unpinned', record['consumers'][0]['disposition'])
        self.assertTrue(record['pipelineAborted'])
        self.assertEqual(str(closure), policy.verified_consumer_closure(self.repo, old)['path'])
        plan = self.plan(retention_terminal=True)
        self.assertNotIn(str(generated), [row['path'] for row in plan['targets']])
        run = self.execute(plan)
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertTrue(generated.exists())
        self.assertEqual(original_consumer, consumer.read_bytes())
        self.assertEqual(original_producer, (old / 'result.json').read_bytes())
        self.assertEqual(str(closure), policy.verified_consumer_closure(self.repo, old, allow_missing_product=True)['path'])

    def diagnostic_observation(self, old, consumer):
        self.unpin_producer(old, consumer)
        record = json.loads(consumer.read_text())
        for key in ('cases', 'completed', 'total'):
            record.pop(key)
        record['scope'] = 'native-semantic-diagnostic-observation'
        consumer.write_text(json.dumps(record))
        return record

    def test_legacy_observation_retirement_preserves_unknown_scope_and_outputs(self):
        old, replacement, consumer = self.products()
        self.diagnostic_observation(old, consumer)
        original = consumer.read_bytes()
        generated = consumer.parent / 'observed.ll'
        generated.write_bytes(b'preserve observation')
        with self.assertRaisesRegex(ValueError, 'BUILD_LINK_INVALID'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        record = json.loads(closure.read_text())
        row = record['consumers'][0]
        self.assertEqual(0, row['completed'])
        for key in ('total', 'executed', 'failed', 'unexecuted', 'observedCompleted', 'observedTotal'):
            self.assertIsNone(row[key])
        self.assertTrue(record['pipelineAborted'])
        self.assertEqual('terminal-observation-without-test-scope', row['disposition'])
        self.assertEqual(str(closure), policy.verified_consumer_closure(self.repo, old)['path'])
        plan = self.plan(retention_terminal=True)
        self.assertNotIn(str(generated), [x['path'] for x in plan['targets']])
        run = self.execute(plan)
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue(generated.exists())
        self.assertEqual(original, consumer.read_bytes())

    def test_legacy_build_capture_counts_do_not_become_verified_tests(self):
        old, replacement, consumer = self.products()
        record = self.unpin_producer(old, consumer)
        record.pop('cases')
        record.update(status='failed', failure='wrapper failed after successful build')
        consumer.write_text(json.dumps(record))
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual(0, row['completed'])
        self.assertIsNone(row['total'])
        self.assertEqual(1, row['observedCompleted'])
        self.assertEqual(1, row['observedTotal'])
        self.assertTrue((consumer.parent / 'consumer-retirement-protection.json').exists())

    def pending_role_capture(self, old, consumer):
        record = self.unpin_producer(old, consumer)
        record.update(status='failed', completed=0, total=6, failure='paired assertion failed')
        record['cases'] = [{'id': 'first', 'status': 'pending',
                            'roles': {'CSharp': {'status': 'passed', 'exit': 0}}}]
        record['processes'][0].update(command=[str(old / 'compiler.exe')], exit=1)
        consumer.write_text(json.dumps(record))
        return record

    def test_legacy_pending_roles_retire_product_preserve_original_outputs(self):
        old, replacement, consumer = self.products(True)
        self.pending_role_capture(old, consumer)
        original = consumer.read_bytes()
        producer = (old / 'result.json').read_bytes()
        generated = consumer.parent / 'unfinished.ll'
        generated.write_bytes(b'incomplete paired output')
        with self.assertRaises(ValueError):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        record = json.loads(closure.read_text())
        row = record['consumers'][0]
        self.assertEqual('terminal-incomplete-role-scope', row['disposition'])
        self.assertEqual(0, row['completed'])
        self.assertEqual((0, 6), (row['observedCompleted'], row['observedTotal']))
        for key in ('total', 'executed', 'failed', 'unexecuted'):
            self.assertIsNone(row[key])
        self.assertTrue(record['verificationFailed'])
        self.assertTrue(record['pipelineAborted'])
        plan = self.plan(retention_terminal=True)
        self.assertNotIn(str(generated), [target['path'] for target in plan['targets']])
        run = self.execute(plan)
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertTrue(generated.exists())
        self.assertEqual(original, consumer.read_bytes())
        self.assertEqual(producer, (old / 'result.json').read_bytes())
        self.assertEqual(str(closure), policy.verified_consumer_closure(self.repo, old, allow_missing_product=True)['path'])

    def test_pending_role_retirement_requires_failed_compiler_capture(self):
        old, replacement, consumer = self.products(True)
        original = self.pending_role_capture(old, consumer)
        for kind in ('passed', 'completed', 'missing-failure', 'zero-exit', 'other-executable', 'no-processes'):
            record = copy.deepcopy(original)
            if kind == 'passed':
                record['status'] = 'passed'
            elif kind == 'completed':
                record['completed'] = 1
            elif kind == 'missing-failure':
                record.pop('failure')
            elif kind == 'zero-exit':
                record['processes'][0]['exit'] = 0
            elif kind == 'other-executable':
                record['processes'][0]['command'] = ['other.exe']
            else:
                record['processes'] = []
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_pending_role_retirement_rejects_invalid_or_active_roles(self):
        old, replacement, consumer = self.products(True)
        original = self.pending_role_capture(old, consumer)
        for kind in ('missing-exit', 'active', 'mismatch', 'empty-roles', 'over-total', 'claimed-case-pass'):
            record = copy.deepcopy(original)
            role = record['cases'][0]['roles']['CSharp']
            if kind == 'missing-exit':
                role.pop('exit')
            elif kind == 'active':
                role['activeProcess'] = {'pid': 123}
            elif kind == 'mismatch':
                role['exit'] = 1
            elif kind == 'empty-roles':
                record['cases'][0]['roles'] = {}
            elif kind == 'over-total':
                record['cases'] *= 7
            else:
                record['cases'][0]['passed'] = True
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_observation_rejects_partial_scope_and_missing_execution(self):
        old, replacement, consumer = self.products()
        original = self.diagnostic_observation(old, consumer)
        for update in ({'completed': None}, {'total': 0}, {'cases': []},
                       {'scope': ''}, {'processes': []},
                       {'processes': [{'pid': 123, 'exit': None}]},
                       {'processesStopped': False}, {'inputsStable': False}):
            with self.subTest(update=update):
                consumer.write_text(json.dumps(dict(original, **update)))
                with self.assertRaises(ValueError):
                    policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def failed_diagnostic_pairs(self, consumer):
        record = json.loads(consumer.read_text())
        diagnostic = {'exitCode': 1, 'stdout': '', 'stderr': 'expected diagnostic\n'}
        record.update(status='failed', completed=1, total=2, cases=[
            {'id': 'syntax', 'sourceSha256': 'a' * 64, 'passed': True,
             'managed': diagnostic.copy(), 'selfhost': diagnostic.copy()},
            {'id': 'build', 'sourceSha256': 'a' * 64, 'passed': False,
             'managed': diagnostic.copy(),
             'selfhost': dict(diagnostic, stderr='expected diagnostic\nretained stage\n')}])
        consumer.write_text(json.dumps(record))
        return record

    def test_legacy_failed_diagnostic_pairs_preserve_failure_and_outputs(self):
        old, replacement, consumer = self.products(True)
        self.failed_diagnostic_pairs(consumer)
        original = consumer.read_bytes()
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        record = json.loads(closure.read_text())
        row = record['consumers'][0]
        self.assertEqual('terminal-failed-diagnostic-pairs', row['disposition'])
        self.assertEqual(('failed', 0, 1), (row['status'], row['completed'], row['observedCompleted']))
        self.assertTrue(record['verificationFailed'])
        self.assertTrue(record['pipelineAborted'])
        self.assertEqual(original, consumer.read_bytes())
        self.assertEqual(str(closure), policy.verified_consumer_closure(self.repo, old)['path'])

    def test_equal_legacy_roles_retire_product_without_promoting_or_deleting_capture(self):
        old, replacement, consumer = self.products(True)
        record = self.failed_diagnostic_pairs(consumer)
        record.update(status='passed', completed=2)
        record['cases'][1]['passed'] = True
        record['cases'][1]['selfhost'] = record['cases'][1]['managed'].copy()
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual(('passed', 0, 2), (row['status'], row['completed'], row['observedCompleted']))
        self.assertEqual('terminal-equal-role-capture', row['disposition'])
        self.assertEqual(original, consumer.read_bytes())
        self.assertTrue((consumer.parent / 'consumer-retirement-protection.json').exists())
        self.assertEqual(str(closure), policy.verified_consumer_closure(self.repo, old)['path'])

    def test_equal_legacy_roles_reject_missing_identity_mismatch_and_nonterminal_evidence(self):
        old, replacement, consumer = self.products(True)
        record = self.failed_diagnostic_pairs(consumer)
        record.update(status='passed', completed=2)
        record['cases'][1].update(passed=True, selfhost=record['cases'][1]['managed'].copy())
        for kind in ('missing-source', 'invalid-hash', 'mismatch', 'boolean-exit', 'duplicate-id', 'missing-process', 'running'):
            invalid = copy.deepcopy(record)
            if kind == 'missing-source': invalid['cases'][0].pop('sourceSha256')
            elif kind == 'invalid-hash': invalid['cases'][0]['sourceSha256'] = 'z' * 64
            elif kind == 'mismatch': invalid['cases'][0]['selfhost']['stderr'] = 'different'
            elif kind == 'boolean-exit': invalid['cases'][0]['selfhost']['exitCode'] = True
            elif kind == 'duplicate-id': invalid['cases'][1]['id'] = invalid['cases'][0]['id']
            elif kind == 'missing-process': invalid['processes'] = []
            elif kind == 'running': invalid['processesStopped'] = False
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_failed_diagnostic_pairs_reject_inconsistent_or_untyped_evidence(self):
        old, replacement, consumer = self.products(True)
        original = self.failed_diagnostic_pairs(consumer)
        for kind in ['false-pass', 'false-failure', 'missing-role', 'untyped-exit',
                     'untyped-output', 'bad-source-hash', 'wrong-completed', 'missing-process', 'running']:
            record = copy.deepcopy(original)
            if kind == 'false-pass': record['cases'][0]['selfhost']['stderr'] = 'different'
            elif kind == 'false-failure': record['cases'][1]['selfhost'] = record['cases'][1]['managed'].copy()
            elif kind == 'missing-role': record['cases'][1].pop('selfhost')
            elif kind == 'untyped-exit': record['cases'][1]['selfhost']['exitCode'] = True
            elif kind == 'untyped-output': record['cases'][1]['selfhost']['stderr'] = None
            elif kind == 'bad-source-hash': record['cases'][1]['sourceSha256'] = 'z' * 64
            elif kind == 'wrong-completed': record['completed'] = 2
            elif kind == 'missing-process': record['processes'] = []
            elif kind == 'running': record['processesStopped'] = False
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_failed_case_without_status_requires_actual_failure(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record['cases'][0].pop('status')
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'CASE_COVERAGE_INVALID'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual('terminal-unstructured-failed-case', row['disposition'])
        self.assertEqual((0, 1, 6), (row['completed'], row['failed'], row['unexecuted']))
        record['cases'][0]['buildExit'] = 0
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'CASE_COVERAGE_INVALID'):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_mode_rejects_stale_producer_and_missing_or_changed_binary_pins(self):
        old, replacement, consumer = self.products()
        original = json.loads(consumer.read_text())
        for kind in ['stale-producer', 'missing-binary', 'changed-binary']:
            record = copy.deepcopy(original)
            if kind == 'stale-producer':
                record['inputHashes'][str(old / 'result.json')] = '0' * 64
            else:
                record['inputHashes'].pop(str(old / 'result.json'))
                if kind == 'missing-binary':
                    record['inputHashes'].pop(str(old / 'compiler.exe'))
                else:
                    record['inputHashes'][str(old / 'compiler.exe')] = '0' * 64
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, 'BUILD_LINK_INVALID'):
                policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_pre_case_failure_is_terminal_but_not_verified(self):
        old, replacement, consumer = self.products(True)
        record = self.unpin_producer(old, consumer)
        record.update(cases=[], failure='FORMAT_PREFLIGHT_FAILED_BEFORE_BUILD')
        consumer.write_text(json.dumps(record))
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual('terminal-pre-case-failure', row['disposition'])
        self.assertTrue(row['producerRecordPinMissing'])
        self.assertEqual((0, 0, 7), (row['completed'], row['executed'], row['unexecuted']))

    def test_legacy_empty_cases_require_failed_nonzero_execution(self):
        old, replacement, consumer = self.products(True)
        original = self.unpin_producer(old, consumer)
        for kind in ['passed', 'zero-exit', 'missing-failure']:
            record = copy.deepcopy(original)
            record.update(cases=[], failure='failed preflight')
            if kind == 'passed':
                record['status'] = 'passed'
            elif kind == 'zero-exit':
                record['processes'][0]['exit'] = 0
            else:
                record.pop('failure')
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, 'CASE_COVERAGE_INVALID'):
                policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def accepted_build_capture_fixture(self):
        old, replacement, consumer = self.products(True)
        record = self.unpin_producer(old, consumer)
        record.update(cases=[], completed=0, total=1, failure="KeyError: 'completed'")
        record['processes'][0]['exit'] = 0
        consumer.write_text(json.dumps(record))
        stage = self.output('consumer/compiler-build01')
        stage_path = stage / 'result.json'
        stage_record = json.loads(stage_path.read_text())
        stage_record['inputHashesStart'] = stage_record['inputHashesEnd'] = {
            str(old / 'compiler.exe'): hashlib.sha256((old / 'compiler.exe').read_bytes()).hexdigest()}
        stage_path.write_text(json.dumps(stage_record))
        acceptance = consumer.parent / 'build-acceptance-result.json'
        acceptance.write_text(json.dumps({
            'status': 'passed', 'completed': 1, 'total': 1,
            'inputsStable': True, 'processesStopped': True, 'scriptExit': 0,
            'knownWrapperFailurePreserved': str(consumer),
            'compilerSha256': stage_record['compilerSha256'],
            'inputHashes': {
                str(consumer): hashlib.sha256(consumer.read_bytes()).hexdigest(),
                str(stage_path): hashlib.sha256(stage_path.read_bytes()).hexdigest(),
                str(stage / 'compiler.exe'): stage_record['compilerSha256']}}))
        return old, replacement, consumer, stage_path, acceptance

    def test_accepted_build_capture_failure_retires_only_producer(self):
        old, replacement, consumer, stage, acceptance = self.accepted_build_capture_fixture()
        original = consumer.read_bytes()
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual('terminal-accepted-build-capture-failure', row['disposition'])
        self.assertEqual(0, row['completed'])
        self.assertIsNone(row['executed'])
        self.assertEqual(original, consumer.read_bytes())
        self.assertEqual(str(acceptance), row['captureFailureEvidence']['acceptancePath'])
        self.assertTrue((stage.parent / 'compiler.exe').is_file())
        policy.verified_consumer_closure(self.repo, old)

    def test_pre_case_log_read_failure_retires_only_stopped_producer(self):
        old, replacement, consumer = self.products(True)
        record = self.unpin_producer(old, consumer)
        record.update(cases=[], completed=0, total=5,
                      failure="FileNotFoundError: missing phase0.stdout.txt")
        record['processes'] = [{'command': [str(old / 'compiler.exe'), 'wasm-stdlib'],
            'exit': 0, 'shutdownConfirmed': True, 'shutdownScope': 'owned-windows-job',
            'naturalShutdownObservation': {'outcome': 'drained'}}]
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual('terminal-pre-case-log-read-failure', row['disposition'])
        self.assertEqual(0, row['completed'])
        self.assertIsNone(row['executed'])
        self.assertEqual(['case-results-unrecorded', 'producer-record-unpinned'], row['unprovenReasons'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        for kind in ('live', 'boolean-exit', 'wrapper', 'other-error', 'partial-case'):
            invalid = copy.deepcopy(record)
            if kind == 'live': invalid['processes'][0]['shutdownConfirmed'] = False
            elif kind == 'boolean-exit': invalid['processes'][0]['exit'] = False
            elif kind == 'wrapper': invalid['processes'][0]['command'][0] = 'unverified-wrapper'
            elif kind == 'other-error': invalid['failure'] = 'AssertionError: wrong output'
            else: invalid['cases'] = [{'status': 'running'}]
            consumer.write_text(json.dumps(invalid))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_accepted_build_capture_failure_rejects_unsealed_evidence(self):
        old, replacement, consumer, stage, acceptance = self.accepted_build_capture_fixture()
        base = json.loads(acceptance.read_text())
        stage_bytes = stage.read_bytes()
        for kind in ('wrapper-pin', 'stage-pin', 'binary-pin', 'script-exit',
                     'wrapper-link', 'passed-claim', 'shutdown', 'stage-source-pin'):
            witness = copy.deepcopy(base)
            stage.write_bytes(stage_bytes)
            if kind == 'wrapper-pin': witness['inputHashes'][str(consumer)] = '0' * 64
            elif kind == 'stage-pin': witness['inputHashes'][str(stage)] = '0' * 64
            elif kind == 'binary-pin': witness['compilerSha256'] = '0' * 64
            elif kind == 'script-exit': witness['scriptExit'] = 1
            elif kind == 'wrapper-link': witness['knownWrapperFailurePreserved'] = str(old / 'result.json')
            elif kind == 'passed-claim': witness['status'] = 'failed'
            elif kind == 'shutdown': witness['processesStopped'] = False
            else:
                producer = json.loads(stage_bytes)
                producer['inputHashesStart'] = producer['inputHashesEnd'] = {'unrelated': 'same'}
                stage.write_text(json.dumps(producer))
                witness['inputHashes'][str(stage)] = hashlib.sha256(stage.read_bytes()).hexdigest()
            acceptance.write_text(json.dumps(witness))
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, 'CAPTURE_FAILURE_EVIDENCE_INVALID'):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_failed_preflight_without_case_collection_is_preserved(self):
        old, replacement, consumer = self.products(True)
        record = self.unpin_producer(old, consumer)
        record.pop('cases')
        record['failure'] = 'AssertionError: preflight failed before case capture'
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual('terminal-observation-without-test-scope', row['disposition'])
        self.assertEqual(0, row['completed'])
        self.assertIsNone(row['executed'])
        self.assertIsNone(row['unexecuted'])
        self.assertEqual(record['total'], row['observedTotal'])
        self.assertEqual(original, consumer.read_bytes())
        for update in ({'status': 'running'}, {'processes': [{'pid': 123, 'exit': None}]}):
            consumer.write_text(json.dumps(dict(record, **update)))
            with self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_mode_keeps_live_unstable_and_nonterminal_consumers_protected(self):
        old, replacement, consumer = self.products(True)
        original = self.unpin_producer(old, consumer)
        for kind in ['active', 'not-stopped', 'unstable', 'canceled', 'missing-exit']:
            record = copy.deepcopy(original)
            expected = 'NOT_TERMINAL'
            if kind == 'active':
                record['activeProcess'] = {'pid': 123}
            elif kind == 'not-stopped':
                record['processesStopped'] = False
                expected = 'SHUTDOWN_OR_STABILITY_MISSING'
            elif kind == 'unstable':
                record['inputsStable'] = False
                expected = 'SHUTDOWN_OR_STABILITY_MISSING'
            elif kind == 'canceled':
                record['status'] = 'canceled'
                expected = 'CANCELED_CONSUMER_AUDIT_MISSING'
            else:
                record['processes'][0].pop('exit')
                expected = 'PROCESS_EXIT_MISSING'
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, expected):
                policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_legacy_evidence_mode_cannot_be_removed_on_replay(self):
        old, replacement, consumer = self.products()
        self.unpin_producer(old, consumer)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        record = json.loads(closure.read_text())
        record.pop('evidenceMode')
        closure.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'BUILD_LINK_INVALID'):
            policy.verified_consumer_closure(self.repo, old)

    def test_legacy_protection_blocks_previously_created_cleanup_plan(self):
        old, replacement, consumer = self.products()
        self.unpin_producer(old, consumer)
        generated = consumer.parent / 'unverified.exe'
        generated.write_bytes(b'preserved legacy output')
        # The fixture's completion must follow its generated output. Depending
        # on filesystem timestamp resolution made this precondition intermittent.
        stamp = max(consumer.stat().st_mtime_ns, generated.stat().st_mtime_ns) + 1000
        os.utime(consumer, ns=(stamp, stamp))
        stale_plan = self.plan(retention_terminal=True)
        self.assertIn(str(generated), [row['path'] for row in stale_plan['targets']])
        policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        with self.assertRaisesRegex(ValueError, 'UNVERIFIED_CONSUMER_PROTECTED'):
            policy.validate_plan(stale_plan)
        run = self.execute(stale_plan)
        self.assertNotEqual(0, run.returncode)
        self.assertTrue(generated.exists())
        self.assertTrue((old / 'compiler.exe').exists())

    def test_legacy_partial_protection_blocks_retirement_until_idempotent_repair(self):
        old, replacement, consumer = self.products()
        self.unpin_producer(old, consumer)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        marker = consumer.parent / 'consumer-retirement-protection.json'
        marker.unlink()
        with self.assertRaisesRegex(ValueError, 'PROTECTION_MISSING'):
            policy.verified_consumer_closure(self.repo, old)
        self.assertEqual(closure, policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True))
        self.assertTrue(marker.exists())
        self.assertEqual(str(closure), policy.verified_consumer_closure(self.repo, old)['path'])

    def test_legacy_mode_flag_requires_consumer_closure_operation(self):
        old, _, _ = self.products()
        run = subprocess.run([sys.executable, str(Path(policy.__file__)), '--repo', str(self.repo),
                              '--legacy-terminal-consumers'], capture_output=True, text=True)
        self.assertEqual(2, run.returncode)
        self.assertIn('requires --close-consumers', run.stderr)
        self.assertTrue((old / 'compiler.exe').exists())
    def attempted_runner_fixture(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        detail_path = consumer.parent / 'cases/first/result.json'
        detail_path.parent.mkdir(parents=True)
        case = record['cases'][0]
        case.update(processes=[0], requiresSelfHostCompiler=True,
                    oracle={'kind': 'llvm', 'expectedPath': 'preserved.stdout.txt'})
        detail = {key: case[key] for key in ('id', 'status', 'oracle', 'requiresSelfHostCompiler')}
        detail['processes'] = copy.deepcopy(record['processes'])
        detail_path.write_text(json.dumps(detail))
        case.update(resultPath=str(detail_path),
                    resultSha256=hashlib.sha256(detail_path.read_bytes()).hexdigest())
        record['completed'] = 1
        consumer.write_text(json.dumps(record))
        return old, replacement, consumer, record, detail_path

    def test_attempted_runner_retirement_preserves_failed_result_and_outputs(self):
        old, replacement, consumer, record, detail = self.attempted_runner_fixture()
        original, original_detail = consumer.read_bytes(), detail.read_bytes()
        unfinished = consumer.parent / 'failed.ll'
        unfinished.write_text('failed output remains protected')
        with self.assertRaisesRegex(ValueError, 'CASE_COVERAGE_INVALID'):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement,
                                                 legacy_terminal=True)
        audit = json.loads(closure.read_text())
        row = audit['consumers'][0]
        self.assertEqual('terminal-attempted-count-runner', row['disposition'])
        self.assertEqual((0, 0, 1, 1, 6), (row['completed'], row['observedPassed'],
                         row['observedAttempted'], row['failed'], row['unexecuted']))
        self.assertTrue(audit['verificationFailed'])
        self.assertTrue(audit['pipelineAborted'])
        self.assertEqual(original, consumer.read_bytes())
        self.assertEqual(original_detail, detail.read_bytes())
        policy.verified_consumer_closure(self.repo, old)
        targets = [item['path'] for item in self.plan(retention_terminal=True)['targets']]
        self.assertIn(str(old / 'compiler.exe'), targets)
        self.assertNotIn(str(unfinished), targets)

    def test_attempted_runner_rejects_unsealed_mismatched_or_reused_execution(self):
        old, replacement, consumer, original, detail = self.attempted_runner_fixture()
        detail_bytes = detail.read_bytes()
        for kind in ('hash', 'verdict', 'identity', 'missing-process', 'duplicate-process',
                     'count', 'live', 'detail-command', 'outside'):
            record = copy.deepcopy(original)
            detail.write_bytes(detail_bytes)
            case = record['cases'][0]
            if kind == 'hash': case['resultSha256'] = '0' * 64
            elif kind == 'verdict': case['status'] = 'passed'
            elif kind == 'identity': case['id'] = 'other'
            elif kind == 'missing-process': case['processes'] = []
            elif kind == 'duplicate-process': case['processes'] = [0, 0]
            elif kind == 'count': record['completed'] = 2
            elif kind == 'live': record['processesStopped'] = False
            elif kind == 'detail-command':
                changed = json.loads(detail_bytes)
                changed['processes'][0]['exit'] = 0
                detail.write_text(json.dumps(changed))
                case['resultSha256'] = hashlib.sha256(detail.read_bytes()).hexdigest()
            elif kind == 'outside':
                other = self.root / 'outside-detail.json'
                other.write_bytes(detail_bytes)
                case['resultPath'] = str(other)
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                               legacy_terminal=True)

    def products(self, failed=False):
        old = self.output('old', {'pendingConsumerProtection': True})
        replacement = self.output('replacement')
        for output in (old, replacement):
            path = output / 'result.json'
            record = json.loads(path.read_text())
            record['compilerSha256'] = policy.hashlib.sha256((output / 'compiler.exe').read_bytes()).hexdigest()
            path.write_text(json.dumps(record))
        consumer = self.root / 'consumer'
        consumer.mkdir()
        path = consumer / 'result.json'
        record = {'status': 'failed' if failed else 'passed', 'inputsStable': True,
                  'processesStopped': True, 'completed': 0 if failed else 1, 'total': 7 if failed else 1,
                  'inputHashes': {str(old / 'result.json'): policy.hashlib.sha256((old / 'result.json').read_bytes()).hexdigest(),
                                  str(old / 'compiler.exe'): policy.hashlib.sha256((old / 'compiler.exe').read_bytes()).hexdigest()},
                  'processes': [{'pid': 123, 'exit': 1 if failed else 0}],
                  'cases': [{'id': 'first', 'status': 'failed' if failed else 'passed', 'passed': not failed,
                             'buildExit': 1 if failed else 0, 'runExit': None if failed else 0}]}
        path.write_text(json.dumps(record))
        return old, replacement, path

    def unqualified_diagnostic_observation_fixture(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        for key in ('completed', 'total', 'cases'):
            record.pop(key)
        record.update(status='observed-not-qualified', claimsGoalComplete=False,
                      observedExit=1, diagnostic='sollang: semantic error: observed only',
                      processes=[dict(pid=123, exit=1, command=[str(old / 'compiler.exe'), 'build'],
                          shutdownConfirmed=True, shutdownScope='owned-windows-job',
                          startedAtUtc='2026-10-26T11:39:22+00:00',
                          finishedAtUtc='2026-10-26T11:39:36+00:00',
                          naturalShutdownObservation=dict(rootPid=123, outcome='drained'))])
        (consumer.parent / 'build.stderr').write_text(record['diagnostic'] + '\n')
        (consumer.parent / 'build.stdout').write_bytes(b'')
        consumer.write_text(json.dumps(record))
        return old, replacement, consumer, record

    def test_unqualified_diagnostic_observation_retires_only_product(self):
        old, replacement, consumer, record = self.unqualified_diagnostic_observation_fixture()
        original = consumer.read_bytes()
        with self.assertRaisesRegex(ValueError, 'NOT_TERMINAL'):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement,
                                                 legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual(0, row['completed'])
        self.assertIsNone(row['total'])
        self.assertEqual('terminal-unqualified-diagnostic-observation', row['disposition'])
        self.assertEqual(['diagnostic-oracle-unverified'], row['unprovenReasons'])
        self.assertEqual(0, self.execute(self.plan(retention_terminal=True)).returncode)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertEqual(original, consumer.read_bytes())
        self.assertTrue((consumer.parent / 'build.stderr').exists())
        self.assertTrue((consumer.parent / 'consumer-retirement-protection.json').exists())

    def test_unqualified_diagnostic_observation_rejects_unproven_capture(self):
        old, replacement, consumer, original = self.unqualified_diagnostic_observation_fixture()
        for mutation in ('active', 'shutdown', 'pin', 'exit', 'scope', 'drained', 'pid',
                         'goal', 'test', 'count', 'diagnostic', 'stdout', 'logs', 'time'):
            record = copy.deepcopy(original)
            (consumer.parent / 'build.stdout').write_bytes(b'')
            extra = consumer.parent / 'other.stderr'
            if extra.exists(): extra.unlink()
            if mutation == 'active': record['activeProcess'] = {'pid': 123}
            elif mutation == 'shutdown': record['processesStopped'] = False
            elif mutation == 'pin': record['inputHashes'] = {}
            elif mutation == 'exit': record['processes'][0]['exit'] = 0
            elif mutation == 'scope': record['processes'][0]['command'][1] = 'run'
            elif mutation == 'drained': record['processes'][0]['naturalShutdownObservation']['outcome'] = 'active'
            elif mutation == 'pid': record['processes'][0]['naturalShutdownObservation']['rootPid'] = 456
            elif mutation == 'goal': record['claimsGoalComplete'] = True
            elif mutation == 'test': record['claimsTestPassed'] = True
            elif mutation == 'count': record['completed'] = 1
            elif mutation == 'diagnostic': record['diagnostic'] = 'different'
            elif mutation == 'stdout': (consumer.parent / 'build.stdout').write_text('unexpected')
            elif mutation == 'logs': extra.write_text('ambiguous')
            elif mutation == 'time': record['processes'][0]['finishedAtUtc'] = '2026-10-26T11:38:00+00:00'
            consumer.write_text(json.dumps(record))
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                               legacy_terminal=True)

    def test_unqualified_diagnostic_observation_rechecks_logs_on_replay(self):
        old, replacement, consumer, record = self.unqualified_diagnostic_observation_fixture()
        policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        (consumer.parent / 'build.stderr').write_text('changed diagnostic')
        with self.assertRaises(ValueError):
            policy.verified_consumer_closure(self.repo, old)

    def retirement_chain(self):
        old, middle, first = self.products()
        path = middle / 'result.json'
        record = json.loads(path.read_text())
        record['pendingConsumerProtection'] = True
        path.write_text(json.dumps(record))
        tail = self.output('tail')
        second = self.root / 'middle-consumer' / 'result.json'
        second.parent.mkdir()
        record = json.loads(first.read_text())
        record['inputHashes'] = {
            str(middle / name): hashlib.sha256((middle / name).read_bytes()).hexdigest()
            for name in ('result.json', 'compiler.exe')}
        second.write_text(json.dumps(record))
        first_closure = policy.close_compiler_consumers(self.repo, old, [first], middle)
        policy.close_compiler_consumers(self.repo, middle, [second], tail)
        return old, middle, tail, first_closure, second

    def test_sealed_closure_revalidates_retired_replacement_chain(self):
        old, middle, tail, closure, second = self.retirement_chain()
        original = closure.read_bytes()
        (middle / 'compiler.exe').unlink()
        policy.verified_consumer_closure(self.repo, old)
        self.assertEqual(original, closure.read_bytes())
        plan = self.plan(retention_terminal=True, reusable_directories=[tail])
        policy.validate_plan(plan)
        self.assertIn(str(old / 'compiler.exe'), [row['path'] for row in plan['targets']])

    def test_retired_replacement_requires_unchanged_terminal_evidence(self):
        old, middle, tail, closure, second = self.retirement_chain()
        (middle / 'compiler.exe').unlink()
        record = json.loads(second.read_text())
        record['processesStopped'] = False
        second.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'SHUTDOWN_OR_STABILITY_MISSING'):
            policy.verified_consumer_closure(self.repo, old)

    def test_retired_replacement_requires_closure_and_live_chain_end(self):
        old, middle, tail, closure, second = self.retirement_chain()
        (middle / 'compiler.exe').unlink()
        (tail / 'compiler.exe').unlink()
        with self.assertRaises((ValueError, FileNotFoundError)):
            policy.verified_consumer_closure(self.repo, old)

    def test_new_registration_cannot_select_retired_replacement(self):
        old, middle, tail, closure, second = self.retirement_chain()
        (middle / 'compiler.exe').unlink()
        first = self.root / 'consumer' / 'result.json'
        with self.assertRaisesRegex(ValueError, 'ARTIFACT_CONSUMER_BINARY_MISSING'):
            policy.consumer_closure_record(self.repo, old, [first], middle)

    def test_retirement_chain_cycle_is_rejected_before_read(self):
        old, middle, tail, closure, second = self.retirement_chain()
        (middle / 'compiler.exe').unlink()
        middle_closure = middle / 'consumer-closure.json'
        record = json.loads(middle_closure.read_text())
        record['replacementBuild'] = {
            'path': str(old / 'result.json'),
            'sha256': hashlib.sha256((old / 'result.json').read_bytes()).hexdigest(),
            'compilerPath': str(old / 'compiler.exe'),
            'compilerSha256': hashlib.sha256((old / 'compiler.exe').read_bytes()).hexdigest()}
        middle_closure.write_text(json.dumps(record))
        self.assertTrue((old / 'compiler.exe').is_file())
        with self.assertRaisesRegex(ValueError, 'ARTIFACT_CONSUMER_REPLACEMENT_CYCLE'):
            policy.verified_consumer_closure(self.repo, old)

    def test_paired_fingerprint_consumer_retires_without_mutating_record(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        pins = record.pop('inputHashes')
        record['inputHashesStart'] = pins
        record['inputHashesEnd'] = copy.deepcopy(pins)
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        self.assertEqual(original, consumer.read_bytes())
        self.assertEqual(1, json.loads(closure.read_text())['consumers'][0]['completed'])
        policy.verified_consumer_closure(self.repo, old)

    def test_legacy_start_only_fingerprint_retires_binary_without_claiming_consumer_pass(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        record['inputHashesStart'] = record.pop('inputHashes')
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual(0, row['completed'])
        self.assertEqual('terminal-unpaired-input-fingerprint', row['disposition'])
        self.assertIn('input-end-fingerprint-missing', row['unprovenReasons'])
        self.assertEqual(original, consumer.read_bytes())
        policy.verified_consumer_closure(self.repo, old)

    def test_paired_fingerprint_consumer_rejects_changed_or_missing_end(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        pins = record.pop('inputHashes')
        record['inputHashesStart'] = pins
        for kind in ('changed', 'missing', 'empty', 'wrong-binary'):
            wrong = copy.deepcopy(record)
            wrong['inputHashesEnd'] = copy.deepcopy(pins)
            if kind == 'changed': wrong['inputHashesEnd'][str(old / 'compiler.exe')] = '0' * 64
            elif kind == 'missing': wrong.pop('inputHashesEnd')
            elif kind == 'empty': wrong['inputHashesStart'] = wrong['inputHashesEnd'] = {}
            else:
                wrong['inputHashesStart'][str(old / 'compiler.exe')] = '0' * 64
                wrong['inputHashesEnd'] = copy.deepcopy(wrong['inputHashesStart'])
            consumer.write_text(json.dumps(wrong))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement)

    def test_consumer_pass_retirement_does_not_mutate_build(self):
        old, replacement, consumer = self.products()
        original = (old / 'result.json').read_bytes()
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        self.assertEqual(original, (old / 'result.json').read_bytes())
        self.assertFalse(json.loads(closure.read_text())['verificationFailed'])
        plan = self.plan(retention_terminal=True)
        policy.validate_plan(plan)
        self.assertIn(str(old / 'compiler.exe'), [row['path'] for row in plan['targets']])
        self.assertEqual('consumer-retired', next(row for row in plan['completionRecords'] if row['output'] == str(old))['disposition'])

    def test_passed_boolean_cases_share_completed_record_contract(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        record['cases'][0].pop('status')
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        self.assertTrue(policy.completed(record))
        closure = policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        self.assertEqual(1, closure['consumers'][0]['completed'])
        self.assertEqual(original, consumer.read_bytes())

    def test_observed_cli_cases_retire_only_with_exact_oracles(self):
        old, replacement, consumer = self.products()
        base = json.loads(consumer.read_text())
        positive = dict(id='positive', passed=True, observedBuildExit=0,
                        observedRunExit=0, actualStdout='13\n', expectedStdout='13\n')
        negative = dict(id='negative', passed=True, observedBuildExit=1,
                        commandKind='public-cli-negative', observedExit=1, expectedExit=1,
                        actualStderr='parse error\n', expectedStderr='parse error\n',
                        formatControl=dict(observedExit=1, actualStderr='parse error\n',
                                           expectedStderr='parse error\n'))
        for case in (positive, negative):
            record = copy.deepcopy(base)
            record['cases'] = [case]
            record['processes'][0]['exit'] = case['observedBuildExit']
            consumer.write_text(json.dumps(record))
            original = consumer.read_bytes()
            with self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement)
            closure = policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                                    legacy_terminal=True)
            self.assertEqual(original, consumer.read_bytes())
            self.assertEqual(1, closure['consumers'][0]['completed'])
        mutations = [dict(actualStdout='wrong'), dict(observedRunExit=1),
                     dict(observedBuildExit=True), dict(passed=False), dict(timedOut=True)]
        for change in mutations:
            record = copy.deepcopy(base)
            record['cases'] = [dict(positive, **change)]
            consumer.write_text(json.dumps(record))
            with self.subTest(change=change), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                              legacy_terminal=True)
        for change in [dict(expectedExit=0), dict(expectedStderr='wrong'),
                       dict(formatControl=dict(observedExit=1, actualStderr='parse error\n',
                                               expectedStderr='parse error\n', timedOut=True)),
                       dict(formatControl=dict(observedExit=0, actualStderr='parse error\n',
                                               expectedStderr='parse error\n'))]:
            record = copy.deepcopy(base)
            record['cases'] = [dict(negative, **change)]
            record['processes'][0]['exit'] = 1
            consumer.write_text(json.dumps(record))
            with self.subTest(change=change), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement,
                                              legacy_terminal=True)

    def test_boolean_case_admission_requires_full_completion(self):
        old, replacement, consumer = self.products()
        original = json.loads(consumer.read_text())
        original['cases'][0].pop('status')
        for kind in ['false', 'untyped', 'count', 'missing-oracle', 'timeout', 'canceled', 'contradictory-status']:
            record = copy.deepcopy(original)
            case = record['cases'][0]
            if kind == 'false': case['passed'] = False
            elif kind == 'untyped': case['passed'] = 1
            elif kind == 'count': record['total'] = 2
            elif kind == 'missing-oracle': case.update(buildExit=1, runExit=None)
            elif kind == 'timeout': case['timedOut'] = True
            elif kind == 'canceled': case['canceled'] = True
            elif kind == 'contradictory-status': case['status'] = 'failed'
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement)

    def test_flat_diagnostic_observation_retires_only_compiler_and_preserves_failure(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        record.update(status='failed', completed=1, total=2, cases=[
            {'id': 'control', 'passed': True, 'actualDiagnostic': 'accepted', 'expectedDiagnostic': 'accepted'},
            {'id': 'mismatch', 'passed': False, 'actualDiagnostic': 'accepted', 'expectedDiagnostic': 'parse error'},
        ])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'failed-observer.exe'
        generated.write_bytes(b'failed observation is preserved')
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual('failed', row['status'])
        self.assertEqual(0, row['completed'])
        self.assertEqual(1, row['observedPassed'])
        self.assertEqual(1, row['failed'])
        self.assertEqual('terminal-flat-diagnostic-observation', row['disposition'])
        run = self.execute(self.plan(retention_terminal=True))
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertTrue(generated.exists())
        self.assertEqual(original, consumer.read_bytes())

    def test_flat_diagnostic_observation_rejects_unproven_or_contradictory_capture(self):
        old, replacement, consumer = self.products()
        original = json.loads(consumer.read_text())
        original['cases'] = [{'id': 'first', 'passed': True,
                              'actualDiagnostic': 'accepted', 'expectedDiagnostic': 'accepted'}]
        for kind in ['oracle', 'mismatch', 'boolean', 'role', 'exit', 'count', 'timeout', 'active']:
            record = copy.deepcopy(original)
            case = record['cases'][0]
            if kind == 'oracle': case.pop('expectedDiagnostic')
            elif kind == 'mismatch': case['actualDiagnostic'] = 'parse error'
            elif kind == 'boolean': case['passed'] = 1
            elif kind == 'role': case['managed'] = {}
            elif kind == 'exit': record['processes'][0]['exit'] = 1
            elif kind == 'count': record['total'] = 2
            elif kind == 'timeout': case['timedOut'] = True
            elif kind == 'active': case['activeProcess'] = True
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_terminal_mismatch_capture_retires_product_preserving_original_failure(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        record.update(status='failed', completed=1, total=2, cases=[
            dict(id='control', status='passed', observedExit=0, observedStdout='ok', observedStderr=''),
            dict(id='mismatch', status='mismatch', observedExit=1, observedStdout='', observedStderr='wrong type'),
        ])
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        with self.assertRaises(ValueError):
            policy.consumer_closure_record(self.repo, old, [consumer], replacement)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement, legacy_terminal=True)
        result = json.loads(closure.read_text())
        self.assertTrue(result['verificationFailed'])
        self.assertEqual(0, result['consumers'][0]['completed'])
        self.assertEqual('terminal-diagnostic-mismatch-capture', result['consumers'][0]['disposition'])
        self.assertEqual(original, consumer.read_bytes())
        self.assertTrue((consumer.parent / 'consumer-retirement-protection.json').exists())

    def test_paired_terminal_diagnostic_mismatch_requires_exact_roles_and_counts(self):
        record = dict(status='mismatch', completed=0, total=1, cases=[
            dict(id='same', mode='managed', exitCode=1, actualStderr='expected', expectedStderr='expected', matchesManagedDecision=True),
            dict(id='same', mode='native', exitCode=1, actualStderr='wrong', expectedStderr='expected', matchesManagedDecision=False),
        ])
        self.assertTrue(policy.terminal_diagnostic_capture(record))
        for key, value in [('completed', 1), ('status', 'passed')]:
            bad = copy.deepcopy(record)
            bad[key] = value
            self.assertFalse(policy.terminal_diagnostic_capture(bad))
        for key, value in [('mode', 'unknown'), ('matchesManagedDecision', True), ('running', True), ('id', 'different')]:
            bad = copy.deepcopy(record)
            bad['cases'][1][key] = value
            self.assertFalse(policy.terminal_diagnostic_capture(bad))

    def test_terminal_mismatch_capture_rejects_active_unpinned_and_incomplete_shutdown(self):
        old, replacement, consumer = self.products()
        original = json.loads(consumer.read_text())
        original.update(status='failed', completed=0, total=1, cases=[
            dict(id='mismatch', status='mismatch', observedExit=1, observedStdout='', observedStderr='wrong type')])
        for kind in ['active', 'unpinned', 'shutdown', 'case-running', 'exit-missing']:
            record = copy.deepcopy(original)
            if kind == 'active': record['activeProcess'] = dict(pid=123)
            elif kind == 'unpinned': record['inputHashes'] = {}
            elif kind == 'shutdown': record['processesStopped'] = False
            elif kind == 'case-running': record['cases'][0]['running'] = True
            elif kind == 'exit-missing': record['processes'][0].pop('exit')
            consumer.write_text(json.dumps(record))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                policy.consumer_closure_record(self.repo, old, [consumer], replacement, legacy_terminal=True)

    def test_consumer_first_failure_preserves_unexecuted_count(self):
        old, replacement, consumer = self.products(True)
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        record = json.loads(closure.read_text())
        self.assertTrue(record['verificationFailed'])
        self.assertTrue(record['pipelineAborted'])
        self.assertEqual(6, record['consumers'][0]['unexecuted'])
        self.assertEqual(0, record['consumers'][0]['completed'])
        policy.validate_plan(self.plan(retention_terminal=True))

    def test_missing_negative_oracle_retires_only_verified_product_as_unproven(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        record['cases'][0].update(buildExit=1, runExit=None)
        record['processes'][0]['exit'] = 1
        consumer.write_text(json.dumps(record))
        original = consumer.read_bytes()
        generated = consumer.parent / 'unproven.exe'
        generated.write_bytes(b'preserved incomplete consumer')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        closed = json.loads(closure.read_text())
        self.assertTrue(closed['pipelineAborted'])
        self.assertFalse(closed['verificationFailed'])
        self.assertEqual(0, closed['consumers'][0]['completed'])
        self.assertEqual(['first'], closed['consumers'][0]['missingExpectedExitCaseIds'])
        plan = self.plan(retention_terminal=True)
        self.assertNotIn(str(generated), [row['path'] for row in plan['targets']])
        run = self.execute(plan)
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertTrue(generated.exists())
        self.assertEqual(original, consumer.read_bytes())

    def test_missing_oracle_does_not_bypass_other_completion_failures(self):
        old, replacement, consumer = self.products()
        original = json.loads(consumer.read_text())
        for mutation in ['timedOut', 'failureId', 'activeProcess']:
            record = copy.deepcopy(original)
            record['cases'][0].update(buildExit=1, runExit=None)
            record['cases'][0][mutation] = 'invalid'
            consumer.write_text(json.dumps(record))
            expected_error = 'NOT_TERMINAL' if mutation == 'activeProcess' else 'CASE_OUTCOME_INVALID'
            with self.assertRaisesRegex(ValueError, expected_error):
                policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_pinned_zero_exit_contradiction_remains_rejected(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        contract = consumer.parent / 'contract.json'
        contract.write_text(json.dumps({'cases': [{'id': 'first', 'exit': 0}]}))
        record['inputHashes'][str(contract)] = hashlib.sha256(contract.read_bytes()).hexdigest()
        record['cases'][0].update(buildExit=1, runExit=None)
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'CASE_OUTCOME_INVALID'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_consumer_missing_closure_keeps_pending_product(self):
        old, _, _ = self.products(True)
        self.assertNotIn(str(old / 'compiler.exe'), [row['path'] for row in self.plan(retention_terminal=True)['targets']])

    def test_input_drift_consumer_retires_verified_product_without_counting_passes(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(inputsStable=False, failure='ValueError: INPUT_DRIFT before ' + str(consumer.parent / 'second/run'))
        record['cases'].insert(0, {'id': 'observed', 'status': 'passed', 'passed': True, 'buildExit': 0, 'runExit': 0})
        record['completed'] = 1
        consumer.write_text(json.dumps(record))
        original_consumer = consumer.read_bytes()
        original_build = (old / 'result.json').read_bytes()
        failed_binary = consumer.parent / 'failed.exe'
        failed_binary.write_bytes(b'preserve failed consumer output')
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        row = json.loads(closure.read_text())['consumers'][0]
        self.assertEqual(0, row['completed'])
        self.assertEqual(1, row['observedPassed'])
        self.assertEqual('terminal-input-drift', row['disposition'])
        plan = self.plan(retention_terminal=True)
        self.assertNotIn(str(failed_binary), [item['path'] for item in plan['targets']])
        run = self.execute(plan)
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertTrue(failed_binary.exists())
        self.assertEqual(original_consumer, consumer.read_bytes())
        self.assertEqual(original_build, (old / 'result.json').read_bytes())

    def test_unstable_consumer_without_exact_drift_failure_remains_protected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(inputsStable=False, failure='timeout or unrelated failure')
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'SHUTDOWN_OR_STABILITY_MISSING'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        self.assertTrue((old / 'compiler.exe').exists())

    def test_input_drift_after_all_cases_counts_zero_completed(self):
        old, replacement, consumer = self.products()
        record = json.loads(consumer.read_text())
        record.update(status='failed', inputsStable=False, failure='INPUT_DRIFT after cases')
        consumer.write_text(json.dumps(record))
        closure = policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        closed = json.loads(closure.read_text())
        self.assertEqual(0, closed['consumers'][0]['completed'])
        self.assertEqual(1, closed['consumers'][0]['observedPassed'])
        self.assertTrue(closed['pipelineAborted'])

    def test_input_drift_operation_outside_consumer_is_rejected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(inputsStable=False, failure='INPUT_DRIFT before ' + str(self.repo / 'outside/run'))
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'SHUTDOWN_OR_STABILITY_MISSING'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_canceled_drift_consumer_is_not_promoted(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(status='canceled', inputsStable=False, failure='INPUT_DRIFT after cases')
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'NOT_TERMINAL'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_input_drift_with_live_process_remains_protected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(inputsStable=False, processesStopped=False, failure='INPUT_DRIFT after cases')
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'SHUTDOWN_OR_STABILITY_MISSING'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_input_drift_missing_process_exit_remains_protected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record.update(inputsStable=False, failure='INPUT_DRIFT after cases')
        record['processes'][0].pop('exit')
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'PROCESS_EXIT_MISSING'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_consumer_active_process_rejected(self):
        old, replacement, consumer = self.products(True)
        from unittest.mock import patch
        with patch.object(policy, 'windows_active_directories', return_value={str(old).casefold()}):
            with self.assertRaisesRegex(ValueError, 'ACTIVE'):
                policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_consumer_stale_build_link_rejected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record['inputHashes'][str(old / 'result.json')] = '0' * 64
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'LINK_INVALID'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_consumer_orphan_rejected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record['orphanProcessIds'] = [123]
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'NOT_TERMINAL'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_consumer_changed_sidecar_rejected_at_execution_validation(self):
        old, replacement, consumer = self.products(True)
        policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        plan = self.plan(retention_terminal=True)
        record = json.loads(consumer.read_text())
        record['failure'] = 'changed'
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'CLOSURE|COMPLETION_RECORD_CHANGED'):
            policy.validate_plan(plan)

    def test_consumer_nonretention_path_still_protected(self):
        old, replacement, consumer = self.products(True)
        policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        self.assertNotIn(str(old / 'compiler.exe'), [row['path'] for row in self.plan()['targets']])

    def test_consumer_replacement_changed_rejected(self):
        old, replacement, consumer = self.products(True)
        policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        (replacement / 'compiler.exe').write_text('changed')
        self.assertNotIn(str(old / 'compiler.exe'), [row['path'] for row in self.plan(retention_terminal=True)['targets']])

    def test_consumer_executor_retirement_and_idempotence(self):
        old, replacement, consumer = self.products(True)
        original = (old / 'result.json').read_bytes()
        policy.close_compiler_consumers(self.repo, old, [consumer], replacement)
        plan = self.plan(retention_terminal=True)
        self.assertNotIn(str(replacement / 'compiler.exe'), [row['path'] for row in plan['targets']])
        run = self.execute(plan)
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        self.assertFalse((old / 'compiler.exe').exists())
        self.assertTrue((replacement / 'compiler.exe').exists())
        self.assertEqual(original, (old / 'result.json').read_bytes())
        repeated = self.execute(plan)
        self.assertEqual(0, repeated.returncode, repeated.stdout + repeated.stderr)

    def test_consumer_outside_owned_boundary_rejected(self):
        old, replacement, _ = self.products(True)
        outside = self.repo / 'result.json'
        outside.write_text('{}')
        with self.assertRaisesRegex(ValueError, 'OUTSIDE_ROOT'):
            policy.close_compiler_consumers(self.repo, old, [outside], replacement)

    def test_consumer_missing_process_exit_rejected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record['processes'][0].pop('exit')
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'PROCESS_EXIT_MISSING'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)

    def test_consumer_contradictory_case_outcome_rejected(self):
        old, replacement, consumer = self.products(True)
        record = json.loads(consumer.read_text())
        record['cases'][0]['passed'] = True
        record['completed'] = 1
        consumer.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'CASE_COVERAGE_INVALID'):
            policy.close_compiler_consumers(self.repo, old, [consumer], replacement)


if __name__ == '__main__':
    unittest.main(verbosity=2)
