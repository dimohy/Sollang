namespace SmallLang.Compiler.Lexing;

internal readonly record struct Token(TokenKind Kind, string Text, int Line, int Column);
