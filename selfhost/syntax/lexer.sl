namespace smalllang.compiler.lexer

import smalllang.compiler.syntax as syntax
import syntax.generated.smalllang as grammar

public lex source: Text -> [syntax.SyntaxToken; ~] {
    isDigit value: UInt8 -> Bool {
        value >= UInt8(48) and value <= UInt8(57)
    }
    isIdentifierStart value: UInt8 -> Bool {
        (value >= UInt8(65) and value <= UInt8(90)) or (value >= UInt8(97) and value <= UInt8(122)) or value == UInt8(95) or value >= UInt8(128)
    }
    isIdentifierContinue value: UInt8 -> Bool {
        value -> isIdentifierStart => start
        value -> isDigit => digit
        start or digit
    }
    isHorizontalWhitespace value: UInt8 -> Bool {
        value == UInt8(32) or value == UInt8(9) or value == UInt8(13)
    }
    pairKind value: UInt16 -> Int => when {
        value == UInt16(11822) => grammar.tokenIdRange
        value == UInt16(11582) => grammar.tokenIdArrow
        value == UInt16(15678) => grammar.tokenIdFatArrow
        value == UInt16(15677) => grammar.tokenIdEqualEqual
        value == UInt16(8541) => grammar.tokenIdBangEqual
        value == UInt16(15421) => grammar.tokenIdLessEqual
        value == UInt16(15933) => grammar.tokenIdGreaterEqual
        else => -1
    }
    singleKind value: UInt8 -> Int => when {
        value == UInt8(123) => grammar.tokenIdLeftBrace
        value == UInt8(125) => grammar.tokenIdRightBrace
        value == UInt8(91) => grammar.tokenIdLeftBracket
        value == UInt8(93) => grammar.tokenIdRightBracket
        value == UInt8(40) => grammar.tokenIdLeftParen
        value == UInt8(41) => grammar.tokenIdRightParen
        value == UInt8(126) => grammar.tokenIdTilde
        value == UInt8(46) => grammar.tokenIdDot
        value == UInt8(44) => grammar.tokenIdComma
        value == UInt8(59) => grammar.tokenIdSemicolon
        value == UInt8(43) => grammar.tokenIdPlus
        value == UInt8(45) => grammar.tokenIdMinus
        value == UInt8(42) => grammar.tokenIdStar
        value == UInt8(47) => grammar.tokenIdSlash
        value == UInt8(37) => grammar.tokenIdPercent
        value == UInt8(63) => grammar.tokenIdQuestion
        value == UInt8(58) => grammar.tokenIdColon
        value == UInt8(33) => grammar.tokenIdBang
        value == UInt8(60) => grammar.tokenIdLess
        value == UInt8(62) => grammar.tokenIdGreater
        value == UInt8(61) => grammar.tokenIdEqual
        else => -1
    }
    [syntax.SyntaxToken; ~] => tokens!
    UIntSize(0) => position!
    source -> len => sourceLength

    position! < sourceLength -> while {
        source -> byte(position!) => current
        current -> isHorizontalWhitespace -> if {
            position! => whitespaceStart
            position! + UIntSize(1) => position!
            (position! < sourceLength and ((source -> byte(position!)) -> isHorizontalWhitespace)) -> while {
                position! + UIntSize(1) => position!
            }
            syntax.SyntaxToken {
                kind: grammar.triviaIdWhitespace
                span: syntax.SourceSpan { fileId: 0, start: whitespaceStart, length: position! - whitespaceStart }
            } => whitespaceToken
            tokens! -> push(whitespaceToken)
        } else {
            current == UInt8(35) -> if {
                position! => commentStart
                position! + UIntSize(1) => position!
                (position! < sourceLength and (source -> byte(position!)) != UInt8(10)) -> while {
                    position! + UIntSize(1) => position!
                }
                syntax.SyntaxToken {
                    kind: grammar.triviaIdComment
                    span: syntax.SourceSpan { fileId: 0, start: commentStart, length: position! - commentStart }
                } => commentToken
                tokens! -> push(commentToken)
            } else {
                current == UInt8(10) -> if {
                    syntax.SyntaxToken {
                        kind: grammar.tokenIdNewLine
                        span: syntax.SourceSpan { fileId: 0, start: position!, length: UIntSize(1) }
                    } => newlineToken
                    tokens! -> push(newlineToken)
                    position! + UIntSize(1) => position!
                } else {
                    current -> isIdentifierStart -> if {
                        position! => identifierStart
                        position! + UIntSize(1) => position!
                        (position! < sourceLength and ((source -> byte(position!)) -> isIdentifierContinue)) -> while {
                            position! + UIntSize(1) => position!
                        }
                        syntax.SyntaxToken {
                            kind: grammar.tokenIdIdentifier
                            span: syntax.SourceSpan { fileId: 0, start: identifierStart, length: position! - identifierStart }
                        } => identifierToken
                        tokens! -> push(identifierToken)
                    } else {
                        current -> isDigit -> if {
                            position! => numberStart
                            position! + UIntSize(1) => position!
                            (position! < sourceLength and ((source -> byte(position!)) -> isDigit)) -> while {
                                position! + UIntSize(1) => position!
                            }
                            syntax.SyntaxToken {
                                kind: grammar.tokenIdNumber
                                span: syntax.SourceSpan { fileId: 0, start: numberStart, length: position! - numberStart }
                            } => numberToken
                            tokens! -> push(numberToken)
                        } else {
                            current == UInt8(34) -> if {
                                position! => stringStart
                                false => rawString!
                                position! + UIntSize(2) < sourceLength -> if {
                                    ((source -> byte(position! + UIntSize(1))) == UInt8(34) and (source -> byte(position! + UIntSize(2))) == UInt8(34)) -> if { true => rawString! }
                                }
                                rawString! -> if {
                                    UIntSize(0) => delimiterWidth!
                                    (position! + delimiterWidth! < sourceLength and (source -> byte(position! + delimiterWidth!)) == UInt8(34)) -> while {
                                        delimiterWidth! + UIntSize(1) => delimiterWidth!
                                    }
                                    position! + delimiterWidth! => position!
                                    false => rawClosed!
                                    (position! < sourceLength and not rawClosed!) -> while {
                                        UIntSize(0) => quoteRun!
                                        (position! + quoteRun! < sourceLength and (source -> byte(position! + quoteRun!)) == UInt8(34)) -> while {
                                            quoteRun! + UIntSize(1) => quoteRun!
                                        }
                                        quoteRun! >= delimiterWidth! -> if { true => rawClosed! }
                                        not rawClosed! -> if { position! + UIntSize(1) => position! }
                                    }
                                    rawClosed! -> if { position! + delimiterWidth! => position! }
                                } else {
                                    position! + UIntSize(1) => position!
                                    (position! < sourceLength and (source -> byte(position!)) != UInt8(34)) -> while {
                                        position! + UIntSize(1) => position!
                                    }
                                    position! < sourceLength -> if {
                                        position! + UIntSize(1) => position!
                                    }
                                }
                                syntax.SyntaxToken {
                                    kind: grammar.tokenIdString
                                    span: syntax.SourceSpan { fileId: 0, start: stringStart, length: position! - stringStart }
                                } => stringToken
                                tokens! -> push(stringToken)
                            } else {
                                Int(-1) => kind!
                                UIntSize(1) => width!
                                position! + UIntSize(1) < sourceLength -> if {
                                    source -> byte(position! + UIntSize(1)) => following
                                    UInt16(current) * UInt16(256) + UInt16(following) -> pairKind => pair
                                    pair >= 0 -> if {
                                        pair => kind!
                                        UIntSize(2) => width!
                                    }
                                }
                                kind! < 0 -> if {
                                    current -> singleKind => kind!
                                }
                                kind! >= 0 -> if {
                                    syntax.SyntaxToken {
                                        kind: kind!
                                        span: syntax.SourceSpan { fileId: 0, start: position!, length: width! }
                                    } => punctuationToken
                                    tokens! -> push(punctuationToken)
                                } else {
                                    syntax.SyntaxToken {
                                        kind: grammar.tokenIdInvalid
                                        span: syntax.SourceSpan { fileId: 0, start: position!, length: width! }
                                    } => invalidToken
                                    tokens! -> push(invalidToken)
                                }
                                position! + width! => position!
                            }
                        }
                    }
                }
            }
        }
    }

    syntax.SyntaxToken {
        kind: grammar.tokenIdEnd
        span: syntax.SourceSpan { fileId: 0, start: sourceLength, length: UIntSize(0) }
    } => endToken
    tokens! -> push(endToken)
    tokens!
}
