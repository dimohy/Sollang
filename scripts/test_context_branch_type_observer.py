"""The observer must reject source-contract mistakes before an LLVM build."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'scripts/probes/selection-result/run-context-branch-type-observer.py'
spec = importlib.util.spec_from_file_location('branch_observer', SCRIPT)
observer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(observer)
HELPER = SCRIPT.with_name('context-branch-type-observer.slg')
TYPE_SOURCE = ROOT / 'selfhost/semantic/type_ids.slg'


class ObserverContractTests(unittest.TestCase):
    def validate_variant(self, body):
        with tempfile.TemporaryDirectory() as directory:
            helper = Path(directory) / 'helper.slg'
            helper.write_text(body, encoding='utf-8')
            observer.validate_helper(helper, TYPE_SOURCE)

    def test_current_source_contract(self):
        observer.validate_helper(HELPER, TYPE_SOURCE)

    def test_previous_unknown_field_failure(self):
        with self.assertRaisesRegex(ValueError, 'UNKNOWN_TYPE_FIELD: sourceModule'):
            self.validate_variant(HELPER.read_text(encoding='utf-8').replace('semanticType.module', 'semanticType.sourceModule'))

    def test_mutable_interpolation_rejected(self):
        with self.assertRaisesRegex(ValueError, 'MUTABLE_INTERPOLATION_REQUIRES_PARENTHESES'):
            self.validate_variant(HELPER.read_text(encoding='utf-8') + '\n"$index!" -> println\n')


if __name__ == '__main__':
    unittest.main()
