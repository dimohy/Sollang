"""Prevent diagnostic-only or unfinished cases from becoming LLVM build evidence."""

import copy
import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location(
    "llvm_subset", Path(__file__).with_name("extract-verified-llvm-emission-proof.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class EmissionSubsetTests(unittest.TestCase):
    def parent(self):
        return {
            "schemaVersion": 1, "status": "passed", "mode": "managed",
            "completed": 2, "total": 2, "inputsStable": True, "processesStopped": True,
            "semanticPreflight": {"status": "passed-current-source", "codegenInvoked": False},
            "cases": [
                {"id": "llvm", "passed": True, "status": "passed", "emittedLlvmSha256": "A" * 64,
                 "buildExit": 0, "assemblyExit": 0, "nativeLinkExit": 0, "nativeRunExit": 0},
                {"id": "diagnostic", "passed": True, "status": "passed", "buildExit": 0}
            ]
        }

    def test_mixed_record_selects_only_actual_llvm_case_without_mutating_parent(self):
        parent = self.parent()
        before = copy.deepcopy(parent)
        self.assertEqual([case["id"] for case in MODULE.emitted_cases(parent)], ["llvm"])
        self.assertEqual(parent, before)

    def test_failed_parent_cannot_promote_successful_prefix(self):
        parent = self.parent()
        parent.update(status="failed", completed=1)
        with self.assertRaisesRegex(ValueError, "PARENT_NOT_VERIFIED"):
            MODULE.emitted_cases(parent)

    def test_running_process_cannot_promote_completed_cases(self):
        parent = self.parent()
        parent["processesStopped"] = False
        with self.assertRaisesRegex(ValueError, "PARENT_NOT_VERIFIED"):
            MODULE.emitted_cases(parent)

    def test_missing_native_execution_cannot_be_emission_evidence(self):
        parent = self.parent()
        del parent["cases"][0]["nativeRunExit"]
        with self.assertRaisesRegex(ValueError, "EMISSION_NOT_EXECUTED"):
            MODULE.emitted_cases(parent)

    def test_diagnostic_only_record_has_no_llvm_evidence(self):
        parent = self.parent()
        del parent["cases"][0]["emittedLlvmSha256"]
        with self.assertRaisesRegex(ValueError, "SUBSET_EMPTY"):
            MODULE.emitted_cases(parent)

    def test_missing_semantic_preflight_is_rejected(self):
        parent = self.parent()
        parent["semanticPreflight"] = {}
        with self.assertRaisesRegex(ValueError, "SEMANTIC_PREFLIGHT_MISSING"):
            MODULE.emitted_cases(parent)

    def test_boolean_counters_cannot_replace_measured_counts(self):
        parent = self.parent()
        parent.update(completed=True, total=True, cases=parent["cases"][:1])
        with self.assertRaisesRegex(ValueError, "PARENT_NOT_VERIFIED"):
            MODULE.emitted_cases(parent)


if __name__ == "__main__":
    unittest.main()
