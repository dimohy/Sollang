import sys.file as file

sourceLength source: file.SourceText -> UIntSize => source -> len

main {
    [file.SourceText; ~] => sources!

    "lexer" -> file.borrowText => borrowed!
    sources! -> push(borrowed!)

    "examples/01-function-basic-hello.sl" -> file.mapText => mapped!
    sources! -> push(mapped!)

    sources![0] -> sourceLength => borrowedLength
    sources![1] -> sourceLength => mappedLength
    sourceLength(sources![0]) => directLength
    sources![0] -> slice(UIntSize(1), UIntSize(3)) => directSlice

    "source lengths = $borrowedLength,$mappedLength,$directLength,$directSlice" -> println
}
