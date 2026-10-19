#!/usr/bin/env python3
"""Pin C# first behavior and the fully qualified SLG lookup gap."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "artifacts/scratch/c527-fully-qualified-source-comparison-20260929-01.json"
FILES = [
    "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs",
    "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
    "selfhost/ir/interpolation.slg",
    "selfhost/semantic/expression_type_ids.slg",
    "scripts/probes/interpolation/c527-fully-qualified-struct-literal-field.slg",
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main() -> None:
    managed = json.loads(read("artifacts/scratch/c527-fully-qualified-managed-first-20260929-01/result.json"))
    slg = json.loads(read("artifacts/scratch/c527-fully-qualified-slg-baseline-20260929-01/result.json"))
    assert managed["buildExit"] == managed["runExit"] == 0
    assert managed["runStdout"] == "value=5\n"
    assert slg["buildExit"] != 0
    assert "unknown struct type 'c527.shapes.Point'" in slg["buildStderr"]
    assert "ParseStructLiteralExpression(ResolveTypePath(path)" in read(FILES[0])
    assert "private BoundType InferStructLiteralExpression(" in read(FILES[1])
    assert "fragmentAst[nominalPathIndex!].length => loweredCallNameLength!" in read(FILES[2])
    assert "resolvedImport.sourceModule == sourceModule and resolvedImport.status == 0" in read(FILES[3])
    hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest().upper() for path in FILES}
    record = {
        "schemaVersion": 1, "unit": "C527 fully qualified nominal interpolation",
        "status": "passed", "managedProof": "artifacts/scratch/c527-fully-qualified-managed-first-20260929-01/result.json",
        "baselineProof": "artifacts/scratch/c527-fully-qualified-slg-baseline-20260929-01/result.json",
        "inputSha256": hashes,
        "managedDecision": "The C# fragment parser retains the full nominal type path and resolves it directly against the visible source closure.",
        "slgGap": "SLG retains the full path but treats the prefix only as an import alias; exact module paths without aliases remain unresolved.",
        "requiredStructure": "Split at the final dot, resolve an exact source-module path when no import alias matches, then select the declared nominal owner and field table.",
        "implementationComplete": False,
    }
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
