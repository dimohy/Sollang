#!/usr/bin/env python3
"""Record the C# index-error precedence and SLG display-diagnostic gap."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
SOURCE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-invalid-bool.slg"
MANAGED_ERROR = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-invalid-index-managed-first-20260929-01\build.stderr.txt")
SELFHOST_ERROR = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-kind10-invalid-index-selfhost-before-20260929-01\build.stderr.txt")
OUTPUT = ROOT / "artifacts/scratch/c527-kind10-index-error-source-comparison-20260929-01.json"
INDEX_ERROR = "sollang: semantic error at 1:24: [module '<main>'] index must be Int\n"
DISPLAY_ERROR = "sollang: semantic error at 15:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def line(lines: list[str], needle: str) -> int:
    matches = [number for number, value in enumerate(lines, 1) if needle in value]
    if not matches:
        raise ValueError(f"missing source decision: {needle}")
    return matches[0]


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    inputs = [MANAGED, INFERENCE, PREPARATION, SOURCE, MANAGED_ERROR, SELFHOST_ERROR,
              Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    managed = MANAGED.read_text(encoding="utf-8-sig").splitlines()
    inference = INFERENCE.read_text(encoding="utf-8-sig").splitlines()
    preparation = PREPARATION.read_text(encoding="utf-8-sig").splitlines()
    index_start = line(managed, "private BoundType InferIndexExpression(")
    managed_order = {
        "indexInference": index_start,
        "indexMismatch": line(managed[index_start - 1:], "if (indexType != expectedIndexType)") + index_start - 1,
        "indexThrow": line(managed[index_start - 1:], '"index must be {FormatType(expectedIndexType)}"') + index_start - 1,
    }
    selfhost_order = {
        "indexMismatchFacts": line(inference, "public invalidCollectionIndexExpectedTypeByNode prepared:"),
        "displayDecision": line(inference, "public invalidDisplayTypeByNode prepared:"),
        "indexMismatchPreparation": line(preparation, "prepared -> interpolationInference.invalidCollectionIndexExpectedTypeByNode("),
        "displayPreparation": line(preparation, "prepared -> interpolationInference.invalidDisplayTypeByNode("),
    }
    if (not managed_order["indexInference"] < managed_order["indexMismatch"] < managed_order["indexThrow"]
            or selfhost_order["indexMismatchPreparation"] >= selfhost_order["displayPreparation"]
            or contents(MANAGED_ERROR) != INDEX_ERROR
            or contents(SELFHOST_ERROR) != INDEX_ERROR + DISPLAY_ERROR):
        raise ValueError("index diagnostic decision or baseline behavior changed")
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("comparison inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 method-result indexed invalid-index precedence",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "managedOrder": managed_order,
              "selfhostOrder": selfhost_order,
              "finding": "C# throws on the bad index before inferring displayability. SLG records the index error but independently adds a Float display error for the same interpolation root.",
              "requiredStructure": "Use the proven index mismatch fact to stop the root display decision when that index is a descendant of the root.",
              "implementationComplete": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: index error precedes root display")


if __name__ == "__main__":
    main()
