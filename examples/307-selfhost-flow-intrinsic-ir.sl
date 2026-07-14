import smalllang.compiler.ir.typed as typedIr

main {
    [
        """"
        struct Span { start: UIntSize }
        struct Token { span: Span }
        inspect: -> UInt8 {
            "abc" => source
            UIntSize(0) => index
            source -> byte(index)
        }
        excerpt: -> Text {
            "abc" => source
            UIntSize(0) => start
            UIntSize(2) => count
            source -> slice(start, count)
        }
        size: -> UIntSize {
            "abc" => source
            source -> len
        }
        tokenStart token: Token -> UIntSize {
            token.span.start
        }
        """",
        ~
    ] => sources!
    sources! -> typedIr.lower => ir!
    ir! -> each node {
        (node.opcode <= -201 and node.opcode >= -203) -> if {
            "intrinsic = $(node.opcode),type=$(node.typeSymbol),base=$(node.operand0),argument=$(node.operand1)" -> println
        }
        node.kind == 13 -> if {
            "member = type=$(node.typeSymbol),base=$(node.operand0)" -> println
        }
    }
}
