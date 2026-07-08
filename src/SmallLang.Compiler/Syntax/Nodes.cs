namespace SmallLang.Compiler.Syntax;

internal sealed record SmallLangProgram(
    IReadOnlyList<FunctionDeclaration> Functions,
    IReadOnlyList<Statement> Statements);

internal sealed record FunctionDeclaration(
    string Name,
    string? InputName,
    string? InputType,
    string ReturnType,
    Expression? Body,
    int Line,
    int Column,
    bool IsIntrinsic,
    bool IsStandardLibrary);

internal abstract record Statement;

internal sealed record BindingStatement(string Name, Expression Value, int Line, int Column) : Statement;

internal sealed record BlockFunctionCallStatement(
    Expression Source,
    IReadOnlyList<string> Target,
    string ItemName,
    IReadOnlyList<Statement> Body,
    int Line,
    int Column,
    bool UsesDefaultItemName)
    : Statement;

internal sealed record ExpressionStatement(Expression Expression) : Statement;

internal abstract record Expression(int Line, int Column);

internal sealed record StringExpression(IReadOnlyList<StringSegment> Segments, int Line, int Column)
    : Expression(Line, Column);

internal sealed record NumberExpression(string Text, int Line, int Column) : Expression(Line, Column);

internal sealed record NameExpression(string Name, int Line, int Column) : Expression(Line, Column);

internal sealed record AddExpression(Expression Left, Expression Right, int Line, int Column)
    : Expression(Line, Column);

internal sealed record MultiplyExpression(Expression Left, Expression Right, int Line, int Column)
    : Expression(Line, Column);

internal sealed record RangeExpression(Expression Start, Expression End, int Line, int Column)
    : Expression(Line, Column);

internal sealed record FlowExpression(
    Expression Source,
    IReadOnlyList<IReadOnlyList<string>> Targets,
    int Line,
    int Column)
    : Expression(Line, Column);

internal sealed record CallExpression(
    IReadOnlyList<string> Path,
    IReadOnlyList<Expression> Arguments,
    int Line,
    int Column)
    : Expression(Line, Column);

internal abstract record StringSegment;

internal sealed record TextSegment(string Text) : StringSegment;

internal sealed record InterpolationSegment(IReadOnlyList<string> Path) : StringSegment;
