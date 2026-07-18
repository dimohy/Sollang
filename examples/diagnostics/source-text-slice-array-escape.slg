import sys.file as file

escapedParts source: file.SourceText -> [Text; ~] => [source -> slice(UIntSize(0), UIntSize(1)), ~]

main {
    "lexer" -> file.borrowText => source!
    source! -> escapedParts => parts
    parts -> len -> println
}
