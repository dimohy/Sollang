import smalllang.compiler.ir.typed as typedIr

main {
    [
        """
        attempt value: Int -> Result<Int, Text> = intrinsic

        main {
            [1, 2, 3, ~] => values!
            values! -> tryParallel value {
                value -> attempt
            } => result
        }
        """,
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    false => callOk!
    false => bindingOk!
    ir! -> each node {
        (node.kind == 6 and node.opcode == -209 and node.typeKind == 7 and node.typeSymbol == 1) -> if {
            true => callOk!
        }
        (node.kind == 17 and node.operand0 >= 0 and ir![node.operand0].opcode == -209 and node.typeKind == 7 and node.typeSymbol == 1) -> if {
            true => bindingOk!
        }
    }
    (callOk! and bindingOk!) -> if {
        "tryParallel IR = valid"
    } else {
        "tryParallel IR = invalid"
    } -> println
}
