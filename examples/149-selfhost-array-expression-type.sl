import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.ast as ast

main {
    ["main {\n[1, 2, ~] => values\nvalues\n}", ~] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources![0] -> ast.lower => nodes!
    inferred! -> each item {
        nodes![item.astNode].kind == 37 -> if {
            "array expression = $(nodes![item.astNode].kind),$(item.origin),$(item.targetModule),$(item.targetSymbol)" -> println
        }
    }
}
