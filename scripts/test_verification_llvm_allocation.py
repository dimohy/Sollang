"""Entry adapter controls for actual CSharp and Native allocation fault probes."""
import unittest
from verification_llvm_allocation import allocation_failure_entrypoint


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


if __name__ == '__main__':
    unittest.main()
