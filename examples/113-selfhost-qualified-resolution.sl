import smalllang.compiler.semantic.qualified as qualified

main {
    ["namespace sample.math\npublic struct Number { }", "namespace app.main\nimport sample.math as math\nmain {\nmath.Number\n}", ~] => sources!
    sources! -> qualified.resolve => results!
    results! -> each result {
        "qualified = $(result.sourceModule),$(result.targetModule),$(result.targetSymbol),$(result.status)" -> println
    }
}
