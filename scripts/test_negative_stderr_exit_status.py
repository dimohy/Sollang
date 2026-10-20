"""An exact-diagnostic mismatch must block the next expensive pipeline step."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/verify-compiler-negative-stderr-exact.ps1'


class ExactDiagnosticExitTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(
            prefix='negative-exact-exit-', dir=ROOT / 'artifacts/scratch')
        self.directory = Path(self.temporary.name).resolve()
        self.assertTrue(self.directory.is_relative_to(ROOT / 'artifacts/scratch'))
        self.addCleanup(self.temporary.cleanup)
        self.record = dict(gate='compiler-parity-negative-fixture', state='passed',
                           inputsStable=True,
                           managed=dict(nonzeroExit=True, noEmittedProducts=True),
                           selfhost=dict(nonzeroExit=True, noEmittedProducts=True))
        # Hashed stand-ins exercise reporting only; these files are never run.
        for path_key, hash_key in [('source', 'sourceSha256'), ('expected', 'expectedSha256'),
                                   ('managedCompilerPath', 'managedCompilerSha256'),
                                   ('selfhostCompilerPath', 'selfhostCompilerSha256')]:
            path = self.directory / path_key
            path.write_bytes(path_key.encode())
            self.record[path_key] = str(path)
            self.record[hash_key] = hashlib.sha256(path.read_bytes()).hexdigest().upper()

    def invoke(self, managed, native):
        left, right = self.directory/'managed.txt', self.directory/'native.txt'
        left.write_bytes(managed)
        right.write_bytes(native)
        self.record['logs'] = dict(managedStderr=str(left), selfhostStderr=str(right))
        input_path, output = self.directory/'input.json', self.directory/'output.json'
        input_path.write_text(json.dumps(self.record), encoding='utf-8')
        process = subprocess.run(['pwsh', '-NoProfile', '-File', str(SCRIPT),
                                  '-Receipt', str(input_path), '-OutputPath', str(output)],
                                 cwd=ROOT, capture_output=True, timeout=30)
        return process, output

    def test_normal_line_endings_pass(self):
        process, output = self.invoke(b'error\r\n', b'error\n')
        self.assertEqual(0, process.returncode)
        self.assertEqual('passed', json.loads(output.read_text())['status'])

    def test_mismatch_blocks_next_step_and_preserves_report(self):
        process, output = self.invoke(b'error at 3:5\n', b'error at 1:1\n')
        next_step = self.directory/'next-step'
        if process.returncode == 0:
            next_step.touch()
        self.assertFalse(next_step.exists())
        self.assertEqual(1, process.returncode)
        report = json.loads(output.read_text())
        self.assertEqual(('mismatched', 0, 1),
                         (report['status'], report['completed'], report['total']))

    def test_failed_pair_cannot_become_exact_success(self):
        self.record['state'] = 'failed'
        process, output = self.invoke(b'error\n', b'error\n')
        self.assertNotEqual(0, process.returncode)
        self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
