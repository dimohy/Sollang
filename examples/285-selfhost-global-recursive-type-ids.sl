import smalllang.compiler.semantic.type_ids as typeIds

main {
    [
        """
        namespace sample.model

        public struct Point {
            x: Int
        }

        public keep value: Result<[Point; ~], {Text: box Point}> -> Result<[Point; ~], {Text: box Point}> => value
        """,
        """
        namespace app.main
        import sample.model as model

        keep value: Result<[model.Point; ~], {Text: box model.Point}> -> Result<[model.Point; ~], {Text: box model.Point}> => value

        main { }
        """,
        ~
    ] => sources!
    sources! -> typeIds.resolve => resolved

    -1 => modelRoot!
    -1 => appRoot!
    0 => resultReferences!
    0 => failedReferences!
    resolved.references -> each reference {
        reference.status != 0 -> if { failedReferences! + 1 => failedReferences! }
        resolved.types[reference.typeId] => semanticType
        (semanticType.kind == 7 and semanticType.origin == 4 and semanticType.symbol == 1) -> if {
            resultReferences! + 1 => resultReferences!
            reference.sourceModule == 0 -> if { reference.typeId => modelRoot! }
            reference.sourceModule == 1 -> if { reference.typeId => appRoot! }
        }
    }

    (failedReferences! == 0 and resultReferences! == 4 and modelRoot! >= 0 and modelRoot! == appRoot!) -> if {
        "global recursive type ids = valid"
    } else {
        "global recursive type ids = invalid"
    } -> println
}
