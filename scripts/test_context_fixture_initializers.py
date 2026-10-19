"""Reject stale nested and top-level initializer shapes before compilation."""
import runpy
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERIFY = runpy.run_path(str(ROOT / 'scripts/verify-context-fixture-initializers.py'))['verify']
SOURCE = ROOT / 'examples/regression/1000-selfhost-partition-route-type-invariant.slg'


class ContextInitializers(unittest.TestCase):
    def check_mutation(self, old, new, diagnostic):
        source = SOURCE.read_text(encoding='utf-8-sig')
        self.assertIn(old, source)
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / SOURCE.name
            fixture.write_text(source.replace(old, new, 1), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, diagnostic):
                VERIFY([fixture])

    def test_current_shapes(self):
        self.assertGreater(VERIFY([SOURCE])['initializers'], 0)

    def test_missing_nested_field(self):
        self.check_mutation(', firstTypeId: -1', '', "missing=\\['firstTypeId'\\]")

    def test_extra_top_field(self):
        self.check_mutation('initializerDiagnostics: []',
                            'unknownDiagnostic: []\n        initializerDiagnostics: []',
                            "extra=\\['unknownDiagnostic'\\]")

    def test_duplicate_top_field(self):
        self.check_mutation('initializerDiagnostics: []',
                            'initializerDiagnostics: []\n        initializerDiagnostics: []',
                            "duplicate=\\['initializerDiagnostics'\\]")


if __name__ == '__main__':
    unittest.main()
