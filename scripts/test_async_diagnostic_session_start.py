import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).with_name('verify-async-diagnostic-session-start.py')
spec = importlib.util.spec_from_file_location('async_start', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ApprovedStartPreflightTests(unittest.TestCase):
    def test_actual_single_allocator_abi_and_missing_or_ambiguous_rejection(self):
        for allocator in ['malloc', 'sollang_alloc']:
            self.assertEqual(module.instrument_start_allocator('call ptr @' + allocator + '(i64 48)'),
                             'call ptr @diagnostic_test_alloc(i64 48)')
        for body in ['', 'call ptr @malloc(i64 48)\ncall ptr @sollang_alloc(i64 48)']:
            with self.assertRaisesRegex(ValueError, 'ALLOCATOR_HOOK_SHAPE'):
                module.instrument_start_allocator(body)

    def test_current_manifest_closure_and_old_missing_reordered_rejected(self):
        manifest = module.ROOT / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
        canonical = [(module.ROOT / line.strip()).resolve() for line in
                     manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
        current = [Path('original-probe.slg'), *canonical[1:]]
        module.validate_source_closure(current, canonical)
        for bad in [current[:151], current[:-1], [current[0], *reversed(current[1:])],
                    [*current[:-1], current[1]], []]:
            with self.subTest(size=len(bad)), self.assertRaisesRegex(ValueError, 'CANONICAL_SOURCE_CLOSURE'):
                module.validate_source_closure(bad, canonical)

    def test_whole_case_deadline_blocks_expired_steps(self):
        self.assertEqual(module.remaining_case_seconds(10, 10), 180)
        self.assertEqual(module.remaining_case_seconds(10, 189), 1)
        for now in [190, 191, 9]:
            with self.subTest(now=now), self.assertRaisesRegex(ValueError, 'CASE_BUDGET_EXHAUSTED'):
                module.remaining_case_seconds(10, now)


if __name__ == '__main__':
    unittest.main()
