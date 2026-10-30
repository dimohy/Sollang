"""Cache builds and runs must share the user's fixed whole-case deadline."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "cache_runner", Path(__file__).with_name("verify-contextual-numeric-cache.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class CacheWholeCaseBudgetTests(unittest.TestCase):
    def setUp(self):
        self.now = 1000.0
        self.row = {"id": "probe"}
        self.budget = runner.CacheCaseBudget(self.row, lambda: self.now)

    def test_build_and_run_share_limit(self):
        self.assertEqual(self.budget.remaining(["build"], 180), 180)
        self.now += 140
        self.assertEqual(self.budget.remaining(["run"], 180), 40)
        self.now += 40
        with self.assertRaises(subprocess.TimeoutExpired):
            self.budget.finish()

    def test_expired_case_cannot_start_another_process(self):
        class NeverRun:
            timeout = 180
            def run(self, *args):
                raise AssertionError("expired case started a process")
        self.now += 180
        with self.assertRaises(subprocess.TimeoutExpired):
            self.budget.run(NeverRun(), ["run"], None, None)

    def test_failed_step_restores_execution_limit(self):
        class Failure:
            timeout = 20
            def run(self, *args):
                raise OSError("process could not start")
        execution = Failure()
        self.now += 175
        with self.assertRaises(OSError):
            self.budget.run(execution, ["run"], None, None)
        self.assertEqual(execution.timeout, 20)
        self.assertEqual(self.row["wholeCaseElapsedSeconds"], 175)

    def test_fresh_case_resets_budget_and_preserves_shorter_step_limit(self):
        self.now += 179
        self.assertEqual(self.budget.remaining(["run"], 5), 1)
        following = runner.CacheCaseBudget({"id": "next"}, lambda: self.now)
        self.assertEqual(following.remaining(["probe"], 5), 5)
        self.assertEqual(following.remaining(["build"], 180), 180)

    def test_real_generic_cache_consumer_shares_each_build_run_deadline(self):
        calls = []
        owner = self
        budget_type = runner.CacheCaseBudget

        class FakeOutput:
            timeout = 180
            def __init__(self, root, output, inputs, result, **kwargs):
                self.result = result
                output.mkdir()
            def __enter__(self):
                return self
            def __exit__(self, *args):
                self.result["status"] = "passed"
            def save(self):
                pass
            def run(self, command, stdout, stderr):
                calls.append(("build" if "build" in command else "run", self.timeout))
                build = "build" in command
                stdout.write_text("[semantic-cache] loaded;" if build else "42\n", encoding="utf-8")
                stderr.write_text("", encoding="utf-8")
                owner.now += 120 if build else 10
                return 0

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            sources = [output / name for name in ("main.slg", "expected.txt", "a.slg", "b.slg")]
            for source in sources:
                source.write_text("42", encoding="utf-8")
            result = {}
            with patch.object(runner, "generic_closure_inputs", return_value=sources), \
                    patch.object(runner, "VerificationOutput", FakeOutput), \
                    patch.object(runner, "CacheCaseBudget", lambda row: budget_type(row, lambda: self.now)):
                runner.verify_generic_closure(output / "compiler.exe", output, [], result, "managed")
        self.assertEqual(calls, [("build", 180), ("run", 60), ("build", 180), ("run", 60)])
        self.assertEqual(result["genericClosureControl"]["status"], "passed")


if __name__ == "__main__":
    unittest.main()
