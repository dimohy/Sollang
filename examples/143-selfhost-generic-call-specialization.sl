import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.type_check as typeCheck
import smalllang.compiler.ast as ast

main {
    ["identity<T> value: T -> T => value\nuse: -> Int => identity(1 + 2)\nmain { }", ~] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources! -> typeCheck.analyze => errors!
    sources![0] -> ast.lower => nodes!
    inferred! -> each item {
        nodes![item.astNode].kind == 11 -> if {
            "specialized call = $(item.origin),$(item.targetModule),$(item.targetSymbol)" -> println
        }
    }
    "specialization errors = $(errors! -> len)" -> println
}
