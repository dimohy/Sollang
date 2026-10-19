"""Prove emitted LLVM failures cannot become successful verification receipts."""

import json
import importlib.util
import subprocess
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import uuid
from pathlib import Path

from slg_fixture_literals import multiline_raw_literal


ROOT = Path(__file__).resolve().parent.parent
VALID_LLVM = '''@message = private constant [4 x i8] c"ok\\0A\\00"
declare i32 @puts(ptr)
define i32 @main() {
  %result = call i32 @puts(ptr @message)
  ret i32 0
}
'''


class NumericStdlibSourcePreflightTests(unittest.TestCase):
    def setUp(self):
        from scripts.test_verification_stdlib_source_preflight import StdlibSourcePreflightTests
        self.fixture = StdlibSourcePreflightTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.fixture.proof_path = self.fixture.repo / "result.json"
        self.fixture.check()
        spec = importlib.util.spec_from_file_location("numeric_stdlib_preflight",
                                                     ROOT / "scripts/verify-c385-preir-call-numeric.py")
        self.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.runner)
        self.runner.ROOT = self.fixture.repo
        self.case = {"id": "stdlib-emission", "source": "selfhost/compiler.slg",
                     "exit": 0, "stderr": "", "stdout": "", "emittedLlvm": True}
        self.contract = {"schemaVersion": 1, "cases": [self.case],
                         "stdlibSourcePreflightProof": "result.json"}
        self.output = self.fixture.repo / "output"

    def invoke(self):
        path = self.fixture.repo / "contract.json"
        path.write_text(json.dumps(self.contract))
        inputs = self.runner.emission_stdlib_source_proof_inputs(
            self.contract, [self.case], [self.fixture.stdlib.resolve()])
        args = SimpleNamespace(contract=path, output=self.output, format_compiler=None,
                               managed_compiler=self.fixture.repo / "managed.exe")
        self.runner.execute(args, None, "test", [self.fixture.stdlib.resolve()], inputs)

    def test_full_stdlib_requires_explicit_proof_before_output_or_build(self):
        del self.contract["stdlibSourcePreflightProof"]
        with patch.object(self.runner, "managed_runtime_inputs") as build_inputs:
            with self.assertRaisesRegex(ValueError, "EMISSION_STDLIB_SOURCE_PREFLIGHT_REQUIRED_BEFORE_BUILD"):
                self.invoke()
            build_inputs.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_failed_proof_blocks_before_output_or_build(self):
        self.fixture.proof["status"] = "failed"
        self.fixture.proof_path.write_text(json.dumps(self.fixture.proof))
        with patch.object(self.runner, "managed_runtime_inputs") as build_inputs:
            with self.assertRaisesRegex(ValueError, "STDLIB_SOURCE_PREFLIGHT_INCOMPLETE"):
                self.invoke()
            build_inputs.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_stdlib_hash_drift_blocks_before_output_or_build(self):
        self.fixture.stdlib.write_text("changed")
        with patch.object(self.runner, "managed_runtime_inputs") as build_inputs:
            with self.assertRaisesRegex(ValueError, "STDLIB_SOURCE_PREFLIGHT_INPUT_DRIFT"):
                self.invoke()
            build_inputs.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_compiler_hash_drift_blocks_before_output_or_build(self):
        self.fixture.compiler.write_text("changed")
        with patch.object(self.runner, "managed_runtime_inputs") as build_inputs:
            with self.assertRaisesRegex(ValueError, "STDLIB_SOURCE_PREFLIGHT_INPUT_DRIFT"):
                self.invoke()
            build_inputs.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_current_proof_reaches_existing_compiler_input_resolution(self):
        with patch.object(self.runner, "managed_runtime_inputs", side_effect=RuntimeError("PROOF_ACCEPTED")) as inputs:
            with self.assertRaisesRegex(RuntimeError, "PROOF_ACCEPTED"):
                self.invoke()
            inputs.assert_called_once_with((self.fixture.repo / "managed.exe").resolve())
        paths = self.runner.emission_stdlib_source_proof_inputs(
            self.contract, [self.case], [self.fixture.stdlib.resolve()])
        self.assertIn(self.fixture.compiler.resolve(), paths)
        self.assertIn(self.fixture.execution.resolve(), paths)
        self.assertFalse(self.output.exists())

    def test_plain_emission_without_full_stdlib_retains_existing_path(self):
        self.assertEqual(self.runner.emission_stdlib_source_proof_inputs(
            {"cases": [self.case]}, [self.case], []), [])


class EmissionPreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = ROOT / "artifacts/scratch" / ("emission-preflight-tests-" + uuid.uuid4().hex)
        cls.folder.mkdir()

    def invoke(self, name, llvm=VALID_LLVM, expected="ok", emitted=True, allocations=None,
               additional_sources=None, semantic_proof=None, emitter_warning=None,
               run_stderr=None):
        source = self.folder / (name + ".slg")
        warning_import = "import sys.runtime as runtime\n" if emitter_warning is not None else ""
        warning_line = ("    " + json.dumps(emitter_warning) + " -> runtime.eprintln\n"
                        if emitter_warning is not None else "")
        source.write_text(warning_import + "main {\n" + multiline_raw_literal(llvm)
                          + " => llvm\n" + warning_line + "    llvm -> print\n}\n", encoding="utf-8")
        contract = self.folder / (name + ".json")
        case = {
            "id": name, "source": source.relative_to(ROOT).as_posix(),
            "exit": 0, "stderr": "", "stdout": expected,
            "emittedLlvm": emitted}
        if run_stderr is not None:
            case["runStderr"] = run_stderr
        if allocations is not None:
            case["expectedAllocations"] = allocations
        if additional_sources is not None:
            case["additionalSources"] = additional_sources
        specification = {"schemaVersion": 1, "cases": [case]}
        if semantic_proof is not None:
            specification["semanticPreflightProof"] = semantic_proof
        contract.write_text(json.dumps(specification), encoding="utf-8")
        output = self.folder / (name + "-output")
        result = subprocess.run([sys.executable, str(ROOT / "scripts/verify-c385-preir-call-numeric.py"),
            "--mode", "managed", "--contract", str(contract), "--output", str(output)],
            cwd=ROOT, capture_output=True, text=True, timeout=120)
        (self.folder / (name + ".stdout.log")).write_text(result.stdout, encoding="utf-8")
        (self.folder / (name + ".stderr.log")).write_text(result.stderr, encoding="utf-8")
        record = json.loads((output / "result.json").read_text()) if output.exists() else None
        if record:
            self.assertTrue(record["inputsStable"])
            self.assertTrue(record["processesStopped"])
        return result, record, output

    def test_valid_llvm_is_assembled_linked_and_executed(self):
        result, record, output = self.invoke("valid")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(record["status"], "passed")
        case = record["cases"][0]
        self.assertEqual(case["assemblyExit"], 0)
        self.assertEqual(case["nativeLinkExit"], 0)
        self.assertEqual(case["nativeRunExit"], 0)
        self.assertEqual(case["nativeRunStdout"], "ok")
        self.assertEqual(len(case["emittedLlvmSha256"]), 64)
        self.assertFalse(list(output.rglob("*.exe")))
        self.assertFalse(list(output.rglob("*.ll")))
        self.assertTrue((output / "valid/run.stdout").is_file())

    def test_invalid_llvm_stops_before_link_and_preserves_failure(self):
        result, record, output = self.invoke("invalid", llvm="invalid LLVM\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(record["status"], "failed")
        self.assertNotEqual(record["cases"][0]["assemblyExit"], 0)
        self.assertNotIn("nativeLinkExit", record["cases"][0])
        self.assertTrue((output / "invalid/emitted.ll").is_file())

    def test_com_runtime_links_in_native_and_allocation_audit_paths(self):
        llvm = VALID_LLVM.replace('[4 x i8] c"ok\\0A\\00"', '[3 x i8] c"ok\\00"')
        llvm = llvm.replace(
            "declare i32 @puts(ptr)",
            "declare i32 @puts(ptr)\n"
            "declare dllimport i32 @CoInitializeEx(ptr, i32)\n"
            "declare dllimport void @CoUninitialize()")
        llvm = llvm.replace(
            "  %result = call i32 @puts(ptr @message)",
            "  %initialized = call i32 @CoInitializeEx(ptr null, i32 0)\n"
            "  %result = call i32 @puts(ptr @message)\n"
            "  call void @CoUninitialize()")
        result, record, output = self.invoke("com-runtime", llvm=llvm, allocations=0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(record["status"], "passed")
        case = record["cases"][0]
        for stage in ("assemblyExit", "nativeLinkExit", "nativeRunExit",
                      "auditLinkExit", "auditRunExit"):
            self.assertEqual(case[stage], 0, stage)
        self.assertEqual(case["nativeRunStdout"], "ok")
        self.assertEqual(case["auditRunStdout"], "ok\nallocations=0,releases=0")
        self.assertFalse(list(output.rglob("*.exe")))

    def test_exact_expected_warning_preserves_native_verification(self):
        warning = "warning S003 expected"
        result, record, _ = self.invoke("expected-warning", emitter_warning=warning,
                                        run_stderr=warning)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(record["cases"][0]["runStderr"], warning)
        self.assertEqual(record["cases"][0]["nativeRunStdout"], "ok")

    def test_different_warning_stops_before_llvm_assembly(self):
        result, record, output = self.invoke("different-warning",
            emitter_warning="warning S003 actual", run_stderr="warning S003 expected")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(record["completed"], 0)
        self.assertNotIn("assemblyExit", record["cases"][0])
        self.assertTrue((output / "different-warning/emitted.ll").is_file())

    def test_undeclared_warning_is_not_silently_accepted(self):
        result, record, _ = self.invoke("undeclared-warning",
                                        emitter_warning="warning S003 actual")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(record["status"], "failed")
        self.assertNotIn("assemblyExit", record["cases"][0])

    def test_invalid_warning_expectation_stops_before_build(self):
        result, record, output = self.invoke("invalid-warning", run_stderr=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("RUN_STDERR_EXPECTATION_INVALID", result.stderr)
        self.assertIsNone(record)
        self.assertFalse(output.exists())

    def test_successful_link_cannot_hide_wrong_execution_output(self):
        result, record, _ = self.invoke("wrong-output", expected="wrong")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(record["status"], "failed")
        self.assertEqual(record["completed"], 0)
        case = record["cases"][0]
        self.assertEqual(case["assemblyExit"], 0)
        self.assertEqual(case["nativeLinkExit"], 0)
        self.assertEqual(case["nativeRunStdout"], "ok")
        self.assertFalse(case["passed"])

    def test_non_boolean_contract_never_starts_build(self):
        result, record, output = self.invoke("invalid-contract", emitted="true")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EMISSION_PREFLIGHT_INVALID_CONTRACT", result.stderr)
        self.assertIsNone(record)
        self.assertFalse(output.exists())

    def test_balanced_allocation_is_audited_and_cleaned(self):
        llvm = '''declare ptr @malloc(i64)
declare void @free(ptr)
define i32 @main() {
  %data = call ptr @malloc(i64 16)
  call void @free(ptr %data)
  ret i32 0
}
'''
        result, record, output = self.invoke("balanced", llvm=llvm, expected="", allocations=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(record["cases"][0]["auditRunExit"], 0)
        self.assertEqual(record["cases"][0]["auditRunStdout"], "allocations=1,releases=1")
        self.assertFalse(list(output.rglob("*.exe")))
        self.assertFalse(list(output.rglob("*.ll")))

    def test_normal_execution_cannot_hide_leaked_allocation(self):
        llvm = '''declare ptr @malloc(i64)
define i32 @main() {
  %data = call ptr @malloc(i64 16)
  ret i32 0
}
'''
        result, record, output = self.invoke("leaked", llvm=llvm, expected="", allocations=1)
        self.assertNotEqual(result.returncode, 0)
        case = record["cases"][0]
        self.assertEqual(case["nativeRunExit"], 0)
        self.assertNotEqual(case["auditRunExit"], 0)
        self.assertEqual(case["auditRunStdout"], "allocations=1,releases=0")
        self.assertEqual(record["completed"], 0)
        self.assertTrue((output / "leaked/audit.ll").is_file())

    def test_boolean_allocation_count_is_rejected_before_build(self):
        result, record, output = self.invoke("invalid-allocation-count", allocations=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EMISSION_AUDIT_INVALID_CONTRACT", result.stderr)
        self.assertIsNone(record)
        self.assertFalse(output.exists())

    def test_selfhost_emission_requires_semantic_proof_before_build(self):
        result, record, output = self.invoke("missing-semantic-proof",
            additional_sources=["selfhost/llvm/text/container_transforms.slg"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EMISSION_SEMANTIC_PREFLIGHT_REQUIRED_BEFORE_BUILD", result.stderr)
        self.assertIsNone(record)
        self.assertFalse(output.exists())

    def test_source_drift_in_semantic_proof_never_starts_compilation(self):
        directory = self.folder / "stale-semantic-proof"
        directory.mkdir()
        proof = directory / "result.json"
        proof.write_text(json.dumps({"status": "passed", "scope": "focused-selfhost",
            "codegenInvoked": False, "codegenPathGuard": "passed", "inputsStable": True,
            "processesStopped": True, "failureIds": [], "completed": 4, "total": 4,
            "cases": [{"id": name, "passed": True} for name in
                      ("positive", "deferred-text", "rebound-owner", "focused-selfhost")],
            "inputHashes": {str(ROOT / "selfhost/llvm/text/container_transforms.slg"): "0" * 64}}),
            encoding="utf-8")
        result, record, output = self.invoke("stale-semantic-proof-rejected",
            additional_sources=["selfhost/llvm/text/container_transforms.slg"],
            semantic_proof=proof.relative_to(ROOT).as_posix())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("EMISSION_SEMANTIC_PREFLIGHT_INPUT_DRIFT", result.stderr)
        self.assertIsNone(record)
        self.assertFalse(output.exists())



if __name__ == "__main__":
    unittest.main()
