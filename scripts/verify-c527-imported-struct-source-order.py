#!/usr/bin/env python3
"""Pin the imported nominal interpolation decision before SLG edits."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FILES = [
    "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs",
    "src/Sollang.Compiler/Parsing/StringLiteralParser.cs",
    "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
    "selfhost/ir/interpolation.slg",
    "selfhost/semantic/expression_type_ids.slg",
]
OUTPUT = ROOT / "artifacts/scratch/c527-imported-struct-source-comparison-20260929-01.json"


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main() -> None:
    managed = json.loads(read("artifacts/scratch/c527-imported-struct-managed-first-20260929-03/result.json"))
    baseline = json.loads(read("artifacts/scratch/c527-imported-struct-slg-baseline-20260929-01/result.json"))
    ast = json.loads(read("artifacts/scratch/c527-imported-struct-ast-run-20260929-03/result.json"))
    assert managed["buildExit"] == managed["runExit"] == 0
    assert managed["runStdout"] == "value=5\n"
    assert baseline["buildExit"] != 0 and "unknown struct type 'shapes'" in baseline["buildStderr"]
    assert ast["buildExit"] == ast["runExit"] == 0
    assert "node=3 kind=16 parent=2 payload=shapes.Point" in ast["runStdout"]
    assert "StringLiteralParser.ParseStringSegments(stringToken, ParseInterpolationExpressionFragment)" in read(FILES[0])
    assert "return parseExpression(text);" in read(FILES[1])
    assert "private BoundType InferStructLiteralExpression(" in read(FILES[2])
    assert "nominalNameToken.span.length => loweredCallNameLength!" in read(FILES[3])
    assert "candidate.kind == 1 and candidate.origin == 0 and candidate.module == sourceModule" in read(FILES[4])
    hashes = {file: hashlib.sha256((ROOT / file).read_bytes()).hexdigest().upper() for file in FILES}
    record = {
        "schemaVersion": 1,
        "unit": "C527 imported nominal struct literal receiver",
        "status": "passed",
        "managedProof": "artifacts/scratch/c527-imported-struct-managed-first-20260929-03/result.json",
        "baselineProof": "artifacts/scratch/c527-imported-struct-slg-baseline-20260929-01/result.json",
        "astProof": "artifacts/scratch/c527-imported-struct-ast-run-20260929-03/result.json",
        "inputSha256": hashes,
        "managedDecision": "The interpolation fragment inherits namespace and imports; its qualified struct literal resolves before field inference and emission.",
        "slgGap": "The fragment AST contains a full kind-16 qualified path, but lowering stores only the first token; nominal type lookup searches local declarations only.",
        "requiredStructure": "Carry the whole path span and resolve a qualified literal through the exact source import edge and declared target type, retaining local literal behavior and unknown-type diagnostics.",
        "implementationComplete": False,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
