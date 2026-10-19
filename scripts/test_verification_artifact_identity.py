"""Historical compiler identity never substitutes for live source-file bytes."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ArtifactIdentityTests(unittest.TestCase):
    @unittest.skipUnless(os.name == 'nt' and os.environ.get('LOCALAPPDATA'), 'Windows lifecycle external root')
    def test_external_archive_uses_exact_lifecycle_root(self):
        helper = Path(__file__).with_name('verification-artifact-identity.ps1').resolve()
        external = Path(os.environ['LOCALAPPDATA']) / 'Sollang'
        external.mkdir(exist_ok=True)
        record = {'schemaVersion': 1, 'status': 'passed', 'inputsStable': True,
                  'compilerSha256': 'B' * 64, 'inputFingerprint': 'A' * 64,
                  'finalInputFingerprint': 'A' * 64, 'compilerSourceCount': 145, 'stdlibSourceCount': 144}
        command = r"""
$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
$request = $input | ConvertFrom-Json
. $request.helper
Get-CompilerEvidenceHash -RepositoryRoot $request.root -LiteralPath $request.path -ArchivedNativeBuild | ConvertTo-Json
"""
        for allowed in (True, False):
            parent = external if allowed else external.parent
            with self.subTest(allowed=allowed), tempfile.TemporaryDirectory(prefix='artifact-identity-test-', dir=parent) as folder:
                path = Path(folder) / 'compiler.exe'
                (path.parent / 'result.json').write_text(json.dumps(record), encoding='utf-8')
                result = subprocess.run([shutil.which('pwsh') or 'pwsh', '-NoProfile', '-Command', command],
                    input=json.dumps({'helper': str(helper), 'root': str(helper.parent.parent), 'path': str(path)}),
                    capture_output=True, text=True, encoding='utf-8', timeout=30)
                self.assertEqual(result.returncode == 0, allowed, result.stderr)
                if allowed:
                    self.assertEqual(json.loads(result.stdout)['IdentitySource'], 'recorded-native-build')

    def test_live_and_recorded_identities_and_forbidden_archives(self):
        helper = Path(__file__).with_name("verification-artifact-identity.ps1").resolve()
        command = r"""
$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
$request = $input | ConvertFrom-Json
. $request.helper
Get-CompilerEvidenceHash -RepositoryRoot $request.root -LiteralPath $request.path -ArchivedNativeBuild:$request.archive | ConvertTo-Json
"""
        for name in ["live", "recorded", "no-authority", "failed", "drift", "unstable", "bad-hash", "source", "outside"]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                folder = root / "artifacts/build"
                folder.mkdir(parents=True)
                path = folder / "compiler.exe"
                record = {"schemaVersion": 1, "status": "passed", "inputsStable": True, "compilerSha256": "B" * 64,
                          "inputFingerprint": "A" * 64, "finalInputFingerprint": "A" * 64,
                          "compilerSourceCount": 145, "stdlibSourceCount": 144}
                if name == "live": path.write_bytes(b"actual bytes")
                if name == "failed": record["status"] = "failed"
                if name == "drift": record["finalInputFingerprint"] = "C" * 64
                if name == "unstable": record["inputsStable"] = False
                if name == "bad-hash": record["compilerSha256"] = "unknown"
                if name == "source": path = folder / "source.slg"
                if name == "outside": path = root / "compiler.exe"
                (folder / "result.json").write_text(json.dumps(record), encoding="utf-8")
                result = subprocess.run([shutil.which("pwsh") or "pwsh", "-NoProfile", "-Command", command],
                    input=json.dumps({"helper": str(helper), "root": str(root), "path": str(path),
                                      "archive": name != "no-authority"}),
                    capture_output=True, text=True, encoding="utf-8", timeout=30)
                allowed = name in ("live", "recorded")
                self.assertEqual(result.returncode == 0, allowed, result.stderr or result.stdout)
                if allowed:
                    data = json.loads(result.stdout)
                    self.assertEqual(data["IdentitySource"], "live-bytes" if name == "live" else "recorded-native-build")
                    if name == "recorded": self.assertEqual(data["Hash"], "B" * 64)


if __name__ == "__main__":
    unittest.main()
