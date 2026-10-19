import copy
import unittest

from verification_c527_enclosing_trace import ROOT, SNAPSHOT, LAYOUT, REQUIRED, validate


class EnclosingTraceTests(unittest.TestCase):
    def setUp(self):
        self.plan = dict(root=ROOT, owners=[ROOT, SNAPSHOT], excludedCallees=[LAYOUT],
                         maximumRecords=1024, markers=[
                             {'label': direction + SNAPSHOT + '->sollang_fn_' + name}
                             for name in REQUIRED for direction in ('before:', 'after:')])

    def test_complete_enclosing_phases(self):
        self.assertEqual(validate(self.plan)['requiredBoundaries'], 8)

    def test_old_combined_nested_owners_are_rejected(self):
        self.plan['owners'].append('sollang_fn_resolveContext')
        with self.assertRaisesRegex(ValueError, 'OWNERS_REQUIRED'):
            validate(self.plan)

    def test_reproduced_layout_loop_budget_failure_is_rejected(self):
        self.plan['excludedCallees'] = []
        with self.assertRaisesRegex(ValueError, 'LAYOUT_LOOP'):
            validate(self.plan)

    def test_silent_boundary_omission_and_insufficient_budget_are_rejected(self):
        omitted = copy.deepcopy(self.plan)
        omitted['markers'].pop()
        with self.assertRaisesRegex(ValueError, 'BOUNDARY_MISSING'):
            validate(omitted)
        self.plan['maximumRecords'] = 2
        with self.assertRaisesRegex(ValueError, 'BUDGET_INSUFFICIENT'):
            validate(self.plan)

    def test_excluded_layout_marker_cannot_survive(self):
        self.plan['markers'].append({'label': 'before:' + SNAPSHOT + '->' + LAYOUT})
        with self.assertRaisesRegex(ValueError, 'STILL_TRACED'):
            validate(self.plan)


if __name__ == '__main__':
    unittest.main()
