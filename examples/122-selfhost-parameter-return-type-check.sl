import smalllang.compiler.semantic.type_check as typeCheck

main {
    ["identity value: Int -> Int => value\nwrong value: Text -> Int => value\nmain { }", ~] => sources!
    sources! -> typeCheck.analyze => errors!
    errors! -> each error {
        sources![error.sourceModule] -> slice(error.span.start, error.span.length) => expression
        "parameter mismatch = $(error.code),$(error.expectedSymbol),$(error.actualSymbol),$expression,$(error.span.start),$(error.span.length)" -> println
    }
}
