"""Exercise the AST identity contract against valid and formerly broken sources."""

import copy
import importlib.util
import json
import unittest
from unittest.mock import patch
from pathlib import Path

from ast_expression_kind_contract import CONTRACT, validate, validate_repository


ROOT = Path(__file__).resolve().parent.parent


class AstKindContractTests(unittest.TestCase):
    def setUp(self):
        self.contract = json.loads((ROOT / CONTRACT).read_text(encoding="utf-8-sig"))
        self.classifier = (ROOT / self.contract["classifier"]).read_text(encoding="utf-8-sig")
        self.consumers = {row["source"]: (ROOT / row["source"]).read_text(encoding="utf-8-sig")
                          for entry in self.contract["kinds"] for row in entry.get("consumers", [])}

    def test_current_repository_has_distinct_identities(self):
        self.assertEqual(validate_repository(ROOT), [])

    def test_previous_shared_identity_is_rejected(self):
        import re
        broken = re.sub(r"(rule\s*==\s*grammar\.ruleIdCompileTimeEachExpression\(\)\s*->\s*if\s*\{\s*)84",
                        r"\g<1>83", self.classifier)
        self.assertNotEqual(broken, self.classifier)
        findings = validate(self.contract, broken, self.consumers)
        self.assertIn("AST_KIND_CLASSIFIER_COLLISION", findings)
        self.assertIn("AST_KIND_CLASSIFIER_MISMATCH:compile-time-each", findings)

    def test_contract_cannot_authorize_collision(self):
        contract = copy.deepcopy(self.contract)
        contract["kinds"][1]["kind"] = 83
        self.assertIn("AST_KIND_CONTRACT_DUPLICATE_KIND", validate(contract, self.classifier, self.consumers))

    def test_consumer_cannot_expand_boolean_literal(self):
        consumers = dict(self.consumers)
        source = "selfhost/semantic/constant_collection_lowering.slg"
        consumers[source] = consumers[source].replace("node.kind == 84", "node.kind == 83")
        self.assertNotEqual(consumers[source], self.consumers[source])
        self.assertIn("AST_KIND_CONSUMER_WRONG_IDENTITY:" + source,
                      validate(self.contract, self.classifier, consumers))

    def test_emitter_rejects_collision_before_requiring_build_proof(self):
        spec = importlib.util.spec_from_file_location("numeric_runner", ROOT / "scripts/verify-c385-preir-call-numeric.py")
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        with patch("ast_expression_kind_contract.validate_repository", return_value=["AST_KIND_CLASSIFIER_COLLISION"]):
            with self.assertRaisesRegex(ValueError, "EMISSION_AST_KIND_PREFLIGHT_FAILED.*AST_KIND_CLASSIFIER_COLLISION"):
                runner.emission_semantic_proof({}, [{"emittedLlvm": True, "additionalSources": ["selfhost/syntax/ast.slg"]}])

    def test_plain_llvm_probe_does_not_require_selfhost_kind_inputs(self):
        spec = importlib.util.spec_from_file_location("numeric_runner", ROOT / "scripts/verify-c385-preir-call-numeric.py")
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        with patch("ast_expression_kind_contract.validate_repository", side_effect=AssertionError("unexpected selfhost guard")):
            self.assertEqual(runner.emission_semantic_proof({}, [{"emittedLlvm": True}]), [])


if __name__ == "__main__":
    unittest.main()
