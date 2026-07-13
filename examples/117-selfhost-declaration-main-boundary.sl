import smalllang.compiler.ast as ast

main {
    """
    namespace app.main

    struct Holder {
        value: Int
    }

    main { }
    """ => source
    source -> ast.lower => nodes!
    "boundary nodes = $(nodes! -> len)" -> println
    "boundary root = $(nodes![0].kind)" -> println
}
