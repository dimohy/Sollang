import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "observer", Path(__file__).with_name("run-http-subject-observer.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class TraceSourceTests(unittest.TestCase):
    def test_mutable_binding_requires_parentheses(self):
        with self.assertRaisesRegex(ValueError, "MUTABLE_INTERPOLATION"):
            MODULE.validate_trace_source('"ir=$irIndex!"')

    def test_parenthesized_mutable_and_immutable_names(self):
        MODULE.validate_trace_source('"ir=$(irIndex!),kind=$kind"')

    def test_actual_observer_source(self):
        MODULE.validate_trace_source(Path(__file__).with_name("http-subject-observer.slg").read_text())


if __name__ == "__main__":
    unittest.main()
