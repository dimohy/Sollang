import smalllang.compiler.semantic.type_check as typeCheck

main {
    ["namespace sample.shapes\npublic struct Point {\nx: Int\ny: Int\n}", "namespace app.main\nimport sample.shapes as shapes\nmain { shapes.Point { x: 1 } }", ~] => sources!
    sources! -> typeCheck.analyze => errors!
    errors! -> each error {
        sources![error.sourceModule] -> slice(error.span.start, error.span.length) => literal
        "imported missing field = $(error.code),$(error.expectedSymbol),$literal,$(error.span.fileId),$(error.span.start),$(error.span.length)" -> println
    }
}
