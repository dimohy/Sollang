import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.ast as ast

main {
    [
        """
        struct Item { value: Int }
        main {
            [1, 2, ~] => values
            [Item; ~] => items
            values
        }
        """,
        ~
    ] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources![0] -> ast.lower => nodes!
    inferred! -> each item {
        nodes![item.astNode].kind == 37 -> if {
            "array expression = $(nodes![item.astNode].kind),$(item.origin),$(item.targetModule),$(item.targetSymbol)" -> println
        }
    }
}
