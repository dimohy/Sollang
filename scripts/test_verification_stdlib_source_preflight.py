import json
import tempfile
import unittest
from pathlib import Path

from scripts.verification_stdlib_source_preflight import compiler_manifest_inputs, sha, validate


class StdlibSourcePreflightTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        self.stdlib = self.repo / "stdlib/std/sample.slg"
        self.compiler = self.repo / "selfhost/compiler.slg"
        self.manifest = self.repo / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
        for path, text in [(self.stdlib, "library"), (self.compiler, "compiler"),
                           (self.manifest, "selfhost/compiler.slg\n")]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        self.proof_path = self.repo / "proof.json"
        self.proof = dict(scope="owned-index-full-stdlib-source", status="passed",
                          completed=1, total=1, inputsStable=True, processesStopped=True,
                          fullStdlibSourceCount=1, packageSourceCount=2,
                          activeStdlibBodyCount=1, diagnosticSourceModule=-1,
                          inputHashes={str(p): sha(p) for p in
                                       [self.stdlib, self.compiler, self.manifest]},
                          compilerSourceHashes={str(self.compiler): sha(self.compiler)})
        self.proof.update(stdlibBodyCount=1, inactiveStdlibBodyCount=0, checkedSemanticDiagnosticCount=0)
        self.stdout = self.repo / "run.stdout"
        self.execution = self.repo / "execution.json"
        self.observed = {key: self.proof[key] for key in
                         ("diagnosticSourceModule", "fullStdlibSourceCount", "packageSourceCount",
                          "activeStdlibBodyCount", "stdlibBodyCount", "inactiveStdlibBodyCount",
                          "checkedSemanticDiagnosticCount")}
        self.write_execution()

    def write_execution(self, status="passed"):
        output = json.dumps(self.observed)
        self.stdout.write_text(output, encoding="utf-8")
        record = dict(status=status, completed=1, total=1, inputsStable=True,
                      processesStopped=True, inputHashes={str(p): sha(p) for p in
                                                        [self.stdlib, self.compiler]},
                      cases=[dict(passed=True, buildExit=0, runExit=0, runStdout=output,
                                  buildStderr="", runStderr="")])
        self.execution.write_text(json.dumps(record), encoding="utf-8")
        self.proof.update(executionResult=str(self.execution), executionStdout=str(self.stdout))
        self.proof["inputHashes"].update({str(p): sha(p) for p in [self.execution, self.stdout]})

    def check(self):
        self.proof_path.write_text(json.dumps(self.proof), encoding="utf-8")
        return validate(self.repo, self.proof_path)

    def test_current_complete_active_package_is_accepted(self):
        self.assertEqual(self.check()["status"], "passed")

    def test_failed_verification_cannot_promote_build(self):
        self.proof["status"] = "failed"
        with self.assertRaisesRegex(ValueError, "INCOMPLETE"):
            self.check()

    def test_changed_stdlib_is_rejected(self):
        self.stdlib.write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "INPUT_DRIFT"):
            self.check()

    def test_partial_stdlib_evidence_is_rejected(self):
        del self.proof["inputHashes"][str(self.stdlib)]
        with self.assertRaisesRegex(ValueError, "EXECUTION_INPUTS_MISSING"):
            self.check()

    def test_source_addition_requires_new_proof(self):
        (self.stdlib.parent / "added.slg").write_text("new", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "SOURCE_COUNT"):
            self.check()

    def test_inactive_package_cannot_hide_failure(self):
        self.proof["activeStdlibBodyCount"] = 0
        with self.assertRaisesRegex(ValueError, "ACTIVE_BODIES"):
            self.check()

    def test_diagnostic_cannot_be_bypassed(self):
        self.proof["diagnosticSourceModule"] = 0
        with self.assertRaisesRegex(ValueError, "DIAGNOSTIC"):
            self.check()

    def test_failed_execution_cannot_be_hidden_by_passed_metadata(self):
        self.write_execution(status="failed")
        with self.assertRaisesRegex(ValueError, "EXECUTION_INCOMPLETE"):
            self.check()

    def test_failed_stdout_cannot_be_hidden_by_clean_metadata(self):
        self.observed["diagnosticSourceModule"] = 4
        self.write_execution()
        with self.assertRaisesRegex(ValueError, "OBSERVATION_CONFLICT"):
            self.check()

    def test_partial_body_coverage_cannot_be_promoted(self):
        self.proof["stdlibBodyCount"] = self.observed["stdlibBodyCount"] = 3
        self.write_execution()
        with self.assertRaisesRegex(ValueError, "BODY_COVERAGE"):
            self.check()

    def test_execution_fixture_must_be_pinned_by_build_proof(self):
        fixture = self.repo / "fixture.slg"
        fixture.write_text("fixture", encoding="utf-8")
        record = json.loads(self.execution.read_text())
        record["inputHashes"][str(fixture)] = sha(fixture)
        self.execution.write_text(json.dumps(record), encoding="utf-8")
        self.proof["inputHashes"][str(self.execution)] = sha(self.execution)
        with self.assertRaisesRegex(ValueError, "EXECUTION_INPUTS_MISSING"):
            self.check()

    def test_unexpected_warning_cannot_be_promoted(self):
        record = json.loads(self.execution.read_text())
        record["cases"][0]["buildStderr"] = "warning"
        self.execution.write_text(json.dumps(record), encoding="utf-8")
        self.proof["inputHashes"][str(self.execution)] = sha(self.execution)
        with self.assertRaisesRegex(ValueError, "UNEXPECTED_STDERR"):
            self.check()

    def test_whole_context_diagnostic_blocks_build(self):
        self.proof["checkedSemanticDiagnosticCount"] = 1
        with self.assertRaisesRegex(ValueError, "CHECKED_SEMANTIC_DIAGNOSTIC"):
            self.check()

    def test_ownership_failure_stdout_cannot_be_hidden(self):
        self.observed["checkedSemanticDiagnosticCount"] = 1
        self.write_execution()
        with self.assertRaisesRegex(ValueError, "OBSERVATION_CONFLICT"):
            self.check()

    def test_owned_index_only_proof_cannot_promote_build(self):
        del self.proof["checkedSemanticDiagnosticCount"]
        with self.assertRaisesRegex(ValueError, "CHECKED_SEMANTIC_DIAGNOSTIC"):
            self.check()


    def test_canonical_manifest_is_resolved_before_execution(self):
        manifest, compiler, inputs = compiler_manifest_inputs(self.repo)
        self.assertEqual(manifest, self.manifest.resolve())
        self.assertEqual(compiler, [self.compiler.resolve()])
        self.assertEqual(inputs, [self.manifest.resolve()])

    def test_equivalent_alternate_manifest_pins_both_authorities(self):
        alternate = self.repo / "alternate.sources.txt"
        alternate.write_text(self.manifest.read_text(encoding="utf-8"), encoding="utf-8")
        _, compiler, inputs = compiler_manifest_inputs(self.repo, alternate)
        self.assertEqual(compiler, [self.compiler.resolve()])
        self.assertEqual(inputs, [self.manifest.resolve(), alternate.resolve()])

    def test_previous_scratch_compiler_substitution_is_rejected(self):
        scratch = self.repo / "scratch/compiler.slg"
        scratch.parent.mkdir()
        scratch.write_text("candidate", encoding="utf-8")
        alternate = self.repo / "alternate.sources.txt"
        alternate.write_text("scratch/compiler.slg\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "MANIFEST_SCOPE_MISMATCH"):
            compiler_manifest_inputs(self.repo, alternate)

    def test_manifest_order_is_part_of_canonical_scope(self):
        second = self.repo / "selfhost/second.slg"
        second.write_text("second", encoding="utf-8")
        self.manifest.write_text("selfhost/compiler.slg\nselfhost/second.slg\n", encoding="utf-8")
        alternate = self.repo / "alternate.sources.txt"
        alternate.write_text("selfhost/second.slg\nselfhost/compiler.slg\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "MANIFEST_SCOPE_MISMATCH"):
            compiler_manifest_inputs(self.repo, alternate)

    def test_invalid_compiler_manifests_fail_closed(self):
        alternate = self.repo / "alternate.sources.txt"
        for text in ("", "selfhost/compiler.slg\nselfhost/compiler.slg\n",
                     "selfhost/missing.slg\n", "../outside.slg\n"):
            with self.subTest(text=text):
                alternate.write_text(text, encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "MANIFEST_INVALID"):
                    compiler_manifest_inputs(self.repo, alternate)

if __name__ == "__main__":
    unittest.main()
