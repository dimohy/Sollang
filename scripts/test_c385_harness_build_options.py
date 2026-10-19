import importlib.util
from pathlib import Path
import sys
import unittest

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location('numeric_harness', SCRIPTS / 'verify-c385-preir-call-numeric.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class HarnessBuildOptionsTests(unittest.TestCase):
    def test_existing_recipes_preserved(self):
        self.assertEqual([], MODULE.harness_build_options({}, 'managed'))
        self.assertEqual(['-O1'], MODULE.harness_build_options({}, 'paired'))
        for mode in ('managed', 'paired'):
            for level in ('-O0', '-O1', '-O2', '-O3'):
                self.assertEqual([level], MODULE.harness_build_options({'harnessBuildOptimization': level}, mode))

    def test_worker_limit_reaches_cli_without_changing_optimization(self):
        self.assertEqual(['--jobs', '1'], MODULE.harness_build_options({'harnessBuildJobs': 1}, 'managed'))
        self.assertEqual(['-O1', '--jobs', '1'], MODULE.harness_build_options({'harnessBuildJobs': 1}, 'paired'))
        self.assertEqual(['-O2', '--jobs', '64'], MODULE.harness_build_options(
            {'harnessBuildOptimization': '-O2', 'harnessBuildJobs': 64}, 'managed'))

    def test_invalid_worker_contract_rejected_before_execution(self):
        for value in (0, -1, 65, True, False, 1.0, '1', []):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'HARNESS_BUILD_JOBS_INVALID'):
                MODULE.harness_build_options({'harnessBuildJobs': value}, 'managed')

    def test_invalid_optimization_is_still_rejected(self):
        with self.assertRaisesRegex(ValueError, 'HARNESS_BUILD_OPTIMIZATION_INVALID'):
            MODULE.harness_build_options({'harnessBuildOptimization': '-O9', 'harnessBuildJobs': 1}, 'managed')


if __name__ == '__main__':
    unittest.main()
