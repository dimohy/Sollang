import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.semantic.composite_types as compositeTypes
import smalllang.compiler.semantic.modules as modules
import smalllang.compiler.semantic.nominal_types as nominalTypes
import smalllang.compiler.semantic.type_ids as typeIds

main {
    [
        """
        struct Point {
            values: [Int; ~]
        }

        keep value: Point -> Point => value

        main {
            Point { values: [1, 2, ~] } -> keep => point
        }
        """,
        ~
    ] => sources!

    sources! -> typeIds.resolve => semantic
    sources! -> nominalTypes.resolve => nominal!
    sources! -> compositeTypes.resolve => composite!
    sources! -> modules.identities => moduleIdentities!
    [Text; ~] => preparedSources!
    sources! -> each preparedSource { preparedSources! -> push(preparedSource) }
    [typeIds.SemanticType; ~] => preparedTypes!
    semantic.types -> each preparedType { preparedTypes! -> push(preparedType) }
    [typeIds.TypeReference; ~] => preparedReferences!
    semantic.references -> each preparedReference { preparedReferences! -> push(preparedReference) }
    [typeIds.NominalField; ~] => preparedFields!
    semantic.fields -> each preparedField { preparedFields! -> push(preparedField) }
    typedIr.TypedIrRequest {
        sources: preparedSources!
        types: preparedTypes!
        references: preparedReferences!
        fields: preparedFields!
        nominal: nominal!
        composite: composite!
        modules: moduleIdentities!
    } => request!
    request! -> typedIr.lowerPrepared => prepared!
    sources! -> typedIr.lower => baseline!

    (prepared! -> len) == (baseline! -> len) => equal!
    0 => canonical!
    0 => nodeIndex!
    (equal! and nodeIndex! < (prepared! -> len)) -> while {
        prepared![nodeIndex!] => left
        baseline![nodeIndex!] => right
        (left.kind != right.kind or left.typeId != right.typeId or left.typeKind != right.typeKind or left.typeFlags != right.typeFlags) -> if { false => equal! }
        left.typeId >= 0 -> if { canonical! + 1 => canonical! }
        nodeIndex! + 1 => nodeIndex!
    }
    equal! -> if { "true" } else { "false" } => equalText
    "prepared=$equalText, nodes=$(prepared! -> len), canonical=$(canonical!)" -> println
}
