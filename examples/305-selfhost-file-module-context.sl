import smalllang.compiler.semantic.context as context

main {
    [
        "examples/52-multi-file-modules.sl",
        "examples/sample/math.sl",
        ~
    ] => paths
    paths -> context.prepareFiles => prepared!
    "file context = $(prepared!.sources -> len),$(prepared!.modules -> len),$(prepared!.tokens -> len)" -> println
}
