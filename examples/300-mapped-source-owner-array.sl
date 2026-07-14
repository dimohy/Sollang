main {
    [MappedBytes; ~] => sources!
    map read "examples/01-function-basic-hello.sl" => source!
    sources! -> push(source!)
    sources! -> len => count
    "mapped sources = $count" -> println
}
