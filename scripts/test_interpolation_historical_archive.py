"""Explicit historical build snapshots retain provenance and never qualify live bytes."""
import json
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

from interpolation_current_source import ROOT, historical_compiler_hash

class HistoricalArchiveTests(unittest.TestCase):
    def test_explicit_snapshot_and_rejections(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'artifacts/scratch') as name:
            folder = Path(name)
            original = folder / 'external-build/result.json'
            original.parent.mkdir()
            compiler = original.parent / 'compiler.exe'
            archive = folder / 'snapshot/result.json'
            archive.parent.mkdir()
            contract = folder / 'contract.json'
            baseline = dict(schemaVersion=1, status='passed', inputsStable=True,
                compilerSha256='B'*64, inputFingerprint='A'*64,
                finalInputFingerprint='A'*64, compilerSourceCount=132, stdlibSourceCount=143)
            for case in ('valid', 'tampered', 'failed', 'drift', 'wrong-original', 'outside'):
                with self.subTest(case=case):
                    record = dict(baseline)
                    if case == 'failed': record['status'] = 'failed'
                    if case == 'drift': record['finalInputFingerprint'] = 'C'*64
                    archive.write_text(json.dumps(record), encoding='utf-8')
                    entry = dict(record=str(archive.relative_to(ROOT)),
                        sha256=hashlib.sha256(archive.read_bytes()).hexdigest().upper(),
                        compilerSha256='B'*64)
                    if case == 'tampered': archive.write_text('{}', encoding='utf-8')
                    if case == 'outside': entry['record'] = 'scripts/contracts/evidence/missing/result.json'
                    key = str(original if case != 'wrong-original' else folder / 'different/result.json')
                    contract.write_text(json.dumps(dict(historicalNativeBuildRecords={key:entry})), encoding='utf-8')
                    if case == 'valid':
                        self.assertEqual(historical_compiler_hash(str(compiler), build_record=key, contract_path=contract), 'B'*64)
                    else:
                        with self.assertRaises((AssertionError, subprocess.CalledProcessError)):
                            historical_compiler_hash(str(compiler), build_record=key, contract_path=contract)
            # Live compiler bytes always retain priority over an archival receipt.
            compiler.write_bytes(b'live compiler')
            self.assertEqual(historical_compiler_hash(str(compiler)), hashlib.sha256(compiler.read_bytes()).hexdigest().upper())

if __name__ == '__main__':
    unittest.main()
