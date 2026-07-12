namespace smalllang.compiler.semantic.type_resolve

import smalllang.compiler.ast as ast
import smalllang.compiler.semantic.qualified as qualified
import smalllang.compiler.semantic.types as types

public struct ResolvedType {
    sourceModule: Int
    typeAst: Int
    canonical: Int
    targetModule: Int
    targetSymbol: Int
    status: Int
}

# Links source-local canonical type uses to module-qualified nominal symbols.
# Status follows qualified resolution: 0 public, 2 missing, 3 non-public.
public resolve sources: [Text; ~] -> [ResolvedType; ~] {
    sources -> qualified.resolve => qualifiedResults!
    [ResolvedType; ~] => results!
    sources -> len => sourceCount
    0 => sourceIndex!
    sourceIndex! < sourceCount -> while {
        sources[sourceIndex!] => source
        source -> ast.lower => nodes!
        source -> types.canonicalize => typeUses!
        0 => typeIndex!
        typeIndex! < (typeUses! -> len) -> while {
            typeUses![typeIndex!] => typeUse
            0 => qualifiedIndex!
            qualifiedIndex! < (qualifiedResults! -> len) -> while {
                qualifiedResults![qualifiedIndex!] => candidate
                candidate.sourceModule == sourceIndex! -> if {
                    candidate.pathAst => ancestor!
                    false => belongsToType!
                    (ancestor! >= 0 and not belongsToType!) -> while {
                        ancestor! == typeUse.astNode -> if {
                            true => belongsToType!
                        } else {
                            nodes![ancestor!].parent => ancestor!
                        }
                    }
                    belongsToType! -> if {
                        ResolvedType {
                            sourceModule: sourceIndex!
                            typeAst: typeUse.astNode
                            canonical: typeUse.canonical
                            targetModule: candidate.targetModule
                            targetSymbol: candidate.targetSymbol
                            status: candidate.status
                        } => result
                        results! -> push(result)
                    }
                }
                qualifiedIndex! + 1 => qualifiedIndex!
            }
            typeIndex! + 1 => typeIndex!
        }
        sourceIndex! + 1 => sourceIndex!
    }
    results!
}
