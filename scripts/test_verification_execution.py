"""Real child-process controls for durable focused verification execution."""

import ast
import hashlib
import copy
import importlib.util
import json
import os
import subprocess
import sys
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch

from verification_execution import VerificationExecution, _WindowsJob
from verification_step_diagnostics import SlowStepDiagnostics


class VerificationExecutionTests(unittest.TestCase):
    def setUp(self):
        self.repo = Path(__file__).resolve().parents[1]
        self.output = self.repo / "artifacts/scratch/verification-execution-controls" / self.id().rsplit(".", 1)[-1]
        suffix = 0
        while self.output.exists():
            suffix += 1
            self.output = self.output.with_name(self.id().rsplit(".", 1)[-1] + f"-{suffix}")
        self.output.mkdir(parents=True)
        self.stable = True
        self.result = {"status": "running", "completed": 0, "total": 1, "cases": []}
        self.execution = VerificationExecution(self.repo, self.output, self.result,
            lambda: self.stable, lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper())

    def test_program_case_preserves_required_arguments_and_spaces(self):
        case = {"arguments": ["-c", "import json,sys; print(json.dumps(sys.argv[1:]))",
                              "required source.slg", ""]}
        run = self.execution.run_program(sys.executable, case, self.output / "program")
        self.assertEqual(run.returncode, 0)
        self.assertEqual(json.loads(run.stdout), ["required source.slg", ""])
        self.result["status"] = "passed"
        self.execution.finalize(cleanup=False)
        self.assertTrue(self.result["processesStopped"])

    def test_invalid_program_arguments_reject_before_launch(self):
        with patch("verification_execution.subprocess.Popen") as launch:
            for arguments in ("required.slg", [None], [1]):
                with self.subTest(arguments=arguments):
                    with self.assertRaisesRegex(ValueError, "PROGRAM_CASE_ARGUMENTS_INVALID"):
                        self.execution.run_program(sys.executable, {"arguments": arguments},
                                                   self.output / "program")
            launch.assert_not_called()

    def test_nonzero_exit_preserves_independent_logs(self):
        run = self.execution.run([sys.executable, "-c",
            "import sys; print('normal-output'); print('diagnostic', file=sys.stderr); sys.exit(7)"],
            self.output / "probe")
        self.assertEqual(run.returncode, 7)
        self.assertEqual(run.stdout.strip(), "normal-output")
        self.assertEqual(run.stderr.strip(), "diagnostic")
        self.execution.finalize(ValueError("EXPECTED_NEGATIVE_CONTROL"))
        self.assertEqual(self.result["status"], "failed")
        self.assertTrue(self.result["processesStopped"])
        self.assertTrue((self.output / "probe.stderr").is_file())

    def test_initial_record_save_failure_stops_created_root(self):
        original_save = self.execution.save
        calls = 0

        def save():
            nonlocal calls
            calls += 1
            if calls == 1:
                raise PermissionError("INITIAL_RECORD_SAVE_DENIED")
            original_save()

        with patch.object(self.execution, "save", side_effect=save):
            with self.assertRaisesRegex(PermissionError, "INITIAL_RECORD_SAVE_DENIED"):
                self.execution.run([sys.executable, "-c", "import time; time.sleep(30)"],
                                   self.output / "probe", timeout=2)
        row = self.result["processes"][0]
        self.assertIsInstance(row["exit"], int)
        self.assertTrue(row["shutdownConfirmed"])
        self.execution.finalize(PermissionError("INITIAL_RECORD_SAVE_DENIED"))
        self.assertTrue(self.result["processesStopped"])
        self.assertEqual(self.result["status"], "failed")

    def test_timeout_stops_real_child_and_preserves_state(self):
        try:
            self.execution.run([sys.executable, "-c", "import time; time.sleep(30)"],
                self.output / "probe", timeout=0.1)
            self.fail("timeout expected")
        except subprocess.TimeoutExpired as error:
            self.execution.finalize(error)
        self.assertEqual(self.result["status"], "timed-out")
        self.assertTrue(self.result["processesStopped"])
        self.assertEqual(len(self.result["terminatedProcesses"]), 1)

    def test_cancel_stops_real_child_and_preserves_state(self):
        real_popen = subprocess.Popen
        children = []

        def interrupted_popen(*args, **kwargs):
            child = real_popen(*args, **kwargs)
            if children:
                return child
            children.append(child)
            real_wait = child.wait
            first = True

            def wait(*wait_args, **wait_kwargs):
                nonlocal first
                if first:
                    first = False
                    raise KeyboardInterrupt()
                return real_wait(*wait_args, **wait_kwargs)

            child.wait = wait
            return child

        with patch("verification_execution.subprocess.Popen", side_effect=interrupted_popen):
            try:
                self.execution.run([sys.executable, "-c", "import time; time.sleep(30)"],
                    self.output / "probe")
                self.fail("cancel expected")
            except KeyboardInterrupt as error:
                self.execution.finalize(error)
        self.assertEqual(self.result["status"], "canceled")
        self.assertTrue(self.result["processesStopped"])
        self.assertIsNotNone(children[0].poll())

    def test_input_drift_rejects_before_spawn(self):
        self.stable = False
        with patch("verification_execution.subprocess.Popen") as popen:
            with self.assertRaisesRegex(ValueError, "INPUT_DRIFT"):
                self.execution.run([sys.executable, "-c", "pass"], self.output / "probe")
            popen.assert_not_called()
        self.execution.finalize(ValueError("INPUT_DRIFT"))
        self.assertFalse(self.result["inputsStable"])
        self.assertEqual(self.result["status"], "failed")

    def test_normal_exit_confirms_shutdown(self):
        run = self.execution.run([sys.executable, '-c', "print('ok')"], self.output / 'probe')
        self.assertEqual(run.returncode, 0)
        self.assertTrue(self.result['processes'][0]['shutdownConfirmed'])

    def test_completed_process_requires_explicit_exit_and_passed_state(self):
        run = self.execution.run([sys.executable, '-c', "print('ok')"], self.output / 'probe')
        self.assertIsInstance(run, subprocess.CompletedProcess)
        self.assertEqual(run.returncode, 0)
        self.assertTrue(run)  # The object is not an integer exit-code predicate.
        self.result['status'] = 'passed'
        with patch('verification_execution.cleanup_output') as cleanup:
            self.execution.finalize(cleanup=False)
        self.assertEqual(self.result['status'], 'passed')
        self.assertTrue(self.result['processesStopped'])
        cleanup.assert_not_called()

    def test_expected_nonzero_exit_can_pass_explicit_caller_oracle(self):
        run = self.execution.run([sys.executable, '-c', 'import sys; sys.exit(7)'],
                                 self.output / 'negative')
        self.assertEqual(run.returncode, 7)
        self.result['status'] = 'passed'
        self.execution.finalize(cleanup=False)
        self.assertEqual(self.result['status'], 'passed')
        self.assertTrue(self.result['processesStopped'])

    def test_finalize_without_terminal_status_fails_without_cleanup(self):
        self.execution.run([sys.executable, '-c', 'pass'], self.output / 'probe')
        with patch('verification_execution.cleanup_output') as cleanup:
            self.execution.finalize()
        self.assertEqual(self.result['status'], 'failed')
        self.assertEqual(self.result['failure'], 'EXECUTION_TERMINAL_STATUS_REQUIRED')
        self.assertTrue(self.result['processesStopped'])
        self.assertEqual(len(self.result['processes']), 1)
        cleanup.assert_not_called()

    def test_reinitialization_preserves_actual_completed_process_evidence(self):
        self.execution.run([sys.executable, '-c', 'pass'], self.output / 'probe')
        before = copy.deepcopy(self.result)
        saved = (self.output / 'result.json').read_bytes()
        with self.assertRaisesRegex(ValueError, 'EXECUTION_REINITIALIZATION_HAS_PROCESS_EVIDENCE'):
            VerificationExecution(self.repo, self.output, self.result, lambda: True, lambda path: '')
        self.assertEqual(self.result, before)
        self.assertEqual((self.output / 'result.json').read_bytes(), saved)

    def test_reinitialization_rejects_active_process_without_mutation(self):
        for active in ({'pid': 1234, 'command': ['retained-live']}, {}):
            result = {'status': 'running', 'processes': [], 'activeProcess': active}
            before = copy.deepcopy(result)
            with self.subTest(active=active), patch('verification_execution.subprocess.Popen') as launch:
                with self.assertRaisesRegex(ValueError, 'EXECUTION_REINITIALIZATION_HAS_PROCESS_EVIDENCE'):
                    VerificationExecution(self.repo, self.output, result, lambda: True, lambda path: '')
                launch.assert_not_called()
                self.assertEqual(result, before)

    def test_windows_exited_root_accounting_lag_then_drain(self):
        process = Mock(pid=1234)
        process.poll.return_value = 0
        job = Mock()
        job.shutdown_observation.side_effect = [(1, [1234]), (0, [])]
        row = {}
        with patch('verification_execution.os', SimpleNamespace(name='nt')), \
                patch('verification_execution.time.sleep') as pause:
            self.assertTrue(self.execution.confirm_natural_shutdown(process, row, job))
        self.assertEqual(row['naturalShutdownObservation']['outcome'], 'drained')
        self.assertEqual(row['naturalShutdownObservation']['observedSamples'], 2)
        pause.assert_called_once_with(0.02)
        job.terminate.assert_not_called()

    def test_windows_real_descendant_does_not_wait_for_accounting(self):
        process = Mock(pid=1234)
        process.poll.return_value = 0
        job = Mock()
        job.shutdown_observation.return_value = (1, [5678])
        row = {}
        with patch('verification_execution.os', SimpleNamespace(name='nt')), \
                patch('verification_execution.time.sleep') as pause:
            self.assertFalse(self.execution.confirm_natural_shutdown(process, row, job))
        self.assertEqual(row['naturalShutdownObservation']['outcome'], 'live-descendant')
        pause.assert_not_called()

    def test_windows_shutdown_query_failure_remains_unconfirmed(self):
        process = Mock(pid=1234)
        process.poll.return_value = 0
        job = Mock()
        job.shutdown_observation.side_effect = OSError('EXPECTED_QUERY_FAILURE')
        row = {}
        with patch('verification_execution.os', SimpleNamespace(name='nt')):
            self.assertFalse(self.execution.confirm_natural_shutdown(process, row, job))
        self.assertEqual(row['naturalShutdownObservation']['outcome'], 'query-failed')
        self.assertIn('EXPECTED_QUERY_FAILURE', row['shutdownFailure'])

    def test_windows_root_accounting_lag_is_bounded(self):
        process = Mock(pid=1234)
        process.poll.return_value = 0
        job = Mock()
        job.shutdown_observation.return_value = (1, [1234])
        row = {}
        with patch('verification_execution.os', SimpleNamespace(name='nt')), \
                patch('verification_execution.time.monotonic', side_effect=[10, 15]):
            self.assertFalse(self.execution.confirm_natural_shutdown(process, row, job))
        self.assertEqual(row['naturalShutdownObservation']['outcome'], 'root-accounting-unconfirmed')

    @unittest.skipUnless(os.name == 'nt', 'requires real Windows Job accounting')
    def test_windows_repeated_root_only_exit(self):
        for index in range(12):
            run = self.execution.run([sys.executable, '-c', 'pass'], self.output / f'root-{index}')
            self.assertEqual(run.returncode, 0)
            row = self.result['processes'][-1]
            self.assertTrue(row['shutdownConfirmed'])
            self.assertEqual(row['naturalShutdownObservation']['outcome'], 'drained')
            self.assertFalse(row.get('descendantOutlivedParent', False))

    def test_posix_timeout_isolates_and_terminates_owned_group(self):
        process = Mock(pid=1234, returncode=-9)
        process.wait.side_effect = [subprocess.TimeoutExpired('probe', 0.1), -9]
        process.poll.return_value = -9
        host = SimpleNamespace(name='posix', killpg=Mock())
        with patch('verification_execution.os', host), \
                patch('verification_execution.signal', SimpleNamespace(SIGKILL=9)), \
                patch('verification_execution.subprocess.Popen', return_value=process) as launch, \
                patch.object(self.execution, 'group_stopped', return_value=True):
            with self.assertRaises(subprocess.TimeoutExpired) as caught:
                self.execution.run(['probe'], self.output / 'probe', timeout=0.1)
            self.execution.finalize(caught.exception)
        self.assertTrue(launch.call_args.kwargs['start_new_session'])
        host.killpg.assert_called_once()
        self.assertEqual(host.killpg.call_args.args[0], process.pid)
        self.assertTrue(self.result['processesStopped'])

    def test_custom_record_path_preserves_proof_path(self):
        proof = self.output / 'result.json'
        proof.write_text('proof-placeholder', encoding='utf-8')
        execution = VerificationExecution(self.repo, self.output, self.result,
            lambda: self.stable, lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper(),
            record_path=Path('execution-result.json'))
        execution.run([sys.executable, '-c', "print('custom-record')"], self.output / 'probe')
        self.result['status'] = 'passed'
        # This custom execution record must not retire its separate proof path.
        execution.finalize(cleanup=False)
        record = json.loads((self.output / 'execution-result.json').read_text())
        self.assertTrue(record['processesStopped'])
        self.assertTrue(record['processes'][0]['shutdownConfirmed'])
        self.assertEqual(proof.read_text(), 'proof-placeholder')
        self.assertFalse((self.output / 'execution-result.json.tmp').exists())

    def test_finalize_can_defer_cleanup_until_consumer_validation(self):
        self.result['status'] = 'passed'
        with patch('verification_execution.assert_output_shutdown') as shutdown, \
                patch('verification_execution.cleanup_output') as cleanup:
            self.execution.finalize(cleanup=False)
            self.assertEqual(self.result['status'], 'passed')
            self.assertTrue(self.result['inputsStable'])
            self.assertTrue(self.result['processesStopped'])
            shutdown.assert_not_called()
            cleanup.assert_not_called()
            self.execution.finalize()
            shutdown.assert_called_once_with(self.repo, self.output)
            cleanup.assert_called_once_with(self.repo, self.output, execute=True)

    def test_deferred_cleanup_preserves_failure_status(self):
        with patch('verification_execution.cleanup_output') as cleanup:
            self.execution.finalize(ValueError('EXPECTED_FAILURE'), cleanup=False)
        self.assertEqual(self.result['status'], 'failed')
        self.assertIn('EXPECTED_FAILURE', self.result['failure'])
        cleanup.assert_not_called()

    def test_record_path_rejects_outside_output_before_spawn(self):
        for record_path in [Path('../outside.json'), self.output.parent / 'outside.json', Path('.')]:
            with self.subTest(record_path=record_path), patch('verification_execution.subprocess.Popen') as launch:
                with self.assertRaisesRegex(ValueError, 'EXECUTION_RECORD_OUTSIDE_OUTPUT'):
                    VerificationExecution(self.repo, self.output, self.result, lambda: True, lambda path: '',
                        record_path=record_path)
                launch.assert_not_called()
        self.assertEqual(list(self.output.iterdir()), [])

    def test_stdlib_diagnostics_plan_keeps_600_second_contract(self):
        path = Path(__file__).with_name('verify-owned-index-full-stdlib-source-preflight.py')
        spec = importlib.util.spec_from_file_location('stdlib_consumer_control', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertIsNone(module.load_diagnostics_plan(None))
        declared = self.repo / 'scripts/contracts/owned-index-full-stdlib-diagnostics-plan.json'
        self.assertEqual(module.load_diagnostics_plan(declared)['hardTimeoutSeconds'], 600)
        wrong = self.output / 'wrong-plan.json'
        wrong.write_text(json.dumps(dict(stage='wrong-native-route', softLimitSeconds=60,
            hardTimeoutSeconds=1200, sampleIntervalSeconds=2, maxSamples=602)))
        with self.assertRaisesRegex(ValueError, 'STDLIB_PREFLIGHT_DIAGNOSTIC_HARD_TIMEOUT_MISMATCH'):
            module.load_diagnostics_plan(wrong)

    def test_group_termination_failure_cannot_claim_shutdown(self):
        process = Mock(pid=1234, returncode=0)
        process.wait.side_effect = subprocess.TimeoutExpired('probe', 0.1)
        process.poll.return_value = 0
        host = SimpleNamespace(name='posix', killpg=Mock(side_effect=PermissionError('denied')))
        with patch('verification_execution.os', host), \
                patch('verification_execution.signal', SimpleNamespace(SIGKILL=9)), \
                patch('verification_execution.subprocess.Popen', return_value=process), \
                patch.object(self.execution, 'group_stopped', return_value=True), \
                patch('verification_execution.cleanup_output') as cleanup:
            with self.assertRaises(subprocess.TimeoutExpired) as caught:
                self.execution.run(['probe'], self.output / 'probe', timeout=0.1)
            self.execution.finalize(caught.exception)
        self.assertFalse(self.result['processesStopped'])
        self.assertIn('PermissionError', self.result['processes'][0]['terminationFailure'])
        cleanup.assert_not_called()

    def test_live_group_after_parent_exit_cannot_pass(self):
        process = Mock(pid=1234, returncode=0)
        process.poll.return_value = 0
        with patch('verification_execution.os', SimpleNamespace(name='posix', killpg=Mock())), \
                patch('verification_execution.signal', SimpleNamespace(SIGKILL=9)), \
                patch('verification_execution.subprocess.Popen', return_value=process), \
                patch.object(self.execution, 'group_stopped', side_effect=[False, True, True, True]), \
                patch('verification_execution.cleanup_output') as cleanup:
            with self.assertRaisesRegex(ValueError, 'DESCENDANT_OUTLIVED_PARENT') as caught:
                self.execution.run(['probe'], self.output / 'probe')
            self.execution.finalize(caught.exception)
        self.assertTrue(self.result['processesStopped'])
        self.assertEqual(self.result['status'], 'failed')
        cleanup.assert_not_called()

    @unittest.skipUnless(os.name == 'nt', 'requires Windows process ownership')
    def test_windows_parent_exit_does_not_prove_descendant_shutdown(self):
        script = "import subprocess,sys; child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); print(child.pid,flush=True)"
        child_pid = None
        try:
            with self.assertRaisesRegex(ValueError, 'DESCENDANT_OUTLIVED_PARENT') as caught:
                self.execution.run([sys.executable, '-c', script], self.output / 'probe')
            child_pid = int((self.output / 'probe.stdout').read_text().strip())
            self.execution.finalize(caught.exception)
            self.assertTrue(self.result['processesStopped'])
            self.assertEqual(self.result['status'], 'failed')
            self.assertTrue(self.result['processes'][0]['descendantOutlivedParent'])
        finally:
            if child_pid is not None:
                subprocess.run(['taskkill', '/PID', str(child_pid), '/T', '/F'],
                    capture_output=True, timeout=5, check=False)

    @unittest.skipUnless(os.name == 'nt', 'requires Windows suspended process')
    def test_windows_assignment_failure_stops_suspended_root(self):
        job = _WindowsJob()
        with patch.object(job.api, 'AssignProcessToJobObject', return_value=0), \
                patch('verification_execution._WindowsJob', return_value=job):
            with self.assertRaises(OSError) as caught:
                self.execution.run([sys.executable, '-c', 'import time; time.sleep(30)'], self.output / 'probe')
        self.execution.finalize(caught.exception)
        self.assertEqual(self.result['status'], 'failed')
        self.assertTrue(self.result['processesStopped'])

    @unittest.skipUnless(os.name == 'posix', 'requires a real POSIX process group')
    def test_posix_timeout_stops_real_descendant(self):
        script = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); time.sleep(30)"
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            self.execution.run([sys.executable, '-c', script], self.output / 'probe', timeout=0.5)
        self.execution.finalize(caught.exception)
        self.assertTrue(self.result['processesStopped'])
        self.assertTrue(self.execution.group_stopped(self.result['processes'][0]['pid']))

    @unittest.skipUnless(os.name == 'posix', 'requires a real POSIX process group')
    def test_posix_parent_exit_rejects_and_stops_descendant(self):
        script = "import subprocess,sys; subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)"
        with self.assertRaisesRegex(ValueError, 'DESCENDANT_OUTLIVED_PARENT') as caught:
            self.execution.run([sys.executable, '-c', script], self.output / 'probe')
        self.execution.finalize(caught.exception)
        self.assertEqual(self.result['status'], 'failed')
        self.assertTrue(self.result['processesStopped'])

    def diagnostics(self, *, soft=0.1, hard=2):
        return SlowStepDiagnostics(dict(stage='focused-test', softLimitSeconds=soft,
            hardTimeoutSeconds=hard, sampleIntervalSeconds=0.02, maxSamples=8),
            self.output / 'diagnostics.json')

    def test_fast_step_stays_within_soft_limit(self):
        self.execution.run([sys.executable, '-c', "print('fast')"], self.output / 'probe',
            timeout=2, diagnostics=self.diagnostics(soft=1))
        record = self.result['processes'][0]['diagnostics']
        self.assertEqual(record['status'], 'within-soft-limit')
        self.assertFalse(record['investigation']['required'])

    def test_slow_step_records_bounded_observations(self):
        self.execution.run([sys.executable, '-c', "import time; print('start',flush=True); time.sleep(0.3)"],
            self.output / 'probe', timeout=2, diagnostics=self.diagnostics())
        record = self.result['processes'][0]['diagnostics']
        self.assertEqual(record['status'], 'slow')
        self.assertLessEqual(record['retainedSamples'], 8)
        expected = 'owned-tree' if os.name == 'nt' or sys.platform == 'linux' else 'unknown'
        self.assertEqual(record['samples'][-1]['cpuScope'], expected)
        self.assertGreater(record['samples'][-1]['stdoutBytes'], 0)
        self.assertTrue((self.output / 'diagnostics.json').is_file())
        self.assertTrue(record['investigation']['required'])
        self.assertEqual(json.loads((self.output / 'diagnostics.json').read_text())['investigation'],
                         record['investigation'])

    def test_diagnostics_preserves_hard_timeout(self):
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            self.execution.run([sys.executable, '-c', 'import time; time.sleep(30)'], self.output / 'probe',
                timeout=0.2, diagnostics=self.diagnostics(soft=0.05, hard=0.2))
        self.execution.finalize(caught.exception)
        self.assertEqual(self.result['status'], 'timed-out')
        self.assertEqual(self.result['processes'][0]['diagnostics']['status'], 'slow')
        self.assertTrue(self.result['processesStopped'])
        self.assertTrue(self.result['processes'][0]['diagnostics']['investigation']['required'])
        self.assertFalse(self.result['processes'][0]['diagnostics']['investigation']['automaticExecution'])

    def test_diagnostic_timeout_mismatch_rejects_before_spawn(self):
        with patch('verification_execution.subprocess.Popen') as launch:
            with self.assertRaisesRegex(ValueError, 'HARD_TIMEOUT_MISMATCH'):
                self.execution.run(['probe'], self.output / 'probe', timeout=3, diagnostics=self.diagnostics())
            launch.assert_not_called()

    def test_observer_failure_does_not_abandon_started_process(self):
        diagnostics = Mock(hard_timeout_seconds=2, sample_interval_seconds=0.02)
        diagnostics.observe.side_effect = ValueError('OBSERVER_CONTROL_FAILURE')
        with self.assertRaisesRegex(ValueError, 'OBSERVER_CONTROL_FAILURE') as caught:
            self.execution.run([sys.executable, '-c', 'import time; time.sleep(30)'], self.output / 'probe',
                timeout=2, diagnostics=diagnostics)
        self.execution.finalize(caught.exception)
        self.assertTrue(self.result['processesStopped'])
        self.assertEqual(self.result['status'], 'failed')

    @staticmethod
    def tree_script(seconds):
        leaf = f"import time; print('grandchild',flush=True); time.sleep({seconds})"
        middle = f"import subprocess,sys; child=subprocess.Popen([sys.executable,'-c',{leaf!r}]); child.wait()"
        return f"import subprocess,sys; child=subprocess.Popen([sys.executable,'-c',{middle!r}]); child.wait()"

    def test_normal_owned_child_and_grandchild_exit(self):
        run = self.execution.run([sys.executable, '-c', self.tree_script(0.05)], self.output / 'probe')
        self.assertEqual(run.returncode, 0)
        self.assertEqual(run.stdout.strip(), 'grandchild')
        self.assertTrue(self.result['processes'][0]['shutdownConfirmed'])

    def test_timeout_stops_owned_child_and_grandchild(self):
        with self.assertRaises(subprocess.TimeoutExpired) as caught:
            self.execution.run([sys.executable, '-c', self.tree_script(30)], self.output / 'probe', timeout=0.5)
        self.execution.finalize(caught.exception)
        self.assertIn('grandchild', (self.output / 'probe.stdout').read_text())
        self.assertTrue(self.result['processesStopped'])

    def test_cancel_stops_owned_child_and_grandchild_with_diagnostics(self):
        original = subprocess.Popen

        def interrupted(*args, **kwargs):
            process = original(*args, **kwargs)
            real_wait = process.wait
            first = True

            def wait(*wait_args, **wait_kwargs):
                nonlocal first
                if first:
                    first = False
                    time.sleep(0.3)
                    raise KeyboardInterrupt()
                return real_wait(*wait_args, **wait_kwargs)

            process.wait = wait
            return process

        with patch('verification_execution.subprocess.Popen', side_effect=interrupted):
            with self.assertRaises(KeyboardInterrupt) as caught:
                self.execution.run([sys.executable, '-c', self.tree_script(30)], self.output / 'probe',
                    timeout=2, diagnostics=self.diagnostics())
        self.execution.finalize(caught.exception)
        self.assertIn('grandchild', (self.output / 'probe.stdout').read_text())
        self.assertEqual(self.result['status'], 'canceled')
        self.assertEqual(self.result['processes'][0]['diagnostics']['status'], 'slow')
        self.assertTrue(self.result['processesStopped'])

    @unittest.skipUnless(os.name == 'nt' or sys.platform == 'linux', 'requires actual owned-group CPU accounting')
    def test_slow_busy_descendant_has_measured_cpu_without_log_progress(self):
        busy = 'import time; end=time.perf_counter()+0.5\nwhile time.perf_counter()<end: pass'
        parent = f"import subprocess,sys; subprocess.Popen([sys.executable,'-c',{busy!r}]).wait()"
        self.execution.run([sys.executable, '-c', parent], self.output / 'probe',
            timeout=2, diagnostics=self.diagnostics())
        record = self.result['processes'][0]['diagnostics']
        active = [sample for sample in record['samples'] if sample['slow']
            and sample['activity'] == 'active' and (sample['cpuSecondsDelta'] or 0) > 0
            and sample['stdoutBytes'] == 0 and sample['stderrBytes'] == 0]
        self.assertTrue(active, 'actual descendant CPU must distinguish busy work from quiet logs')
        self.assertTrue(all(sample['investigationClassification'] == 'cpu-active'
                            and 'cpu-work-or-spin' in sample['causeCandidates'] for sample in active))
        self.assertTrue(any(len(sample['ownedPids']) > 1 for sample in record['samples']))

    @unittest.skipUnless(os.name == 'nt' or sys.platform == 'linux', 'requires actual owned-group CPU accounting')
    def test_slow_sleep_has_quiet_measured_cpu_samples(self):
        self.execution.run([sys.executable, '-c', 'import time; time.sleep(0.3)'], self.output / 'probe',
            timeout=2, diagnostics=self.diagnostics())
        record = self.result['processes'][0]['diagnostics']
        self.assertTrue(any(sample['slow'] and sample['activity'] == 'quiet'
            and sample['cpuSecondsDelta'] == 0 for sample in record['samples']))
        self.assertTrue(any(sample['slow'] and sample['investigationClassification'] == 'quiet-observed-interval'
            and 'wait-or-block-or-unmeasured-work' in sample['causeCandidates'] for sample in record['samples']))

    @staticmethod
    def numeric_runner():
        path = Path(__file__).with_name('verify-c385-preir-call-numeric.py')
        spec = importlib.util.spec_from_file_location('numeric_consumer_control', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_numeric_failure_retains_output_without_automatic_recompile(self):
        source = Path(__file__).with_name('verify-c385-preir-call-numeric.py')
        tree = ast.parse(source.read_text(encoding='utf-8-sig'))
        failure = next(node for node in ast.walk(tree) if isinstance(node, ast.If)
                       and isinstance(node.test, ast.UnaryOp)
                       and isinstance(node.test.op, ast.Not)
                       and isinstance(node.test.operand, ast.Name)
                       and node.test.operand.id == 'passed')
        code = compile(ast.fix_missing_locations(ast.Module(body=[failure], type_ignores=[])),
                       str(source), 'exec')
        for passed in (True, False):
            with self.subTest(passed=passed):
                row, launch, save = {'buildExit': 1}, Mock(), Mock()
                context = dict(passed=passed, row=row, case={'id': 'original-build-failure', 'exit': 0},
                               run=launch, save=save, group=None,
                               args=SimpleNamespace(mode='paired'))
                if passed:
                    exec(code, context)
                    save.assert_not_called()
                else:
                    with self.assertRaisesRegex(ValueError, 'original-build-failure'):
                        exec(code, context)
                    self.assertEqual(row['failureDiagnosticsMode'], 'retained-output-only')
                    self.assertEqual(row['buildExit'], 1)
                    save.assert_called_once()
                launch.assert_not_called()

    def test_numeric_optional_plan_preserves_legacy_mode(self):
        self.assertIsNone(self.numeric_runner().load_diagnostics_plan(None))

    def test_numeric_finalizer_rejects_unconfirmed_shutdown(self):
        numeric = self.numeric_runner()
        for process in [{'exit': 0, 'shutdownConfirmed': False}, {'exit': 0},
                        {'exit': None, 'shutdownConfirmed': True}]:
            with self.subTest(process=process):
                result = dict(status='passed', cases=[], processes=[process])
                numeric.finalize_result(result, True)
                self.assertFalse(result['processesStopped'])
                self.assertEqual(result['status'], 'failed')
                self.assertEqual(result['failure'], 'PROCESS_SHUTDOWN_UNCONFIRMED')
        normal = dict(status='passed', cases=[], processes=[{'exit': 0, 'shutdownConfirmed': True}])
        numeric.finalize_result(normal, True)
        self.assertEqual(normal['status'], 'passed')
        self.assertTrue(normal['processesStopped'])
        failure = dict(status='passed', cases=[], processes=[{'exit': 0, 'shutdownConfirmed': False}])
        numeric.finalize_result(failure, True, ValueError('ORIGINAL_FAILURE'))
        self.assertIn('ORIGINAL_FAILURE', failure['failure'])
        drift = dict(status='passed', cases=[], processes=[{'exit': 0, 'shutdownConfirmed': False}])
        numeric.finalize_result(drift, False)
        self.assertEqual(drift['failure'], 'INPUT_DRIFT after cases')

    def test_numeric_plan_timeout_cannot_relax_existing_contract(self):
        path = self.output / 'invalid-diagnostics.json'
        path.write_text(json.dumps(dict(stage='control', softLimitSeconds=30,
            hardTimeoutSeconds=1200, sampleIntervalSeconds=2, maxSamples=92)), encoding='utf-8')
        numeric = self.numeric_runner()
        child_output = self.output / 'must-not-exist'
        with patch.object(sys, 'argv', ['numeric', '--mode', 'managed', '--output', str(child_output),
                '--diagnostics-plan', str(path)]), \
                patch('verification_execution.subprocess.Popen') as launch:
            with self.assertRaisesRegex(ValueError, 'NUMERIC_DIAGNOSTICS_HARD_TIMEOUT_MISMATCH'):
                numeric.main()
            launch.assert_not_called()
        self.assertFalse(child_output.exists())

    def test_numeric_plan_invalid_budget_rejects_before_output(self):
        path = self.output / 'invalid-diagnostics.json'
        path.write_text(json.dumps(dict(stage='control', softLimitSeconds=30,
            hardTimeoutSeconds=180, sampleIntervalSeconds=2, maxSamples=1)), encoding='utf-8')
        with self.assertRaises(ValueError):
            self.numeric_runner().load_diagnostics_plan(path)


if __name__ == "__main__":
    unittest.main()
