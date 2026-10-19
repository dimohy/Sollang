"""Exercise SLG emission proof rejection before any compiler build output."""

import argparse
import hashlib
import json
import subprocess
import sys
import unittest
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FORMATTER = None
STDLIB_PROOF = None


class EmissionBuildGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if FORMATTER is None or not FORMATTER.is_file() or STDLIB_PROOF is None or not STDLIB_PROOF.is_file():
            raise ValueError("BUILD_GUARD_TEST_EXPLICIT_FORMATTER_AND_STDLIB_PROOF_REQUIRED")
        cls.folder = ROOT / "artifacts/scratch" / ("emission-build-guard-tests-" + uuid.uuid4().hex)
        cls.folder.mkdir()

    def proof(self):
        manifest = ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
        return {"status": "passed", "mode": "managed", "inputsStable": True,
                "processesStopped": True, "completed": 1, "total": 1,
                "semanticPreflight": {"status": "passed-current-source", "codegenInvoked": False},
                "cases": [{"passed": True, "emittedLlvmSha256": "A" * 64,
                           "assemblyExit": 0, "nativeLinkExit": 0, "nativeRunExit": 0}],
                "inputHashes": {str(manifest): hashlib.sha256(manifest.read_bytes()).hexdigest().upper()}}

    def reject(self, name, proof, failure_id):
        path = self.folder / (name + ".json")
        path.write_text(json.dumps(proof), encoding="utf-8")
        output = self.folder / (name + "-output")
        result = subprocess.run(["pwsh", "-NoProfile", "-File",
            str(ROOT / "scripts/build-focused-selfhost-compiler.ps1"),
            "-SeedCompiler", str(ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"),
            "-OutputDirectory", str(output), "-FormatCompiler", str(FORMATTER),
            "-StdlibSourceProofRecord", str(STDLIB_PROOF),
            "-SlgEmissionProofRecord", str(path)], cwd=ROOT, capture_output=True, timeout=30)
        (self.folder / (name + ".stdout.log")).write_bytes(result.stdout)
        (self.folder / (name + ".stderr.log")).write_bytes(result.stderr)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(failure_id, result.stderr.decode("utf-8"))
        self.assertFalse(output.exists())

    def test_missing_semantic_preflight_is_rejected(self):
        proof = self.proof()
        del proof["semanticPreflight"]
        self.reject("missing-semantic", proof, "FOCUSED_SELFHOST_SLG_EMISSION_PROOF_INCOMPLETE")

    def test_failed_llvm_assembly_cannot_authorize_build(self):
        proof = self.proof()
        proof["cases"][0]["assemblyExit"] = 1
        self.reject("assembly-failed", proof, "FOCUSED_SELFHOST_SLG_EMISSION_PROOF_NOT_EXECUTED")

    def test_missing_canonical_compiler_sources_are_rejected(self):
        proof = self.proof()
        proof["inputHashes"] = {str(ROOT / "scripts/build-focused-selfhost-compiler.ps1"): "A" * 64}
        self.reject("missing-canonical-manifest", proof, "FOCUSED_SELFHOST_SLG_EMISSION_PROOF_CANONICAL_INPUTS_MISSING")

    def test_changed_inputs_cannot_reuse_emission_success(self):
        proof = self.proof()
        proof["inputHashes"][str(ROOT / "selfhost/llvm/text/core_calls.slg")] = "0" * 64
        self.reject("changed-source", proof, "FOCUSED_SELFHOST_MANAGED_PROOF_INPUT_DRIFT")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--format-compiler", type=Path, required=True)
    parser.add_argument("--stdlib-source-proof", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    FORMATTER = args.format_compiler.resolve()
    STDLIB_PROOF = args.stdlib_source_proof.resolve()
    unittest.main(argv=[sys.argv[0], *remaining])
