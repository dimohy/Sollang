import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("layout_source", Path(__file__).with_name("verify-source.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LayoutStatusContract(unittest.TestCase):
    def test_only_canonical_overflow_is_accepted(self):
        expected = dict(capacity=536870908, status="overflow")
        valid = dict(capacity=536870908, status=4, size=-1, align=1)
        self.assertTrue(module.matches_layout(expected, valid))
        for delta in [dict(status=0), dict(status=1), dict(status=2), dict(status=3),
                      dict(size=8), dict(size=-2147483640), dict(align=8), dict(capacity=1)]:
            with self.subTest(delta=delta):
                self.assertFalse(module.matches_layout(expected, {**valid, **delta}))

    def test_valid_size_and_alignment_remain_exact(self):
        expected = dict(capacity=1, status="known", size=16)
        valid = dict(capacity=1, status=0, size=16, align=8)
        self.assertTrue(module.matches_layout(expected, valid))
        for delta in [dict(status=4), dict(size=-1), dict(align=1)]:
            with self.subTest(delta=delta):
                self.assertFalse(module.matches_layout(expected, {**valid, **delta}))


if __name__ == "__main__":
    unittest.main()
