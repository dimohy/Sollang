import smalllang.compiler.ir.typed as typedIr

main {
    [
        """"
        struct OwnedValues {
            values: [Int; ~]
        }

        makeValues: -> [OwnedValues; ~] => [
            OwnedValues { values: [10, 11, ~] },
            OwnedValues { values: [20, 21, 22, ~] },
            ~
        ]

        main {
            makeValues => items!
            items! -> take(0) => item!
            item!.values -> len -> println
        }
        """",
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    0 => takes!
    ir! -> each node {
        node.opcode == -213 -> if {
            takes! + 1 => takes!
            "take kind=$(node.kind),typeId=$(node.typeId),typeOrigin=$(node.typeOrigin),typeKind=$(node.typeKind),base=$(node.operand0),index=$(node.operand1)" -> println
        }
    }
    "take count=$(takes!)" -> println
}
