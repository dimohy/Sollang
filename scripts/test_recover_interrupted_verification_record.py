"""Recovery must distinguish drained PID reuse from a live consumer."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('recover_record', Path(__file__).with_name('recover-interrupted-verification-record.py'))
recover = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recover)


class RecoveryIdentityTests(unittest.TestCase):
    def exercise(self, *, active_pid=None, output_consumer=False, drained=True):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        folder = root / 'artifacts' / 'interrupted'
        folder.mkdir(parents=True)
        source = root / 'source.slg'
        source.write_text('main {}', encoding='utf-8')
        original = dict(status='running', completed=1, total=2,
                        cases=[dict(status='passed', passed=True), dict(status='running', passed=False)],
                        inputHashes={str(source): recover.hashlib.sha256(source.read_bytes()).hexdigest()},
                        processes=[dict(pid=101, exit=0, shutdownConfirmed=drained), dict(pid=202)])
        target = folder / 'result.json'
        raw = json.dumps(original).encode()
        target.write_bytes(raw)

        def probe(command, **kwargs):
            text = command[-1]
            owned = re.search(r'\$owned = @\(([^)]*)\)', text).group(1)
            selected = [int(value) for value in owned.split(',') if value]
            self.assertIn('CommandLine.Contains', text)
            live = [active_pid] if output_consumer or active_pid in selected else []
            return subprocess.CompletedProcess(command, 0, json.dumps(live), '')

        with patch.object(recover, 'ROOT', root), patch.object(recover.subprocess, 'run', side_effect=probe), \
                patch.object(sys, 'argv', ['recover', '--result', str(target), '--reason', 'observed interruption']):
            if output_consumer or active_pid == 202 or active_pid == 101 and not drained:
                with self.assertRaisesRegex(ValueError, 'PROCESSES_STILL_ACTIVE'):
                    recover.main()
                self.assertEqual(target.read_bytes(), raw)
                self.assertFalse(target.with_name('interrupt-shutdown-result.json').exists())
            else:
                recover.main()
                result = json.loads(target.read_text())
                self.assertEqual(result['status'], 'canceled')
                self.assertEqual(result['completed'], 1)
                self.assertEqual(result['cases'][-1]['status'], 'canceled')
                self.assertNotIn('exit', result['processes'][-1])
                self.assertEqual(target.with_name('interrupted-running-result.json').read_bytes(), raw)

    def test_drained_pid_reused_by_unrelated_process(self):
        self.exercise(active_pid=101)

    def test_live_pending_identity_blocks_recovery(self):
        self.exercise(active_pid=202)

    def test_output_consumer_with_other_pid_blocks_recovery(self):
        self.exercise(active_pid=303, output_consumer=True)

    def test_exit_without_shutdown_confirmation_stays_pending(self):
        self.exercise(active_pid=101, drained=False)


if __name__ == '__main__':
    unittest.main()
