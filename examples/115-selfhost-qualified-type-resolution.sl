import smalllang.compiler.semantic.type_resolve as typeResolve

main {
    ["namespace sample.math\npublic struct Number { }", "namespace app.main\nimport sample.math as math\nstruct Holder {\nvalue: math.Number\n}", ~] => sources!
    sources! -> typeResolve.resolve => results!
    results! -> each result {
        "type = $(result.sourceModule),$(result.canonical),$(result.targetModule),$(result.targetSymbol),$(result.status)" -> println
    }
}
