import smalllang.compiler.semantic.type_diagnostics as typeDiagnostics

main {
    ["namespace sample.math\npublic struct Number { }", "namespace app.main\nimport sample.math as math\nstruct Holder {\nvalue: math.Missing\n}", ~] => sources!
    sources! -> typeDiagnostics.analyze => errors!
    errors! -> each error {
        sources![error.sourceModule] -> slice(error.span.start, error.span.length) => typeName
        "type diagnostic = $(error.code),$typeName,$(error.span.fileId),$(error.span.start),$(error.span.length),$(error.targetSymbol)" -> println
    }
}
