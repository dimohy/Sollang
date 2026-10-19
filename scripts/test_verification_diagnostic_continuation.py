import json
from pathlib import Path
import tempfile
import unittest
from verification_diagnostic_continuation import ROOT, check_c527_plan, ref, whole_input_history


class ContinuationTests(unittest.TestCase):
    def test_real_history_blocks_another_whole_input_observation(self):
        history = whole_input_history()
        self.assertGreater(len(history), 0)
        audit = ROOT / 'artifacts/scratch/resume-rootfc1a-c527-diagnostic-reuse-source-audit-20261003-01.json'
        evidence = ref(audit)
        command = ['diagnostic-worker.exe', 'original-input']
        plan = dict(ruleId='AS-DC-001', purpose='diagnostic', completionMode='diagnostic-only',
                    mode='whole-input', authorizedScope='project', requestedScope='project',
                    inputFingerprint='a'*64, acceptance=dict(inputFingerprint='a'*64, timeoutMs=1200000),
                    command=dict(executable=command[0], args=command[1:], cwd=str(ROOT),
                                 expectedCostMs=1200000, timeoutMs=1200000),
                    maximumWholeInputRuns=999, priorRuns=[], targetIds=['intrinsic', 'terminal'],
                    outcomes=[dict(id='I', remainingIds=['intrinsic']), dict(id='T', remainingIds=['terminal'])],
                    observation=dict(stride=1, maximumRecords=8192, requiredRecords=7683),
                    alternatives=[dict(kind=k, disposition='unavailable', reason='Evidence-bound source audit',
                                       record=evidence, expectedCostMs=1000)
                                  for k in ['source-review', 'focused-reproduction', 'checkpoint-reuse']],
                    evidence=[evidence])
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'candidate.json'
            output = Path(folder) / 'result.json'
            path.write_text(json.dumps(plan))
            with self.assertRaisesRegex(ValueError, 'AS-DC-001-BUDGET'):
                check_c527_plan(path, command, 1200000, output)
            result = json.loads(output.read_text())
            self.assertFalse(result['childStarted'])
            bound = json.loads(output.with_suffix('.plan.json').read_text())
            self.assertEqual(len(history), len(bound['priorRuns']))
            self.assertEqual(len(history), bound['maximumWholeInputRuns'])

    def test_project_command_cannot_be_substituted(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'candidate.json'
            path.write_text(json.dumps(dict(ruleId='AS-DC-001', purpose='acceptance')))
            with self.assertRaisesRegex(ValueError, 'AS-DC-001-PROJECT-COMMAND-MISMATCH'):
                check_c527_plan(path, ['different.exe'], 1200000, Path(folder) / 'result.json')


if __name__ == '__main__':
    unittest.main()
