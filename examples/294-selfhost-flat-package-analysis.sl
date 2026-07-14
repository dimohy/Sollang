import smalllang.compiler.semantic.analysis

main {
    [
        """
        namespace sample.first

        public keep value: Int -> Int => value

        main {
            7 -> keep => result
        }
        """,
        """
        namespace sample.second

        public twice value: Int -> Int => value + value

        main {
            9 -> twice => result
        }
        """,
        ~
    ] => sources!

    sources! -> analysis.analyze => package
    package.ranges[0] => first
    package.ranges[1] => second
    (package.ranges -> len) == 2 and first.sourceModule == 0 and second.sourceModule == 1 and first.astStart == 0 and second.astStart == first.astCount and first.tokenStart == 0 and second.tokenStart == first.tokenCount and first.symbolStart == 0 and second.symbolStart == first.symbolCount and first.nameStart == 0 and second.nameStart == first.nameCount and (package.nodes -> len) == first.astCount + second.astCount and (package.tokens -> len) == first.tokenCount + second.tokenCount and (package.symbols -> len) == first.symbolCount + second.symbolCount and (package.names -> len) == first.nameCount + second.nameCount and package.nodes[first.astStart].kind == 0 and package.nodes[second.astStart].kind == 0 => flat
    flat -> if { "true" } else { "false" } => flatText
    "flat=$flatText, sources=$(package.ranges -> len), ast=$(package.nodes -> len), symbols=$(package.symbols -> len), names=$(package.names -> len)" -> println
}
