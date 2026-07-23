using System.Diagnostics;
using System.Globalization;
using System.Reflection;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Lexing;
using Sollang.Compiler.Parsing;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Browser;

public sealed record PlaygroundExecutionResult(
    bool Success,
    string Output,
    string Diagnostics,
    double CompileMilliseconds,
    double ExecuteMilliseconds);

public static class BrowserPlaygroundCompiler
{
    private static readonly Lazy<IReadOnlyList<SourceModule>> StandardLibrary =
        new(LoadStandardLibrary, LazyThreadSafetyMode.ExecutionAndPublication);

    public static PlaygroundExecutionResult CompileAndRun(string source)
    {
        var compileWatch = Stopwatch.StartNew();
        try
        {
            var standardLibrary = StandardLibrary.Value;
            var user = Parse("<playground>", source, isStandardLibrary: false);
            var modules = standardLibrary
                .Where(static module => module.ModuleName.Length > 0)
                .ToDictionary(static module => module.ModuleName, StringComparer.Ordinal);
            user = ReparseWithOpenImports(user, modules);

            var combined = new SollangProgram(
                [],
                [],
                standardLibrary.SelectMany(static module => module.Program.Structs)
                    .Concat(user.Program.Structs)
                    .ToArray(),
                standardLibrary.SelectMany(static module => module.Program.Enums)
                    .Concat(user.Program.Enums)
                    .ToArray(),
                standardLibrary.SelectMany(static module => module.Program.Traits)
                    .Concat(user.Program.Traits)
                    .ToArray(),
                standardLibrary.SelectMany(static module => module.Program.Functions)
                    .Concat(user.Program.Functions)
                    .ToArray(),
                user.Program.Statements);

            _ = new SemanticCompiler(combined, pointerBitWidth: 32).Compile();
            compileWatch.Stop();

            var executeWatch = Stopwatch.StartNew();
            var interpreter = new PlaygroundInterpreter(combined);
            var output = interpreter.Run();
            executeWatch.Stop();
            return new PlaygroundExecutionResult(
                true,
                output,
                "",
                compileWatch.Elapsed.TotalMilliseconds,
                executeWatch.Elapsed.TotalMilliseconds);
        }
        catch (SollangException ex)
        {
            compileWatch.Stop();
            return new PlaygroundExecutionResult(
                false,
                "",
                $"sollang: {ex.Message}",
                compileWatch.Elapsed.TotalMilliseconds,
                0);
        }
        catch (PlaygroundRuntimeException ex)
        {
            compileWatch.Stop();
            return new PlaygroundExecutionResult(
                false,
                ex.Output,
                $"sollang: runtime error: {ex.Message}",
                compileWatch.Elapsed.TotalMilliseconds,
                ex.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            compileWatch.Stop();
            return new PlaygroundExecutionResult(
                false,
                "",
                $"sollang: unexpected browser compiler failure: {ex.Message}",
                compileWatch.Elapsed.TotalMilliseconds,
                0);
        }
    }

    private static IReadOnlyList<SourceModule> LoadStandardLibrary()
    {
        var assembly = typeof(BrowserPlaygroundCompiler).Assembly;
        var parsed = assembly
            .GetManifestResourceNames()
            .Where(static name => name.StartsWith("Sollang.StandardLibrary.", StringComparison.Ordinal)
                && name.EndsWith(".slg", StringComparison.Ordinal))
            .Order(StringComparer.Ordinal)
            .Select(name =>
            {
                using var stream = assembly.GetManifestResourceStream(name)
                    ?? throw new SollangException($"embedded standard library resource is missing: {name}");
                using var reader = new StreamReader(
                    stream,
                    new UTF8Encoding(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true),
                    detectEncodingFromByteOrderMarks: true);
                return Parse(name, reader.ReadToEnd(), isStandardLibrary: true);
            })
            .ToArray();

        var modules = parsed
            .Where(static source => source.ModuleName.Length > 0)
            .ToDictionary(static source => source.ModuleName, StringComparer.Ordinal);
        return parsed.Select(source => ReparseWithOpenImports(source, modules)).ToArray();
    }

    private static SourceModule Parse(string path, string source, bool isStandardLibrary,
        IReadOnlyDictionary<string, IReadOnlyList<OpenImportCandidate>>? openImports = null)
    {
        var tokens = new Lexer(source).Lex();
        var program = new Parser(tokens, isStandardLibrary, openImports).Parse();
        return new SourceModule(path, source, program, string.Join('.', program.NamespacePath));
    }

    private static SourceModule ReparseWithOpenImports(
        SourceModule source,
        IReadOnlyDictionary<string, SourceModule> modules)
    {
        var localNames = DirectDeclarationNames(source.Program).ToHashSet(StringComparer.Ordinal);
        var explicitAliases = source.Program.Imports
            .Select(static import => import.Alias)
            .ToHashSet(StringComparer.Ordinal);
        var candidates = new Dictionary<string, List<OpenImportCandidate>>(StringComparer.Ordinal);

        foreach (var import in source.Program.Imports)
        {
            var moduleName = string.Join('.', import.Path);
            if (!modules.TryGetValue(moduleName, out var importedModule))
            {
                continue;
            }

            foreach (var (name, path) in PublicModuleSymbols(importedModule))
            {
                if (localNames.Contains(name) || explicitAliases.Contains(name))
                {
                    continue;
                }
                if (!candidates.TryGetValue(name, out var named))
                {
                    named = [];
                    candidates.Add(name, named);
                }
                if (!named.Any(candidate => candidate.Path.SequenceEqual(path)))
                {
                    named.Add(new OpenImportCandidate(path, import.Alias));
                }
            }
        }

        if (candidates.Count == 0)
        {
            return source;
        }

        var openImports = candidates.ToDictionary(
            static pair => pair.Key,
            static pair => (IReadOnlyList<OpenImportCandidate>)pair.Value,
            StringComparer.Ordinal);
        return Parse(source.Path, source.Text, source.Program.Functions.Any(static function => function.IsStandardLibrary),
            openImports);
    }

    private static IEnumerable<string> DirectDeclarationNames(SollangProgram program)
    {
        var moduleName = string.Join('.', program.NamespacePath);
        foreach (var function in program.Functions)
        {
            if (TryGetDirectSymbolName(moduleName, function.Name, out var name))
            {
                yield return name;
            }
        }
        foreach (var name in program.Structs.Select(static value => value.Name)
                     .Concat(program.Enums.Select(static value => value.Name))
                     .Concat(program.Traits.Select(static value => value.Name)))
        {
            if (TryGetDirectSymbolName(moduleName, name, out var symbol))
            {
                yield return symbol;
            }
        }
    }

    private static IEnumerable<(string Name, IReadOnlyList<string> Path)> PublicModuleSymbols(SourceModule source)
    {
        foreach (var function in source.Program.Functions)
        {
            if ((function.IsPublic || function.IsStandardLibrary)
                && TryGetDirectSymbolName(source.ModuleName, function.Name, out var name))
            {
                yield return (name, function.Name.Split('.'));
            }
        }
        foreach (var (name, isPublic) in source.Program.Structs
                     .Select(static value => (value.Name, value.IsPublic))
                     .Concat(source.Program.Enums.Select(static value => (value.Name, value.IsPublic)))
                     .Concat(source.Program.Traits.Select(static value => (value.Name, value.IsPublic))))
        {
            if (isPublic && TryGetDirectSymbolName(source.ModuleName, name, out var symbol))
            {
                yield return (symbol, name.Split('.'));
            }
        }
    }

    private static bool TryGetDirectSymbolName(string moduleName, string declarationName, out string symbolName)
    {
        var prefix = moduleName.Length == 0 ? "" : moduleName + ".";
        if (!declarationName.StartsWith(prefix, StringComparison.Ordinal))
        {
            symbolName = "";
            return false;
        }
        var remainder = declarationName[prefix.Length..];
        if (remainder.Length == 0 || remainder.Contains('.', StringComparison.Ordinal))
        {
            symbolName = "";
            return false;
        }
        symbolName = remainder;
        return true;
    }

    private sealed record SourceModule(string Path, string Text, SollangProgram Program, string ModuleName);
}

internal sealed class PlaygroundRuntimeException(
    string message,
    string output,
    double elapsedMilliseconds = 0) : Exception(message)
{
    public string Output { get; } = output;
    public double ElapsedMilliseconds { get; } = elapsedMilliseconds;
}

internal sealed class PlaygroundInterpreter
{
    private readonly SollangProgram _program;
    private readonly Dictionary<string, FunctionDeclaration> _functions;
    private readonly StringBuilder _output = new();
    private readonly Stopwatch _watch = Stopwatch.StartNew();
    private readonly PipelineControl _pipeline = new();
    private BlockInvocation? _blockInvocation;
    private Action<object?>? _emit;
    private const long StepLimit = 5_000_000;
    private long _steps;

    public PlaygroundInterpreter(SollangProgram program)
    {
        _program = program;
        _functions = FlattenFunctions(program.Functions)
            .GroupBy(static function => function.Name, StringComparer.Ordinal)
            .ToDictionary(static group => group.Key, static group => group.Last(), StringComparer.Ordinal);
    }

    public string Run()
    {
        try
        {
            ExecuteStatements(_program.Statements, new Scope());
            _watch.Stop();
            return _output.ToString();
        }
        catch (PlaygroundRuntimeException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _watch.Stop();
            throw new PlaygroundRuntimeException(ex.Message, _output.ToString(), _watch.Elapsed.TotalMilliseconds);
        }
    }

    private static IEnumerable<FunctionDeclaration> FlattenFunctions(IEnumerable<FunctionDeclaration> functions)
    {
        foreach (var function in functions)
        {
            yield return function;
            foreach (var local in FlattenFunctions(function.LocalFunctions))
            {
                yield return local;
            }
        }
    }

    private void Tick()
    {
        _steps++;
        if (_steps > StepLimit)
        {
            throw new PlaygroundRuntimeException(
                "execution step limit exceeded",
                _output.ToString(),
                _watch.Elapsed.TotalMilliseconds);
        }
    }

    private void ExecuteStatements(IReadOnlyList<Statement> statements, Scope scope)
    {
        foreach (var statement in statements)
        {
            Tick();
            ExecuteStatement(statement, scope);
        }
    }

    private void ExecuteStatement(Statement statement, Scope scope)
    {
        switch (statement)
        {
            case BindingStatement binding:
                if (binding.IsStreamState && scope.ContainsLocal(binding.Name))
                {
                    return;
                }
                scope.Set(binding.Name, Evaluate(binding.Value, scope));
                return;
            case FieldAssignmentStatement assignment:
                var owner = AsStruct(scope.Get(assignment.Name), assignment.Name);
                owner.Fields[assignment.FieldName] = Evaluate(assignment.Value, scope);
                return;
            case IndexAssignmentStatement assignment:
                var list = AsList(scope.Get(assignment.Name), assignment.Name);
                list[checked((int)AsInt(Evaluate(assignment.Index, scope)))] =
                    Evaluate(assignment.Value, scope);
                return;
            case ExpressionStatement expression:
                _ = Evaluate(expression.Expression, scope);
                return;
            case BlockFunctionPipelineStatement pipeline:
                ExecutePipeline(pipeline, scope);
                return;
            case BlockFunctionCallStatement call:
                ExecuteBlockCall(call, scope);
                return;
            case StreamStopStatement:
                _pipeline.Stopped = true;
                return;
            case LoopControlStatement { Kind: LoopControlKind.Break }:
                throw new BreakSignal();
            case LoopControlStatement { Kind: LoopControlKind.Continue }:
                throw new ContinueSignal();
            case GuardLoopControlStatement guard:
                if (AsBool(Evaluate(guard.Condition, scope)))
                {
                    if (guard.Kind == LoopControlKind.Break)
                    {
                        throw new BreakSignal();
                    }
                    throw new ContinueSignal();
                }
                return;
            case ReturnStatement returned:
                throw new ReturnSignal(returned.Value is null ? Unit.Value : Evaluate(returned.Value, scope));
            default:
                throw RuntimeError($"unsupported statement {statement.GetType().Name}");
        }
    }

    private object? Evaluate(Expression expression, Scope scope)
    {
        Tick();
        return expression switch
        {
            NumberExpression number => long.Parse(number.Text, NumberStyles.Integer, CultureInfo.InvariantCulture),
            BoolExpression boolean => boolean.Value,
            StringExpression text => EvaluateString(text, scope),
            NameExpression name => scope.Get(name.Name),
            AddExpression value => Add(Evaluate(value.Left, scope), Evaluate(value.Right, scope)),
            SubtractExpression value => AsInt(Evaluate(value.Left, scope)) - AsInt(Evaluate(value.Right, scope)),
            MultiplyExpression value => AsInt(Evaluate(value.Left, scope)) * AsInt(Evaluate(value.Right, scope)),
            DivideExpression value => AsInt(Evaluate(value.Left, scope)) / AsInt(Evaluate(value.Right, scope)),
            ModuloExpression value => AsInt(Evaluate(value.Left, scope)) % AsInt(Evaluate(value.Right, scope)),
            NegateExpression value => -AsInt(Evaluate(value.Value, scope)),
            CompareExpression value => Compare(
                Evaluate(value.Left, scope), value.Operator, Evaluate(value.Right, scope)),
            AndExpression value => AsBool(Evaluate(value.Left, scope)) && AsBool(Evaluate(value.Right, scope)),
            OrExpression value => AsBool(Evaluate(value.Left, scope)) || AsBool(Evaluate(value.Right, scope)),
            NotExpression value => !AsBool(Evaluate(value.Value, scope)),
            RangeExpression range => new RangeValue(
                AsInt(Evaluate(range.Start, scope)), AsInt(Evaluate(range.End, scope))),
            ArrayLiteralExpression array => array.Elements.Select(item => Evaluate(item, scope)).ToList(),
            ArrayRepeatExpression array => Enumerable.Range(0, array.Count ?? 0)
                .Select(_ => Evaluate(array.Value, scope)).ToList(),
            TypedEmptyArrayExpression => new List<object?>(),
            IndexExpression index => EvaluateIndex(index, scope),
            StructLiteralExpression structure => new StructValue(
                structure.TypeName,
                structure.Fields.ToDictionary(
                    static field => field.Name,
                    field => Evaluate(field.Value, scope),
                    StringComparer.Ordinal)),
            FieldAccessExpression field => AsStruct(Evaluate(field.Source, scope), field.FieldName)
                .Fields[field.FieldName],
            FlowExpression flow => EvaluateFlow(flow, scope),
            CallExpression call => InvokeCall(call.Path, call.Arguments, scope),
            IfExpression conditional => EvaluateIf(conditional, scope),
            FoldExpression fold => EvaluateFold(fold, scope),
            _ => throw RuntimeError($"unsupported expression {expression.GetType().Name}")
        };
    }

    private string EvaluateString(StringExpression expression, Scope scope)
    {
        var builder = new StringBuilder();
        foreach (var segment in expression.Segments)
        {
            switch (segment)
            {
                case TextSegment text:
                    builder.Append(text.Text);
                    break;
                case InterpolationSegment interpolation:
                    builder.Append(Format(Evaluate(interpolation.Expression, scope)));
                    break;
            }
        }
        return builder.ToString();
    }

    private object? EvaluateIndex(IndexExpression expression, Scope scope)
    {
        var source = Evaluate(expression.Source, scope);
        var index = checked((int)AsInt(Evaluate(expression.Index, scope)));
        return source switch
        {
            List<object?> list => list[index],
            string text => text[index].ToString(),
            _ => throw RuntimeError("indexing requires an array or Text")
        };
    }

    private object? EvaluateFlow(FlowExpression expression, Scope scope)
    {
        object? current = Evaluate(expression.Source, scope);
        foreach (var target in expression.Targets)
        {
            var name = string.Join('.', target.Path);
            switch (name)
            {
                case "yield":
                    if (_blockInvocation is null)
                    {
                        throw RuntimeError("yield is only valid inside a block function");
                    }
                    current = InvokeBlock(
                        _blockInvocation,
                        current,
                        target.Arguments.Select(argument => Evaluate(argument, scope)).ToArray());
                    break;
                case "emit":
                    if (_emit is null)
                    {
                        throw RuntimeError("emit requires a downstream stream consumer");
                    }
                    _emit(current);
                    current = Unit.Value;
                    break;
                case "print":
                case "sys.io.print":
                    _output.Append(Format(current));
                    current = Unit.Value;
                    break;
                case "println":
                case "sys.io.println":
                    _output.Append(Format(current));
                    _output.Append('\n');
                    current = Unit.Value;
                    break;
                case "len":
                    current = current switch
                    {
                        List<object?> list => (long)list.Count,
                        string text => (long)text.Length,
                        _ => throw RuntimeError("len expects an array or Text")
                    };
                    break;
                default:
                    current = InvokeFunction(
                        ResolveFunction(name),
                        current,
                        target.Arguments.Select(argument => Evaluate(argument, scope)).ToArray(),
                        scope,
                        callback: null,
                        emit: null,
                        persistentScope: null);
                    break;
            }
        }
        return current;
    }

    private object? InvokeCall(IReadOnlyList<string> path, IReadOnlyList<Expression> arguments, Scope scope)
    {
        var name = string.Join('.', path);
        if (name is "println" or "sys.io.println")
        {
            if (arguments.Count == 0)
            {
                _output.Append('\n');
            }
            else
            {
                _output.Append(Format(Evaluate(arguments[0], scope)));
                _output.Append('\n');
            }
            return Unit.Value;
        }
        if (name is "print" or "sys.io.print")
        {
            if (arguments.Count > 0)
            {
                _output.Append(Format(Evaluate(arguments[0], scope)));
            }
            return Unit.Value;
        }

        var function = ResolveFunction(name);
        var values = arguments.Select(argument => Evaluate(argument, scope)).ToArray();
        object? primary = values.Length > 0 ? values[0] : Unit.Value;
        var additional = values.Length > 1 ? values[1..] : [];
        return InvokeFunction(function, primary, additional, scope, null, null, null);
    }

    private object? EvaluateIf(IfExpression expression, Scope scope)
    {
        if (AsBool(Evaluate(expression.Condition, scope)))
        {
            return EvaluateBlockBody(expression.Then, scope);
        }
        return expression.Else is null ? Unit.Value : EvaluateBlockBody(expression.Else, scope);
    }

    private object? EvaluateFold(FoldExpression fold, Scope scope)
    {
        var accumulator = Evaluate(fold.Initial, scope);
        foreach (var item in Enumerate(Evaluate(fold.Source, scope)))
        {
            var child = new Scope(scope);
            child.Set(fold.AccumulatorName, accumulator);
            child.Set(fold.ItemName, item);
            accumulator = EvaluateBlockBody(fold.Body, child);
        }
        return accumulator;
    }

    private object? EvaluateBlockBody(BlockBody block, Scope scope)
    {
        var child = new Scope(scope);
        try
        {
            ExecuteStatements(block.Statements, child);
            return block.Value is null ? Unit.Value : Evaluate(block.Value, child);
        }
        catch (ReturnSignal)
        {
            throw;
        }
    }

    private void ExecuteBlockCall(BlockFunctionCallStatement call, Scope scope)
    {
        var name = string.Join('.', call.Target);
        if (name == "each")
        {
            foreach (var item in Enumerate(Evaluate(call.Source, scope)))
            {
                try
                {
                    var child = new Scope(scope);
                    child.Set(call.ItemName, item);
                    ExecuteStatements(call.Body, child);
                }
                catch (ContinueSignal)
                {
                }
                catch (BreakSignal)
                {
                    break;
                }
                if (_pipeline.Stopped)
                {
                    break;
                }
            }
            return;
        }

        var function = ResolveFunction(name);
        var result = InvokeFunction(
            function,
            Evaluate(call.Source, scope),
            (call.Arguments ?? []).Select(argument => Evaluate(argument, scope)).ToArray(),
            scope,
            new BlockInvocation(call, scope, function.BlockResultType),
            null,
            null);
        if (call.ResultName is not null)
        {
            scope.Set(call.ResultName, result);
        }
    }

    private void ExecutePipeline(BlockFunctionPipelineStatement pipeline, Scope callerScope)
    {
        _pipeline.Stopped = false;
        var calls = pipeline.Calls;
        if (calls.Count == 0)
        {
            return;
        }

        var source = Evaluate(calls[0].Source, callerScope);
        Action<object?> terminal = value =>
        {
            var call = calls[^1];
            var child = new Scope(callerScope);
            child.Set(call.ItemName, value);
            try
            {
                ExecuteStatements(call.Body, child);
            }
            catch (ContinueSignal)
            {
            }
            catch (BreakSignal)
            {
                _pipeline.Stopped = true;
            }
        };

        Action<object?> sink = terminal;
        for (var index = calls.Count - 2; index >= 1; index--)
        {
            var call = calls[index];
            var function = ResolveFunction(string.Join('.', call.Target));
            var downstream = sink;
            var state = new Scope();
            var arguments = (call.Arguments ?? [])
                .Select(argument => Evaluate(argument, callerScope))
                .ToArray();
            var callback = function.BlockInputType is null
                ? null
                : new BlockInvocation(call, callerScope, function.BlockResultType);
            sink = value =>
            {
                _ = InvokeFunction(
                    function, value, arguments, callerScope, callback, downstream, state);
            };
        }

        var first = calls[0];
        if (string.Join('.', first.Target) == "each")
        {
            foreach (var item in Enumerate(source))
            {
                terminal(item);
                if (_pipeline.Stopped)
                {
                    break;
                }
            }
            return;
        }

        var firstFunction = ResolveFunction(string.Join('.', first.Target));
        var firstCallback = firstFunction.BlockInputType is null
            ? null
            : new BlockInvocation(first, callerScope, firstFunction.BlockResultType);
        _ = InvokeFunction(
            firstFunction,
            source,
            (first.Arguments ?? []).Select(argument => Evaluate(argument, callerScope)).ToArray(),
            callerScope,
            firstCallback,
            sink,
            new Scope());
    }

    private object? InvokeFunction(
        FunctionDeclaration function,
        object? primary,
        IReadOnlyList<object?> additional,
        Scope callerScope,
        BlockInvocation? callback,
        Action<object?>? emit,
        Scope? persistentScope)
    {
        if (function.IsIntrinsic)
        {
            return InvokeIntrinsic(function.Name, primary);
        }

        var scope = persistentScope ?? new Scope();
        if (function.InputName is not null)
        {
            scope.Set(function.InputName, primary);
        }
        var parameters = function.AdditionalParameters ?? [];
        for (var index = 0; index < parameters.Count; index++)
        {
            scope.Set(parameters[index].Name, additional[index]);
        }

        var previousBlock = _blockInvocation;
        var previousEmit = _emit;
        _blockInvocation = callback;
        _emit = emit;
        try
        {
            ExecuteStatements(function.BlockBody, scope);
            return function.Body is null ? Unit.Value : Evaluate(function.Body, scope);
        }
        catch (ReturnSignal returned)
        {
            return returned.Value;
        }
        finally
        {
            _blockInvocation = previousBlock;
            _emit = previousEmit;
        }
    }

    private object? InvokeIntrinsic(string name, object? primary)
    {
        if (name.EndsWith(".print", StringComparison.Ordinal))
        {
            _output.Append(Format(primary));
            return Unit.Value;
        }
        if (name.EndsWith(".println", StringComparison.Ordinal))
        {
            _output.Append(Format(primary));
            _output.Append('\n');
            return Unit.Value;
        }
        throw RuntimeError($"intrinsic '{name}' is unavailable in the browser playground");
    }

    private object? InvokeBlock(BlockInvocation invocation, object? value, IReadOnlyList<object?> additional)
    {
        var child = new Scope(invocation.CallerScope);
        child.Set(invocation.Call.ItemName, value);
        var names = invocation.Call.AdditionalItemNames ?? [];
        for (var index = 0; index < names.Count; index++)
        {
            child.Set(names[index], additional[index]);
        }

        if (invocation.ResultType is null or "Unit")
        {
            ExecuteStatements(invocation.Call.Body, child);
            return Unit.Value;
        }
        if (invocation.Call.Body.Count == 0
            || invocation.Call.Body[^1] is not ExpressionStatement result)
        {
            throw RuntimeError("result-producing callback has no final expression");
        }
        ExecuteStatements(invocation.Call.Body.Take(invocation.Call.Body.Count - 1).ToArray(), child);
        return Evaluate(result.Expression, child);
    }

    private FunctionDeclaration ResolveFunction(string name)
    {
        if (_functions.TryGetValue(name, out var function))
        {
            return function;
        }
        var matches = _functions.Values
            .Where(candidate => candidate.Name.EndsWith("." + name, StringComparison.Ordinal)
                || candidate.Name == name)
            .ToArray();
        return matches.Length == 1
            ? matches[0]
            : throw RuntimeError($"unknown function '{name}'");
    }

    private static IEnumerable<object?> Enumerate(object? value)
    {
        return value switch
        {
            RangeValue range => EnumerateRange(range),
            List<object?> list => list,
            string text => text.Select(static character => (object?)character.ToString()),
            _ => throw new InvalidOperationException("each expects a Range, array, or Text")
        };
    }

    private static IEnumerable<object?> EnumerateRange(RangeValue range)
    {
        for (var value = range.Start; value <= range.End; value++)
        {
            yield return value;
            if (value == long.MaxValue)
            {
                yield break;
            }
        }
    }

    private static object Add(object? left, object? right) =>
        left is string || right is string
            ? Format(left) + Format(right)
            : AsInt(left) + AsInt(right);

    private static bool Compare(object? left, ComparisonOperator operation, object? right)
    {
        if (left is long leftInt && right is long rightInt)
        {
            return operation switch
            {
                ComparisonOperator.Equal => leftInt == rightInt,
                ComparisonOperator.NotEqual => leftInt != rightInt,
                ComparisonOperator.Less => leftInt < rightInt,
                ComparisonOperator.LessOrEqual => leftInt <= rightInt,
                ComparisonOperator.Greater => leftInt > rightInt,
                ComparisonOperator.GreaterOrEqual => leftInt >= rightInt,
                _ => false
            };
        }
        var comparison = string.CompareOrdinal(Format(left), Format(right));
        return operation switch
        {
            ComparisonOperator.Equal => comparison == 0,
            ComparisonOperator.NotEqual => comparison != 0,
            ComparisonOperator.Less => comparison < 0,
            ComparisonOperator.LessOrEqual => comparison <= 0,
            ComparisonOperator.Greater => comparison > 0,
            ComparisonOperator.GreaterOrEqual => comparison >= 0,
            _ => false
        };
    }

    private static long AsInt(object? value) => value switch
    {
        long integer => integer,
        int integer => integer,
        _ => throw new InvalidOperationException($"expected Int but received {Format(value)}")
    };

    private static bool AsBool(object? value) => value is bool boolean
        ? boolean
        : throw new InvalidOperationException($"expected Bool but received {Format(value)}");

    private static List<object?> AsList(object? value, string name) => value as List<object?>
        ?? throw new InvalidOperationException($"{name} is not an array");

    private static StructValue AsStruct(object? value, string name) => value as StructValue
        ?? throw new InvalidOperationException($"{name} is not a struct");

    private static string Format(object? value) => value switch
    {
        null => "",
        Unit => "",
        bool boolean => boolean ? "true" : "false",
        long integer => integer.ToString(CultureInfo.InvariantCulture),
        StructValue structure => structure.TypeName,
        List<object?> list => "[" + string.Join(", ", list.Select(Format)) + "]",
        _ => Convert.ToString(value, CultureInfo.InvariantCulture) ?? ""
    };

    private PlaygroundRuntimeException RuntimeError(string message) =>
        new(message, _output.ToString(), _watch.Elapsed.TotalMilliseconds);

    private sealed class Scope(Scope? parent = null)
    {
        private readonly Dictionary<string, object?> _values = new(StringComparer.Ordinal);

        public bool ContainsLocal(string name) => _values.ContainsKey(name);

        public object? Get(string name)
        {
            if (_values.TryGetValue(name, out var value))
            {
                return value;
            }
            return parent?.Get(name)
                ?? throw new InvalidOperationException($"unknown binding '{name}'");
        }

        public void Set(string name, object? value)
        {
            if (_values.ContainsKey(name))
            {
                _values[name] = value;
                return;
            }
            if (parent is not null && parent.Contains(name))
            {
                parent.Set(name, value);
                return;
            }
            _values[name] = value;
        }

        private bool Contains(string name) => _values.ContainsKey(name)
            || (parent?.Contains(name) ?? false);
    }

    private sealed record RangeValue(long Start, long End);
    private sealed record StructValue(string TypeName, Dictionary<string, object?> Fields);
    private sealed record BlockInvocation(
        BlockFunctionCallStatement Call,
        Scope CallerScope,
        string? ResultType);
    private sealed class PipelineControl
    {
        public bool Stopped { get; set; }
    }
    private sealed class Unit
    {
        public static Unit Value { get; } = new();
    }
    private sealed class BreakSignal : Exception;
    private sealed class ContinueSignal : Exception;
    private sealed class ReturnSignal(object? value) : Exception
    {
        public object? Value { get; } = value;
    }
}
