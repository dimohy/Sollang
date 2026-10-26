"""Stopped partial captures retire compiler products without test credit."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import completed_artifact_plan as policy

class PartialCaptureRetirementTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        self.folder = self.repo / 'artifacts/scratch/consumer'
        self.folder.mkdir(parents=True)
        self.path = self.folder / 'result.json'
        self.product = self.repo / 'artifacts/scratch/build/compiler.exe'
        self.product.parent.mkdir()
        self.product.write_bytes(b'compiler')
    def tearDown(self):
        self.temp.cleanup()
    def process(self, pid, exit_code):
        return dict(pid=pid,command=[str(self.product),'build','source.slg'],
            shutdownScope='owned-windows-job',shutdownConfirmed=exit_code is not None,
            startedAtUtc='2026-10-26T00:00:00+00:00',
            finishedAtUtc='2026-10-26T00:00:01+00:00',exit=exit_code,
            naturalShutdownObservation=dict(rootPid=pid,outcome='drained'))
    def rejection(self):
        return dict(schemaVersion=1,status='failed',completed=1,total=3,
            inputsStable=True,processesStopped=True,failure='AssertionError: original diagnostic mismatch',
            cases=[dict(id='passed',status='passed',passed=True),
                   dict(id='rejected',status='running',passed=False,expectedBuildExit=1,buildExit=1)],
            processes=[self.process(101,0),self.process(102,1)],claimsGoalComplete=False)
    def test_partial_rejection_positive_and_rejected_controls(self):
        captures = self.folder / 'rejected'
        captures.mkdir()
        stdout, stderr = captures/'build.stdout', captures/'build.stderr'
        for variant in ['valid','wrong-producer','active-root','active-case','wrong-count',
                        'missing-log','undrained','missing-exit','unknown-time','claims-complete',
                        'mismatched-exit','completed-label','live-process']:
            with self.subTest(variant=variant):
                record=self.rejection()
                stdout.write_text('original diagnostic\n')
                stderr.write_text('')
                if variant=='wrong-producer': record['processes'][-1]['command'][0]='other.exe'
                if variant=='active-root': record['activeProcess']={'pid':102}
                if variant=='active-case': record['cases'][-1]['activeProcess']={'pid':102}
                if variant=='wrong-count': record['completed']=2
                if variant=='missing-log': stdout.unlink()
                if variant=='undrained': record['processes'][-1]['naturalShutdownObservation']['outcome']='active'
                if variant=='missing-exit': record['processes'][-1]['exit']=None
                if variant=='unknown-time': record['processes'][-1]['finishedAtUtc']='bad'
                if variant=='claims-complete': record['claimsGoalComplete']=True
                if variant=='mismatched-exit': record['cases'][-1]['buildExit']=0
                if variant=='completed-label': record['status']='passed'
                before=copy.deepcopy(record)
                try:
                    with patch.object(policy,'assert_output_shutdown',
                            side_effect=ValueError('ACTIVE') if variant=='live-process' else None):
                        result=policy.stopped_partial_rejection_capture(self.repo,self.path,record,self.product)
                    accepted=result is not None
                except ValueError:
                    accepted=False
                self.assertEqual(accepted,variant=='valid')
                self.assertEqual(record,before)
                if accepted:
                    self.assertFalse(result['claimsTestPassed'])
                    self.assertEqual(result['observedCompleted'],1)
    def recovered(self):
        original=self.rejection()
        original.update(status='running',inputsStable=None,processesStopped=None,failure=None)
        original['processes'][-1]=self.process(102,None)
        original['activeProcess']=copy.deepcopy(original['processes'][-1])
        raw=json.dumps(original,indent=2).encode()
        (self.folder/'interrupted-running-result.json').write_bytes(raw)
        audit_path=self.folder/'interrupt-shutdown-result.json'
        audit=dict(schemaVersion=1,status='shutdown-confirmed',reason='known interruption',
            observedAtUtc='2026-10-26T00:00:02+00:00',processIds=[101,102],
            activeProcessIds=[],inputsStable=False,
            originalResultSha256=hashlib.sha256(raw).hexdigest().upper(),
            exitCodesUnavailable=[102],outputDisposition='preserve-canceled-unverified-output')
        current=copy.deepcopy(original)
        current.update(status='canceled',inputsStable=False,processesStopped=True,
            cancellationReason=audit['reason'],cancellationShutdownEvidence=str(audit_path))
        current.pop('activeProcess')
        current['cases'][-1].update(status='canceled',passed=False)
        current['processes'][-1].update(terminationVerified=True,exitCodeUnavailable=True)
        return raw,audit_path,audit,current
    def test_recovery_authentication_and_rejected_controls(self):
        for variant in ['valid','changed-original','invented-exit','invented-completion',
                        'missing-audit','wrong-pids','active-pids','missing-unknown-exit',
                        'bad-time','unpreserved-output','modified-case','live-process']:
            with self.subTest(variant=variant):
                raw,audit_path,audit,record=self.recovered()
                if variant=='changed-original': audit['originalResultSha256']='0'*64
                if variant=='invented-exit': record['processes'][-1]['exit']=0
                if variant=='invented-completion': record['completed']=2
                if variant=='wrong-pids': audit['processIds']=[101]
                if variant=='active-pids': audit['activeProcessIds']=[102]
                if variant=='missing-unknown-exit': audit['exitCodesUnavailable']=[]
                if variant=='bad-time': audit['observedAtUtc']='2020-01-01T00:00:00+00:00'
                if variant=='unpreserved-output': audit['outputDisposition']='delete'
                if variant=='modified-case': record['cases'][-1].update(status='passed',passed=True)
                audit_path.write_text(json.dumps(audit))
                if variant=='missing-audit': audit_path.unlink()
                before=copy.deepcopy(record)
                try:
                    with patch.object(policy,'assert_output_shutdown',
                            side_effect=ValueError('ACTIVE') if variant=='live-process' else None):
                        result=policy.recovered_interruption_shutdown(self.repo,self.path,record)
                    accepted=result is not None
                except ValueError:
                    accepted=False
                self.assertEqual(accepted,variant=='valid')
                self.assertEqual(record,before)
                self.assertEqual((self.folder/'interrupted-running-result.json').read_bytes(),raw)
                if accepted:
                    self.assertFalse(result['claimsTestPassed'])
                    self.assertEqual(result['observedCompleted'],1)

if __name__=='__main__':
    unittest.main()
