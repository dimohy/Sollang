"""Reject incomplete output contracts before creating output or running tools."""

import json
import subprocess
import sys
import unittest
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class StdoutPreflightTests(unittest.TestCase):
    def invoke(self, expectation):
        folder = ROOT / "artifacts/scratch" / ("stdout-preflight-" + uuid.uuid4().hex)
        folder.mkdir()
        contract = folder / "contract.json"
        case = {"id": "probe", "source": "missing-stdout-preflight-source.slg",
                "exit": 0, "stderr": "", **expectation}
        contract.write_text(json.dumps({"schemaVersion": 1, "cases": [case]}), encoding="utf-8")
        output = folder / "output"
        result = subprocess.run([sys.executable, str(ROOT / "scripts/verify-c385-preir-call-numeric.py"),
                                 "--mode", "managed", "--contract", str(contract), "--output", str(output)],
                                cwd=ROOT, capture_output=True, text=True)
        (folder / "stderr.log").write_text(result.stderr, encoding="utf-8")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())
        return result.stderr

    def test_missing_stdout_stops_before_source_lookup_and_output(self):
        self.assertIn("CASE_STDOUT_EXPECTATION_REQUIRED", self.invoke({}))

    def test_nonstring_stdout_stops_before_source_lookup_and_output(self):
        self.assertIn("CASE_STDOUT_EXPECTATION_REQUIRED", self.invoke({"stdout": 0}))

    def test_explicit_empty_stdout_is_valid(self):
        diagnostic = self.invoke({"stdout": ""})
        self.assertNotIn("CASE_STDOUT_EXPECTATION_REQUIRED", diagnostic)
        self.assertIn("invalid source path", diagnostic)

    def test_trailing_newline_stops_before_source_lookup_and_output(self):
        self.assertIn("CASE_STDOUT_EXPECTATION_NONCANONICAL", self.invoke({"stdout": "line\n"}))

    def test_leading_whitespace_stops_before_source_lookup_and_output(self):
        self.assertIn("CASE_STDOUT_EXPECTATION_NONCANONICAL", self.invoke({"stdout": " line"}))

    def test_stderr_whitespace_stops_before_source_lookup_and_output(self):
        self.assertIn("CASE_STDERR_EXPECTATION_NONCANONICAL", self.invoke({"stdout": "", "stderr": "error\n"}))

    def test_internal_newline_is_preserved(self):
        diagnostic = self.invoke({"stdout": "first\nsecond"})
        self.assertNotIn("CASE_STDOUT_EXPECTATION_NONCANONICAL", diagnostic)
        self.assertIn("invalid source path", diagnostic)


if __name__ == "__main__":
    unittest.main()
