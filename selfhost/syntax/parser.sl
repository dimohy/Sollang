namespace smalllang.compiler.parser

import smalllang.compiler.lexer as lexer
import syntax.generated.smalllang as grammar

# Executes the generated parser bytecode without embedding grammar-specific
# control flow in the VM. CST construction will be layered on this recognizer.
public accepts source: Text -> Bool {
    source -> lexer.lex => tokens!
    grammar.parserProgram => program!
    grammar.ruleOffsets => ruleOffsets!
    grammar.keywordTexts => keywords!

    [Int; ~] => returnPcs!
    [Int; ~] => choicePcs!
    [Int; ~] => choiceTokens!
    [Int; ~] => choiceCallDepths!
    0 => callDepth!
    0 => choiceDepth!
    grammar.startRule => startRule
    ruleOffsets![startRule] => pc!
    0 => tokenIndex!
    true => running!
    false => accepted!

    running! -> while {
        program![pc!] => opcode
        opcode == 0 -> if {
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
                    tokenIndex! + 1 => tokenIndex!
                    pc! + 2 => pc!
                } else {
                    choiceDepth! > 0 -> if {
                        choiceDepth! - 1 => choiceDepth!
                        choicePcs![choiceDepth!] => pc!
                        choiceTokens![choiceDepth!] => tokenIndex!
                        choiceCallDepths![choiceDepth!] => callDepth!
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
                        tokenIndex! + 1 => tokenIndex!
                        pc! + 3 => pc!
                    } else {
                        choiceDepth! > 0 -> if {
                            choiceDepth! - 1 => choiceDepth!
                            choicePcs![choiceDepth!] => pc!
                            choiceTokens![choiceDepth!] => tokenIndex!
                            choiceCallDepths![choiceDepth!] => callDepth!
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
                        ruleOffsets![rule] => pc!
                    } else {
                        opcode == 4 -> if {
                            choicePcs! -> len => choiceCount
                            choiceDepth! < choiceCount -> if {
                                program![pc! + 1] => choicePcs![choiceDepth!]
                                tokenIndex! => choiceTokens![choiceDepth!]
                                callDepth! => choiceCallDepths![choiceDepth!]
                            } else {
                                choicePcs! -> push(program![pc! + 1])
                                choiceTokens! -> push(tokenIndex!)
                                choiceCallDepths! -> push(callDepth!)
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

    accepted!
}
