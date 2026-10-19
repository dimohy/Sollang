import unittest

from verification_llvm_callback_trace import instrument, summarize, CALLEE


SOURCE = '''declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
define internal void @callback(ptr %group, i64 %index) #0 {
entry:
  %item = load i32, ptr %group
  %mapped = call i32 @''' + CALLEE + '''(ptr %stdin, ptr %sink_stdout, ptr %written, ptr %read, ptr %ok_state, i32 %item, ptr %capture_value_0, ptr %capture_value_1)
  ret void
}
'''


class CallbackTests(unittest.TestCase):
    def test_preserves_exact_call(self):
        source, plan = instrument(SOURCE, 'callback')
        original = next(line for line in SOURCE.splitlines() if '%mapped = call' in line)
        self.assertEqual(source.count(original), 1)
        self.assertEqual(source.count('call void @sollang_observe_callback_item('), 2)
        self.assertTrue(plan['concurrent'])

    def test_rejects_wrong_owner_call_abi_and_reinstrumentation(self):
        for source, owner in ((SOURCE, 'missing'), (SOURCE.replace('i32 %item,', 'i32 42,'), 'callback'),
                              (SOURCE.replace('declare dllimport ptr @GetStdHandle(i32)', ''), 'callback'),
                              (instrument(SOURCE, 'callback')[0], 'callback')):
            with self.assertRaises(ValueError):
                instrument(source, owner)

    def test_concurrent_returns_and_partial_lines(self):
        _, plan = instrument(SOURCE, 'callback')
        trace = 'B:00000004:0000000000000001\nB:00000008:0000000000000002\nA:00000008:0000000000000002\nA:000'
        result = summarize(plan, trace)
        self.assertEqual(result['completedItems'], {2: 8})
        self.assertEqual(result['pendingItems'], {1: 4})
        self.assertTrue(result['ignoredPartialLine'])

    def test_invalid_duplicate_and_unmatched(self):
        _, plan = instrument(SOURCE, 'callback')
        for trace in ('garbage\n', 'A:00000004:0000000000000001\n',
                      'B:00000004:0000000000000001\n' * 2,
                      'B:00000004:0000000000000001\nA:00000008:0000000000000001\n'):
            with self.assertRaises(ValueError):
                summarize(plan, trace)

    def test_bounded_evidence(self):
        _, plan = instrument(SOURCE, 'callback', 2)
        result = summarize(plan, 'B:00000004:0000000000000001\nB:00000008:0000000000000002\n')
        self.assertTrue(result['traceBudgetExhausted'])
        self.assertFalse(result['pendingItemsConclusive'])
        with self.assertRaises(ValueError):
            instrument(SOURCE, 'callback', 65537)


if __name__ == '__main__':
    unittest.main()
