import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.type_check as typeCheck
import smalllang.compiler.ast as ast

main {
    ["namespace sample.shapes\npublic struct Point {\nx: Int\n}", "namespace app.main\nimport sample.shapes as shapes\nget point: shapes.Point -> Int => point.x\nmain { }", ~] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources! -> typeCheck.analyze => errors!
    sources![1] -> ast.lower => nodes!
    inferred! -> each item {
        (item.sourceModule == 1 and nodes![item.astNode].kind == 36) -> if {
            "imported member type = $(item.origin),$(item.targetModule),$(item.targetSymbol)" -> println
        }
    }
    "imported member errors = $(errors! -> len)" -> println
}
