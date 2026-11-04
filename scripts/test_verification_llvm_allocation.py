"""Entry adapter controls for actual CSharp and Native allocation fault probes."""
import unittest
from verification_llvm_allocation import allocation_failure_entrypoint, allocation_failure_case_call, allocation_failure_call_binding


class AllocationFailureEntrypointTests(unittest.TestCase):
    def test_existing_main_is_preserved(self):
        text = 'define i32 @main() {\n  ret i32 0\n}\n'
        self.assertEqual(allocation_failure_entrypoint(text), text)

    def test_current_native_startup_is_adapted(self):
        text = 'define i32 @sollang_start() {\n  ret i32 7\n}\n'
        result = allocation_failure_entrypoint(text)
        self.assertTrue(result.startswith(text))
        self.assertEqual(result.count('define i32 @main()'), 1)
        self.assertIn('%value = call i32 @sollang_start()', result)
        self.assertIn('ret i32 %value', result)

    def test_dso_local_startup_and_idempotent_reuse(self):
        text = 'define dso_local i32 @sollang_start() {\n  ret i32 7\n}\n'
        result = allocation_failure_entrypoint(text)
        self.assertEqual(allocation_failure_entrypoint(result), result)

    def test_current_csharp_optimized_startup_is_adapted(self):
        text = 'define dso_local i32 @sollang_start() local_unnamed_addr {\n  ret i32 7\n}\n'
        result = allocation_failure_entrypoint(text)
        self.assertEqual(result.count('define i32 @main()'), 1)
        self.assertTrue(result.startswith(text))

    def test_missing_or_duplicate_entry_is_rejected(self):
        for text in ('', 'define void @sollang_start() {\n}\n',
                     'define i32 @main() {\n}\ndefine i32 @main() {\n}\n',
                     'define i32 @sollang_start() {\n}\ndefine dso_local i32 @sollang_start() {\n}\n'):
            with self.subTest(text=text):
                with self.assertRaisesRegex(ValueError, 'ALLOCATION_FAILURE_ENTRY_SHAPE'):
                    allocation_failure_entrypoint(text)


class AllocationFailureCallSelectionTests(unittest.TestCase):
    def test_constant_and_observed_dynamic_calls(self):
        self.assertEqual(allocation_failure_case_call({'allocationBytes': 12}),
                         'call ptr @sollang_alloc(i64 12)')
        call = 'call ptr @sollang_alloc(i64 %deque_grown_bytes49)'
        self.assertEqual(allocation_failure_case_call({'allocationCall': call}), call)

    def test_ambiguous_invalid_or_other_callee_is_rejected(self):
        for case in ({}, {'allocationBytes': 0}, {'allocationBytes': True},
                     {'allocationBytes': 12, 'allocationCall': 'call ptr @sollang_alloc(i64 12)'},
                     {'allocationCall': 'call ptr @malloc(i64 12)'},
                     {'allocationCall': 'call ptr @sollang_alloc(i32 12)'},
                     {'allocationCall': 'call ptr @sollang_alloc(i64 %size)\nret void'}):
            with self.subTest(case=case):
                with self.assertRaisesRegex(ValueError, 'ALLOCATION_FAILURE_CASE_CALL_INVALID'):
                    allocation_failure_case_call(case)


class AllocationFailureDeclaredSiteTests(unittest.TestCase):
    def test_selects_source_function_without_backend_value_numbers(self):
        case = {'allocationSite': {'functionSymbol': 'sollang_start', 'index': 1, 'count': 2}}
        text = ('define i32 @sollang_start() {\n'
                '  %first = call ptr @sollang_alloc(i64 12)\n'
                '  %second = call ptr @sollang_alloc(i64 %grown_bytes)\n}\n')
        self.assertIsNone(allocation_failure_case_call(case))
        self.assertEqual(allocation_failure_case_call(case, text),
                         'call ptr @sollang_alloc(i64 %grown_bytes)')
        self.assertEqual(allocation_failure_case_call(case, text.replace('%second', '%v492')),
                         'call ptr @sollang_alloc(i64 %grown_bytes)')

    def test_changed_count_duplicate_function_and_missing_owner_are_rejected(self):
        case = {'allocationSite': {'functionSymbol': 'sollang_start', 'index': 0, 'count': 1}}
        body = 'define i32 @sollang_start() {\n  %x = call ptr @sollang_alloc(i64 12)\n}\n'
        for text, code in (('', 'FUNCTION_NOT_UNIQUE'), (body + body, 'FUNCTION_NOT_UNIQUE'),
                           (body.replace('  %x = call ptr @sollang_alloc(i64 12)', ''), 'COUNT_MISMATCH')):
            with self.subTest(text=text):
                with self.assertRaisesRegex(ValueError, code):
                    allocation_failure_case_call(case, text)

    def test_invalid_or_ambiguous_site_is_rejected(self):
        for site in ({'functionSymbol': 'x', 'index': True, 'count': 1},
                     {'functionSymbol': 'x', 'index': 1, 'count': 1},
                     {'functionSymbol': 'x\ny', 'index': 0, 'count': 1}):
            with self.subTest(site=site):
                with self.assertRaisesRegex(ValueError, 'CASE_CALL_INVALID'):
                    allocation_failure_case_call({'allocationSite': site})


class AllocationFailureDiagnosticSiteTests(unittest.TestCase):
    def test_identical_diagnostic_text_binds_to_selected_call(self):
        text = ('@first = private constant [22 x i8] c"main:allocation_failed"\n'
                '@selected = private constant [22 x i8] c"main:allocation_failed"\n'
                'define i32 @sollang_start() {\nentry:\n'
                '  %data = call ptr @sollang_alloc(i64 %grown_bytes)\n'
                '  %ok = icmp ne ptr %data, null\n'
                '  br i1 %ok, label %ready, label %failed\nfailed:\n'
                '  call void @sollang_runtime_eprint(ptr @selected, i64 22, i1 false)\n'
                '  call void @llvm.trap()\n  unreachable\nready:\n  ret i32 0\n}\n')
        observe = lambda value: allocation_failure_call_binding(
            value, 'call ptr @sollang_alloc(i64 %grown_bytes)', 'main', diagnostic_code='allocation_failed')
        binding = observe(text)
        self.assertEqual(text[binding['diagnosticStart']:binding['diagnosticEnd']], 'main:allocation_failed')
        self.assertGreater(binding['diagnosticStart'], text.index('@selected'))
        # Altering an unrelated identical literal must preserve this site's result.
        observe(text.replace('main:allocation_failed', 'Xain:allocation_failed', 1))
        bad = text[:binding['diagnosticStart']] + 'X' + text[binding['diagnosticStart']:]
        with self.assertRaisesRegex(ValueError, 'DIAGNOSTIC_OWNER_MISMATCH'):
            observe(bad)


if __name__ == '__main__':
    unittest.main()
