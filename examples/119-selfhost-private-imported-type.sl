import smalllang.compiler.semantic.type_diagnostics as typeDiagnostics

main {
    ["namespace private.model\nstruct Hidden { }", "namespace app.main\nimport private.model as model\nstruct Holder {\nvalue: model.Hidden\n}", ~] => sources!
    sources! -> typeDiagnostics.analyze => errors!
    errors! -> each error {
        sources![error.sourceModule] -> slice(error.span.start, error.span.length) => typeName
        "type diagnostic = $(error.code),$typeName,$(error.span.fileId),$(error.span.start),$(error.span.length),$(error.targetSymbol)" -> println
    }
}
