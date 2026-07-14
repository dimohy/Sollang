import smalllang.compiler.ast
import smalllang.compiler.ir.typed as typedIr
import smalllang.compiler.semantic.calls
import smalllang.compiler.semantic.expression_types as expressionTypes
import smalllang.compiler.semantic.resolve as resolution
import smalllang.compiler.semantic.symbols
import smalllang.compiler.semantic.type_check as typeCheck

main {
    [
        """
        namespace sample.roles

        public relay<T> value: T -> T block item: T {
            value -> yield
            value
        }

        public visit<T> values: [T; ~] -> Int block item: T {
            values![0] -> yield
            1
        }

        public collect<T> value: T -> Int block items: [T; ~] {
            [value, ~] => yielded!
            yielded! -> yield
            1
        }
        """,
        """
        namespace app.main
        import sample.roles

        main {
            7 -> roles.relay item {
                item + 1
            } => relayed
            [1, 2, ~] -> roles.visit element {
                element + 1
            } => visited
            9 -> roles.collect items {
                items![0] + 1
            } => collected
            relayed + visited + collected
        }
        """,
        ~
    ] => sources!
    sources! -> expressionTypes.infer => inferred!
    sources! -> calls.resolveModules => resolvedCalls!
    sources! -> typeCheck.analyze => errors!
    sources![1] -> ast.lower => nodes!
    sources![1] -> symbols.collect => table!
    sources![1] -> resolution.resolve => resolvedNames!
    sources! -> typedIr.lower => ir!

    0 => specializedItems!
    0 => specializedCompositeItems!
    0 => typedBodyOperators!
    0 => resolvedRoles!
    0 => resolvedIndex!
    resolvedIndex! < (resolvedNames! -> len) -> while {
        resolvedNames![resolvedIndex!] => resolved
        table![resolved.symbol] => symbol
        (symbol.kind == 35 and nodes![symbol.astNode].kind == 48) -> if {
            0 => itemTypeIndex!
            itemTypeIndex! < (inferred! -> len) -> while {
                inferred![itemTypeIndex!] => itemType
                (itemType.sourceModule == 1 and itemType.astNode == resolved.astNode and itemType.origin == 1 and itemType.targetSymbol == 2) -> if {
                    specializedItems! + 1 => specializedItems!
                }
                (itemType.sourceModule == 1 and itemType.astNode == resolved.astNode and itemType.origin == 13 and itemType.targetModule == -1 and itemType.targetSymbol == 2) -> if {
                    specializedCompositeItems! + 1 => specializedCompositeItems!
                }
                itemTypeIndex! + 1 => itemTypeIndex!
            }
        }
        resolvedIndex! + 1 => resolvedIndex!
    }
    resolvedCalls! -> each call {
        (call.sourceModule == 1 and call.status == 0 and nodes![call.callAst].kind == 48) -> if {
            resolvedRoles! + 1 => resolvedRoles!
        }
    }
    ir! -> each node {
        (node.sourceModule == 1 and nodes![node.astNode].kind == 20 and node.typeOrigin == 1 and node.typeSymbol == 2) -> if {
            typedBodyOperators! + 1 => typedBodyOperators!
        }
    }

    specializedItems! => scalarCount
    specializedCompositeItems! => compositeCount
    resolvedRoles! => roleCount
    typedBodyOperators! => operatorCount
    "generic role counts = errors:$((errors! -> len)),scalar:$scalarCount,composite:$compositeCount,roles:$roleCount,operators:$operatorCount" -> println
    ((errors! -> len) == 0 and specializedItems! == 2 and specializedCompositeItems! == 1 and resolvedRoles! == 3 and typedBodyOperators! >= 3) -> if {
        "generic role specialization = valid"
    } else {
        "generic role specialization = invalid"
    } -> println
}
