namespace Sollang.Compiler.Lexing;

internal readonly record struct Token(
    TokenKind Kind,
    string Text,
    int Line,
    int Column,
    bool IsRawString = false,
    int ByteOffset = -1)
{
    // Fragment diagnostics retain their established local coordinates;
    // suspension metadata additionally needs the enclosing source location.
    public int SourceLine { get; init; }
    public int SourceColumn { get; init; }
}
