"""A focused case shares one fixed budget across all execution stages."""
import importlib.util
from pathlib import Path
import subprocess
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


if __name__ == '__main__':
    unittest.main()
