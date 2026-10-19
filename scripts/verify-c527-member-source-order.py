#!/usr/bin/env python3
"""Compare current interpolation member type and displayability decision timing."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    "src/Sollang.Compiler/Semantics/SemanticCompiler.cs",
    "selfhost/semantic/expression_type_ids.slg",
    "selfhost/semantic/interpolation_inference.slg",
    "selfhost/llvm/text/context_prepare.slg",
)
OUTPUT = ROOT / "artifacts/scratch/c527-member-source-order-20260929-01.json"


def line(lines: list[str], needle: str) -> int:
    matches = [i + 1 for i, value in enumerate(lines) if needle in value]
    if len(matches) != 1:
        raise ValueError(f"expected one occurrence of {needle!r}, got {matches}")
    return matches[0]


def main() -> None:
    data = {name: (ROOT / name).read_bytes() for name in SOURCES}
    managed, semantic_types, inference, preparation = (
        data[name].decode("utf-8-sig").splitlines() for name in SOURCES
    )
    managed_method = line(managed, "private BoundType InferFieldAccessExpression(")
    managed_member_lines = managed[managed_method - 1:managed_method + 190]
    managed_source_type = managed_method - 1 + line(managed_member_lines, "var sourceType = InferExpression(")
    managed_field_return = managed_method - 1 + line(managed_member_lines, "            return field.Type;")
    managed_display = line(managed, "EnsureDisplayable(interpolationType, expression.Line")
    if not (managed_method < managed_source_type < managed_field_return):
        raise ValueError("C# field decision order changed")
    pre_ir_field = line(semantic_types, "[Int; ~] => interpolationMemberTypeByNode!")
    pre_ir_field_lookup = line(semantic_types, "prepared -> memberFieldIndex(types!, fields!")
    resolve_types = line(preparation, "prepared -> expressionTypeIds.resolveContext")
    pre_ir_display = line(preparation, "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode")
    lower_ir = line(preparation, "prepared -> lowerPreparedIr(recursiveTypes!")
    post_ir_member = line(preparation, "prepared -> interpolationInference.memberResultTypeByNode")
    post_ir_display = line(preparation, "prepared -> interpolationInference.invalidDisplayTypeByNode")
    if not (pre_ir_field < pre_ir_field_lookup and resolve_types < pre_ir_display < lower_ir < post_ir_member < post_ir_display):
        raise ValueError("SLG member or displayability order changed")
    direct_display_function = line(inference, "public preIrInvalidDirectDisplayTypeByNode prepared:")
    display_function = line(inference, "public invalidDisplayTypeByNode prepared:")
    direct_body = inference[direct_display_function - 1:display_function - 1]
    direct_member_guard = line(inference, "memberSeparators! == 1 -> if {")
    direct_field_lookup = direct_display_function - 1 + line(direct_body, "prepared -> expressionTypeIds.memberFieldIndex(bindingFacts.types")
    private_field_guard = line(inference, "declaration.flags / 4 % 2 == 0 -> if { false => accessible! }")
    member_function = line(inference, "public memberResultTypeByNode prepared:")
    if not (member_function < direct_display_function < direct_member_guard < direct_field_lookup < private_field_guard < display_function):
        raise ValueError("SLG member result is not prepared before displayability")
    result = {
        "schemaVersion": 1,
        "unit": "C527-pre-IR-member-result-source-comparison",
        "status": "passed",
        "managedDecision": "Field access infers its source, unwraps reference and box, checks struct field visibility and ownership, and returns field type during semantic analysis; interpolation then checks displayability.",
        "selfhostDecision": "Semantic type preparation resolves a direct lexical struct field and accessible single-member displayability before Typed IR; other member results and displayability remain after Typed IR lowering.",
        "managedMethodLine": managed_method,
        "managedFieldReturnLine": managed_field_return,
        "managedInterpolationDisplayLine": managed_display,
        "semanticPreIrFieldLine": pre_ir_field,
        "semanticPreIrFieldLookupLine": pre_ir_field_lookup,
        "preparationOrder": {
            "resolveTypes": resolve_types,
            "directMemberDisplayability": pre_ir_display,
            "lowerTypedIr": lower_ir,
            "memberResult": post_ir_member,
            "displayability": post_ir_display,
        },
        "sourceSha256": {name: hashlib.sha256(content).hexdigest().upper() for name, content in data.items()},
        "priorFocusedMemberUnit": "artifacts/scratch/c582-member-field-preir-unit-20260928-01.json",
        "boundary": "Accessible single-member lexical struct-field displayability is checked before Typed IR. Nested paths, reference, box, method, enum, ownership, and indexed source cases need separate comparison before migration.",
        "fullPreIrExpressionClosure": False,
        "structuralPhasesClosed": "0/7",
    }
    OUTPUT.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: current C# and SLG member decision timing compared")


if __name__ == "__main__":
    main()
