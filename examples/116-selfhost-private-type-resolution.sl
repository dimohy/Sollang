import smalllang.compiler.semantic.type_resolve as typeResolve

main {
    ["namespace private.model\nstruct Hidden { }", "namespace app.main\nimport private.model as model\nstruct Holder {\nvalue: model.Hidden\n}", ~] => sources!
    sources! -> typeResolve.resolve => results!
    results! -> each result {
        "private type = $(result.targetModule),$(result.targetSymbol),$(result.status)" -> println
    }
}
