#!/usr/bin/env python3
"""Compare C# computed field validation with SLG pre-IR timing."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
EMITTER = ROOT / "selfhost/llvm/text/foundation.slg"
FIRST = ROOT / "artifacts/scratch/c527-struct-literal-expression-managed-first-20260929-01.json"
BASE = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-expression-selfhost-before-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-expression-source-comparison-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def line(path: Path, needle: str) -> int:
    for number, text in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if needle in text:
            return number
    raise ValueError(f"missing decision in {path}: {needle}")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    first = json.loads(read(FIRST))
    baseline = read(BASE / "expression-type.build.stderr.txt")
    if (first["status"] != "passed" or first["positiveStdout"] != "value=5\n"
            or first["negativeStderr"] != "sollang: semantic error at 1:15: [module '<main>'] field 'x' expects Bool, got Int\n"
            or read(BASE / "expression.native.stdout.txt") != "value=5\n"
            or "defined with type 'i32' but expected 'i1'" not in baseline):
        raise ValueError("C# first or SLG baseline changed")
    decisions = {
        "managedFieldValueInference": line(MANAGED, "var actualType = InferStructFieldValue("),
        "managedMismatch": line(MANAGED, "field '{field.Name}' expects {FormatType(field.Type)}, got {FormatType(actualType)}"),
        "selfhostEarlyValidation": line(FACTS, "contextualStructDiagnostic prepared:"),
        "selfhostScalarCases": [line(FACTS, f"value.kind == {kind}") for kind in (0, 1, 4)],
        "selfhostBinaryInference": line(INFERENCE, "arithmeticDecision prepared:"),
        "preparedFacts": line(PREPARATION, "prepared -> expressionTypeIds.resolveContext => recursiveTypes!"),
        "preparedBinaryResult": line(PREPARATION, "binaryResultTypeByNode(streamPlan, recursiveTypes!"),
        "selfhostStructEmission": line(EMITTER, "emitInterpolationContextualStruct labelIndex:"),
    }
    inputs = [MANAGED, FACTS, INFERENCE, PREPARATION, EMITTER, FIRST,
              BASE / "expression.native.stdout.txt", BASE / "expression-type.build.stderr.txt",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field.slg",
              ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field-type.slg",
              Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("source comparison inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 computed nominal field source comparison",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "sourceDecisions": decisions,
              "finding": "C# infers each field initializer expression before comparing its type. SLG's early contextual validator recognizes literal, name, and Bool values only; binary result type is computed later. A Bool field initialized with 2+3 bypasses semantic validation and reaches LLVM as i32 where i1 is required.",
              "requiredStructure": "Check explicit nominal initializer field existence and expression result types in source order after full interpolation expression inference, before displayability and LLVM emission. Preserve contextual dictionary validation separately.",
              "implementationComplete": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: computed field type decision occurs too early in SLG")


if __name__ == "__main__":
    main()
