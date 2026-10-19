#!/usr/bin/env python3
"""Pin the C# struct receiver path and the missing SLG interpolation node."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-field-selfhost-before-20260929-01")
AST_RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-ast-shape-20260929-03")
LOWERED_RUN = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-struct-literal-shape-20260929-01")
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-source-comparison-20260929-01.json"
FILES = [
    ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
    ROOT / "src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs",
    ROOT / "selfhost/syntax/ast.slg",
    ROOT / "selfhost/ir/interpolation.slg",
    ROOT / "selfhost/semantic/interpolation_inference.slg",
    ROOT / "selfhost/semantic/expression_type_ids.slg",
    ROOT / "selfhost/llvm/text/foundation.slg",
    ROOT / "scripts/probes/interpolation/c527-struct-literal-field-positive.slg",
    ROOT / "scripts/probes/interpolation/c527-struct-literal-field-float.slg",
    ROOT / "artifacts/scratch/c527-struct-literal-managed-first-20260929-01.json",
    ROOT / "artifacts/scratch/c527-struct-literal-ast-probe-20260929-01.slg",
    AST_RUN / "probe.stdout.txt",
    LOWERED_RUN / "probe.stdout.txt",
    RUN / "positive.build.stderr.txt",
    RUN / "float.build.stderr.txt",
    Path(__file__).resolve(),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def line(path: Path, needle: str) -> int:
    for number, text in enumerate(read(path).splitlines(), 1):
        if needle in text:
            return number
    raise ValueError(f"missing decision in {path}: {needle}")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    hashes = {str(path): sha(path) for path in FILES}
    proof = json.loads(read(ROOT / "artifacts/scratch/c527-struct-literal-managed-first-20260929-01.json"))
    ast = read(AST_RUN / "probe.stdout.txt")
    lowered = read(LOWERED_RUN / "probe.stdout.txt")
    if proof["status"] != "passed" or "node=1 kind=39 parent=0 payload=Point { x: 5 }" not in ast:
        raise ValueError("C# first proof or nominal AST shape changed")
    if "node=0 kind=5 parent=-1 operand0=1" not in lowered or "node=1 kind=0 parent=0 operand0=-1 payload=5" not in lowered:
        raise ValueError("SLG lowered shape changed")
    for name in ("positive", "float"):
        failure = read(RUN / f"{name}.build.stderr.txt")
        if "use of undefined value '%v117417_expression0'" not in failure:
            raise ValueError(f"SLG baseline failure changed: {name}")
    managed = {
        "literalInference": line(FILES[0], "private BoundType InferStructLiteralExpression("),
        "fieldReceiverInference": line(FILES[0], "var sourceType = InferExpression("),
        "literalEmission": line(FILES[1], "private RuntimeStruct EmitStructLiteralExpressionCore("),
    }
    selfhost = {
        "astNominalKind": line(FILES[2], "38 dictionary expression, 39 struct literal"),
        "interpolationDictionaryOnly": line(FILES[3], "fragmentNode.kind == 38 -> if { 12 => loweredKind! }"),
        "memberReceiverInference": line(FILES[4], "node.kind == 5 and node.operand0 >= 0 -> if {"),
        "contextualDictionaryType": line(FILES[5], "interpolationContextualStructTypeByNode! -> push(-1)"),
        "contextualDictionaryEmission": line(FILES[6], "emitInterpolationContextualStruct labelIndex:"),
    }
    if hashes != {str(path): sha(path) for path in FILES}:
        raise ValueError("source comparison inputs changed")
    result = {
        "schemaVersion": 1,
        "unit": "C527 direct nominal struct literal field receiver source comparison",
        "status": "passed", "completed": 1, "total": 1, "inputStable": True,
        "inputSha256": hashes, "managedSource": managed, "selfhostSource": selfhost,
        "finding": "C# infers the nominal literal, then its field, and emits the literal value. SLG AST preserves kind 39 and its initializer, but interpolation lowering maps kind 38 only and skips kind 39/40. Its member operand becomes the numeric initializer, leaving the member result undefined in LLVM.",
        "requiredStructure": "Preserve the nominal literal and initializer topology in interpolation IR, resolve the declared struct and field types before member inference, and emit the nominal value before field extraction. Validate positive and Float diagnostic against C#.",
        "implementationComplete": False,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: nominal struct receiver topology gap")


if __name__ == "__main__":
    main()
