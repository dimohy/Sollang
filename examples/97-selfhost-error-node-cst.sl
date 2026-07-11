import smalllang.compiler.cst as cst

main {
    cst.build("main { -> }") => nodes!
    nodes! -> len => nodeCount
    nodes![0] => root
    "nodes = $nodeCount" -> println
    "root = $(root.tokenCount),$(root.start),$(root.length)" -> println
    nodes! -> each node {
        node.ruleId == -1 -> if {
            "error = $(node.parent),$(node.firstToken),$(node.tokenCount),$(node.start),$(node.length)" -> println
        }
    }
}
