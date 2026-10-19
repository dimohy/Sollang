"""Check that committed expression keywords share one C#/SLG parser contract."""

import argparse
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def method(source: str, name: str, next_name: str) -> str:
    start = source.index(f"private Expression {name}(")
    end = source.index(f"private Expression {next_name}(", start)
    return source[start:end]


def managed_keywords(source: str) -> dict[str, str]:
    unary = method(source, "ParseUnaryExpression", "ParsePrimaryExpression")
    atom = method(source, "ParseAtomExpression", "ParseMapExpression")
    result = {}
    for keyword, node in re.findall(
        r'CheckIdentifier\(\\"(\w+)\\"\).*?return new (\w+Expression)\(', unary, re.S
    ):
        result[keyword] = node
    for keyword, parser in re.findall(
        r'CheckIdentifier\(\\"(\w+)\\"\).*?return (Parse\w+Expression)\(', atom, re.S
    ):
        result[keyword] = parser
    # The map branch consumes an Identifier before checking its text.
    for keyword, parser in re.findall(
        r'if \(identifier\.Text == \\"(\w+)\\"\).*?return (Parse\w+Expression)\(', atom, re.S
    ):
        result[keyword] = parser
    if 'return new BoolExpression(identifier.Text == \\"true\\"' in atom:
        for keyword in re.findall(r'identifier\.Text == \\"(true|false)\\"', atom):
            result[keyword] = "BoolExpression"
    return result


def grammar_keywords(source: str) -> tuple[set[str], dict[str, str]]:
    rules = dict(re.findall(r"^rule (\w+) = (.+)$", source, re.M))
    name_rule = rules.get("NameExpression", "")
    rejected = set(re.findall(r'notKeyword\("(\w+)"\)', name_rule))
    dedicated = {}
    for keyword in rejected:
        rules_with_keyword = [
            name for name, body in rules.items()
            if name != "NameExpression" and f'Identifier("{keyword}")' in body
        ]
        if keyword in ("not", "box"):
            target = "UnaryExpression"
        elif keyword in ("true", "false"):
            target = "BoolExpression"
        else:
            target = keyword.capitalize() + "Expression"
        if target in rules_with_keyword:
            dedicated[keyword] = target
    return rejected, dedicated


def generated_hash(lexer: str, grammar: str) -> str:
    normalized = lexer.replace("\r\n", "\n").replace("\r", "\n")
    normalized += "\n---grammar---\n"
    normalized += grammar.replace("\r\n", "\n").replace("\r", "\n")
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def check(result: dict, check_id: str, passed: bool, **details: object) -> None:
    result["checks"].append({"id": check_id, "passed": passed, **details})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    paths = {
        "managed": ROOT / "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs",
        "grammar": ROOT / "syntax/sollang.grammar",
        "lexer": ROOT / "syntax/sollang.lexer",
        "generated": ROOT / "syntax/generated/sollang_grammar.slg",
        "selfhost": ROOT / "selfhost/syntax/parser.slg",
        "ast": ROOT / "selfhost/syntax/ast.slg",
        "semantic": ROOT / "selfhost/semantic/expression_types.slg",
        "type_ids": ROOT / "selfhost/semantic/expression_type_ids_resolution_phases.slg",
        "typed": ROOT / "selfhost/ir/typed.slg",
        "entry": ROOT / "selfhost/ir/typed/source_lowering.slg",
        "ordinary": ROOT / "selfhost/ir/typed/ordinary_function_expressions.slg",
        "interpolation": ROOT / "selfhost/ir/interpolation.slg",
        "parity_contract": ROOT / "scripts/contracts/expression-lowering-parity.json",
        "c385_batch": ROOT / "scripts/contracts/c385-expression-family-batch.json",
        "verifier": Path(__file__).resolve(),
    }
    for path in paths.values():
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    before = {key: sha256(path) for key, path in paths.items()}
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "checks": []}
    try:
        sources = {key: path.read_text(encoding="utf-8") for key, path in paths.items()}
        managed = managed_keywords(sources["managed"])
        rejected, dedicated = grammar_keywords(sources["grammar"])
        expected = {"not", "box", "when", "map", "true", "false"}
        check(result, "managed-committed-keywords", set(managed) == expected,
              observed=managed)
        check(result, "grammar-name-exclusions", rejected == set(managed),
              observed=sorted(rejected))
        check(result, "dedicated-grammar-rules", set(dedicated) == set(managed),
              observed=dedicated)
        match = re.search(r"^# Source SHA-256: ([0-9a-f]{64})$", sources["generated"], re.M)
        check(result, "generated-source-current",
              match is not None and match.group(1) == generated_hash(sources["lexer"], sources["grammar"]))
        check(result, "selfhost-reject-opcode",
              "opcode == 8" in sources["selfhost"] and
              "opcode == 9" in sources["selfhost"] and
              "# 5 commit, 6 jump, 7 token lookahead, 8 reject keyword, 9 function start." in sources["generated"])
        rules = dict(re.findall(r"^rule (\w+) = (.+)$", sources["grammar"], re.M))
        check(result, "boolean-before-call-and-name",
              rules.get("AtomExpression", "").index("BoolExpression") <
              rules.get("AtomExpression", "").index("CallExpression") and
              all(rules.get(name, "").startswith('notKeyword("true") notKeyword("false")')
                  for name in ("CallExpression", "TypeApplicationExpression",
                               "StructLiteralExpression", "EnumConstructorExpression")))
        check(result, "boolean-ast-identity",
              "rule == grammar.ruleIdBoolExpression() -> if { 83 => kind! }" in sources["ast"])
        check(result, "boolean-semantic-identity",
              "node.kind == 83 -> if {" in sources["semantic"] and
              "booleanLiteral!" not in sources["semantic"])
        check(result, "boolean-type-id-identity",
              "node.kind == 83 -> if { 23 => builtinTypeId! }" in sources["type_ids"])
        check(result, "boolean-typed-ir-identity",
              "kind == 83 -> if { 4 => irKind! }" in sources["typed"] and
              "entryExpression.kind == 83 -> if { true => entryExpressionIsBoolLiteral! }" in sources["entry"] and
              "expression.kind == 83 -> if { true => expressionIsBoolLiteral! }" in sources["ordinary"])
        check(result, "boolean-interpolation-identity",
              "fragmentNode.kind == 83 -> if { 4 => loweredKind! }" in sources["interpolation"])
        parity = json.loads(sources["parity_contract"])
        mapping = next((row for row in parity["mappings"]
                        if row["managedExpression"] == "BoolExpression"), None)
        check(result, "boolean-parity-contract",
              mapping is not None and mapping["selfhostAstKinds"] == [83]
              and mapping["typedIrKinds"] == [4] and mapping["behavior"] == "value"
              and mapping["policy"] == "defaultExpressionIrKindForAstKind")
        batch = json.loads(sources["c385_batch"])
        probes = [probe for fixture in batch["fixtures"] for probe in fixture["probes"]
                  if probe["family"] == "BoolExpression"]
        check(result, "boolean-c385-coverage-plan",
              len(probes) == 1 and probes[0]["astKinds"] == [83]
              and probes[0]["typedIrKinds"] == [4])
        # Mutation controls prove that source drift makes this contract fail closed.
        removed = sources["grammar"].replace('notKeyword("box") ', "", 1)
        extra = sources["grammar"].replace('notKeyword("false") Identifier Bang?',
                                           'notKeyword("false") notKeyword("future") Identifier Bang?', 1)
        missing_managed = sources["managed"].replace('CheckIdentifier(\\"when\\")',
                                                       'CheckIdentifier(\\"other\\")', 1)
        check(result, "control-removed-exclusion",
              grammar_keywords(removed)[0] != set(managed))
        check(result, "control-added-exclusion",
              grammar_keywords(extra)[0] != set(managed))
        check(result, "control-removed-managed-branch",
              set(managed_keywords(missing_managed)) != rejected)
    except Exception as error:
        result["error"] = repr(error)
    after = {key: sha256(path) for key, path in paths.items()}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = ("passed" if before == after and "error" not in result
                        and len(result["checks"]) == 16
                        and all(row["passed"] for row in result["checks"]) else "failed")
    path = output / "result.json"
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[parser expression keywords] {result['status']} "
          f"{sum(row['passed'] for row in result['checks'])}/{len(result['checks'])}; result={path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
