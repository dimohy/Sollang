import unittest

from test_verification_llvm_callback_trace import SOURCE
from verification_llvm_call_trace import FUNCTION
from verification_llvm_function_phase_trace import instrument, summarize, OWNER, PREFIX, PHASES, WRAPPER


NAMED = f'''define internal i32 @{OWNER}(i32 %it, ptr %context) {{
entry:
  %node = load %node_type, ptr %context, align 8
  %next = add i32 %it, 1
  store i32 %next, ptr %end_slot, align 4
  %module = extractvalue %node_type %node, 2
  call void @{PREFIX}writeDecimal(i32 %module)
  %symbol = extractvalue %node_type %node, 4
''' + ''.join(f'  call void @{PREFIX}{p}(i32 %it)\n' for p in PHASES) + '  ret i32 %it\n}\n'


class FunctionPhaseTests(unittest.TestCase):
    def test_exact_calls_and_other_owner_preserved(self):
        source = SOURCE + NAMED
        changed, plan = instrument(source, 'callback', [4, 8])
        callback = next(m.group(0) for m in FUNCTION.finditer(source) if m.group(1) == 'callback')
        self.assertIn(callback, changed)
        for line in NAMED.splitlines():
            if 'call void @' in line:
                self.assertEqual(changed.count(line), 1)
        self.assertEqual(plan['phases'][8], 'ordinary-expression-emission')
        self.assertIn('%selected_0 = icmp eq i32 %item, 4', changed)
        self.assertIn('%selected_1 = icmp eq i32 %item, 8', changed)

    def test_scope_identity_and_missing_phase_rejected(self):
        for source in (SOURCE, SOURCE + NAMED.replace(', 2\n', ', 3\n'),
                       SOURCE + NAMED.replace(PREFIX + PHASES[0], PREFIX + 'other')):
            with self.assertRaises(ValueError):
                instrument(source, 'callback', [4])
        for indices in ([], [4, 4], [-1], [1, 2, 3, 4, 5]):
            with self.assertRaises(ValueError):
                instrument(SOURCE + NAMED, 'callback', indices)

    def test_concurrent_phase_records_and_partial_return(self):
        _, plan = instrument(SOURCE + NAMED, 'callback', [4, 8])
        trace = ('I:00000004:0000000000000000\nM:00000004:0000000000000002\n'
                 'I:00000008:0000000000000000\nB:00000004:0000000000000001\n'
                 'B:00000008:0000000000000001\nA:00000008:0000000000000001\nA:000')
        result = summarize(plan, trace)
        self.assertEqual(result['functions'][4]['pendingPhase'], 1)
        self.assertEqual(result['functions'][8]['returnedPhases'], [1])
        self.assertTrue(result['ignoredPartialLine'])

    def test_invalid_foreign_unmatched_and_missing_entry_rejected(self):
        _, plan = instrument(SOURCE + NAMED, 'callback', [4])
        for trace in ('garbage\n', 'I:00000008:0000000000000000\n',
                      'M:00000004:0000000000000002\n',
                      'I:00000004:0000000000000000\nA:00000004:0000000000000001\n',
                      'I:00000004:0000000000000000\nB:00000004:00000000000000ff\n'):
            with self.assertRaises(ValueError):
                summarize(plan, trace)

    def test_exhausted_records_are_inconclusive(self):
        _, plan = instrument(SOURCE + NAMED, 'callback', [4])
        plan['maximumRecords'] = 2
        result = summarize(plan, 'I:00000004:0000000000000000\nB:00000004:0000000000000001\n')
        self.assertTrue(result['traceBudgetExhausted'])
        self.assertFalse(result['pendingPhasesConclusive'])


if __name__ == '__main__':
    unittest.main()
