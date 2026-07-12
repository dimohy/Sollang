import smalllang.compiler.semantic.type_check as typeCheck

main {
    ["namespace private.math\ndouble value: Int -> Int => value + value", "namespace app.main\nimport private.math as math\nmain { math.double(1) }", ~] => sources!
    sources! -> typeCheck.analyze => errors!
    errors! -> each error {
        sources![error.sourceModule] -> slice(error.span.start, error.span.length) => call
        "private call diagnostic = $(error.code),$call,$(error.span.start),$(error.span.length)" -> println
    }
}
