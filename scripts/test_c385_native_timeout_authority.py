import copy
import importlib.util
import json
import tempfile
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("numeric_runner", ROOT / "scripts/verify-c385-preir-call-numeric.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ContextTimeoutAuthorityTests(unittest.TestCase):
    def setUp(self):
        stem = "examples/regression/expected/1999-selfhost-context-fixture-suite"
        sources = runner.read(ROOT / (stem + ".sources.txt")).splitlines()
        self.contract = {"cases": [{"id": "1999-selfhost-context-fixture-suite",
            "source": sources[0], "additionalSources": sources[1:], "exit": 0,
            "stderr": "", "stdout": runner.read(ROOT / (stem + ".stdout.txt")).strip()}],
            "nativeBuildTimeoutAuthority": {"path": "scripts/contracts/context-fixture-pair-plan.json",
                "sha256": runner.sha(ROOT / "scripts/contracts/context-fixture-pair-plan.json")}}

    def test_original_suite_uses_original_budget(self):
        self.assertEqual(runner.native_build_timeout(self.contract)[0], 1200)

    def test_ordinary_focused_budget_unchanged(self):
        self.assertEqual(runner.native_build_timeout({"cases": []}), (180, []))

    def test_wrong_authority_rejected(self):
        self.contract["nativeBuildTimeoutAuthority"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "AUTHORITY_INVALID"):
            runner.native_build_timeout(self.contract)

    def test_previous_short_runner_rejected_before_native_cost(self):
        del self.contract["nativeBuildTimeoutAuthority"]
        with self.assertRaisesRegex(ValueError, "AUTHORITY_REQUIRED"):
            runner.native_build_timeout(self.contract)
        self.assertEqual(runner.native_build_timeout(self.contract, "managed"), (180, []))

    def test_scope_or_expectation_cannot_be_weakened(self):
        for key, value in (("stdout", ""), ("additionalSources", []), ("id", "another-case")):
            changed = copy.deepcopy(self.contract)
            changed["cases"][0][key] = value
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "SCOPE_INVALID"):
                runner.native_build_timeout(changed)

    def test_private_array_case_rejected_without_launch_or_budget_escalation(self):
        contract = {"cases": [{"id": "array-layout-live-type-roots"}]}
        with self.assertRaisesRegex(ValueError, "PRIVATE_COMPILER_WORKLOAD_REQUIRES_SEPARATE_BUDGET"):
            runner.native_build_timeout(contract)
        self.assertEqual(runner.native_build_timeout(contract, "managed"), (180, []))

    def test_renaming_private_case_does_not_bypass_source_admission(self):
        source = "artifacts/scratch/resume-20261006-owner-continuation22/array-layout-live-types-focused212.slg"
        contract = {"cases": [{"id": "renamed-case", "source": source}]}
        with self.assertRaisesRegex(ValueError, "PRIVATE_COMPILER_WORKLOAD_REQUIRES_SEPARATE_BUDGET"):
            runner.native_build_timeout(contract)

    def test_copying_private_fixture_does_not_bypass_admission(self):
        original = ROOT / "artifacts/scratch/resume-20261006-owner-continuation22/array-layout-live-types-focused212.slg"
        with tempfile.NamedTemporaryFile(dir=ROOT / "artifacts/scratch", suffix=".slg", delete=False) as copied:
            copied.write(original.read_bytes())
        try:
            contract = {"cases": [{"id": "renamed-copy", "source": Path(copied.name).relative_to(ROOT).as_posix()}]}
            with self.assertRaisesRegex(ValueError, "PRIVATE_COMPILER_WORKLOAD_REQUIRES_SEPARATE_BUDGET"):
                runner.native_build_timeout(contract)
        finally:
            Path(copied.name).unlink()

    def test_public_fixture_stays_at_original_budget(self):
        contract = {"cases": [{"id": "499-selfhost-transitive-nonsendable-parallel-capture",
            "source": "examples/regression/499-selfhost-transitive-nonsendable-parallel-capture.slg"}]}
        self.assertEqual(runner.native_build_timeout(contract), (180, []))


if __name__ == "__main__":
    unittest.main()
