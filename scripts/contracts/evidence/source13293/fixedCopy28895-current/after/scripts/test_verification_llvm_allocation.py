"""Entry adapter controls for actual CSharp and Native allocation fault probes."""
import unittest
from verification_llvm_allocation import (allocation_failure_entrypoint, allocation_failure_case_call,
    allocation_failure_call_binding, instrument_owned_allocation_audit, task_start_failure_trace)


class TaskStartFailureAuditTests(unittest.TestCase):
    source = ('define internal ptr @sollang_task_start(ptr %w, ptr %d, ptr %c, ptr %x) #0 {\n'
              '  ret ptr null\n}\n'
              'define i32 @sollang_start() {\n'
              '  %p = call ptr @sollang_alloc(i64 72)\n'
              '  %h = call ptr @sollang_task_start(ptr null, ptr @sollang_free, ptr null, ptr %p)\n'
              '  call void @sollang_free(ptr %p)\n  ret i32 0\n}\n')

    def test_normal_audit_keeps_real_task_start_and_tracks_callback_frees(self):
        result = instrument_owned_allocation_audit(self.source)
        self.assertIn('call ptr @sollang_task_start(', result)
        self.assertNotIn('audit_task_start_fail', result)
        self.assertIn('ptr @audit_free,', result)
        self.assertIn('call void @audit_free(ptr %p)', result)

    def test_failure_mode_replaces_call_without_erasing_cleanup(self):
        result = instrument_owned_allocation_audit(self.source, task_start_failure=True)
        self.assertIn('define internal ptr @sollang_task_start(', result)
        self.assertIn('call ptr @audit_task_start_fail(', result)
        self.assertIn('call void @audit_free(ptr %p)', result)
        self.assertEqual(result.count('define i32 @slg_program_main()'), 1)

    def test_changed_signature_and_missing_call_fail_before_link(self):
        for text, error in [(self.source.replace(', ptr %x)', ')'), 'SIGNATURE_CHANGED'),
                            (self.source.replace('call ptr @sollang_task_start', 'call ptr @other'), 'CALL_MISSING')]:
            with self.subTest(error=error):
                with self.assertRaisesRegex(ValueError, error):
                    instrument_owned_allocation_audit(text, task_start_failure=True)

    def test_exact_release_trace_and_invalid_expected_counts(self):
        self.assertEqual(task_start_failure_trace(2), 'task-start-failure:live=2\n'
                         'task-start-release:released=1,live=1\n'
                         'task-start-release:released=2,live=0\n')
        for count in [0, -1, True, '2']:
            with self.assertRaisesRegex(ValueError, 'LIVE_COUNT_INVALID'):
                task_start_failure_trace(count)

    def test_ambiguous_entry_cannot_be_silently_selected(self):
        with self.assertRaisesRegex(ValueError, 'ENTRY_SHAPE'):
            instrument_owned_allocation_audit(self.source + 'define i32 @main() {\n}\n')


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


class AllocationFailureScopedSiteTests(unittest.TestCase):
    literal = '@diagnostic = private constant [22 x i8] c"main:allocation_failed"\n'

    @staticmethod
    def function(name, guarded=True):
        body = ('  %p = call ptr @sollang_alloc(i64 8)\n'
                '  %ok = icmp ne ptr %p, null\n'
                '  br i1 %ok, label %ready, label %failed\nfailed:\n'
                '  call void @sollang_runtime_eprint(ptr @diagnostic, i64 22, i1 false)\n'
                '  call void @llvm.trap()\n  unreachable\nready:\n  ret i32 0\n')
        if not guarded:
            body = '  %p = call ptr @sollang_alloc(i64 8)\n  ret i32 0\n'
        return 'define i32 @' + name + '() {\nentry:\n' + body + '}\n'

    def test_equal_calls_in_other_functions_do_not_change_selected_guard_or_injection(self):
        text = self.literal + self.function('first', False) + self.function('second')
        needle = 'call ptr @sollang_alloc(i64 8)'
        with self.assertRaisesRegex(ValueError, 'CALL_NOT_UNIQUE'):
            allocation_failure_call_binding(text, needle, 'main', diagnostic_code='allocation_failed')
        site = dict(functionSymbol='second', index=0, count=1)
        binding = allocation_failure_call_binding(text, needle, 'main',
            diagnostic_code='allocation_failed', allocation_site=site)
        self.assertGreater(binding['callStart'], text.index('define i32 @second'))
        changed = text[:binding['callStart']] + needle.replace('@sollang_alloc', '@fail') + text[binding['callEnd']:]
        self.assertEqual(changed.count('call ptr @fail(i64 8)'), 1)
        self.assertIn('call ptr @sollang_alloc(i64 8)', changed[:changed.index('define i32 @second')])
        with self.assertRaisesRegex(ValueError, 'GUARD_MISSING_BEFORE_USE'):
            allocation_failure_call_binding(text, needle, 'main', diagnostic_code='allocation_failed',
                allocation_site=dict(functionSymbol='first', index=0, count=1))

    def test_equal_calls_inside_one_function_keep_the_declared_ordinal(self):
        first = self.function('same').replace('%p', '%first').replace('%ok', '%first_ok')
        first = first.replace('ret i32 0\n}', 'SECOND\n}')
        second = self.function('unused').split('entry:\n', 1)[1].rsplit('}', 1)[0]
        second = second.replace('%p', '%second').replace('%ok', '%second_ok')
        second = second.replace('ready', 'ready2').replace('failed', 'failed2')
        # Preserve the diagnostic code while giving only the blocks distinct names.
        second = second.replace('allocation_failed2', 'allocation_failed')
        text = self.literal + first.replace('SECOND', second)
        needle = 'call ptr @sollang_alloc(i64 8)'
        site = dict(functionSymbol='same', index=1, count=2)
        self.assertEqual(allocation_failure_case_call(dict(allocationSite=site), text), needle)
        binding = allocation_failure_call_binding(text, needle, 'main',
            diagnostic_code='allocation_failed', allocation_site=site)
        self.assertEqual(binding['allocationPointer'], '%second')
        changed = text[:binding['callStart']] + needle.replace('@sollang_alloc', '@fail') + text[binding['callEnd']:]
        self.assertIn('%first = call ptr @sollang_alloc(i64 8)', changed)
        self.assertIn('%second = call ptr @fail(i64 8)', changed)
        bad = text.replace('%second_ok = icmp ne ptr %second, null', '%second_ok = icmp ne ptr %first, null')
        with self.assertRaisesRegex(ValueError, 'GUARD_MISSING_BEFORE_USE'):
            allocation_failure_call_binding(bad, needle, 'main', diagnostic_code='allocation_failed', allocation_site=site)

    def test_count_and_selected_instruction_must_match(self):
        text = self.literal + self.function('one')
        with self.assertRaisesRegex(ValueError, 'SITE_COUNT_MISMATCH'):
            allocation_failure_case_call(dict(allocationSite=dict(functionSymbol='one', index=0, count=2)), text)
        with self.assertRaisesRegex(ValueError, 'SITE_CALL_MISMATCH'):
            allocation_failure_call_binding(text, 'call ptr @sollang_alloc(i64 9)', 'main',
                diagnostic_code='allocation_failed', allocation_site=dict(functionSymbol='one', index=0, count=1))


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
