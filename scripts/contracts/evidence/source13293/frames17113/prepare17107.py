from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22');o=b/'frames17107-candidate';o.mkdir(exist_ok=False)
proof=json.loads((b/'frames17106-reference22/source-frame-result.json').read_text());assert proof['status']=='passed' and proof['completed']==22
(b/'frames17107-source-comparison.json').write_text(json.dumps(dict(status='compared-before-slg-edit',csharp=(b/'frames17106-reference22/source-frame-result.json').as_posix(),managedSources=['src/Sollang.Compiler/Semantics/StoragePlacementAnalyzer.cs'],decisions=['Collect each direct binding literal using canonical literal storage syntax; fixed payloads bypass readonly-use admission, dynamic/dictionary payloads require immutable whole-scope admission.','Use the last containing source unit for payload lifetime; mutable heap owners instead own a 24-byte header through the end of their source scope and have no automatic lifetime end.','Preserve per-function frame ownership and the existing allocator stable start ordering, inclusive overlap, cheapest slot growth, 4096-byte budget, and original lifetime sizes.','Async functions produce no stack frame; inline frame merge and final LLVM consumers are separate pending paths.'],pending=['Typed non-Int payload admission controls','Broader heap producer source forms and readonly controls','Inline frame merge and shared LLVM consumers','Current general Native and final gates'],claimsGoalComplete=False),indent=2)+'\n',encoding='utf-8')
(o/'storage_placement_frames.slg').write_text('''namespace sollang.compiler.semantic.storage_placement_frames

import sollang.compiler.semantic.context as semanticContext
import sollang.compiler.semantic.expression_type_ids as expressionTypes
import sollang.compiler.semantic.storage_placement as placement
import sollang.compiler.semantic.storage_placement_literals as literals
import sollang.compiler.semantic.storage_placement_source_index as sourceIndex
import sollang.compiler.semantic.storage_placement_units as sourceUnits
import sollang.compiler.semantic.storage_placement_uses as ownerUses
import sollang.compiler.semantic.type_ids as typeIds
import syntax.generated.slg as grammar

public enum Error { InvalidSourceDomain, InvalidFrame, InvalidLiteral, InvalidLifetime, InvalidPlacement }
public struct FramePlan {
    public frameAst: Int
    public candidates: [placement.Candidate; ~]
    public slots: [placement.Slot; ~]
    public slotsByCandidate: [Int; ~]
    public ends: [placement.LifetimeEnd; ~]
}

valueChild nodeIndex: Int, prepared: ref semanticContext.SemanticSnapshot, sourceModule: Int, indexed: ref sourceIndex.SourceIndex -> Int {
    prepared.package.ranges[sourceModule] => range
    indexed.firstChild[nodeIndex] => child!
    child! >= 0 -> while {
        prepared.package.nodes[range.astStart + child!].kind => kind
        kind != 12 and kind != 16 and kind != 17 -> if { child! -> return }
        indexed.nextSibling[child!] => child!
    }
    -1
}

scopeEnd scope: Int, frame: Int, units: ref sourceUnits.UnitPlan -> Int {
    -1 => selected!
    -1 => position!
    units.units -> each unit {
        unit.scopeAst == scope and unit.frameAst == frame and unit.position > position! -> if {
            unit.astNode => selected!
            unit.position => position!
        }
    }
    selected!
}

intType typeId: Int, facts: ref expressionTypes.ExpressionTypeIdSet -> Bool {
    typeId < 0 or typeId >= (facts.types -> len) -> if { false -> return }
    facts.types[typeId] => type
    type.kind == 1 and type.origin == 1 and (type.symbol -> typeIds.canonicalBuiltinSymbol) == 2
}

heapCall callAst: Int, prepared: ref semanticContext.SemanticSnapshot, facts: ref expressionTypes.ExpressionTypeIdSet, sourceModule: Int -> Bool {
    false => selected!
    prepared.calls -> each call {
        call.sourceModule == sourceModule and call.callAst == callAst and call.status == 0
            and call.functionSymbol >= 0 -> if { true => selected! }
    }
    not selected! -> if { false -> return }
    facts.expressions -> each value {
        value.sourceModule == sourceModule and value.astNode == callAst and value.status == 0 and value.typeId >= 0 -> if {
            facts.types[value.typeId] => type
            type.kind == 3 and (type.first -> intType(facts)) -> if { true -> return }
            type.kind == 5 and (type.first -> intType(facts)) and (type.second -> intType(facts)) -> if { true -> return }
        }
    }
    false
}

mutableName nodeIndex: Int, prepared: ref semanticContext.SemanticSnapshot, sourceModule: Int -> Bool {
    prepared.package.ranges[sourceModule] => range
    prepared.package.nodes[range.astStart + nodeIndex] => node
    node.payloadToken + 1 => token!
    token! < node.firstToken + node.tokenCount -> while {
        prepared.package.tokens[range.tokenStart + token!] => next
        next.kind == grammar.triviaIdWhitespace() or next.kind == grammar.triviaIdComment()
            -> if { token! + 1 => token! } else {
                next.span.length == 1 and (prepared.package.sources[sourceModule] -> byte(next.span.start)) == 33 -> return
            }
    }
    false
}

heapBody bodyAst: Int, frame: Int, source: Text, prepared: ref semanticContext.SemanticSnapshot, facts: ref expressionTypes.ExpressionTypeIdSet, sourceModule: Int, indexed: ref sourceIndex.SourceIndex, units: ref sourceUnits.UnitPlan -> Bool {
    prepared.package.ranges[sourceModule] => range
    -1 => result!
    units.units -> each unit {
        unit.frameAst == frame and unit.scopeAst == bodyAst and unit.isResult -> if { unit.astNode => result! }
    }
    result! < 0 -> if { false -> return }
    prepared.package.nodes[range.astStart + result!] => value
    value.kind == 15 -> if {
        prepared.package.tokens[range.tokenStart + value.payloadToken] => name
        source -> slice(name.span.start, name.span.length) => spelling
        result! -> mutableName(prepared, sourceModule) => mutable
        -1 => binding!
        units.units -> each unit {
            unit.frameAst == frame and unit.scopeAst == bodyAst and unit.position < units.positionByAst[result!] -> if {
                prepared.package.nodes[range.astStart + unit.astNode] => candidate
                candidate.kind == 9 and candidate.payloadToken >= 0 -> if {
                    prepared.package.tokens[range.tokenStart + candidate.payloadToken] => bindingName
                    source -> slice(bindingName.span.start, bindingName.span.length) => bindingSpelling
                    candidate.flags % 2 == 1 => bindingMutable
                    spelling == bindingSpelling and not (mutable and not bindingMutable or bindingMutable and not mutable)
                        -> if { unit.astNode => binding! }
                }
            }
        }
        binding! >= 0 -> if {
            binding! -> valueChild(prepared, sourceModule, indexed) => initializer
            initializer < 0 -> if { false -> return }
            initializer -> heapExpression(frame, source, prepared, facts, sourceModule, indexed, units) -> return
        }
    }
    result! -> heapExpression(frame, source, prepared, facts, sourceModule, indexed, units)
}

heapBranches nodeIndex: Int, requireElse: Bool, frame: Int, source: Text, prepared: ref semanticContext.SemanticSnapshot, facts: ref expressionTypes.ExpressionTypeIdSet, sourceModule: Int, indexed: ref sourceIndex.SourceIndex, units: ref sourceUnits.UnitPlan -> Bool {
    prepared.package.ranges[sourceModule] => range
    0 => count!
    indexed.firstChild[nodeIndex] => child!
    child! >= 0 -> while {
        prepared.package.nodes[range.astStart + child!].kind => kind
        kind == 43 -> if {
            child! -> heapBody(frame, source, prepared, facts, sourceModule, indexed, units) -> unless { false -> return }
            count! + 1 => count!
        }
        kind == 58 -> if {
            child! -> heapBranches(false, frame, source, prepared, facts, sourceModule, indexed, units) -> unless { false -> return }
            count! + 1 => count!
        }
        indexed.nextSibling[child!] => child!
    }
    count! > 0 and (not requireElse or count! == 2)
}

heapExpression nodeIndex: Int, frame: Int, source: Text, prepared: ref semanticContext.SemanticSnapshot, facts: ref expressionTypes.ExpressionTypeIdSet, sourceModule: Int, indexed: ref sourceIndex.SourceIndex, units: ref sourceUnits.UnitPlan -> Bool {
    prepared.package.ranges[sourceModule] => range
    prepared.package.nodes[range.astStart + nodeIndex] => node
    node.kind == 38 or node.kind == 23 -> if { true -> return }
    node.kind == 37 -> if { prepared.package -> typeIds.arrayStorageSyntax(sourceModule, nodeIndex) => storage; storage.dynamic -> return }
    node.kind == 11 -> if { nodeIndex -> heapCall(prepared, facts, sourceModule) -> return }
    node.kind == 42 -> if { nodeIndex -> heapBranches(true, frame, source, prepared, facts, sourceModule, indexed, units) -> return }
    node.kind == 56 or node.kind == 57 -> if { nodeIndex -> heapBranches(false, frame, source, prepared, facts, sourceModule, indexed, units) -> return }
    node.kind == 10 -> if {
        -1 => target!
        indexed.firstChild[nodeIndex] => child!
        child! >= 0 -> while {
            prepared.package.nodes[range.astStart + child!].kind => kind
            kind == 16 or kind == 42 or kind == 44 or kind == 56 or kind == 64 or kind == 73 or kind == 74 or kind == 76 or kind == 78 or kind == 81
                -> if { child! => target! }
            indexed.nextSibling[child!] => child!
        }
        target! < 0 -> if { false -> return }
        prepared.package.nodes[range.astStart + target!] => target
        target.kind == 42 or target.kind == 56 -> if {
            target! -> heapExpression(frame, source, prepared, facts, sourceModule, indexed, units) -> return
        }
        target.kind == 16 and target.payloadToken >= 0 -> if {
            source -> slice(target.start, target.length) => path
            path == "append" or path == "updated" -> if { true -> return }
            nodeIndex -> heapCall(prepared, facts, sourceModule) -> return
        }
    }
    false
}

public build frameAst: Int, source: Text, prepared: ref semanticContext.SemanticSnapshot, facts: ref expressionTypes.ExpressionTypeIdSet, sourceModule: Int, indexed: ref sourceIndex.SourceIndex, units: ref sourceUnits.UnitPlan -> Result<FramePlan, Error> {
    sourceModule < 0 or sourceModule >= (prepared.package.ranges -> len)
        or frameAst < 0 or frameAst >= indexed.astCount
        or (units.positionByAst -> len) != indexed.astCount
        or (units.scopeByAst -> len) != indexed.astCount or (units.frameByAst -> len) != indexed.astCount
        -> if { Error.InvalidSourceDomain -> Result<FramePlan, Error>.Err -> return }
    prepared.package.ranges[sourceModule] => range
    range.astStart != indexed.astStart or range.astCount != indexed.astCount
        -> if { Error.InvalidSourceDomain -> Result<FramePlan, Error>.Err -> return }
    prepared.package.nodes[range.astStart + frameAst] => frame
    frame.kind != 7 and frame.kind != 8 and frame.kind != 31
        -> if { Error.InvalidFrame -> Result<FramePlan, Error>.Err -> return }
    [placement.Candidate; ~] => candidates!
    frame.flags / 8 % 2 == 0 -> if {
        units.units -> each unit {
            prepared.package.nodes[range.astStart + unit.astNode] => binding
            unit.frameAst == frameAst and binding.kind == 9 -> if {
                unit.astNode -> valueChild(prepared, sourceModule, indexed) => value
                value < 0 -> if { Error.InvalidSourceDomain -> Result<FramePlan, Error>.Err -> return }
                prepared.package -> typeIds.arrayStorageSyntax(sourceModule, value) => storage
                literals.LiteralRequest { astNode: value, tokenStart: range.tokenStart }
                    -> literals.payload(source, prepared.package.nodes, prepared.package.tokens, storage, indexed) -> when {
                        Err(_) { Error.InvalidLiteral -> Result<FramePlan, Error>.Err -> return }
                        Ok(payload) { payload -> when {
                                None { }
                                Some(payload) {
                                    false => admitted!
                                    payload.kind -> when {
                                        StaticArray { true => admitted! }
                                        DynamicArray { unit.astNode -> ownerUses.readonlyPayload(payload.kind, source, prepared, sourceModule, indexed, units) -> when {
                                                Err(_) { Error.InvalidLifetime -> Result<FramePlan, Error>.Err -> return }
                                                Ok(value) { value => admitted! }
                                        } }
                                        Dictionary { unit.astNode -> ownerUses.readonlyPayload(payload.kind, source, prepared, sourceModule, indexed, units) -> when {
                                                Err(_) { Error.InvalidLifetime -> Result<FramePlan, Error>.Err -> return }
                                                Ok(value) { value => admitted! }
                                        } }
                                    }
                                    admitted! -> if {
                                        unit.astNode -> ownerUses.lastUse(source, prepared.package, sourceModule, indexed, units) -> when {
                                            Err(_) { Error.InvalidLifetime -> Result<FramePlan, Error>.Err -> return }
                                            Ok(last) { candidates! -> push(placement.Candidate { source: value, size: payload.bytes, start: unit.position, end: last.position, endUnit: last.astNode, automaticEnd: true }) }
                                        }
                                    }
                                }
                        } }
                }
                binding.flags % 2 == 1 and (value -> heapExpression(frameAst, source, prepared, facts, sourceModule, indexed, units)) -> if {
                    unit.scopeAst -> scopeEnd(frameAst, units) => endUnit
                    endUnit < 0 -> if { Error.InvalidLifetime -> Result<FramePlan, Error>.Err -> return }
                    candidates! -> push(placement.Candidate { source: unit.astNode, size: 24, start: unit.position, end: units.positionByAst[endUnit], endUnit: endUnit, automaticEnd: false })
                }
            }
        }
    }
    candidates! -> placement.allocateFrame -> when {
        Err(_) { Error.InvalidPlacement -> Result<FramePlan, Error>.Err }
        Ok(plan) { FramePlan { frameAst: frameAst, candidates: candidates!, slots: plan.slots, slotsByCandidate: plan.slotsByCandidate, ends: plan.ends } -> Result<FramePlan, Error>.Ok }
    }
}
'''.replace('=> storage; storage.dynamic','=> storage\n        storage.dynamic'),encoding='utf-8')
