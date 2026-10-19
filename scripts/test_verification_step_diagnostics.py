"""Deterministic tests; no sleeping, processes or external dependencies."""

import json
from pathlib import Path
import tempfile
import unittest

from verification_step_diagnostics import SlowStepDiagnostics


def plan(**changes):
    result = dict(stage="native-build", softLimitSeconds=10, hardTimeoutSeconds=20,
                  sampleIntervalSeconds=2, maxSamples=3)
    result.update(changes)
    return result


class SlowStepDiagnosticsTests(unittest.TestCase):
    def test_normal_and_exact_soft_boundary(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(0, 100, 0, 0)
        self.assertEqual(diagnostic.observe(10, 100, 20, 0)["status"], "within-soft-limit")
        self.assertEqual(diagnostic.observe(10.01, 100, 20, 0)["status"], "slow")

    def test_slow_busy_with_explicit_process_scope(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(9, 100, 0, 0, cpu_seconds=8, cpu_scope="owned-process")
        record = diagnostic.observe(11, 100, 0, 0, cpu_seconds=10, cpu_scope="owned-process")
        self.assertEqual((record["status"], record["activity"]), ("slow", "active"))
        self.assertEqual(record["samples"][-1]["cpuScope"], "owned-process")
        self.assertFalse(record["automaticRetry"])
        self.assertFalse(record["automaticProfiling"])
        self.assertFalse(record["hardTimeoutChanged"])

    def test_slow_quiet_requires_known_cpu(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(9, 100, 0, 0, cpu_seconds=8, cpu_scope="owned-tree", owned_pids=[100, 101])
        record = diagnostic.observe(11, 100, 0, 0, cpu_seconds=8, cpu_scope="owned-tree", owned_pids=[100, 101])
        self.assertEqual((record["status"], record["activity"]), ("slow", "quiet"))
        self.assertTrue(any("outside the observed scope" in item for item in record["limitations"]))

    def test_cpu_unknown_can_only_use_log_evidence(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(9, 100, 0, 0)
        self.assertEqual(diagnostic.observe(11, 100, 0, 0)["activity"], "unknown")
        self.assertEqual(diagnostic.observe(13, 100, 2, 0)["activity"], "active")

    def test_bound_preserves_first_latest_and_gap_evidence(self):
        diagnostic = SlowStepDiagnostics(plan())
        for elapsed in (0, 2, 4, 6, 15, 17):
            record = diagnostic.observe(elapsed, 100, elapsed, 0)
        self.assertEqual([sample["elapsedSeconds"] for sample in record["samples"]], [0, 15, 17])
        self.assertEqual(record["observedSamples"], 6)
        self.assertEqual(record["droppedSamples"], 3)
        self.assertTrue(record["storageBudgetExhausted"])
        self.assertEqual(record["samplingGapCount"], 1)
        self.assertEqual(record["maximumObservedGapSeconds"], 9)
        record["samples"][0]["ownedPids"].append(200)
        self.assertEqual(diagnostic.snapshot()["samples"][0]["ownedPids"], [100])

    def test_cpu_scope_reset_and_counter_reset_are_unknown(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(0, 100, 0, 0, cpu_seconds=2, cpu_scope="owned-process")
        record = diagnostic.observe(2, 100, 0, 0, cpu_seconds=1, cpu_scope="owned-process")
        self.assertEqual(record["activity"], "unknown")
        self.assertEqual(record["cpuCounterResetCount"], 1)
        record = diagnostic.observe(4, 100, 0, 0, cpu_seconds=1, cpu_scope="owned-tree")
        self.assertEqual(record["activity"], "unknown")
        self.assertEqual(record["cpuScopeChangeCount"], 1)

    def test_invalid_plan_before_file_write(self):
        base = plan()
        mutations = [dict(base, stage=""), dict(base, softLimitSeconds=0),
                     dict(base, softLimitSeconds=20), dict(base, hardTimeoutSeconds=True),
                     dict(base, sampleIntervalSeconds=float("nan")), dict(base, maxSamples=1),
                     dict(base, maxSamples=True), dict(base, unexpected=True)]
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "result.json"
            for invalid in mutations:
                with self.subTest(plan=invalid), self.assertRaises(ValueError):
                    SlowStepDiagnostics(invalid, target)
                self.assertFalse(target.exists())
            self.assertEqual(list(Path(folder).iterdir()), [])

    def test_invalid_observations_do_not_commit(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(2, 100, 0, 0)
        with self.assertRaises(ValueError):
            diagnostic.observe(1, 100, 0, 0)
        with self.assertRaises(ValueError):
            diagnostic.observe(3, 100, 0, 0, cpu_seconds=1)
        with self.assertRaises(ValueError):
            diagnostic.observe(3, 100, 0, 0, owned_pids=[101])
        self.assertEqual(diagnostic.snapshot()["observedSamples"], 1)

    def test_durable_json_records_latest_sample(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / "step.json"
            diagnostic = SlowStepDiagnostics(plan(), target)
            diagnostic.observe(0, 100, 0, 0)
            diagnostic.observe(11, 100, 0, 0)
            record = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(record["status"], "slow")
            self.assertEqual(record["samples"][-1]["elapsedSeconds"], 11)
            self.assertFalse(target.with_name("step.json.tmp").exists())

    def test_investigation_only_after_soft_budget(self):
        diagnostic = SlowStepDiagnostics(plan())
        self.assertFalse(diagnostic.snapshot()["investigation"]["required"])
        diagnostic.observe(8, 100, 0, 0, cpu_seconds=1, cpu_scope="owned-process")
        at_boundary = diagnostic.observe(10, 100, 0, 0, cpu_seconds=2, cpu_scope="owned-process")
        self.assertEqual(at_boundary["investigation"]["causeCandidates"], [])
        record = diagnostic.observe(12, 100, 0, 0, cpu_seconds=3, cpu_scope="owned-process")
        investigation = record["investigation"]
        self.assertEqual(investigation["classification"], "cpu-active")
        self.assertEqual(investigation["causeCandidates"], ["cpu-work-or-spin"])
        self.assertEqual(investigation["evidence"]["cpuScope"], "owned-process")
        self.assertEqual(investigation["certainty"], "candidate-only")
        self.assertFalse(investigation["automaticExecution"])
        self.assertTrue(all(step["execution"] == "read-only" for step in investigation["nextSteps"]))

    def test_investigation_output_and_quiet_routes(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(9, 100, 0, 0, cpu_seconds=1, cpu_scope="owned-tree")
        output = diagnostic.observe(11, 100, 3, 0, cpu_seconds=1, cpu_scope="owned-tree")["investigation"]
        self.assertEqual(output["classification"], "output-active")
        self.assertIn("inspect-existing-stdout-stderr-content", [step["id"] for step in output["nextSteps"]])
        quiet = diagnostic.observe(13, 100, 3, 0, cpu_seconds=1, cpu_scope="owned-tree")["investigation"]
        self.assertEqual(quiet["classification"], "quiet-observed-interval")
        self.assertEqual(quiet["causeCandidates"], ["wait-or-block-or-unmeasured-work"])
        step = next(step for step in quiet["nextSteps"] if step["id"] == "plan-bounded-wait-investigation")
        self.assertEqual(step["execution"], "plan-only")
        self.assertTrue(step["requiresExplicitExecutionBudget"])

    def test_investigation_unknown_reset_scope_and_gap_are_not_stoppage(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(9, 100, 0, 0)
        unknown = diagnostic.observe(11, 100, 0, 0)["investigation"]
        self.assertEqual(unknown["classification"], "insufficient-evidence")
        diagnostic.observe(13, 100, 0, 0, cpu_seconds=3, cpu_scope="owned-tree")
        reset = diagnostic.observe(15, 100, 0, 0, cpu_seconds=2, cpu_scope="owned-tree")["investigation"]
        self.assertEqual(reset["evidence"]["cpuContinuity"], "counter-reset")
        self.assertEqual(reset["classification"], "insufficient-evidence")
        changed = diagnostic.observe(20, 100, 0, 0, cpu_seconds=2, cpu_scope="owned-tree", owned_pids=[100, 101])["investigation"]
        self.assertEqual(changed["classification"], "insufficient-evidence")
        self.assertIn("owned-process-set-changed", changed["causeCandidates"])
        self.assertIn("sampling-gap", changed["causeCandidates"])
        self.assertEqual(changed["evidence"]["cpuContinuity"], "scope-changed")
        self.assertNotIn("wait-or-block-or-unmeasured-work", changed["causeCandidates"])

    def test_investigation_zero_interval_and_log_reset_are_not_quiet(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(11, 100, 3, 0, cpu_seconds=1, cpu_scope="owned-tree")
        zero = diagnostic.observe(11, 100, 3, 0, cpu_seconds=1, cpu_scope="owned-tree")["investigation"]
        self.assertEqual(zero["classification"], "insufficient-evidence")
        reset = diagnostic.observe(13, 100, 0, 0, cpu_seconds=1, cpu_scope="owned-tree")["investigation"]
        self.assertEqual(reset["classification"], "insufficient-evidence")
        self.assertIn("log-counter-reset", reset["causeCandidates"])

    def test_investigation_snapshot_is_detached(self):
        diagnostic = SlowStepDiagnostics(plan())
        diagnostic.observe(9, 100, 0, 0, cpu_seconds=1, cpu_scope="owned-tree")
        record = diagnostic.observe(11, 100, 0, 0, cpu_seconds=2, cpu_scope="owned-tree")
        record["investigation"]["evidence"]["ownedPids"].append(101)
        record["investigation"]["evidence"]["logSizeDelta"]["stdoutBytes"] = 99
        self.assertEqual(diagnostic.snapshot()["investigation"]["evidence"]["ownedPids"], [100])
        self.assertEqual(diagnostic.snapshot()["investigation"]["evidence"]["logSizeDelta"]["stdoutBytes"], 0)


if __name__ == "__main__":
    unittest.main()
