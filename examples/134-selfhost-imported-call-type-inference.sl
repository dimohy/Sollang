import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.ast as ast

main {
    ["namespace sample.math\npublic double value: Int -> Int => value + value", "namespace app.main\nimport sample.math as math\nmain { math.double(2) }", ~] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources![1] -> ast.lower => nodes!
    inferred! -> each item {
        (item.sourceModule == 1 and nodes![item.astNode].kind == 11) -> if {
            "imported call type = $(item.origin),$(item.targetModule),$(item.targetSymbol)" -> println
        }
    }
}
