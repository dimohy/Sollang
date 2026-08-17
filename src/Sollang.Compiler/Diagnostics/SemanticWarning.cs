namespace Sollang.Compiler.Diagnostics;

internal sealed record SemanticWarning(
    string Code,
    string ModuleName,
    int Line,
    int Column,
    string Message);
