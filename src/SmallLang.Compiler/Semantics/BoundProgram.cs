using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.Semantics;

internal sealed record BoundProgram(
    IReadOnlyDictionary<string, BoundFunction> Functions,
    IReadOnlyList<Statement> MainStatements,
    IReadOnlyDictionary<string, BoundType> MainBindings);

internal sealed record BoundFunction(
    string Name,
    BoundType? InputType,
    BoundType ReturnType,
    Expression Body,
    int Line,
    int Column);

internal enum BoundType
{
    Unit,
    Text,
    Int
}
