import smalllang.compiler.lexer
import smalllang.compiler.semantic.type_terms as typeTerms

main {
    """
    project<T> value: Result<[T; ~], {Text: box T}> -> Result<[T; ~], {Text: box T}> {
        value
    }

    concrete value: Int -> Int => value

    main { }
    """ => source
    source -> typeTerms.lower => terms!
    source -> lexer.lex => tokens!

    -1 => root!
    -1 => parameter!
    -1 => replacement!
    0 => termIndex!
    termIndex! < (terms! -> len) -> while {
        terms![termIndex!] => term
        (root! < 0 and term.kind == 7) -> if { termIndex! => root! }
        term.nameToken >= 0 -> if {
            tokens![term.nameToken] => name
            name.span.length == UIntSize(1) -> if {
                source -> byte(name.span.start) => nameByte
                nameByte == UInt8(84) -> if { termIndex! => parameter! }
            }
            name.span.length == UIntSize(3) -> if {
                source -> byte(name.span.start) => byte0
                source -> byte(name.span.start + UIntSize(1)) => byte1
                source -> byte(name.span.start + UIntSize(2)) => byte2
                (byte0 == UInt8(73) and byte1 == UInt8(110) and byte2 == UInt8(116)) -> if {
                    termIndex! => replacement!
                }
            }
        }
        termIndex! + 1 => termIndex!
    }

    typeTerms.SubstitutionRequest {
        terms: terms!
        root: root!
        parameter: parameter!
        replacement: replacement!
    } => request!
    request! -> typeTerms.substitute => specialized

    false => valid!
    specialized.status == 0 -> if {
        specialized.root => specializedRoot
        specialized.terms[specializedRoot] => result
        specialized.terms[result.firstArgument] => ok
        specialized.terms[result.secondArgument] => error
        specialized.terms[ok.firstArgument] => okElement
        specialized.terms[error.secondArgument] => boxed
        specialized.terms[boxed.firstArgument] => boxedElement
        (result.kind == 7 and ok.kind == 3 and error.kind == 5 and boxed.kind == 6 and okElement.nameId == boxedElement.nameId) -> if {
            true => valid!
        }
    }
    valid! -> if {
        "recursive type substitution = valid"
    } else {
        "recursive type substitution = invalid"
    } -> println
}
