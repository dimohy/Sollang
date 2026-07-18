import sys.file as file

escapedPrefix source: file.SourceText -> Text => source -> slice(UIntSize(0), UIntSize(1))

main {
    "lexer" -> file.borrowText => source!
    source! -> escapedPrefix -> println
}
