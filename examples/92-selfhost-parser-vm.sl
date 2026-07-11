import smalllang.compiler.parser as parser

main {
    parser.accepts("main { 42 -> println }") => valid
    parser.accepts("main { -> }") => invalid
    valid -> if { "valid = true" } else { "valid = false" } -> println
    invalid -> if { "invalid = true" } else { "invalid = false" } -> println
}
