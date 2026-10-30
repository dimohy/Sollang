"""A focused case shares one fixed budget across all execution stages."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('focused_runner', Path(__file__).with_name('verify-c385-preir-call-numeric.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class WholeCaseBudgetTests(unittest.TestCase):
    def setUp(self):
        self.now = 1000.0
        self.budget = runner.CaseBudget(lambda: self.now)

    def test_build_run_and_audit_share_deadline(self):
        self.assertEqual(self.budget.remaining(['build'], 180), 180)
        self.now += 100
        self.assertEqual(self.budget.remaining(['run'], 180), 80)
        self.now += 60
        self.assertEqual(self.budget.remaining(['audit-link'], 180), 20)
        self.now += 20
        with self.assertRaises(subprocess.TimeoutExpired):
            self.budget.remaining(['audit-run'], 180)

    def test_old_per_command_budget_cannot_extend_case(self):
        self.now += 170
        self.assertEqual(self.budget.remaining(['build'], 1200), 10)

    def test_shorter_step_limit_is_preserved(self):
        self.assertEqual(self.budget.remaining(['probe'], 5), 5)

    def test_each_case_has_its_own_budget(self):
        self.now += 179
        self.assertEqual(self.budget.remaining(['finish'], 180), 1)
        following = runner.CaseBudget(lambda: self.now)
        self.assertEqual(following.remaining(['build'], 180), 180)


class DiagnosticCaseDeadlineTests(unittest.TestCase):
    def setUp(self):
        self.plan = dict(stage='case-step', softLimitSeconds=30, hardTimeoutSeconds=180,
                         sampleIntervalSeconds=2, maxSamples=92)

    def test_fractional_remaining_deadline_matches_execution(self):
        diagnostic = runner.diagnostics_for_timeout(self.plan, Path('step'), 179.999)
        self.assertEqual(diagnostic.hard_timeout_seconds, 179.999)
        self.assertEqual(diagnostic.soft_limit_seconds, 30)
        self.assertEqual(self.plan['hardTimeoutSeconds'], 180)

    def test_short_remaining_case_preserves_valid_observation_window(self):
        diagnostic = runner.diagnostics_for_timeout(self.plan, Path('step'), 0.5)
        self.assertEqual(diagnostic.hard_timeout_seconds, 0.5)
        self.assertLess(diagnostic.soft_limit_seconds, 0.5)
        self.assertLessEqual(diagnostic.sample_interval_seconds, 0.5)

    def test_expired_invalid_or_extended_deadline_is_rejected(self):
        for timeout in (0, -1, 181, True, float('nan')):
            with self.subTest(timeout=timeout), self.assertRaises(ValueError):
                runner.diagnostics_for_timeout(self.plan, Path('step'), timeout)

    def test_real_child_accepts_the_bound_diagnostic_deadline(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            result = dict(status='running')
            execution = runner.VerificationExecution(runner.ROOT, output, result,
                                                      lambda: True, runner.sha)
            diagnostic = runner.diagnostics_for_timeout(self.plan, output / 'child', 2)
            completed = execution.run([sys.executable, '-c', 'print("ok")'],
                                      output / 'child', timeout=2, diagnostics=diagnostic)
            self.assertEqual(completed.returncode, 0)
            self.assertEqual(completed.stdout.strip(), 'ok')
            self.assertTrue(result['processes'][0]['shutdownConfirmed'])


if __name__ == '__main__':
    unittest.main()
