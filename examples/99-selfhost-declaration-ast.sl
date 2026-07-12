import smalllang.compiler.ast as ast

main {
    ast.lower("double value: Int -> Int { value * 2 } main { 5 -> double }") => nodes!
    nodes! -> len => count
    "ast nodes = $count" -> println
    nodes! -> each node {
        "kind = $(node.kind), parent = $(node.parent), rule = $(node.cstRuleId), span = $(node.start),$(node.length)" -> println
    }
}
