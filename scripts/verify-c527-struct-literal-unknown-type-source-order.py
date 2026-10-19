#!/usr/bin/env python3
"""Compare C# unknown nominal type rejection with SLG unresolved lowering."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
RESOLVER = ROOT / "selfhost/semantic/expression_type_ids.slg"
EMITTER = ROOT / "selfhost/llvm/emitter/diagnostics.slg"
FIRST = ROOT / "artifacts/scratch/c527-struct-literal-unknown-type-managed-first-20260929-01.json"
BASELINE = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-unknown-type-selfhost-before-20260929-01\unknown.stderr.txt")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-unknown-type-source-comparison-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def line(path: Path, needle: str) -> int:
    for number, text in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if needle in text:
            return number
    raise ValueError(f"missing decision in {path}: {needle}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, RESOLVER, EMITTER, FIRST, BASELINE,
              ROOT / "scripts/probes/interpolation/c527-struct-literal-unknown-type.slg",
              Path(__file__).resolve()]
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    baseline = BASELINE.read_text(encoding="utf-8").replace("\r\n", "\n")
    if first["status"] != "passed" or "error: expected type" not in baseline or "= freeze ] poison" not in baseline:
        raise ValueError("C# first or SLG baseline changed")
    decisions = {
        "managedRejectUnknown": line(MANAGED, "unknown struct type '{expression.TypeName}'"),
        "selfhostUnresolvedType": line(RESOLVER, "literal.kind != 14 or literal.callNameLength == 0"),
        "selfhostSilentDiagnostic": line(RESOLVER, "literalIndex >= (typeByNode -> len) or typeByNode[literalIndex] < 0"),
        "firstBlocking": line(EMITTER, "firstBlockingInterpolationNode context:"),
    }
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("comparison inputs changed")
    result = {"schemaVersion": 1, "unit": "C527 unresolved nominal struct receiver source comparison",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "sourceDecisions": decisions,
              "finding": "C# rejects the unknown nominal constructor before field inference. SLG returns unresolved type, treats the literal as having no contextual diagnostic, then emits a malformed LLVM freeze with an undefined type.",
              "requiredStructure": "Create a semantic diagnostic for an unresolved explicit nominal literal at its type name and stop before LLVM emission. Preserve contextual literal behavior.",
              "implementationComplete": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: unresolved nominal type diagnostic gap")


if __name__ == "__main__":
    main()
