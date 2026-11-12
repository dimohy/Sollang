"""Exercise trap instrumentation through PowerShell and the pinned LLVM assembler."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/instrument-llvm-traps.ps1'
ASSEMBLER = ROOT / '.tools/llvm-22.1.8/bin/llvm-as.exe'


class TrapInstrumentationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(
            prefix='trap-instrumentation-', dir=ROOT / 'artifacts/scratch')
        self.directory = Path(self.temp.name).resolve()
        self.assertTrue(self.directory.is_relative_to(ROOT / 'artifacts/scratch'))
        self.source = self.directory / 'input.ll'
        self.output = self.directory / 'instrumented.ll'

    def tearDown(self):
        if not self.directory.is_relative_to(ROOT / 'artifacts/scratch'):
            raise AssertionError('fixture cleanup escaped its workspace')
        self.temp.cleanup()

    def write(self, declaration='', trap=True):
        self.source.write_text(
            'target triple = "x86_64-pc-windows-msvc"\n'
            'declare void @llvm.trap()\n' + declaration + '\n'
            'define i32 @main() {\nentry:\n' +
            ('  call void @llvm.trap()\n  unreachable\n' if trap else '  ret i32 0\n') +
            '}\n', encoding='utf-8')

    def instrument(self, output=None):
        return subprocess.run(
            ['pwsh', '-NoProfile', '-File', str(SCRIPT), '-InputPath',
             str(self.source), '-OutputPath', str(output or self.output)],
            capture_output=True, text=True, encoding='utf-8', timeout=30)

    def assert_assembles(self):
        result = self.instrument()
        self.assertEqual(result.returncode, 0, result.stderr)
        assembled = subprocess.run(
            [str(ASSEMBLER), str(self.output), '-o', str(self.directory / 'output.bc')],
            capture_output=True, text=True, encoding='utf-8', timeout=30)
        self.assertEqual(assembled.returncode, 0, assembled.stderr)
        self.assertIn('call void @ExitProcess(i32 1)', self.output.read_text(encoding='utf-8'))

    def test_adds_missing_exit_declaration(self):
        self.write()
        self.assert_assembles()

    def test_reuses_existing_runtime_declaration(self):
        self.write('declare dllimport void @ExitProcess(i32)')
        self.assert_assembles()

    def test_rejects_incompatible_signature_before_output(self):
        self.write('declare i32 @ExitProcess(i32)')
        original = self.source.read_bytes()
        self.assertNotEqual(self.instrument().returncode, 0)
        self.assertFalse(self.output.exists())
        self.assertEqual(self.source.read_bytes(), original)

    def test_rejects_same_path_without_modifying_input(self):
        self.write()
        original = self.source.read_bytes()
        self.assertNotEqual(self.instrument(self.source).returncode, 0)
        self.assertEqual(self.source.read_bytes(), original)

    @unittest.skipUnless(os.name == 'nt', 'Windows path identity')
    def test_rejects_windows_case_alias_without_modifying_input(self):
        self.write()
        original = self.source.read_bytes()
        self.assertNotEqual(self.instrument(Path(str(self.source).upper())).returncode, 0)
        self.assertEqual(self.source.read_bytes(), original)

    def test_rejects_missing_trap_before_output(self):
        self.write(trap=False)
        self.assertNotEqual(self.instrument().returncode, 0)
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
