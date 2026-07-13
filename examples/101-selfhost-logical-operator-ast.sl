import smalllang.compiler.ast as ast

main {
    """
    main {
        true or false and not false
    }
    """ -> ast.lower => nodes!
    nodes! -> len => count
    0 => index!
    index! < count -> while {
        nodes![index!] => node
        node.kind >= 22 -> if {
            "logical = $(node.kind),$(node.parent),$(node.operatorKind),$(node.payloadToken),$(node.start),$(node.length)" -> println
        }
        index! + 1 => index!
    }
}
