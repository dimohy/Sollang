"""Exercise focused output supervision without deleting live verification products."""
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from focused_verification_output import VerificationOutput
from completed_artifact_plan import initialize_output

ROOT = Path(__file__).resolve().parents[1]


class FocusedOutputTests(unittest.TestCase):
    def setUp(self):
        self.parent = Path(tempfile.mkdtemp(prefix='focused-supervision-control-', dir=ROOT / 'artifacts/scratch'))
        self.source = self.parent / 'input.txt'
        self.source.write_text('frozen input')
        self.output = self.parent / 'output'
        self.record = {'total': 1, 'cases': [{'status': 'running', 'passed': False}]}

    def read(self):
        return json.loads((self.output / 'result.json').read_text())

    def session(self, timeout=10):
        return VerificationOutput(ROOT, self.output, [self.source], self.record,
                                  cleanup_mode='plan-only', timeout_seconds=timeout)

    def test_completed_records_saved_before_cleanup(self):
        def cleanup(repo, output, execute):
            result = self.read()
            self.assertEqual('passed', result['status'])
            self.assertTrue(result['processesStopped'])
            self.assertTrue(result['inputsStable'])
            self.assertFalse(execute)
        with patch('focused_verification_output.cleanup_output', side_effect=cleanup) as call:
            with self.session() as execution:
                code = execution.run([sys.executable, '-c', 'print("ok")'], self.output/'stdout.log', self.output/'stderr.log')
                self.assertEqual(0, code)
                self.record['cases'][0].update(status='passed', passed=True)
            self.assertEqual(1, call.call_count)

    @unittest.skipUnless(os.name == 'nt', 'Windows delete-sharing contract')
    def test_brief_progress_reader_lock_does_not_repeat_verification(self):
        import ctypes
        from ctypes import wintypes
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                   wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        api.CreateFileW.restype = wintypes.HANDLE
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        with patch('focused_verification_output.cleanup_output'):
            with self.session() as execution:
                code = execution.run([sys.executable, '-c', 'print("once")'],
                                     self.output/'stdout.log', self.output/'stderr.log')
                self.assertEqual(0, code)
                self.record['cases'][0].update(status='passed', passed=True)
                handle = api.CreateFileW(str(self.output/'result.json'), 0x80000000, 3, None, 3, 0, None)
                self.assertNotEqual(handle, ctypes.c_void_p(-1).value)
                release = threading.Timer(0.05, api.CloseHandle, args=(handle,))
                release.start()
                try:
                    execution.save()
                finally:
                    release.join()
        result = self.read()
        self.assertEqual('passed', result['status'])
        self.assertEqual(1, len(result['processes']))
        self.assertEqual('once\n', (self.output/'stdout.log').read_text())
        self.assertFalse(list(self.output.glob('*.tmp')))

    def test_expected_compile_failure_preserved(self):
        with patch('focused_verification_output.cleanup_output') as call:
            with self.session() as execution:
                code = execution.run([sys.executable, '-c', 'raise SystemExit(1)'], self.output/'stdout.log', self.output/'stderr.log')
                self.record['cases'][0].update(status='passed', passed=True, buildExit=code, expectedBuildExit=1)
            call.assert_called_once()
        self.assertEqual(1, self.read()['cases'][0]['buildExit'])
        self.assertEqual('passed', self.read()['status'])

    def test_failed_output_never_cleaned(self):
        with patch('focused_verification_output.cleanup_output') as call:
            with self.assertRaisesRegex(ValueError, 'failure'):
                with self.session():
                    raise ValueError('failure')
            call.assert_not_called()
        self.assertEqual('failed', self.read()['status'])

    def test_cancelled_output_never_cleaned(self):
        with patch('focused_verification_output.cleanup_output') as call:
            with self.assertRaises(KeyboardInterrupt):
                with self.session():
                    raise KeyboardInterrupt()
            call.assert_not_called()
        self.assertEqual('canceled', self.read()['status'])

    def test_timeout_process_stopped(self):
        with patch('focused_verification_output.cleanup_output') as call:
            with self.assertRaises(subprocess.TimeoutExpired):
                with self.session(.1) as execution:
                    execution.run([sys.executable, '-c', 'import time; time.sleep(30)'], self.output/'stdout.log', self.output/'stderr.log')
            call.assert_not_called()
        self.assertEqual('timed-out', self.read()['status'])
        self.assertTrue(self.read()['processesStopped'])

    def test_active_process_blocks_completion(self):
        with patch('focused_verification_output.cleanup_output') as call:
            with self.session():
                self.record['cases'][0].update(status='passed', passed=True)
                self.record['activeProcess'] = {'pid': 123}
            call.assert_not_called()
        self.assertEqual('failed', self.read()['status'])

    def test_input_change_blocks_cleanup(self):
        with patch('focused_verification_output.cleanup_output') as call:
            with self.session():
                self.record['cases'][0].update(status='passed', passed=True)
                self.source.write_text('changed')
            call.assert_not_called()
        self.assertFalse(self.read()['inputsStable'])

    def test_existing_output_is_rejected(self):
        with patch('focused_verification_output.cleanup_output'):
            with self.session():
                pass
        with self.assertRaises(FileExistsError):
            self.session()

    def test_path_escape_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'OUTSIDE_ROOT'):
            initialize_output(ROOT, ROOT / 'outside-owned-output')


if __name__ == '__main__':
    unittest.main()
