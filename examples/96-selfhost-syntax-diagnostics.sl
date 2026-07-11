import smalllang.compiler.diagnostics as diagnostics

main {
    diagnostics.analyze("main { -> }") => syntaxErrors!
    syntaxErrors![0] => syntaxError
    diagnostics.analyze("main {@}") => invalidErrors!
    invalidErrors![0] => invalidError

    "syntax = $(syntaxError.code),$(syntaxError.span.start),$(syntaxError.span.length),$(syntaxError.foundKind)" -> println
    "invalid = $(invalidError.code),$(invalidError.span.start),$(invalidError.span.length),$(invalidError.foundKind)" -> println
}
