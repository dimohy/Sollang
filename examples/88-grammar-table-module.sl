import syntax.generated.smalllang as grammar

main {
    grammar.tokenCount => tokenCount
    grammar.ruleCount => ruleCount
    grammar.programWordCount => wordCount
    "grammar tokens = $tokenCount" -> println
    "grammar rules = $ruleCount" -> println
    "grammar words = $wordCount" -> println
}
