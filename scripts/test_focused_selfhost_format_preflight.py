"""Exercise the real preflight failure before any harness or LLVM work."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CompilerFormatPreflightTests(unittest.TestCase):
    def test_noncanonical_source_stops_before_harness_build(self):
        fixture = ROOT / "scripts/contracts/fixtures/focused-selfhost-format-noncanonical.slg"
        # Failure evidence remains available under the artifact lifecycle contract.
        workspace = Path(tempfile.mkdtemp(prefix="compiler-format-regression-", dir=ROOT / "artifacts/scratch"))
        manifest = workspace / "sources.txt"
        manifest.write_text(fixture.as_posix() + "\n", encoding="utf-8")
        output = workspace / "preflight"
        completed = subprocess.run([sys.executable, str(ROOT / "scripts/verify-focused-selfhost-semantic-preflight.py"),
                                    "--manifest", str(manifest), "--output", str(output)],
                                   cwd=ROOT, capture_output=True, text=True, timeout=60)
        self.assertEqual(completed.returncode, 1, completed.stdout + completed.stderr)
        record = json.loads((output / "result.json").read_text(encoding="utf-8-sig"))
        self.assertEqual(record["failureIds"], ["SEMANTIC_PREFLIGHT_COMPILER_SOURCE_FORMAT_FAILED"])
        self.assertTrue(record["inputsStable"])
        self.assertTrue(record["processesStopped"])
        self.assertFalse(record["codegenInvoked"])
        self.assertEqual(record["formatPreflight"]["invalidSources"], [str(fixture)])
        self.assertNotIn("harness-build", [step["id"] for step in record["steps"]])
        self.assertFalse((output / "SemanticPreflight.csproj").exists())
        self.assertFalse((output / "bin").exists())
        self.assertFalse(list(output.rglob("*.ll")))
        self.assertEqual(completed.stderr, "")


if __name__ == "__main__":
    unittest.main()
