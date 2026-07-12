import smalllang.compiler.semantic.qualified as qualified

main {
    ["namespace private.model\nstruct Hidden { }", "namespace app.main\nimport private.model as model\nmain {\nmodel.Hidden\n}", ~] => sources!
    sources! -> qualified.resolve => results!
    results![0] => result
    "visibility = $(result.targetModule),$(result.targetSymbol),$(result.status)" -> println
}
