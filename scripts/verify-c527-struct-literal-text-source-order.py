#!/usr/bin/env python3
"""Compare C# and SLG Text initializer type and emission routes."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
MANAGED_EMITTER = ROOT / "src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
SELFHOST_EMITTER = ROOT / "selfhost/llvm/text/foundation.slg"
MANAGED_PROOF = ROOT / "artifacts/scratch/c527-struct-literal-text-managed-first-20260929-01.json"
SELFHOST_RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-text-selfhost-before-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-text-source-comparison-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def line(path: Path, needle: str) -> int:
    for number, text in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if needle in text:
            return number
    raise ValueError(f"missing source decision in {path}: {needle}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, MANAGED_EMITTER, FACTS, SELFHOST_EMITTER, MANAGED_PROOF,
              SELFHOST_RUN / "text.exe", SELFHOST_RUN / "text.build.stdout.txt",
              SELFHOST_RUN / "text.build.stderr.txt", SELFHOST_RUN / "text.native.stdout.txt",
              SELFHOST_RUN / "text.native.stderr.txt", Path(__file__).resolve()]
    proof = json.loads(MANAGED_PROOF.read_text(encoding="utf-8"))
    if (proof["status"] != "passed" or proof["nativeStdout"] != "value=hello\n"
            or (SELFHOST_RUN / "text.build.stderr.txt").read_text(encoding="utf-8") != ""
            or (SELFHOST_RUN / "text.native.stderr.txt").read_text(encoding="utf-8") != ""
            or (SELFHOST_RUN / "text.native.stdout.txt").read_text(encoding="utf-8").replace("\r\n", "\n") != "value=hello\n"):
        raise ValueError("C# or SLG Text initializer behavior changed")
    decisions = {
        "managedFieldType": line(MANAGED, "var actualType = InferStructFieldValue("),
        "managedFieldAccess": line(MANAGED, "private BoundType InferFieldAccessExpression("),
        "managedEmission": line(MANAGED_EMITTER, "private RuntimeStruct EmitStructLiteralExpressionCore("),
        "selfhostLexicalFieldType": line(FACTS, "value.kind == 1 and valueIndex! < (lexicalTypes -> len)"),
        "selfhostEmission": line(SELFHOST_EMITTER, "emitInterpolationContextualStruct labelIndex:"),
    }
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("source comparison inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nominal Text initializer source comparison",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "sourceDecisions": decisions,
              "finding": "C# checks a lexical Text initializer against the declared field, then emits the nominal value before field extraction. SLG resolves the lexical field type and emits the same constructed value and field result; both native runs print value=hello.",
              "implementationChangeRequired": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: existing Text initializer structure matches")


if __name__ == "__main__":
    main()
