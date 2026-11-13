"""Controls for resuming real interrupted prefixes without weakening contracts."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("resume_focused", Path(__file__).with_name("resume-focused-cohort.py"))
resume = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resume)


class ResumePrefixTests(unittest.TestCase):
    def setUp(self):
        self.contract = {"cases": [dict(id="ok", exit=0, stderr="", stdout="value"),
                                    dict(id="reject", exit=1, stderr="specific rejection")]}
        self.passed = dict(id="ok", status="passed", passed=True, buildExit=0, buildStderr="",
                           runExit=0, runStdout="value", runStderr="",
                           wholeCaseBudgetSeconds=180, wholeCaseElapsedSeconds=10)
        self.record = dict(total=2, completed=1, cases=[self.passed,
                           dict(id="reject", status="canceled", passed=False, buildExit=None)])

    def test_finished_prefix_survives_missing_exit_of_interrupted_case(self):
        self.assertEqual(resume.prefix_rows(self.record, self.contract), [self.passed])

    def test_observed_expected_field_cannot_override_static_exit(self):
        data = copy.deepcopy(self.record)
        data["cases"][0].update(expectedBuildExit=1, buildExit=1)
        with self.assertRaisesRegex(ValueError, "DECLARED_BUILD_EXIT_MISMATCH"):
            resume.prefix_rows(data, self.contract)

    def test_passed_flag_does_not_admit_unknown_exit(self):
        data = copy.deepcopy(self.record)
        data["cases"][0]["buildExit"] = None
        with self.assertRaisesRegex(ValueError, "DECLARED_BUILD_EXIT_MISMATCH"):
            resume.prefix_rows(data, self.contract)

    def test_runtime_and_diagnostic_oracles_are_preserved(self):
        for field, value in [("runStdout", "wrong"), ("runStderr", "new warning"),
                             ("buildStderr", "different")]:
            data = copy.deepcopy(self.record)
            data["cases"][0][field] = value
            with self.assertRaises(ValueError):
                resume.prefix_rows(data, self.contract)

    def test_over_budget_observation_is_not_reused(self):
        data = copy.deepcopy(self.record)
        data["cases"][0]["wholeCaseElapsedSeconds"] = 181
        with self.assertRaisesRegex(ValueError, "BUDGET_UNPROVEN"):
            resume.prefix_rows(data, self.contract)

    def test_noncontiguous_and_inflated_completion_are_rejected(self):
        data = copy.deepcopy(self.record)
        data["completed"] = 2
        with self.assertRaisesRegex(ValueError, "COUNT_MISMATCH"):
            resume.prefix_rows(data, self.contract)
        data = copy.deepcopy(self.record)
        data["cases"][0].update(status="canceled", passed=False)
        data["cases"][1] = dict(self.passed, id="reject")
        with self.assertRaisesRegex(ValueError, "NONCONTIGUOUS"):
            resume.prefix_rows(data, self.contract)

    def test_conflicting_dependency_hash_cannot_be_hidden_by_union(self):
        with self.assertRaisesRegex(ValueError, "CONFLICTING_INPUT_PIN"):
            resume.union_pins({"source": "A"}, {"source": "B"})

    def test_selected_case_requires_confirmed_process_shutdown(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            record = {"processes": [dict(command=[str(root / "ok" / "probe.exe")], exit=0,
                                          shutdownConfirmed=False)]}
            with self.assertRaisesRegex(ValueError, "PROCESS_UNCONFIRMED"):
                resume.case_processes(record, root, ["ok"])

    def test_unresolved_other_case_is_excluded_but_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            finished = dict(command=[str(root / "ok" / "probe.exe")], exit=0, shutdownConfirmed=True)
            interrupted = dict(command=[str(root / "reject" / "probe.exe")], exit=None, shutdownConfirmed=False)
            record = {"processes": [finished, interrupted]}
            self.assertEqual(resume.case_processes(record, root, ["ok"]), [finished])
            self.assertIsNone(interrupted["exit"])


if __name__ == "__main__":
    unittest.main()
