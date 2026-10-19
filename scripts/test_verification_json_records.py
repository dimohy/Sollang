import json
import errno
from pathlib import Path
import tempfile
import os
import threading
import unittest
from unittest.mock import patch

from verification_json_records import write_json_atomic
from verification_execution import VerificationExecution


class AtomicJsonRecordTests(unittest.TestCase):
    @unittest.skipUnless(os.name == "nt", "Windows delete-sharing contract")
    def test_brief_reader_without_delete_sharing_does_not_abort_publication(self):
        import ctypes
        from ctypes import wintypes
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        api.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                   ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        api.CreateFileW.restype = wintypes.HANDLE
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        with tempfile.TemporaryDirectory(prefix="sollang-json-sharing-") as directory:
            target = Path(directory) / "result.json"
            target.write_text('{"previous": true}\n', encoding="utf-8")
            execution = VerificationExecution(
                Path(directory), Path(directory), {"next": True}, lambda: True, lambda path: "unused")
            handle = api.CreateFileW(str(target), 0x80000000, 3, None, 3, 0, None)
            self.assertNotEqual(handle, ctypes.c_void_p(-1).value)
            release = threading.Timer(0.05, api.CloseHandle, args=(handle,))
            release.start()
            try:
                execution.save()
            finally:
                release.join()
            self.assertEqual({"next": True, "processes": []}, json.loads(target.read_text(encoding="utf-8")))
            self.assertEqual([target], list(Path(directory).iterdir()))

    def test_persistent_windows_denial_is_bounded_and_preserves_record(self):
        error = PermissionError("Windows reader denies replacement")
        error.winerror = 5
        with tempfile.TemporaryDirectory(prefix="sollang-json-") as directory:
            target = Path(directory) / "result.json"
            original = b'{"previous": true}\n'
            target.write_bytes(original)
            with patch("verification_json_records.os.replace", side_effect=error) as replace:
                with self.assertRaises(PermissionError):
                    write_json_atomic(target, {"next": True})
            self.assertEqual(8, replace.call_count)
            self.assertEqual(original, target.read_bytes())
            self.assertEqual([target], list(Path(directory).iterdir()))

    def test_utf8_is_independent_of_cp949_locale(self):
        value = {"message": "진행 — 검증 완료", "completed": 7}
        with self.assertRaises(UnicodeEncodeError):
            json.dumps(value, ensure_ascii=False).encode("cp949")
        with tempfile.TemporaryDirectory(prefix="sollang-json-") as directory:
            target = Path(directory) / "result.json"
            write_json_atomic(target, value)
            self.assertEqual(value, json.loads(target.read_bytes().decode("utf-8")))
            self.assertEqual([target], list(Path(directory).iterdir()))

    def test_encoding_failure_preserves_existing_record(self):
        with tempfile.TemporaryDirectory(prefix="sollang-json-") as directory:
            target = Path(directory) / "result.json"
            original = b'{"previous": true}\n'
            target.write_bytes(original)
            with self.assertRaises(UnicodeEncodeError):
                write_json_atomic(target, {"invalid": "\ud800"})
            self.assertEqual(original, target.read_bytes())
            self.assertEqual([target], list(Path(directory).iterdir()))

    def test_failed_replace_preserves_existing_record_and_removes_temp(self):
        with tempfile.TemporaryDirectory(prefix="sollang-json-") as directory:
            target = Path(directory) / "result.json"
            original = b'{"previous": true}\n'
            target.write_bytes(original)
            with patch("verification_json_records.os.replace", side_effect=PermissionError("locked")):
                with self.assertRaises(PermissionError):
                    write_json_atomic(target, {"next": True})
            self.assertEqual(original, target.read_bytes())
            self.assertEqual([target], list(Path(directory).iterdir()))

    def test_disk_full_before_publish_preserves_existing_record(self):
        with tempfile.TemporaryDirectory(prefix="sollang-json-") as directory:
            target = Path(directory) / "result.json"
            original = b'{"previous": true}\n'
            target.write_bytes(original)
            with patch("verification_json_records.os.fsync", side_effect=OSError(errno.ENOSPC, "full")):
                with self.assertRaises(OSError):
                    write_json_atomic(target, {"next": True})
            self.assertEqual(original, target.read_bytes())
            self.assertEqual([target], list(Path(directory).iterdir()))

    def test_corrupt_temp_is_not_published(self):
        with tempfile.TemporaryDirectory(prefix="sollang-json-") as directory:
            target = Path(directory) / "result.json"
            original = b'{"previous": true}\n'
            target.write_bytes(original)
            with patch("verification_json_records.Path.read_bytes", return_value=b"corrupt"):
                with self.assertRaisesRegex(OSError, "CONTENT_MISMATCH"):
                    write_json_atomic(target, {"next": True})
            self.assertEqual(original, target.read_bytes())
            self.assertEqual([target], list(Path(directory).iterdir()))


if __name__ == "__main__":
    unittest.main()
