from pathlib import Path
import json,hashlib
root=Path.cwd();b=root/'artifacts/scratch/resume-20261006-owner-continuation22';out=b/'duplicate16743-candidate';out.mkdir(exist_ok=False)
semantic=(root/'selfhost/semantic/diagnostics.slg').read_text(encoding='utf-8-sig')
helper='''# Canonical declaration spelling ignores namespace/name trivia, preserves case,
# and includes the full dotted function path. The same builder renders errors.
public appendFunctionDeclarationName source: Text, tokens: ref [syntax.SyntaxToken; ~], tokenStart: Int, tokenCount: Int, namespaceStart: UIntSize, namespaceLength: UIntSize, nameToken: Int, bytes: mut [UInt8; ~] -> Unit {
    namespaceLength > 0 -> if {
        tokenStart => index!
        index! < tokenStart + tokenCount -> while {
            tokens[index!] => token
            token.span.start >= namespaceStart + namespaceLength -> if { break }
            token.span.start >= namespaceStart and token.kind != grammar.triviaIdWhitespace() and token.kind != grammar.triviaIdComment() -> if {
                UIntSize(0) => byteIndex!
                byteIndex! < token.span.length -> while {
                    bytes -> push(source -> byte(token.span.start + byteIndex!))
                    byteIndex! + 1 => byteIndex!
                }
            }
            index! + 1 => index!
        }
        bytes -> push(46)
    }
    nameToken => index!
    true => identifier!
    index! < tokenCount -> while {
        tokens[tokenStart + index!] => token
        token.kind != grammar.triviaIdWhitespace() and token.kind != grammar.triviaIdComment() -> if {
            identifier! -> if {
                token.kind != grammar.tokenIdIdentifier() -> if { break }
                UIntSize(0) => byteIndex!
                byteIndex! < token.span.length -> while {
                    bytes -> push(source -> byte(token.span.start + byteIndex!))
                    byteIndex! + 1 => byteIndex!
                }
            } else {
                token.kind != grammar.tokenIdDot() -> if { break }
                bytes -> push(46)
            }
            not identifier! => identifier!
        }
        index! + 1 => index!
    }
}

'''
start=semantic.index('firstFunctionNameDiagnostic prepared:');end=semantic.index('\n# Repeat owns',start)
function=semantic[start:end]
needle='    prepared.package.ranges -> each range {';assert function.count(needle)==1
function=function.replace(needle,'''    [UInt8; ~] => declarationNames!
    [Int; ~] => declarationStarts!
    [Int; ~] => declarationLengths!
    [Int; ~] => declarationSlots!
    (prepared.package.symbols -> len) * 2 + 1 => capacity
    0 => slotIndex!
    slotIndex! < capacity -> while {
        declarationSlots! -> push(-1)
        slotIndex! + 1 => slotIndex!
    }
'''+needle)
needle='                    code! > 0 -> if {';assert function.count(needle)==1
function=function.replace(needle,'''                    code! == 0 and symbol.parent < 0 and not local! -> if {
                        declarationNames! -> len => nameStart
                        prepared.modules[range.sourceModule] => identity
                        prepared.package.sources[range.sourceModule] -> slice(UIntSize(0), prepared.package.sources[range.sourceModule] -> len) => declarationSource
                        declarationSource -> appendFunctionDeclarationName(prepared.package.tokens, range.tokenStart, range.tokenCount, identity.pathStart, identity.pathLength, symbol.nameToken, declarationNames!)
                        (declarationNames! -> len) - nameStart => nameLength
                        UInt64(0) => hash!
                        nameStart => byteIndex!
                        byteIndex! < nameStart + nameLength -> while {
                            (hash! * UInt64(257) + UInt64(declarationNames![byteIndex!])) % UInt64(4294967291) => hash!
                            byteIndex! + 1 => byteIndex!
                        }
                        Int(hash! % UInt64(capacity)) => slot!
                        true => searching!
                        searching! -> while {
                            declarationSlots![slot!] => previous
                            previous < 0 -> if {
                                declarationStarts! -> len => declarationSlots![slot!]
                                declarationStarts! -> push(nameStart)
                                declarationLengths! -> push(nameLength)
                                false => searching!
                            } else {
                                declarationLengths![previous] == nameLength => same!
                                0 => character!
                                same! and character! < nameLength -> while {
                                    declarationNames![declarationStarts![previous] + character!] != declarationNames![nameStart + character!] -> if { false => same! }
                                    character! + 1 => character!
                                }
                                same! -> if {
                                    73 => code!
                                    false => searching!
                                } else { (slot! + 1) % capacity => slot! }
                            }
                        }
                    }
'''+needle)
semantic=semantic[:start]+helper+function+semantic[end:]
emitter=(root/'selfhost/llvm/emitter/diagnostics.slg').read_text(encoding='utf-8-sig')
helper2='''# Declaration duplicates precede body binding, but retain an earlier
# invalid signature. Compare source order and token locations, not IR order.
duplicateFunctionPrecedesSignature context: ref emitterContext.EmitContext -> Bool {
    context.expressionOperandDiagnostic => diagnostic
    diagnostic.code != 73 -> if { false -> return }
    context.signatureTypeDiagnostic => signature
    signature.sourceModule < 0 -> if { true -> return }
    diagnostic.sourceModule != signature.sourceModule -> if {
        diagnostic.sourceModule < signature.sourceModule -> return
    }
    context.ranges[signature.sourceModule] => range
    context.tokens[range.tokenStart + signature.nameToken] => token
    diagnostic.locationOffset <= token.span.start
}

'''
needle='public blockingDiagnosticCount context:';assert emitter.count(needle)==1;emitter=emitter.replace(needle,helper2+needle)
start=emitter.index('public blockingDiagnosticCount context:');end=emitter.index('public emitBlockingDiagnostics context:',start)
chunk=emitter[start:end];needle='    context.signatureTypeDiagnostic.sourceModule >= 0';assert needle in chunk;chunk=chunk.replace(needle,'    context -> duplicateFunctionPrecedesSignature -> if { 1 -> return }\n'+needle,1);emitter=emitter[:start]+chunk+emitter[end:]
start=emitter.index('public emitBlockingDiagnostics context:');needle='    context.signatureTypeDiagnostic.sourceModule >= 0';index=emitter.index(needle,start);emitter=emitter[:index]+'''    context -> duplicateFunctionPrecedesSignature -> if {
        context -> emitExpressionOperandDiagnostics
        return
    }
'''+emitter[index:]
needle='    diagnostic.code == 49 -> if {';assert emitter.count(needle)==1
emitter=emitter.replace(needle,'''    diagnostic.code == 73 -> if {
        context.ranges[diagnostic.sourceModule] => range
        context.nodes[range.astStart + diagnostic.astNode] => function
        context.modules[diagnostic.sourceModule] => identity
        context.sources[diagnostic.sourceModule] => source
        [UInt8; ~] => bytes!
        source -> semanticDiagnostics.appendFunctionDeclarationName(context.tokens, range.tokenStart, range.tokenCount, identity.pathStart, identity.pathLength, function.payloadToken, bytes!)
        bytes! -> file.borrowBytes => nameView
        nameView -> slice(UIntSize(0), nameView -> len) => name
        source -> syntaxDiagnostics.sourceLocation(diagnostic.locationOffset) => location
        context -> emitExpressionSemanticPrefix(diagnostic, location)
        "function '$name' already exists" -> println
        return
    }
'''+needle)
(out/'semantic-diagnostics.slg').write_text(semantic,encoding='utf-8');(out/'emitter-diagnostics.slg').write_text(emitter,encoding='utf-8')
manifest=(root/'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt').read_text(encoding='utf-8-sig').splitlines();mapping={'selfhost/semantic/diagnostics.slg':out/'semantic-diagnostics.slg','selfhost/llvm/emitter/diagnostics.slg':out/'emitter-diagnostics.slg'}
manifest=[str(mapping[x].relative_to(root)).replace('\\','/') if x in mapping else x for x in manifest];(out/'producer.sources.txt').write_text('\n'.join(manifest)+'\n',encoding='utf-8');print('prepared private declaration diagnostic candidate; canonical inputs untouched')
