import smalllang.compiler.ast as ast

main {
    "namespace app.main\nstruct Holder {\nvalue: Int\n}\nmain { }" => source
    source -> ast.lower => nodes!
    "boundary nodes = $(nodes! -> len)" -> println
    "boundary root = $(nodes![0].kind)" -> println
}
