import smalllang.compiler.ast
import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.semantic.expression_type_ids as expressionTypeIds
import smalllang.compiler.semantic.type_check as typeCheck

main {
    [
        """
        namespace sample.generic

        public project<T> value: Result<[T; ~], {Text: box T}> -> Result<[T; ~], {Text: box T}> => value

        public swap<K, V> value: Result<K, V> -> Result<V, K> => value

        public arrayCopy<T> values: [T; ~] -> [T; ~] => values

        public dictionaryCopy<K, V> value: {K: V} -> {K: V} => value

        public wrap<T> value: box T -> box T => value
        """,
        """
        namespace app.main
        import sample.generic as generic

        projectInt value: Result<[Int; ~], {Text: box Int}> -> Result<[Int; ~], {Text: box Int}> => generic.project(value)

        badProject value: Result<[Int; ~], {Text: box Text}> -> Result<[Int; ~], {Text: box Int}> => generic.project(value)

        swapIntText value: Result<Int, Text> -> Result<Text, Int> => generic.swap(value)

        arrayLiteral: -> [Int; ~] => generic.arrayCopy([1, 2, ~])

        dictionaryLiteral: -> {Int: Text} => generic.dictionaryCopy({1: "one"})

        boxLiteral: -> box Int => generic.wrap(box 1)

        main { }
        """,
        ~
    ] => sources!
    sources! -> expressionTypeIds.resolve => resolved
    sources! -> typedIr.lower => ir!
    sources! -> typeCheck.analyze => diagnostics!
    0 => argumentErrors!
    diagnostics! -> each diagnostic {
        diagnostic.code == 6 -> if { argumentErrors! + 1 => argumentErrors! }
    }
    0 => validCalls!
    resolved.expressions -> each expression {
        sources![expression.sourceModule] -> ast.lower => nodes!
        nodes![expression.astNode].kind == 11 -> if {
            resolved.types[expression.typeId] => result
            false => valid!
            (expression.status == 0 and result.kind == 7 and result.symbol == 1 and not result.containsParameter) -> if {
                (result.first == 1 and result.second == 2) -> if { true => valid! }
                resolved.types[result.first] => first
                resolved.types[result.second] => second
                (first.kind == 3 and second.kind == 5 and resolved.types[first.first].symbol == 2 and resolved.types[second.first].symbol == 1 and resolved.types[resolved.types[second.second].first].symbol == 2) -> if {
                    true => valid!
                }
            }
            (expression.status == 0 and result.kind == 3 and not result.containsParameter and resolved.types[result.first].symbol == 2) -> if { true => valid! }
            (expression.status == 0 and result.kind == 5 and not result.containsParameter and resolved.types[result.first].symbol == 2 and resolved.types[result.second].symbol == 1) -> if { true => valid! }
            (expression.status == 0 and result.kind == 6 and not result.containsParameter and resolved.types[result.first].symbol == 2) -> if { true => valid! }
            valid! -> if { validCalls! + 1 => validCalls! }
        }
    }
    0 => typedCalls!
    ir! -> each node {
        (node.kind == 6 and node.typeId >= 0) -> if {
            resolved.types[node.typeId] => result
            not result.containsParameter -> if { typedCalls! + 1 => typedCalls! }
        }
    }
    "recursive generic calls = $(validCalls!), typed calls = $(typedCalls!), argument errors = $(argumentErrors!), total = $(diagnostics! -> len)" -> println
}
