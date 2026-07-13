import smalllang.compiler.ir.typed as typedIr

struct Context {
    sources: [Text; ~]
    ir: [typedIr.TypedIrNode; ~]
}

inspect context: move Context -> Int {
    kindAt index: Int -> Int {
        context.ir[index].kind
    }
    0 -> kindAt
}

main {
    ["main {}", ~] => sources!
    sources! -> typedIr.lower => ir!
    Context { sources: sources!, ir: ir! } => context!
    context! -> inspect => kind
    "kind=$kind" -> println
}
