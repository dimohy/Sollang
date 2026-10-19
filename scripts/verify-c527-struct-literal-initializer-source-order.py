#!/usr/bin/env python3
"""Compare C# nominal initializer validation order with SLG contextual order."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
SELFHOST = ROOT / "selfhost/semantic/expression_type_ids.slg"
EMITTER = ROOT / "selfhost/llvm/emitter/diagnostics.slg"
MANAGED_PROOF = ROOT / "artifacts/scratch/c527-struct-literal-initializer-managed-first-20260929-01.json"
BASELINE = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-init-selfhost-before-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-initializer-source-comparison-20260929-01.json"
BASELINE_ERRORS = {
    "unknown-field": "sollang: semantic error at 1:2: [module '<main>'] contextual Point literal is missing field 'x'\n",
    "duplicate-field": "sollang: semantic error at 1:16: [module '<main>'] field 'x' is initialized more than once\n",
    "missing-field": "sollang: semantic error at 1:2: [module '<main>'] contextual Point literal is missing field 'x'\n",
    "field-type": "sollang: semantic error at 1:13: [module '<main>'] field 'Point.x' expects Bool, got Int\n",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def line(path: Path, needle: str, after: int = 0) -> int:
    for number, text in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if number > after and needle in text:
            return number
    raise ValueError(f"missing source decision in {path}: {needle}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, SELFHOST, EMITTER, MANAGED_PROOF, Path(__file__).resolve()]
    proof = json.loads(MANAGED_PROOF.read_text(encoding="utf-8"))
    if proof["status"] != "passed":
        raise ValueError("C# first proof is invalid")
    for name, expected in BASELINE_ERRORS.items():
        path = BASELINE / f"{name}.stderr.txt"
        inputs.append(path)
        if path.read_text(encoding="utf-8").replace("\r\n", "\n") != expected:
            raise ValueError(f"SLG baseline changed: {name}")
    managed = {
        "duplicate": line(MANAGED, "if (!initializers.TryAdd(initializer.Name, initializer))"),
        "unknown": line(MANAGED, "if (field is null)"),
        "type": line(MANAGED, "var actualType = InferStructFieldValue(",
                     line(MANAGED, "if (!initializers.TryAdd(initializer.Name, initializer))")),
        "missing": line(MANAGED, "var missing = definition.Fields.FirstOrDefault"),
    }
    selfhost = {
        "duplicate": line(SELFHOST, "ContextualStructDiagnostic { code: 2, locationNode: childIndex!"),
        "missing": line(SELFHOST, "ContextualStructDiagnostic { code: 3, locationNode: literalIndex"),
        "type": line(SELFHOST, "code: 4"),
        "unknown": line(SELFHOST, "ContextualStructDiagnostic { code: 5, locationNode: unknownIndex!"),
        "message": line(EMITTER, "context.interpolationContextualDiagnosticByNode[nodeIndex!] => diagnostic"),
    }
    if (not managed["duplicate"] < managed["unknown"] < managed["type"] < managed["missing"]
            or not selfhost["duplicate"] < selfhost["missing"] < selfhost["type"] < selfhost["unknown"]):
        raise ValueError("initializer validation order changed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("comparison inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nominal struct initializer diagnostic source comparison",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "managedOrder": managed, "selfhostOrder": selfhost,
              "finding": "C# validates duplicate, unknown field, field value type, then missing field. SLG contextual validator checks duplicate, missing, type, then unknown, and its contextual wording differs from explicit nominal C# diagnostics.",
              "requiredStructure": "For explicit nominal literals, validate initializer names and values in declaration order after duplicate detection and before missing-field detection. Keep contextual dictionary diagnostics unchanged; emit nominal messages without contextual wording.",
              "implementationComplete": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: nominal initializer order and message gap")


if __name__ == "__main__":
    main()
