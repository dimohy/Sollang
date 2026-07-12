import smalllang.compiler.lexer as lexer
import smalllang.compiler.semantic.modules as modules

main {
    ["namespace sample.math", "import sample.math as math", ~] => sources!
    sources! -> modules.identities => identities!
    sources! -> modules.imports => imports!
    identities! -> each module {
        "module = $(module.sourceIndex),$(module.pathHash),$(module.importCount)" -> println
    }
    imports! -> each edge {
        sources![edge.sourceModule] => source
        source -> lexer.lex => tokens!
        tokens![edge.aliasToken] => aliasToken
        source -> slice(aliasToken.span.start, aliasToken.span.length) => alias
        "import = $(edge.sourceModule),$(edge.targetHash),$alias" -> println
    }
}
