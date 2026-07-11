import smalllang.compiler.cst as cst

main {
    cst.build("main { 42 -> println } # note") => nodes!
    nodes! -> len => nodeCount
    nodes![0] => root
    "nodes = $nodeCount" -> println
    "root rule = $(root.ruleId)" -> println
    "root parent = $(root.parent)" -> println
    "root tokens = $(root.tokenCount)" -> println
    "root span = $(root.start),$(root.length)" -> println
}
