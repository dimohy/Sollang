"""Static exit and stream authority for the read-only phase consumer."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("readonly_phase", Path(__file__).with_name("verify-native-exact-phase-record.py"))
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class OracleTests(unittest.TestCase):
    def setUp(self):
        self.expected = dict(exitCode=1, stdout="", stderr="declared rejection")
        self.outcome = dict(exitCode=1, expectedExitCode=1, actualStdout="", actualStderr="declared rejection")
        self.process = dict(exit=1, pid=123, finishedAtUtc="2026-11-13T00:00:00Z",
                            processesStopped=True, failure=None)

    def test_declared_cli_rejection_is_not_wrapper_failure(self):
        reader.oracle(self.expected, self.outcome, self.process)

    def test_observed_expected_field_cannot_authorize_another_exit(self):
        for exit_code in (0, 42, None, False):
            out = dict(self.outcome, exitCode=exit_code, expectedExitCode=exit_code)
            with self.assertRaisesRegex(ValueError, "DECLARED_EXIT"):
                reader.oracle(self.expected, out, dict(self.process, exit=exit_code))
        with self.assertRaisesRegex(ValueError, "DECLARED_EXIT"):
            reader.oracle(self.expected, dict(self.outcome, expectedExitCode=True), self.process)

    def test_result_cannot_hide_actual_child_failure(self):
        with self.assertRaisesRegex(ValueError, "PROCESS_UNCONFIRMED"):
            reader.oracle(self.expected, self.outcome, dict(self.process, exit=42))

    def test_shutdown_and_real_process_identity_are_required(self):
        for changes in (dict(pid=0), dict(pid=True), dict(finishedAtUtc=None),
                        dict(processesStopped=False), dict(failure="timeout")):
            with self.assertRaisesRegex(ValueError, "PROCESS_UNCONFIRMED"):
                reader.oracle(self.expected, self.outcome, dict(self.process, **changes))

    def test_raw_diagnostics_and_stdout_do_not_follow_observed_expectations(self):
        for changes in (dict(actualStderr="other"), dict(actualStdout="unexpected")):
            with self.assertRaises(ValueError):
                reader.oracle(self.expected, dict(self.outcome, **changes), self.process)

    def test_hashed_runner_reference_is_code_not_json(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            code = root / "runner.ps1"
            code.write_text("[CmdletBinding()]\nparam()\n", encoding="utf-8")
            reference = dict(path="runner.ps1", sha256=reader.authority.file_hash(code))
            with patch.object(reader, "ROOT", root):
                self.assertEqual(reader.reference_path(reference), code.resolve())


class CompilerRuntimeTests(unittest.TestCase):
    def test_native_empty_sidecars_still_require_actual_executable_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            product = root / "compiler.exe"
            product.write_bytes(b"native product")
            binary = dict(path="compiler.exe", sha256=reader.authority.file_hash(product))
            with patch.object(reader, "ROOT", root):
                reader.compiler_runtime_pins({}, binary)
                with self.assertRaisesRegex(ValueError, "REFERENCE_CHANGED"):
                    reader.compiler_runtime_pins({}, dict(binary, sha256="F" * 64))

    def test_native_cannot_acquire_unexpected_managed_sidecar_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            product = root / "compiler.exe"
            product.write_bytes(b"native product")
            binary = dict(path="compiler.exe", sha256=reader.authority.file_hash(product))
            with patch.object(reader, "ROOT", root):
                for values in (None, [], {"other.dll": "F" * 64}):
                    with self.assertRaisesRegex(ValueError, "NATIVE_RUNTIME_SCOPE"):
                        reader.compiler_runtime_pins(values, binary)

    def test_managed_sidecars_cannot_be_empty_or_omit_main_product(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            product = root / "compiler.dll"
            product.write_bytes(b"managed product")
            config = root / "compiler.runtimeconfig.json"
            config.write_text("{}", encoding="utf-8")
            binary = dict(path="compiler.dll", sha256=reader.authority.file_hash(product))
            values = {str(path): reader.authority.file_hash(path) for path in (product, config)}
            with patch.object(reader, "ROOT", root):
                reader.compiler_runtime_pins(values, binary)
                with self.assertRaisesRegex(ValueError, "INPUTS_MISSING"):
                    reader.compiler_runtime_pins({}, binary)
                with self.assertRaisesRegex(ValueError, "MANAGED_RUNTIME_MAIN_MISSING"):
                    reader.compiler_runtime_pins({str(config): values[str(config)]}, binary)


if __name__ == "__main__":
    unittest.main()
