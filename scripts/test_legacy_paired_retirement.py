"""Paired PowerShell journals prove terminal consumption, never case completion."""
import json
from pathlib import Path
import tempfile
import unittest
from completed_artifact_plan import legacy_paired_processes

class LegacyPairedRetirementTests(unittest.TestCase):
    def test_verified_journals_and_rejected_controls(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'artifacts/paired'
            folder.mkdir(parents=True)
            compiler = root / 'artifacts/build/compiler.exe'
            result = folder / 'result.json'
            base = dict(schemaVersion=1,status='passed',inputStable=True,
                        completed=1,total=1,inputHashesStart={'source':'A'*64},
                        inputHashesEnd={'source':'A'*64},runs=[dict(compiler='selfhost')])
            journal = folder / 'fixture.selfhost.build.execution.json'
            stdout = Path(str(journal)+'.stdout.log')
            stderr = Path(str(journal)+'.stderr.log')
            stdout.write_text('')
            stderr.write_text('')
            event = dict(schemaVersion=1,status='passed',pid=123,command=[str(compiler),'build'],
                         startedAtUtc='2026-10-26T00:00:00+00:00',
                         finishedAtUtc='2026-10-26T00:00:01+00:00',exit=0,processesStopped=True,
                         stdoutPath=str(stdout),stderrPath=str(stderr),failure=None)
            for case in ('valid','wrong-binary','active','drift','missing-log','missing-journal'):
                with self.subTest(case=case):
                    record=dict(base)
                    capture=dict(event)
                    if case=='wrong-binary': capture['command']=['different.exe','build']
                    if case=='active': capture['processesStopped']=False
                    if case=='drift': record['inputHashesEnd']={}
                    journal.write_text(json.dumps(capture))
                    stdout.write_text('')
                    if case=='missing-log': stdout.unlink()
                    if case=='missing-journal': journal.unlink()
                    result.write_text(json.dumps(record))
                    actual=legacy_paired_processes(root,result,record,compiler)
                    self.assertEqual(actual is not None,case=='valid')
                    if case=='valid': self.assertEqual(actual,[capture])

if __name__=='__main__': unittest.main()
