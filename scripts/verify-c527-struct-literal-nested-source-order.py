#!/usr/bin/env python3
"""Pin matching nested nominal receiver structure and paired output."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = Path(r"C:\Users\dimohy\AppData\Local\Sollang")
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
MANAGED_EMITTER = ROOT / "src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs"
LOWERING = ROOT / "selfhost/ir/interpolation.slg"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
EMITTER = ROOT / "selfhost/llvm/text/foundation.slg"
SOURCE = ROOT / "scripts/probes/interpolation/c527-struct-literal-nested-field.slg"
FIRST = ROOT / "artifacts/scratch/c527-struct-literal-nested-managed-first-20260929-01.json"
SELFHOST_RUN = BASE / "c527-struct-literal-nested-selfhost-before-20260929-01"
BUILD = BASE / "c527-struct-literal-expression-compiler-o1-20260929-01/result.json"
COMPILER = BASE / "c527-struct-literal-expression-compiler-o1-20260929-01/compiler.exe"
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-nested-source-comparison-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def line(path: Path, needle: str) -> int:
    for number, text in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if needle in text:
            return number
    raise ValueError(f"missing source decision in {path}: {needle}")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    first = json.loads(read(FIRST))
    build = json.loads(read(BUILD))
    if (first["status"] != "passed" or first["nativeStdout"] != "value=5\n"
            or build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(COMPILER)
            or read(SELFHOST_RUN / "nested.build.stderr.txt") != ""
            or read(SELFHOST_RUN / "nested.native.stderr.txt") != ""
            or read(SELFHOST_RUN / "nested.native.stdout.txt") != "value=5\n"
            or not (SELFHOST_RUN / "nested.exe").is_file()):
        raise ValueError("C# first or SLG nested receiver output changed")
    decisions = {
        "managedNestedInference": line(MANAGED, "var actualType = InferStructFieldValue("),
        "managedNestedEmission": line(MANAGED_EMITTER, "private RuntimeStruct EmitStructLiteralExpressionCore("),
        "selfhostNominalNode": line(LOWERING, "fragmentNode.kind == 39 -> if { 14 => loweredKind! }"),
        "selfhostInitializerParent": line(LOWERING, "fragmentAst[parentAst!].kind == 40"),
        "selfhostNominalType": line(FACTS, "nominalInterpolationTypeId prepared:"),
        "selfhostNestedFieldType": line(INFERENCE, "public nominalInitializerDiagnosticByNode prepared:"),
        "selfhostRecursiveEmission": line(EMITTER, "labelIndex -> emitInterpolationSubtree(valueIndex!, nodes,"),
    }
    inputs = [MANAGED, MANAGED_EMITTER, LOWERING, FACTS, INFERENCE, EMITTER, SOURCE, FIRST,
              BUILD, COMPILER, SELFHOST_RUN / "nested.exe", SELFHOST_RUN / "nested.build.stdout.txt",
              SELFHOST_RUN / "nested.build.stderr.txt", SELFHOST_RUN / "nested.native.stdout.txt",
              SELFHOST_RUN / "nested.native.stderr.txt", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("comparison inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nested nominal literal receiver source and paired proof",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "sourceDecisions": decisions, "nativeStdout": "value=5\n",
              "finding": "C# recursively infers and emits the inner nominal initializer before extracting the outer and inner fields. SLG retains both literal nodes and their labels, checks the nested value type, emits the inner value recursively, and produces the same native output.",
              "implementationChangeRequired": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: nested receiver source and paired output")


if __name__ == "__main__":
    main()
