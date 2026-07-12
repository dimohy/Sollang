import smalllang.compiler.semantic.type_check as typeCheck

main {
    ["struct Point {\nx: Int\n}\nget point: Point -> Int => point.y\nmain { }", ~] => sources!
    sources! -> typeCheck.analyze => errors!
    errors! -> each error {
        sources![error.sourceModule] -> slice(error.span.start, error.span.length) => member
        "unknown member = $(error.code),$(error.expectedSymbol),$member,$(error.span.start),$(error.span.length)" -> println
    }
}
