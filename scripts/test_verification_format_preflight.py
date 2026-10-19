"""Exercise format rejection before a compiler build or implicit tool fallback."""

import json
import subprocess
import sys
import unittest
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FORMATTER = Path.home() / "AppData/Local/Sollang/c92-fixed-array-region-abi-direct-20261001-20/compiler.exe"


class FormatPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = ROOT / "artifacts/scratch" / ("format-preflight-tests-" + uuid.uuid4().hex)
        cls.folder.mkdir()
        cls.source = cls.folder / "unformatted.slg"
        cls.source.write_text('main {\n  "preflight" -> println\n}\n', encoding="utf-8")

    def invoke(self, name, format_sources, formatter=False):
        contract = self.folder / (name + ".json")
        contract.write_text(json.dumps({"schemaVersion": 1, "formatCheckSources": format_sources,
            "cases": [{"id": "probe", "source": self.source.relative_to(ROOT).as_posix(),
                       "exit": 0, "stderr": "", "stdout": "preflight"}]}), encoding="utf-8")
        output = self.folder / (name + "-output")
        command = [sys.executable, str(ROOT / "scripts/verify-c385-preir-call-numeric.py"),
                   "--mode", "managed", "--contract", str(contract), "--output", str(output)]
        if formatter:
            command += ["--format-compiler", str(FORMATTER)]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        (self.folder / (name + ".stdout.log")).write_text(result.stdout, encoding="utf-8")
        (self.folder / (name + ".stderr.log")).write_text(result.stderr, encoding="utf-8")
        self.assertNotEqual(result.returncode, 0)
        return result, output

    def test_missing_formatter_has_no_fallback_or_output(self):
        result, output = self.invoke("missing-formatter", [self.source.relative_to(ROOT).as_posix()])
        self.assertIn("FORMAT_PREFLIGHT_EXPLICIT_COMPILER_REQUIRED", result.stderr)
        self.assertFalse(output.exists())

    def test_unpinned_source_is_rejected_before_tool_invocation(self):
        result, output = self.invoke("unpinned-source", ["selfhost/source_root.slg"], formatter=True)
        self.assertIn("FORMAT_PREFLIGHT_UNDECLARED_SOURCE", result.stderr)
        self.assertFalse(output.exists())

    def test_unformatted_source_never_starts_compilation(self):
        self.assertTrue(FORMATTER.is_file(), "the explicitly retained formatter is required")
        result, output = self.invoke("unformatted", [self.source.relative_to(ROOT).as_posix()], formatter=True)
        self.assertIn("FORMAT_PREFLIGHT_FAILED_BEFORE_BUILD", result.stderr)
        record = json.loads((output / "result.json").read_text(encoding="utf-8"))
        self.assertEqual(record["status"], "failed")
        self.assertTrue(record["inputsStable"])
        self.assertTrue(record["processesStopped"])
        self.assertEqual(record["cases"], [])
        self.assertTrue(record["processes"])
        self.assertTrue(all("build" not in process["command"] for process in record["processes"]))


if __name__ == "__main__":
    unittest.main()
