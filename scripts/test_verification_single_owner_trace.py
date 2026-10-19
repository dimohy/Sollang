import unittest
from verification_single_owner_trace import summarize


class TraceTests(unittest.TestCase):
    def setUp(self):
        self.plan = dict(root='root', depth=0, owners=['root'], maximumRecords=10,
                         markers=[dict(label=x) for x in
                                  ('enter:root', 'before:root->a', 'after:root->a',
                                   'before:root->b', 'after:root->b')])

    def test_conditional_calls_and_duplicate_invocations(self):
        row = summarize(self.plan, 'enter:root\nbefore:root->b\nafter:root->b\n'
                        'before:root->b\nafter:root->b\n')
        self.assertEqual(row['returnedCalls'], ['b', 'b'])
        self.assertIsNone(row['pendingCall'])
        self.assertEqual(row['scope'], 'diagnostic-only-not-root-completion')

    def test_partial_return_cannot_close_call(self):
        row = summarize(self.plan, 'enter:root\nbefore:root->a\nafter:root->a')
        self.assertEqual(row['pendingCall'], 'a')
        self.assertTrue(row['ignoredPartialLine'])

    def test_wrong_return_and_missing_entry_rejected(self):
        for text in ('enter:root\nbefore:root->a\nafter:root->b\n',
                     'before:root->a\n', 'enter:root\nenter:root\n'):
            with self.assertRaises(ValueError):
                summarize(self.plan, text)

    def test_exhausted_budget_is_inconclusive(self):
        self.plan['maximumRecords'] = 2
        row = summarize(self.plan, 'enter:root\nbefore:root->a\n')
        self.assertFalse(row['pendingCallConclusive'])

    def test_unknown_marker_and_nested_scope_rejected(self):
        with self.assertRaises(ValueError):
            summarize(self.plan, 'garbage\n')
        self.plan['depth'] = 1
        with self.assertRaises(ValueError):
            summarize(self.plan, '')


if __name__ == '__main__':
    unittest.main()
