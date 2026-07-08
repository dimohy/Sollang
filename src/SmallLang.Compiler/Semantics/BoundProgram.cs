using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.Semantics;

internal sealed record BoundProgram(
    IReadOnlyDictionary<string, BoundFunction> Functions,
    IReadOnlyList<Statement> MainStatements,
    IReadOnlyDictionary<string, BoundType> MainBindings);

internal sealed record BoundFunction(
    string Name,
    string? InputName,
    BoundType? InputType,
    BoundType ReturnType,
    Expression? Body,
    int Line,
    int Column,
    BoundFunctionKind Kind,
    bool IsStandardLibrary);

internal enum BoundFunctionKind
{
    User,
    RuntimePrint,
    RuntimePrintLine,
    RuntimeReadInt
}

internal enum BoundType
{
    Unit,
    Text,
    Int
}
