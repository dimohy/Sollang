import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.ast as ast

main {
    ["main {\n1 => x\nx + 2\n}", ~] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources![0] -> ast.lower => nodes!
    inferred! -> each item {
        (nodes![item.astNode].kind == 15 or nodes![item.astNode].kind == 20) -> if {
            "binding type = $(nodes![item.astNode].kind),$(item.targetSymbol)" -> println
        }
    }
}
