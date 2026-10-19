import copy
import hashlib
import importlib.util
from pathlib import Path
import unittest
import tempfile

PATH = Path(__file__).with_name("verify-late-await-function-order-contract.py")
SPEC = importlib.util.spec_from_file_location("await_owner_contract", PATH)
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)


class RuntimeSourceContractTests(unittest.TestCase):
    def setUp(self):
        self.contract = {"observedSourceOrder": ["stdlib/a.slg", "stdlib/b.slg", "program.slg"]}
        self.wrapper = ('["stdlib/a.slg", "stdlib/b.slg"] => paths\n'
                        '"""\n    main { }\n    """ => input\n'
                        'sources! -> compiler.emitChecked => diagnosticCount')
        self.stdlib = ["stdlib/a.slg", "stdlib/b.slg"]

    def test_complete_native_input_contract(self):
        GUARD.validate_runtime_sources(self.contract, self.wrapper, self.stdlib, "main { }")

    def test_missing_stdlib_rejected_before_execution(self):
        changed = copy.deepcopy(self.contract)
        changed["observedSourceOrder"].pop(0)
        with self.assertRaisesRegex(ValueError, "STDLIB_SCOPE_MISMATCH"):
            GUARD.validate_runtime_sources(changed, self.wrapper, self.stdlib, "main { }")

    def test_runtime_order_drift_rejected(self):
        changed = self.wrapper.replace('"stdlib/a.slg", "stdlib/b.slg"',
                                       '"stdlib/b.slg", "stdlib/a.slg"')
        with self.assertRaisesRegex(ValueError, "RUNTIME_SOURCE_ORDER_MISMATCH"):
            GUARD.validate_runtime_sources(self.contract, changed, self.stdlib, "main { }")

    def test_replaced_program_rejected(self):
        with self.assertRaisesRegex(ValueError, "EMBEDDED_PROGRAM_MISMATCH"):
            GUARD.validate_runtime_sources(self.contract, self.wrapper, self.stdlib, "main { 1 -> println }")

    def test_library_preparation_substitution_rejected(self):
        changed = self.wrapper.replace("compiler.emitChecked", "compiler.emitCheckedFiles")
        # The native API must match as a complete identifier.
        with self.assertRaisesRegex(ValueError, "NATIVE_PREPARATION_MISSING"):
            GUARD.validate_runtime_sources(self.contract, changed, self.stdlib, "main { }")

    def test_failed_observation_cannot_replace_llvm_execution(self):
        with self.assertRaisesRegex(ValueError, "LLVM_PROOF_NOT_COMPLETE"):
            GUARD.validate_proof({"status": "observed"}, PATH, PATH)

    def test_selected_contract_must_be_the_exact_pinned_contract(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            contract, wrapper, other = [directory / name for name in ('selected.json', 'wrapper.slg', 'other.json')]
            for path in (contract, wrapper, other):
                path.write_text(path.name, encoding='utf-8')
            digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper()
            case = dict(id='full-stdlib-nested-await-owner', passed=True, status='passed',
                        emittedLlvmSha256='A' * 64, buildExit=0, assemblyExit=0,
                        nativeLinkExit=0, nativeRunExit=0, nativeRunStdout='count=1,status=0')
            proof = dict(status='passed', completed=1, total=1, inputsStable=True,
                         processesStopped=True, cases=[case],
                         inputHashes={str(contract): digest(contract), str(wrapper): digest(wrapper)})
            GUARD.validate_proof(proof, contract, wrapper)
            with self.assertRaisesRegex(ValueError, 'PROOF_INPUT_DRIFT'):
                GUARD.validate_proof(proof, other, wrapper)


if __name__ == "__main__":
    unittest.main()
