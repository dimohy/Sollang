"""Check registered AST grammar identities and their semantic consumers."""

import json
import re
from pathlib import Path


CONTRACT = "scripts/contracts/ast-expression-kinds.json"


def validate(contract, classifier, consumers):
    issues = []
    kinds = contract.get("kinds", [])
    if contract.get("schemaVersion") != 1 or not kinds:
        return ["AST_KIND_CONTRACT_SCHEMA"]
    for field in ("identity", "kind", "rule"):
        if len({entry[field] for entry in kinds}) != len(kinds):
            issues.append("AST_KIND_CONTRACT_DUPLICATE_" + field.upper())
    assignments = re.findall(
        r"rule\s*==\s*grammar\.(ruleId\w+)\(\)\s*->\s*if\s*\{\s*(\d+)\s*=>\s*kind!", classifier)
    actual = {}
    for entry in kinds:
        values = [int(value) for rule, value in assignments if rule == entry["rule"]]
        if values != [entry["kind"]]:
            issues.append("AST_KIND_CLASSIFIER_MISMATCH:" + entry["identity"])
        if len(values) == 1:
            actual[entry["identity"]] = values[0]
        for consumer in entry.get("consumers", []):
            text = consumers[consumer["source"]]
            expression = r"\bnode\.kind\s*" + re.escape(consumer["comparison"]) + r"\s*" + str(entry["kind"]) + r"\b"
            if not re.search(expression, text):
                issues.append("AST_KIND_CONSUMER_MISMATCH:" + consumer["source"])
            for other in kinds:
                if other["identity"] != entry["identity"] and re.search(
                        r"\bnode\.kind\s*(?:==|!=)\s*" + str(other["kind"]) + r"\b", text):
                    issues.append("AST_KIND_CONSUMER_WRONG_IDENTITY:" + consumer["source"])
    if len(set(actual.values())) != len(actual):
        issues.append("AST_KIND_CLASSIFIER_COLLISION")
    return issues


def contract_inputs(root: Path):
    path = root / CONTRACT
    contract = json.loads(path.read_text(encoding="utf-8-sig"))
    return [path, Path(__file__).resolve(), root / contract["classifier"],
            *[root / consumer["source"] for entry in contract["kinds"] for consumer in entry.get("consumers", [])]]


def validate_repository(root: Path):
    contract = json.loads((root / CONTRACT).read_text(encoding="utf-8-sig"))
    consumers = {consumer["source"]: (root / consumer["source"]).read_text(encoding="utf-8-sig")
                 for entry in contract["kinds"] for consumer in entry.get("consumers", [])}
    return validate(contract, (root / contract["classifier"]).read_text(encoding="utf-8-sig"), consumers)
