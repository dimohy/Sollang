import unittest
from verification_llvm_compute_trace import instrument_compute, ROOT, CALLEE


class ComputeTraceTests(unittest.TestCase):
    def setUp(self):
        self.plan = dict(root=ROOT, depth=0, owners=[ROOT], abi='managed-windows',
                         markers=[dict(id=0, label='enter:' + ROOT)], maximumRecords=16)
        self.call = '  call void @' + CALLEE + '(i64 7)'
        self.source = ('define internal void @' + ROOT + '() {\nentry:\n'
                       + self.call + '\n' + self.call + '\n  ret void\n}\n'
                       'define internal void @other() {\nentry:\n' + self.call
                       + '\n  ret void\n}\n')

    def test_dispatch_arguments_and_other_owner_preserved(self):
        text, plan = instrument_compute(self.source, self.plan)
        self.assertEqual(text.count(self.call), 3)
        self.assertIn(self.source[self.source.index('define internal void @other'):], text)
        self.assertEqual(len(plan['markers']), 5)
        self.assertEqual(len(self.plan['markers']), 1)
        self.assertEqual(text.count('call void @sollang_observation_emit'), 4)

    def test_non_core_owner_rejected(self):
        self.plan['depth'] = 1
        with self.assertRaisesRegex(ValueError, 'SCOPE'):
            instrument_compute(self.source, self.plan)

    def test_missing_dispatch_rejected(self):
        with self.assertRaisesRegex(ValueError, 'TWO_DISPATCHES'):
            instrument_compute(self.source.replace(self.call, '', 1), self.plan)

    def test_reinstrumentation_rejected(self):
        text, plan = instrument_compute(self.source, self.plan)
        with self.assertRaisesRegex(ValueError, 'ALREADY'):
            instrument_compute(text, plan)

    def test_budget_overrun_rejected(self):
        self.plan['maximumRecords'] = 4
        with self.assertRaisesRegex(ValueError, 'BUDGET'):
            instrument_compute(self.source, self.plan)


if __name__ == '__main__':
    unittest.main()
