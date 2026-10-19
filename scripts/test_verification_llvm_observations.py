"""LLVM content observations retain exact predicates without trusting missing bytes."""

import copy
import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verification_llvm_observations as evidence


class LlvmObservationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.source = self.root / "fixture.slg"
        self.source.write_text("main {}\n", encoding="utf-8")
        self.compiler = self.root / "compiler.exe"
        self.compiler.write_bytes(b"synthetic compiler identity")
        self.output = self.root / "output"
        self.output.mkdir()
        self.llvm = self.output / "fixture.exe.ll"
        self.llvm.write_text("alpha beta\n", encoding="utf-8")
        self.contract = self.root / "contract.json"
        self.data = {"schemaVersion": 1, "fixtures": [{"name": "fixture", "source": "fixture.slg",
            "checks": [{"id": "present", "text": "alpha", "expected": True},
                       {"id": "absent", "text": "gamma", "expected": False}]}]}
        self.save(self.contract, self.data)

    @staticmethod
    def save(path, value):
        path.write_text(json.dumps(value), encoding="utf-8")

    def proof(self):
        observation = evidence.observe(self.root, self.contract, "fixture", self.llvm, self.compiler)
        path = self.output / "observation.json"
        self.save(path, observation)
        inputs = {str(p): evidence.sha(p) for p in
                  (self.source, self.compiler, self.contract, Path(evidence.__file__).resolve())}
        runs = [{"fixture": "fixture", "compiler": side, "compilerSha256": evidence.sha(self.compiler),
                 "sourceSha256": evidence.sha(self.source), "buildExit": 0, "llvmAsExit": 0,
                 "directCallExit": 0, "nativeExit": 0,
                 "llvmObservation": {"path": str(path), "sha256": evidence.sha(path)}}
                for side in ("managed", "selfhost")]
        result = {"status": "passed", "completed": 1, "total": 1, "inputsStable": True,
                  "processesStopped": True, "inputHashesStart": inputs, "inputHashesEnd": inputs,
                  "runs": runs}
        proof = self.output / "result.json"
        self.save(proof, result)
        return proof, result, path

    def test_positive_and_absence_are_observed_and_bound_to_live_llvm(self):
        proof, _, _ = self.proof()
        result = evidence.verify_proof(self.root, self.contract, proof)
        self.assertEqual(result["fixtures"], {"fixture": {"present": True, "absent": False}})

    def test_wrong_llvm_predicate_is_not_reported_as_passed(self):
        self.llvm.write_text("gamma\n", encoding="utf-8")
        result = evidence.observe(self.root, self.contract, "fixture", self.llvm, self.compiler)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(all(not c["passed"] for c in result["checks"]))

    def test_contract_rejects_type_coercion_duplicates_and_path_escape(self):
        for change in ("string-bool", "duplicate", "escape"):
            with self.subTest(change=change):
                data = copy.deepcopy(self.data)
                if change == "string-bool": data["fixtures"][0]["checks"][0]["expected"] = "false"
                if change == "duplicate": data["fixtures"] *= 2
                if change == "escape": data["fixtures"][0]["source"] = "../foreign.slg"
                with self.assertRaises(ValueError): evidence.contract_cases(self.root, data)

    def test_failed_unexecuted_and_modified_proofs_are_rejected(self):
        for change in ("failed", "missing-managed", "nonzero-stage", "source", "llvm", "observation"):
            with self.subTest(change=change):
                proof, data, observation = self.proof()
                if change == "failed": data["status"] = "failed"
                if change == "missing-managed": data["runs"] = data["runs"][1:]
                if change == "nonzero-stage": data["runs"][0]["nativeExit"] = 1
                if change == "source": self.source.write_text("changed", encoding="utf-8")
                if change == "llvm": self.llvm.write_text("changed", encoding="utf-8")
                if change == "observation": observation.write_text("changed", encoding="utf-8")
                self.save(proof, data)
                with self.assertRaises((ValueError, RuntimeError)):
                    evidence.verify_proof(self.root, self.contract, proof)
                self.source.write_text("main {}\n", encoding="utf-8")
                self.llvm.write_text("alpha beta\n", encoding="utf-8")

    def test_missing_llvm_requires_completed_cleanup_evidence(self):
        proof, _, _ = self.proof()
        self.llvm.unlink()
        with self.assertRaises(FileNotFoundError):
            evidence.verify_proof(self.root, self.contract, proof)

    def test_declared_trap_exit_and_both_exact_outputs_are_required(self):
        runtime = {"exit": -1073741795, "stdout": "", "stderr": {"managed": "trap", "selfhost": ""}}
        self.data['fixtures'][0]['runtime'] = runtime
        self.save(self.contract, self.data)
        for change in ('none', 'wrong-exit', 'wrong-stdout', 'wrong-stderr', 'build-failed'):
            with self.subTest(change=change):
                proof, data, _ = self.proof()
                for run in data['runs']:
                    run.update(nativeExit=runtime['exit'], runtimeStdout='',
                               runtimeStderr=runtime['stderr'][run['compiler']])
                if change == 'wrong-exit': data['runs'][0]['nativeExit'] = 0
                if change == 'wrong-stdout': data['runs'][0]['runtimeStdout'] = 'unexpected'
                if change == 'wrong-stderr': data['runs'][1]['runtimeStderr'] = 'unexpected'
                if change == 'build-failed': data['runs'][0]['buildExit'] = runtime['exit']
                self.save(proof, data)
                if change == 'none': evidence.verify_proof(self.root, self.contract, proof)
                else:
                    with self.assertRaises(ValueError): evidence.verify_proof(self.root, self.contract, proof)

    def test_runtime_contract_rejects_coercion_and_missing_side(self):
        for runtime in ({'exit': True, 'stdout': '', 'stderr': {'managed': '', 'selfhost': ''}},
                        {'exit': 2**31, 'stdout': '', 'stderr': {'managed': '', 'selfhost': ''}},
                        {'exit': 0, 'stdout': '', 'stderr': {'managed': ''}}):
            data = copy.deepcopy(self.data)
            data['fixtures'][0]['runtime'] = runtime
            with self.assertRaisesRegex(ValueError, 'RUNTIME_CONTRACT_INVALID'):
                evidence.contract_cases(self.root, data)


if __name__ == "__main__":
    unittest.main()
