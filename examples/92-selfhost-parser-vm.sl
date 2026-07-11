import smalllang.compiler.parser as parser

main {
    parser.parseEvents("main { 42 -> println } # note") => validEvents!
    validEvents! -> len => validEventCount
    validEvents![validEventCount - 1].value => valid
    parser.parseEvents("main { -> }") => invalidEvents!
    invalidEvents! -> len => invalidEventCount
    invalidEvents![invalidEventCount - 1].value => invalid
    valid == 1 -> if { "valid = true" } else { "valid = false" } -> println
    invalid == 1 -> if { "invalid = true" } else { "invalid = false" } -> println
    "events = $validEventCount" -> println
}
