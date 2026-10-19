import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from verification_llvm_call_trace import instrument


SOURCE = """define internal void @sollang_runtime_eprint(ptr %data, i64 %length, i1 %newline) {
entry:
  ret void
}
define void @sollang_m1_s0() {
entry:
  call void @sollang_m1_s1()
  ret void
}
define void @sollang_m1_s1() {
entry:
  call void @sollang_m2_s0()
  ret void
}
define void @sollang_m2_s0() {
entry:
  call void @sollang_m2_s1()
  ret void
}
"""


class CallTraceTests(unittest.TestCase):
    @unittest.skipUnless(os.name == 'nt', 'Windows trace writer ABI')
    def test_sparse_runtime_observes_later_visits_and_preserves_record_bound(self):
        clang = Path(__file__).resolve().parents[1] / '.tools/llvm-22.1.8/bin/clang.exe'
        self.assertTrue(clang.is_file())
        source = '''declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare dllimport void @ExitProcess(i32)
define void @sollang_fn_root() {
entry:
  call void @sollang_fn_child()
  ret void
}
define void @sollang_fn_child() {
entry:
  ret void
}
define void @sollang_start() {
entry:
  call void @sollang_fn_child()
ROOT_CALLS
  call void @ExitProcess(i32 0)
  unreachable
}
'''.replace('ROOT_CALLS', '\n'.join(['  call void @sollang_fn_root()'] * 17))
        with tempfile.TemporaryDirectory(prefix='sollang-trace-sparse-') as directory:
            for limit, expected_lines in [(64, 15), (4, 4)]:
                text, _, markers = instrument(source, 'sollang_fn_root', 0, limit,
                    abi='managed-windows', power_of_two_visits=True)
                ir, binary = Path(directory) / f'probe{limit}.ll', Path(directory) / f'probe{limit}.exe'
                ir.write_text(text, encoding='utf-8')
                built = subprocess.run([str(clang), '-target', 'x86_64-pc-windows-msvc',
                    '-Werror', '-Wno-override-module', str(ir), '-o', str(binary),
                    '-lkernel32', '-lucrt', '-Xlinker', '/entry:sollang_start',
                    '-Xlinker', '/subsystem:console'], capture_output=True, text=True, timeout=15)
                self.assertEqual(built.returncode, 0, built.stderr)
                run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                lines = run.stderr.splitlines()
                self.assertEqual(len(lines), expected_lines)
                if limit == 64:
                    for marker in markers:
                        self.assertEqual(lines.count(marker['label']), 5)

    def test_sparse_mode_rejects_ambiguous_flags_and_unbounded_records(self):
        for options in [{'power_of_two_visits': 'true'},
                        {'power_of_two_visits': True, 'first_visit_only': True}]:
            with self.assertRaisesRegex(ValueError, 'SPARSE_VISIT_MODE_INVALID'):
                instrument(SOURCE, 'sollang_m1_s0', 0, 16, **options)
        with self.assertRaisesRegex(ValueError, 'BOUND_INVALID'):
            instrument(SOURCE, 'sollang_m1_s0', 0, 8193, power_of_two_visits=True)

    def test_phase_boundaries_preserve_original_calls_and_returns(self):
        text, owners, markers = instrument(SOURCE, 'sollang_m1_s0', 1, 16,
            first_visit_only=True, phase_boundaries_only=True)
        self.assertEqual(len(markers), 4)
        self.assertTrue(all(':enter:' in m['label'] or ':exit:' in m['label'] for m in markers))
        self.assertEqual(text.count('call void @sollang_m1_s1()'), 1)
        self.assertEqual(text.count('call void @sollang_m2_s0()'), 1)
        with self.assertRaisesRegex(ValueError, 'PHASE_MODE_INVALID'):
            instrument(SOURCE, 'sollang_m1_s0', 0, 16,
                power_of_two_visits=True, phase_boundaries_only=True)


    @unittest.skipUnless(os.name == 'nt', 'Windows trace writer ABI')
    def test_first_visit_runtime_ignores_inactive_calls_and_deduplicates_repeats(self):
        clang = Path(__file__).resolve().parents[1] / '.tools/llvm-22.1.8/bin/clang.exe'
        self.assertTrue(clang.is_file(), 'Pinned project LLVM toolchain is required')
        source = '''declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare dllimport void @ExitProcess(i32)
define void @sollang_fn_root() {
entry:
  call void @sollang_fn_child()
  ret void
}
define void @sollang_fn_child() {
entry:
  call void @sollang_fn_leaf()
  ret void
}
define void @sollang_fn_leaf() {
entry:
  ret void
}
define void @sollang_start() {
entry:
  call void @sollang_fn_child()
  call void @sollang_fn_root()
  call void @sollang_fn_root()
  call void @sollang_fn_root()
  call void @ExitProcess(i32 0)
  unreachable
}
'''
        text, _, markers = instrument(source, 'sollang_fn_root', 1, 5,
            abi='managed-windows', first_visit_only=True)
        with tempfile.TemporaryDirectory(prefix='sollang-trace-first-visit-') as directory:
            ir = Path(directory) / 'probe.ll'
            binary = Path(directory) / 'probe.exe'
            ir.write_text(text, encoding='utf-8')
            built = subprocess.run([str(clang), '-target', 'x86_64-pc-windows-msvc',
                '-Werror', '-Wno-override-module', str(ir), '-o', str(binary),
                '-lkernel32', '-lucrt', '-Xlinker', '/entry:sollang_start',
                '-Xlinker', '/subsystem:console'], capture_output=True, text=True, timeout=15)
            self.assertEqual(built.returncode, 0, built.stderr)
            run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=5)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(run.stdout, '')
            self.assertCountEqual(run.stderr.splitlines(), [m['label'] for m in markers])
            phase_text, _, phase_markers = instrument(source, 'sollang_fn_root', 1, 16,
                abi='managed-windows', first_visit_only=True, phase_boundaries_only=True)
            ir.write_text(phase_text, encoding='utf-8')
            built = subprocess.run([str(clang), '-target', 'x86_64-pc-windows-msvc',
                '-Werror', '-Wno-override-module', str(ir), '-o', str(binary),
                '-lkernel32', '-lucrt', '-Xlinker', '/entry:sollang_start',
                '-Xlinker', '/subsystem:console'], capture_output=True, text=True, timeout=15)
            self.assertEqual(built.returncode, 0, built.stderr)
            run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=5)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertCountEqual(run.stderr.splitlines(), [m['label'] for m in phase_markers])

    def test_first_visit_preserves_repeated_calls_with_distinct_static_sites(self):
        source = SOURCE.replace('  call void @sollang_m1_s1()',
                                '  call void @sollang_m1_s1()\n  call void @sollang_m1_s1()')
        text, _, markers = instrument(source, 'sollang_m1_s0', 0, 5,
                                      first_visit_only=True)
        self.assertEqual(text.count('call void @sollang_m1_s1()'), 2)
        self.assertEqual(len(markers), 5)
        self.assertEqual(len({m['label'] for m in markers}), 5)
        self.assertIn('private global [5 x i1] zeroinitializer', text)
        self.assertIn('%enabled = and i1 %active, %unseen', text)
        self.assertIn('store i1 true, ptr %slot', text)

    def test_first_visit_rejects_insufficient_static_budget_and_invalid_mode(self):
        with self.assertRaisesRegex(ValueError, 'STATIC_BUDGET_REQUIRED'):
            instrument(SOURCE, 'sollang_m1_s0', 0, 2, first_visit_only=True)
        with self.assertRaisesRegex(ValueError, 'MODE_INVALID'):
            instrument(SOURCE, 'sollang_m1_s0', 0, 16, first_visit_only='true')

    def test_first_phase_and_deep_phase_share_one_activation_and_bound(self):
        text, owners, markers = instrument(SOURCE, "sollang_m1_s0", 0, 32,
            additional_roots=["sollang_m2_s0"])
        self.assertEqual(owners, ["sollang_m1_s0", "sollang_m2_s0"])
        self.assertEqual(text.count("store i1 true, ptr @sollang_observation_active"), 1)
        self.assertIn("before:sollang_m1_s0->sollang_m1_s1", [m["label"] for m in markers])
        self.assertIn("before:sollang_m2_s0->sollang_m2_s1", [m["label"] for m in markers])
        self.assertEqual(text.count("call void @sollang_m2_s1()"), 1)
        self.assertIn("icmp ult i32 %count, 32", text)

    def test_additional_roots_cannot_expand_to_invalid_functions(self):
        for extra in (["missing"], ["sollang_m1_s0"], ["sollang_m2_s0"] * 2,
                      ["sollang_runtime_eprint"], ["missing"] * 5, [None], [[]]):
            with self.subTest(extra=extra), self.assertRaisesRegex(ValueError, "ADDITIONAL_ROOTS_INVALID"):
                instrument(SOURCE, "sollang_m1_s0", 0, 32, additional_roots=extra)
        with self.assertRaisesRegex(ValueError, "ADDITIONAL_ROOTS_SCOPE_MISSING"):
            instrument(SOURCE, "sollang_m1_s0", 0, 32, "sollang_m1_",
                       additional_roots=["sollang_m2_s0"])

    def test_explicit_reachable_owners_preserve_cross_owner_boundaries(self):
        text, owners, markers = instrument(SOURCE, "sollang_m1_s0", 2, 32,
                                           observed_owners=["sollang_m1_s0", "sollang_m1_s1"])
        self.assertEqual(owners, ["sollang_m1_s0", "sollang_m1_s1"])
        self.assertIn("before:sollang_m1_s1->sollang_m2_s0", [row["label"] for row in markers])
        self.assertNotIn("before:sollang_m2_s0->sollang_m2_s1", text)
        self.assertEqual(text.count("call void @sollang_m2_s0()"), 1)

    def test_explicit_owner_scope_rejects_missing_root_or_unreachable_owner(self):
        for owners in (["sollang_m1_s1"], ["sollang_m1_s0", "sollang_m2_s1"], ["missing"]):
            with self.assertRaisesRegex(ValueError, "EXPLICIT_OWNERS_INVALID"):
                instrument(SOURCE, "sollang_m1_s0", 1, 32, observed_owners=owners)

    def test_explicit_callee_exclusion_preserves_call_and_other_boundaries(self):
        text, owners, markers = instrument(SOURCE, "sollang_m1_s0", 2, 32,
                                           excluded_callees=["sollang_m1_s1"])
        labels = [row["label"] for row in markers]
        self.assertEqual(text.count("call void @sollang_m1_s1()"), 1)
        self.assertNotIn("before:sollang_m1_s0->sollang_m1_s1", labels)
        self.assertIn("before:sollang_m1_s1->sollang_m2_s0", labels)
        for excluded in ("missing", "sollang_m1_s0"):
            with self.assertRaisesRegex(ValueError, "EXCLUDED_CALLEE_INVALID"):
                instrument(SOURCE, "sollang_m1_s0", 2, 32, excluded_callees=[excluded])

    def test_managed_windows_attributes_and_explicit_writer(self):
        source = '''declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
define void @sollang_fn_root() #0 {
entry:
  call void @sollang_fn_child()
  ret void
}
define void @sollang_fn_child() #0 {
entry:
  ret void
}
'''.replace('\n', '\r\n')
        text, owners, markers = instrument(source, 'sollang_fn_root', 1, 16, 'sollang_fn_', 'managed-windows')
        self.assertEqual(owners, ['sollang_fn_child', 'sollang_fn_root'])
        self.assertIn('call ptr @GetStdHandle(i32 -12)', text)
        self.assertIn('call i32 @WriteFile', text)
        self.assertNotIn('call void @sollang_runtime_eprint', text)
        self.assertEqual(text.count('call void @sollang_fn_child()'), 1)

    def test_managed_writer_abi_is_required_without_fallback(self):
        with self.assertRaisesRegex(ValueError, 'RUNTIME_INVALID'):
            instrument(SOURCE, 'sollang_m1_s0', 1, 16, '', 'managed-windows')
        with self.assertRaisesRegex(ValueError, 'ABI_INVALID'):
            instrument(SOURCE, 'sollang_m1_s0', 1, 16, '', 'automatic')

    def test_boundaries_preserve_original_call_and_keep_single_activation(self):
        text, owners, markers = instrument(SOURCE, "sollang_m1_s0", 2, 32)
        self.assertEqual(owners, ["sollang_m1_s0", "sollang_m1_s1", "sollang_m2_s0"])
        self.assertEqual(text.count("store i1 true, ptr @sollang_observation_active"), 1)
        self.assertEqual(text.count("call void @sollang_m1_s1()"), 1)
        self.assertIn("icmp ult i32 %count, 32", text)
        labels = [row["label"] for row in markers]
        self.assertLess(labels.index("before:sollang_m1_s0->sollang_m1_s1"),
                        labels.index("after:sollang_m1_s0->sollang_m1_s1"))

    def test_module_filter_excludes_hot_loop_owner_without_losing_boundary(self):
        text, owners, markers = instrument(SOURCE, "sollang_m1_s0", 2, 32, "sollang_m1_")
        self.assertEqual(owners, ["sollang_m1_s0", "sollang_m1_s1"])
        self.assertIn("before:sollang_m1_s1->sollang_m2_s0", [row["label"] for row in markers])
        self.assertNotIn("before:sollang_m2_s0->sollang_m2_s1", text)

    def test_invalid_observation_contracts_fail_before_emission(self):
        cases = [
            (SOURCE, "missing", 2, 32, ""),
            (SOURCE, "sollang_m1_s0", 5, 32, ""),
            (SOURCE, "sollang_m1_s0", 2, 0, ""),
            (SOURCE, "sollang_m1_s0", 2, 32, "sollang_m2_"),
            (SOURCE.replace("sollang_runtime_eprint", "missing_runtime"), "sollang_m1_s0", 2, 32, ""),
            (SOURCE + SOURCE, "sollang_m1_s0", 2, 32, ""),
        ]
        for arguments in cases:
            with self.subTest(arguments=arguments[1:]):
                with self.assertRaises(ValueError):
                    instrument(*arguments)


if __name__ == "__main__":
    unittest.main()
