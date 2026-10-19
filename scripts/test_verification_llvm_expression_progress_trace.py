import unittest
from test_verification_llvm_callback_trace import SOURCE
from verification_llvm_expression_progress_trace import instrument, summarize, OWNER, PREFIX, HANDLERS

NAMED = f'define internal i32 @{OWNER}(i32 %it, ptr %context) {{\nentry:\n' + ''.join(
    f'  call void @{PREFIX}{h}(ptr %context, i32 %expr, i32 %it, ptr %state)\n'
    for h in HANDLERS if h != 'inline-expression-branches') + f'  call void @{PREFIX}emitFunctionReturn(i32 %it)\n  ret i32 %it\n}}\n'

def rec(kind,item,ordinal=0,expr=100,handler=1):
    payload = (ordinal<<40)|(expr<<8)|handler if kind in 'BA' else ordinal
    return f'{kind}:{item:08x}:{payload:016x}\n'

class ExpressionProgressTests(unittest.TestCase):
    def setUp(self):
        self.changed,self.plan=instrument(SOURCE+NAMED,'callback',[4,8])

    def test_calls_preserved_and_bounded_sampling(self):
        for line in NAMED.splitlines():
            if 'call void @' in line:self.assertEqual(self.changed.count(line),1)
        self.assertIn('  %observe_mod = and i32 %observe_ordinal, 127',self.changed)
        self.assertIn('icmp ult i64 %record, 8192',self.changed)
        self.assertEqual(self.plan['handlers'][2],'inline-expression-branches')
        self.assertNotIn(f'i8 66, i32 %item, i64 %index',self.changed)

    def test_scope_and_changed_abi_rejected(self):
        for source in [SOURCE,SOURCE+NAMED.replace('emitFunctionArrayExpressions','other'),
                       SOURCE+NAMED.replace('emitFunctionCalls(ptr %context, i32 %expr','emitFunctionCalls(ptr %context, i32 %different')]:
            with self.assertRaises(ValueError):instrument(source,'callback',[4])
        for selected,stride in [([],128),([4,4],128),([-1],128),([4],3)]:
            with self.assertRaises(ValueError):instrument(SOURCE+NAMED,'callback',selected,stride)

    def test_concurrent_progress_pending_inline_and_partial(self):
        trace=rec('I',4)+rec('I',8)
        for h in range(1,11):trace+=rec('B',4,handler=h)+rec('A',4,handler=h)
        trace+=rec('B',4,128,200)+rec('A',4,128,200)+rec('B',4,128,200,2)
        trace+=rec('B',8)+rec('A',8)+rec('B',8,handler=2)+'A:00000008:'
        summary=summarize(self.plan,trace)
        self.assertEqual(summary['functions'][4]['completedCheckpoints'],1)
        self.assertEqual(summary['functions'][4]['pending']['ordinal'],128)
        self.assertEqual(summary['functions'][8]['pending']['handler'],2)
        self.assertTrue(summary['ignoredPartialLine'])

    def test_invalid_record_order_and_foreign_function_rejected(self):
        for trace in ['oops\n',rec('I',9),rec('B',4),rec('I',4)+rec('A',4),
                      rec('I',4)+rec('B',4,handler=2),rec('I',4)+rec('B',4,ordinal=1),
                      rec('I',4)+rec('B',4)+rec('A',4,expr=101),
                      rec('I',4)+rec('B',4)+rec('R',4)]:
            with self.assertRaises(ValueError):summarize(self.plan,trace)

    def test_return_and_budget_are_distinct(self):
        summary=summarize(self.plan,rec('I',4)+rec('R',4,5))
        self.assertTrue(summary['functions'][4]['reachedReturn'])
        self.assertEqual(summary['functions'][4]['iterationCount'],5)
        plan=dict(self.plan,maximumRecords=2)
        summary=summarize(plan,rec('I',4)+rec('B',4))
        self.assertTrue(summary['traceBudgetExhausted'])
        self.assertFalse(summary['pendingBoundariesConclusive'])

    def test_every_expression_records_exact_pending_handler(self):
        changed,plan=instrument(SOURCE+NAMED,'callback',[4],stride=1)
        self.assertIn('  %observe_mod = and i32 %observe_ordinal, 0',changed)
        trace=rec('I',4)
        for h in range(1,11):trace+=rec('B',4,handler=h)+rec('A',4,handler=h)
        trace+=rec('B',4,1,123,1)+rec('A',4,1,123,1)+rec('B',4,1,123,2)
        summary=summarize(plan,trace)
        self.assertEqual(summary['functions'][4]['pending'],dict(ordinal=1,expression=123,handler=2))
        self.assertEqual(summary['functions'][4]['completedCheckpoints'],1)

if __name__=='__main__':unittest.main()
