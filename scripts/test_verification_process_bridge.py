"""Exercise the real shared supervisor used by the PowerShell matrix."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class ProcessBridgeTests(unittest.TestCase):
    def execute(self, code, timeout=5):
        temporary = tempfile.TemporaryDirectory(prefix='sollang-process-bridge-')
        self.addCleanup(temporary.cleanup)
        repo = Path(temporary.name)
        (repo / 'artifacts/scratch').mkdir(parents=True)
        output = repo / 'artifacts/scratch/observed'
        bridge = Path(__file__).with_name('verification_process_bridge.py')
        result = subprocess.run([sys.executable, str(bridge), '--repo', str(repo),
            '--output', str(output), '--timeout-seconds', str(timeout), '--',
            sys.executable, '-X', 'utf8', '-c', code], capture_output=True, timeout=15)
        return result, json.loads((output / 'result.json').read_text(encoding='utf-8')), output

    def test_raw_unicode_output_and_confirmed_shutdown(self):
        observed, record, output = self.execute("print('한글😀')")
        self.assertEqual(0, observed.returncode, observed.stderr)
        self.assertEqual(0, record['programExit'])
        self.assertTrue(record['processesStopped'])
        self.assertEqual('한글😀\n', (output / 'command.stdout').read_text(encoding='utf-8'))
        self.assertFalse(record['claimsTestPassed'])

    def test_nonzero_exit_is_an_observation_and_keeps_its_actual_code(self):
        observed, record, _ = self.execute('raise SystemExit(7)')
        self.assertEqual(0, observed.returncode, observed.stderr)
        self.assertEqual(7, record['programExit'])
        self.assertEqual('observed-not-qualified', record['status'])
        self.assertFalse(record['claimsTestPassed'])

    def test_timeout_cannot_be_reported_as_an_observed_completion(self):
        observed, record, _ = self.execute('import time;time.sleep(60)', timeout=.2)
        self.assertNotEqual(0, observed.returncode)
        self.assertEqual('timed-out', record['status'])
        self.assertTrue(record['processesStopped'])
        self.assertNotIn('programExit', record)

    @unittest.skipUnless(os.name == 'nt', 'Windows owned-job behavior')
    def test_live_descendant_fails_instead_of_being_hidden_by_parent_exit(self):
        observed, record, _ = self.execute(
            "import subprocess,sys;subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)'])")
        self.assertNotEqual(0, observed.returncode)
        self.assertEqual('failed', record['status'])
        self.assertEqual('live-descendant', record['processes'][0]['naturalShutdownObservation']['outcome'])
        self.assertTrue(record['processesStopped'])  # failed tree was then terminated
        self.assertNotIn('programExit', record)


if __name__ == '__main__':
    unittest.main()
