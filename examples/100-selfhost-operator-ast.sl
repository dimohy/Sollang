import smalllang.compiler.ast as ast

main {
    ast.lower("main { 1 + 2 * 3 == 7 }") => nodes!
    nodes! -> each node {
        node.kind >= 18 -> if {
            "operator = $(node.kind),$(node.parent),$(node.operatorKind),$(node.payloadToken),$(node.start),$(node.length)" -> println
        }
    }
}
