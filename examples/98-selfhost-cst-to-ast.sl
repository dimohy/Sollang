import smalllang.compiler.ast as ast

main {
    """
    main {
        42 -> println
    }
    """ -> ast.lower => nodes!
    nodes! -> len => count
    "ast nodes = $count" -> println
    nodes! -> each node {
        "ast = $(node.kind),$(node.parent),$(node.cstRuleId),$(node.firstToken),$(node.tokenCount),$(node.start),$(node.length)" -> println
    }
}
