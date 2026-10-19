"""Verify generated literal tables and the self-host lexer's single authority."""

import argparse
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def generated_array(source: str, name: str) -> list:
    match = re.search(rf"public {re.escape(name)}:.*?=> \[(.*?); ~\]", source)
    if match is None:
        raise ValueError(f"missing generated array: {name}")
    return json.loads("[" + match.group(1) + "]")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error(f"output already exists: {output}")
    lexer_spec = ROOT / "syntax/sollang.lexer"
    generated = ROOT / "syntax/generated/sollang_grammar.slg"
    selfhost = ROOT / "selfhost/syntax/lexer.slg"
    managed_generator = ROOT / "src/Sollang.Compiler.Generators/LexerSourceGenerator.cs"
    inputs = [lexer_spec, generated, selfhost, managed_generator, Path(__file__).resolve()]
    for path in inputs:
        if not path.is_file():
            parser.error(f"missing input: {path}")
    output.mkdir(parents=True)
    before = {str(path): sha256(path) for path in inputs}
    result = {"schemaVersion": 1, "status": "running", "inputHashesStart": before, "checks": []}
    result_path = output / "result.json"
    try:
        spec = lexer_spec.read_text(encoding="utf-8")
        table = generated.read_text(encoding="utf-8")
        slg = selfhost.read_text(encoding="utf-8")
        csharp = managed_generator.read_text(encoding="utf-8")
        names = generated_array(table, "lexerRuleNames")
        kinds = generated_array(table, "lexerRuleKinds")
        tokens = generated_array(table, "lexerRuleTokens")
        literals = generated_array(table, "lexerLiteralTexts")
        indexes = generated_array(table, "lexerLiteralIndexes")
        token_names = generated_array(table, "tokenNames")
        spec_literals = {}
        for line in spec.splitlines():
            match = re.fullmatch(r'token ([A-Za-z]+) = (".*")', line.strip())
            if match:
                spec_literals[match.group(1)] = json.loads(match.group(2))
        valid_shape = len(names) == len(kinds) == len(tokens) == len(indexes)
        result["checks"].append({"id": "generated-shape", "passed": valid_shape})
        rows = []
        if valid_shape:
            for name, kind, token, index in zip(names, kinds, tokens, indexes):
                if index >= 0:
                    rows.append({"name": name, "kind": kind, "token": token, "literal": literals[index]})
        mapping = {row["name"]: row["literal"] for row in rows}
        result["checks"].append({"id": "canonical-literals", "passed": mapping == spec_literals and len(rows) == len(spec_literals), "count": len(rows)})
        result["checks"].append({"id": "literal-token-ids", "passed": all(row["kind"] == 7 and token_names[row["token"]] == row["name"] for row in rows)})
        result["checks"].append({"id": "managed-longest-literal", "passed": "OrderByDescending(static rule => rule.Literal.Length)" in csharp})
        result["checks"].append({"id": "selfhost-generated-table", "passed": all(f"grammar.{name}()" in slg for name in ("lexerLiteralTexts", "lexerLiteralIndexes", "lexerRuleTokens")) and all(name not in slg for name in ("tripleKind", "pairKind", "singleKind")) and "spellingLength > width!" in slg})
    except Exception as error:
        result["error"] = repr(error)
    after = {str(path): sha256(path) for path in inputs}
    result["inputHashesEnd"] = after
    result["inputsStable"] = before == after
    result["status"] = "passed" if "error" not in result and before == after and len(result["checks"]) == 5 and all(check["passed"] for check in result["checks"]) else "failed"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[lexer literal authority] {result['status']} {sum(check['passed'] for check in result['checks'])}/{len(result['checks'])}; result={result_path}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
