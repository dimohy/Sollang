import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.type_check as typeCheck
import smalllang.compiler.ast as ast

main {
    ["struct Store {\nvalues: [Int; ~]\n}\nget store: Store -> [Int; ~] => store.values\nmain { }", ~] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources! -> typeCheck.analyze => errors!
    sources![0] -> ast.lower => nodes!
    inferred! -> each item {
        nodes![item.astNode].kind == 36 -> if {
            "composite member = $(item.origin),$(item.targetModule),$(item.targetSymbol)" -> println
        }
    }
    "composite member errors = $(errors! -> len)" -> println
}
