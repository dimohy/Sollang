namespace smalllang.compiler.parser

import smalllang.compiler.lexer as lexer
import syntax.generated.smalllang as grammar

# Parser events are lossless building blocks for a green CST. Enter/exit events
# carry rule ids, token events carry token indexes, and the final outcome event
# carries 1 for acceptance or 0 for rejection. Kind 4 rewinds consumers to the
# prior event depth when a grammar alternative backtracks.
public struct ParseEvent {
    kind: Int
    value: Int
    tokenIndex: Int
}

# Executes the generated parser bytecode without embedding grammar-specific
# control flow in the VM. Events invalidated by backtracking are rolled back.
public parseEvents source: Text -> [ParseEvent; ~] {
    source -> lexer.lex => tokens!
    grammar.parserProgram => program!
    grammar.ruleOffsets => ruleOffsets!
    grammar.keywordTexts => keywords!

    [Int; ~] => returnPcs!
    [Int; ~] => choicePcs!
    [Int; ~] => choiceTokens!
    [Int; ~] => choiceCallDepths!
    [Int; ~] => choiceEventDepths!
    [Int; ~] => activeRules!
    [ParseEvent; ~] => events!
    0 => callDepth!
    0 => choiceDepth!
    0 => eventDepth!
    grammar.startRule => startRule
    ruleOffsets![startRule] => pc!
    0 => tokenIndex!
    true => running!
    false => accepted!

    ParseEvent { kind: 0, value: startRule, tokenIndex: tokenIndex! } => startEvent
    events! -> push(startEvent)
    activeRules! -> push(startRule)
    1 => eventDepth!

    running! -> while {
        program![pc!] => opcode
        opcode == 0 -> if {
            ParseEvent {
                kind: 1
                value: activeRules![callDepth!]
                tokenIndex: tokenIndex!
            } => exitEvent
            events! -> push(exitEvent)
            eventDepth! + 1 => eventDepth!
            callDepth! == 0 -> if {
                tokens! -> len => tokenCount
                tokenIndex! == tokenCount => accepted!
                false => running!
            } else {
                callDepth! - 1 => callDepth!
                returnPcs![callDepth!] => pc!
            }
        } else {
            opcode == 1 -> if {
                program![pc! + 1] => expectedKind
                tokens![tokenIndex!].kind == expectedKind -> if {
                    ParseEvent { kind: 2, value: expectedKind, tokenIndex: tokenIndex! } => tokenEvent
                    events! -> push(tokenEvent)
                    eventDepth! + 1 => eventDepth!
                    tokenIndex! + 1 => tokenIndex!
                    pc! + 2 => pc!
                } else {
                    choiceDepth! > 0 -> if {
                        choiceDepth! - 1 => choiceDepth!
                        choicePcs![choiceDepth!] => pc!
                        choiceTokens![choiceDepth!] => tokenIndex!
                        choiceCallDepths![choiceDepth!] => callDepth!
                        choiceEventDepths![choiceDepth!] => tokenRollbackDepth
                        ParseEvent { kind: 4, value: tokenRollbackDepth, tokenIndex: tokenIndex! } => tokenRollbackEvent
                        events! -> push(tokenRollbackEvent)
                        eventDepth! + 1 => eventDepth!
                    } else {
                        false => running!
                    }
                }
            } else {
                opcode == 2 -> if {
                    program![pc! + 1] => expectedKind
                    program![pc! + 2] => keywordIndex
                    tokens![tokenIndex!] => token
                    source -> slice(token.span.start, token.span.length) => tokenText
                    keywords![keywordIndex] => expectedText
                    tokenText -> len => tokenTextLength
                    expectedText -> len => expectedTextLength
                    tokenTextLength == expectedTextLength => keywordMatches!
                    UIntSize(0) => keywordByte!
                    (keywordMatches! and keywordByte! < tokenTextLength) -> while {
                        tokenText -> byte(keywordByte!) => actualByte
                        expectedText -> byte(keywordByte!) => expectedByte
                        actualByte != expectedByte -> if {
                            false => keywordMatches!
                        }
                        keywordByte! + UIntSize(1) => keywordByte!
                    }
                    token.kind == expectedKind and keywordMatches! -> if {
                        ParseEvent { kind: 2, value: expectedKind, tokenIndex: tokenIndex! } => keywordEvent
                        events! -> push(keywordEvent)
                        eventDepth! + 1 => eventDepth!
                        tokenIndex! + 1 => tokenIndex!
                        pc! + 3 => pc!
                    } else {
                        choiceDepth! > 0 -> if {
                            choiceDepth! - 1 => choiceDepth!
                            choicePcs![choiceDepth!] => pc!
                            choiceTokens![choiceDepth!] => tokenIndex!
                            choiceCallDepths![choiceDepth!] => callDepth!
                            choiceEventDepths![choiceDepth!] => keywordRollbackDepth
                            ParseEvent { kind: 4, value: keywordRollbackDepth, tokenIndex: tokenIndex! } => keywordRollbackEvent
                            events! -> push(keywordRollbackEvent)
                            eventDepth! + 1 => eventDepth!
                        } else {
                            false => running!
                        }
                    }
                } else {
                    opcode == 3 -> if {
                        program![pc! + 1] => rule
                        returnPcs! -> len => returnCount
                        callDepth! < returnCount -> if {
                            pc! + 2 => returnPcs![callDepth!]
                        } else {
                            returnPcs! -> push(pc! + 2)
                        }
                        callDepth! + 1 => callDepth!
                        activeRules! -> len => activeRuleCount
                        callDepth! < activeRuleCount -> if {
                            rule => activeRules![callDepth!]
                        } else {
                            activeRules! -> push(rule)
                        }
                        ParseEvent { kind: 0, value: rule, tokenIndex: tokenIndex! } => enterEvent
                        events! -> push(enterEvent)
                        eventDepth! + 1 => eventDepth!
                        ruleOffsets![rule] => pc!
                    } else {
                        opcode == 4 -> if {
                            choicePcs! -> len => choiceCount
                            choiceDepth! < choiceCount -> if {
                                program![pc! + 1] => choicePcs![choiceDepth!]
                                tokenIndex! => choiceTokens![choiceDepth!]
                                callDepth! => choiceCallDepths![choiceDepth!]
                                eventDepth! => choiceEventDepths![choiceDepth!]
                            } else {
                                choicePcs! -> push(program![pc! + 1])
                                choiceTokens! -> push(tokenIndex!)
                                choiceCallDepths! -> push(callDepth!)
                                choiceEventDepths! -> push(eventDepth!)
                            }
                            choiceDepth! + 1 => choiceDepth!
                            pc! + 2 => pc!
                        } else {
                            opcode == 5 -> if {
                                choiceDepth! - 1 => choiceDepth!
                                program![pc! + 1] => pc!
                            } else {
                                opcode == 6 -> if {
                                    program![pc! + 1] => pc!
                                } else {
                                    opcode == 7 -> if {
                                        program![pc! + 1] => expectedKind
                                        tokens![tokenIndex!].kind == expectedKind -> if {
                                            pc! + 2 => pc!
                                        } else {
                                            choiceDepth! > 0 -> if {
                                                choiceDepth! - 1 => choiceDepth!
                                                choicePcs![choiceDepth!] => pc!
                                                choiceTokens![choiceDepth!] => tokenIndex!
                                                choiceCallDepths![choiceDepth!] => callDepth!
                                                choiceEventDepths![choiceDepth!] => lookaheadRollbackDepth
                                                ParseEvent { kind: 4, value: lookaheadRollbackDepth, tokenIndex: tokenIndex! } => lookaheadRollbackEvent
                                                events! -> push(lookaheadRollbackEvent)
                                                eventDepth! + 1 => eventDepth!
                                            } else {
                                                false => running!
                                            }
                                        }
                                    } else {
                                        false => running!
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ParseEvent {
        kind: 3
        value: accepted! -> if { 1 } else { 0 }
        tokenIndex: tokenIndex!
    } => outcome
    events! -> push(outcome)
    eventDepth! + 1 => eventDepth!

    events!
}
