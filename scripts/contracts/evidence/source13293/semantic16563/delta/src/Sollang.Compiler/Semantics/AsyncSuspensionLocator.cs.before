using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal static class AsyncSuspensionLocator
{
    public static IReadOnlyDictionary<object, BoundAsyncSuspensionLocation> Index(
        IEnumerable<BoundFunction> functions)
    {
        var result = new Dictionary<object, BoundAsyncSuspensionLocation>(
            ReferenceEqualityComparer.Instance);
        var visited = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var function in functions)
        {
            IndexFunction(function, result, visited);
        }
        return result;
    }

    private static void IndexFunction(
        BoundFunction function,
        IDictionary<object, BoundAsyncSuspensionLocation> result,
        ISet<BoundFunction> visited)
    {
        if (!visited.Add(function))
        {
            return;
        }

        if (function.IsAsync)
        {
            IndexStatements(function, function.BlockBody, result);
            if (function.Body is { } body)
            {
                IndexExpression(function, body, body, result);
            }
        }

        foreach (var local in function.LocalFunctions.Values)
        {
            IndexFunction(local, result, visited);
        }
    }

    private static void IndexStatements(
        BoundFunction function,
        IReadOnlyList<Statement> statements,
        IDictionary<object, BoundAsyncSuspensionLocation> result)
    {
        foreach (var statement in statements)
        {
            switch (statement)
            {
                case BindingStatement binding:
                    IndexExpression(function, binding.Value, binding, result);
                    break;
                case ExpressionStatement { Expression: NameExpression { Name: "yield" } yield } expression:
                    Add(function, expression, yield.ByteOffset, yield.Line, yield.Column, result);
                    break;
                case ExpressionStatement expression:
                    IndexExpression(function, expression.Expression, expression, result);
                    break;
                case BlockFunctionCallStatement block:
                    IndexExpression(function, block.Source, block.Source, result);
                    foreach (var argument in block.Arguments ?? [])
                    {
                        IndexExpression(function, argument, argument, result);
                    }
                    IndexStatements(function, block.Body, result);
                    break;
                case BlockFunctionPipelineStatement pipeline:
                    foreach (var block in pipeline.Calls)
                    {
                        IndexExpression(function, block.Source, block.Source, result);
                        foreach (var argument in block.Arguments ?? [])
                        {
                            IndexExpression(function, argument, argument, result);
                        }
                        IndexStatements(function, block.Body, result);
                    }
                    break;
            }
        }
    }

    private static void IndexExpression(
        BoundFunction function,
        Expression expression,
        object suspensionSite,
        IDictionary<object, BoundAsyncSuspensionLocation> result)
    {
        if (expression is FlowExpression { Targets.Count: > 0 } flow
            && flow.Targets[^1] is { Path.Count: 1 } target
            && string.Equals(target.Path[0], "await", StringComparison.Ordinal)
            && target.Arguments.Count == 0)
        {
            Add(function, suspensionSite, target.ByteOffset, target.Line, target.Column, result);
        }

        switch (expression)
        {
            case StringExpression value:
                foreach (var segment in value.Segments.OfType<InterpolationSegment>())
                    IndexExpression(function, segment.Expression, segment.Expression, result);
                break;
            case AddExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case SubtractExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case MultiplyExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case DivideExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case ModuloExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case CompareExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case AndExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case OrExpression value:
                IndexPair(function, value.Left, value.Right, result);
                break;
            case NegateExpression value:
                IndexExpression(function, value.Value, value.Value, result);
                break;
            case NotExpression value:
                IndexExpression(function, value.Value, value.Value, result);
                break;
            case FlowExpression value:
                IndexExpression(function, value.Source, value.Source, result);
                foreach (var argument in value.Targets.SelectMany(static target => target.Arguments))
                    IndexExpression(function, argument, argument, result);
                break;
            case BranchExpression value:
                IndexExpression(function, value.Source, value.Source, result);
                foreach (var argument in value.Arms.SelectMany(static arm => arm.Targets).SelectMany(static target => target.Arguments))
                    IndexExpression(function, argument, argument, result);
                break;
            case TapExpression value:
                IndexExpression(function, value.Source, value.Source, result);
                foreach (var argument in value.Targets.SelectMany(static target => target.Arguments))
                    IndexExpression(function, argument, argument, result);
                break;
            case StreamJoinExpression value:
                IndexExpression(function, value.Source, value.Source, result);
                break;
            case CallExpression value:
                foreach (var argument in value.Arguments)
                    IndexExpression(function, argument, argument, result);
                break;
            case RangeExpression value:
                IndexPair(function, value.Start, value.End, result);
                break;
            case ArrayLiteralExpression value:
                foreach (var element in value.Elements)
                    IndexExpression(function, element, element, result);
                break;
            case ArrayRepeatExpression value:
                IndexExpression(function, value.Value, value.Value, result);
                break;
            case DictionaryLiteralExpression value:
                foreach (var entry in value.Entries)
                    IndexPair(function, entry.Key, entry.Value, result);
                break;
            case IndexExpression value:
                IndexPair(function, value.Source, value.Index, result);
                break;
            case StructLiteralExpression value:
                foreach (var field in value.Fields)
                    IndexExpression(function, field.Value, field.Value, result);
                break;
            case ProductExpression value:
                foreach (var element in value.Elements)
                    IndexExpression(function, element.Value, element.Value, result);
                break;
            case BoxExpression value:
                IndexExpression(function, value.Value, value.Value, result);
                break;
            case TryExpression value:
                IndexExpression(function, value.Value, value.Value, result);
                break;
            case FieldAccessExpression value:
                IndexExpression(function, value.Source, value.Source, result);
                break;
            case IfExpression conditional:
                IndexExpression(function, conditional.Condition, conditional.Condition, result);
                IndexStatements(function, conditional.Then.Statements, result);
                if (conditional.Then.Value is { } thenValue)
                {
                    IndexExpression(function, thenValue, thenValue, result);
                }
                if (conditional.Else is { } alternative)
                {
                    IndexStatements(function, alternative.Statements, result);
                    if (alternative.Value is { } elseValue)
                    {
                        IndexExpression(function, elseValue, elseValue, result);
                    }
                }
                break;
            case WhenExpression selection:
                if (selection.Subject is { } subject)
                    IndexExpression(function, subject, subject, result);
                foreach (var arm in selection.Arms)
                {
                    IndexExpression(function, arm.Condition, arm.Condition, result);
                    IndexStatements(function, arm.Body.Statements, result);
                    if (arm.Body.Value is { } armValue)
                    {
                        IndexExpression(function, armValue, armValue, result);
                    }
                }
                IndexStatements(function, selection.Else.Statements, result);
                if (selection.Else.Value is { } selectionElseValue)
                {
                    IndexExpression(function, selectionElseValue, selectionElseValue, result);
                }
                break;
            case EnumMatchExpression selection:
                IndexExpression(function, selection.Subject, selection.Subject, result);
                foreach (var arm in selection.Arms)
                {
                    IndexStatements(function, arm.Body.Statements, result);
                    if (arm.Body.Value is { } armValue)
                        IndexExpression(function, armValue, armValue, result);
                }
                if (selection.Else is { } enumAlternative)
                {
                    IndexStatements(function, enumAlternative.Statements, result);
                    if (enumAlternative.Value is { } elseValue)
                        IndexExpression(function, elseValue, elseValue, result);
                }
                break;
            case FoldExpression value:
                IndexExpression(function, value.Source, value.Source, result);
                IndexExpression(function, value.Initial, value.Initial, result);
                IndexStatements(function, value.Body.Statements, result);
                if (value.Body.Value is { } foldValue)
                    IndexExpression(function, foldValue, foldValue, result);
                break;
        }
    }

    private static void IndexPair(
        BoundFunction function,
        Expression left,
        Expression right,
        IDictionary<object, BoundAsyncSuspensionLocation> result)
    {
        IndexExpression(function, left, left, result);
        IndexExpression(function, right, right, result);
    }

    private static void Add(
        BoundFunction function,
        object site,
        int byteOffset,
        int line,
        int column,
        IDictionary<object, BoundAsyncSuspensionLocation> result)
    {
        if (byteOffset < 0)
        {
            throw new InvalidOperationException(
                $"async suspension locator for '{function.Name}' is missing its parser byte offset");
        }

        result[site] = new BoundAsyncSuspensionLocation(function, byteOffset, line, column);
    }
}
