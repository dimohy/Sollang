#!/usr/bin/env python3
"""Pin the C# nominal missing-member diagnostic before SLG edits."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "artifacts/scratch/c527-missing-member-source-comparison-20260929-01.json"
FILES = [
    "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
    "selfhost/semantic/expression_type_ids.slg",
    "selfhost/semantic/diagnostics.slg",
    "selfhost/llvm/emitter/diagnostics.slg",
    "scripts/probes/interpolation/c527-fully-qualified-struct-missing-member.slg",
]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def main() -> None:
    managed = json.loads(read("artifacts/scratch/c527-fullpath-missing-member-managed-20260929-01/result.json"))
    slg = json.loads(read("artifacts/scratch/c527-fullpath-missing-member-slg-baseline-20260929-01/result.json"))
    assert managed["buildExit"] != 0 and slg["buildExit"] != 0
    assert "at 1:29:" in managed["buildStderr"] and "member 'missing'" in managed["buildStderr"]
    assert "at 1:1:" in slg["buildStderr"] and "member '.missing'" in slg["buildStderr"]
    assert "private BoundType InferFieldAccessExpression(" in read(FILES[0])
    assert "public memberFieldIndex prepared:" in read(FILES[1])
    assert "public interpolationFragmentLocation nodes:" in read(FILES[2])
    assert "memberBase.payloadStart + memberBase.payloadLength + 1 => memberNameStart" in read(FILES[3])
    hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest().upper() for path in FILES}
    record = {
        "schemaVersion": 1, "unit": "C527 missing member after nominal literal",
        "status": "passed", "managedProof": "artifacts/scratch/c527-fullpath-missing-member-managed-20260929-01/result.json",
        "baselineProof": "artifacts/scratch/c527-fullpath-missing-member-slg-baseline-20260929-01/result.json",
        "inputSha256": hashes,
        "managedDecision": "Report the missing field name and its position inside the interpolation expression.",
        "slgGap": "Diagnostic slices from the constructor end plus one, retaining a dot after the closing parenthesis; it also reports the root expression start.",
        "requiredStructure": "Find the actual member segment after the constructor, use that span as the field name, and map its start into the parsed interpolation fragment for the diagnostic.",
        "implementationComplete": False,
    }
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
