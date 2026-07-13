import smalllang.compiler.ast as ast

main {
    """
    compute value: Int -> async Int {
        value * value
    }

    main {
    }
    """ -> ast.lower => nodes!
    nodes! -> each node {
        node.kind == 7 -> if {
            "function flags = $(node.flags)" -> println
        }
    }
}
