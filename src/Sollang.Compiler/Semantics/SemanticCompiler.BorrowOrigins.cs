using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private void DiscoverBorrowedTextReturnOrigins(
        IReadOnlyDictionary<string, BoundFunction> functions)
    {
        var candidates = new HashSet<BoundFunction>(ReferenceEqualityComparer.Instance);
        foreach (var function in functions.Values)
        {
            CollectFunctionTree(function, candidates);
        }

        var changed = true;
        while (changed)
        {
            changed = false;
            foreach (var function in candidates)
            {
                if (_borrowedTextReturnOrigins.ContainsKey(function)
                    || function.ReturnType != BoundType.Text
                    || !BorrowedSourceTextParameterNames(function).Any())
                {
                    continue;
                }

                if (TryInferFunctionBorrowedTextOrigins(function, functions, out var origins))
                {
                    _borrowedTextReturnOrigins.Add(function, origins);
                    changed = true;
                }
            }
        }
    }

    private static void CollectFunctionTree(
        BoundFunction function,
        HashSet<BoundFunction> functions)
    {
        if (!functions.Add(function))
        {
            return;
        }
        foreach (var local in function.LocalFunctions.Values)
        {
            CollectFunctionTree(local, functions);
        }
    }

    private static IEnumerable<string> BorrowedSourceTextParameterNames(BoundFunction function)
    {
        if (function.InputType == BoundType.SourceText
            && function.InputOwnership == BoundFunctionInputOwnership.Default)
        {
            yield return function.InputName ?? "it";
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            if (parameter.Type == BoundType.SourceText
                && parameter.Ownership == BoundFunctionInputOwnership.Default)
            {
                yield return parameter.Name;
            }
        }
    }

    private bool TryInferFunctionBorrowedTextOrigins(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        out IReadOnlySet<string> origins)
    {
        var locals = BorrowedSourceTextParameterNames(function).ToDictionary(
            static name => name,
            static name => (IReadOnlySet<string>)new HashSet<string>([name], StringComparer.Ordinal),
            StringComparer.Ordinal);
        foreach (var statement in function.BlockBody)
        {
            if (statement is ReturnStatement)
            {
                origins = EmptyBorrowOrigins();
                return false;
            }
            if (statement is BindingStatement binding
                && TryInferBorrowedTextOrigins(binding.Value, functions, locals, out var bindingOrigins))
            {
                locals[binding.Name] = bindingOrigins;
            }
        }

        if (function.Body is not null)
        {
            return TryInferBorrowedTextOrigins(function.Body, functions, locals, out origins);
        }
        origins = EmptyBorrowOrigins();
        return false;
    }

    private bool TryInferBorrowedTextOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        if (expression is NameExpression name && locals.TryGetValue(name.Name, out origins!))
        {
            return true;
        }

        if (expression is CallExpression call
            && TryGetFunction(call.Path, functions, out var called)
            && _borrowedTextReturnOrigins.TryGetValue(called, out var returnOrigins))
        {
            return TryMapBorrowedReturnOrigins(
                called,
                returnOrigins,
                call.Arguments,
                functions,
                locals,
                out origins);
        }

        if (expression is FlowExpression flow)
        {
            Expression current = flow.Source;
            for (var targetIndex = 0; targetIndex < flow.Targets.Count; targetIndex++)
            {
                var target = flow.Targets[targetIndex];
                var path = string.Join('.', target.Path);
                if (path == "slice")
                {
                    if (targetIndex != flow.Targets.Count - 1)
                    {
                        origins = EmptyBorrowOrigins();
                        return false;
                    }
                    if (!TryInferBorrowedTextOrigins(current, functions, locals, out origins))
                    {
                        origins = EmptyBorrowOrigins();
                        return false;
                    }
                    continue;
                }
                if (TryGetFunction(target.Path, functions, out var flowedFunction)
                    && _borrowedTextReturnOrigins.TryGetValue(flowedFunction, out var flowedReturnOrigins))
                {
                    if (targetIndex != flow.Targets.Count - 1)
                    {
                        origins = EmptyBorrowOrigins();
                        return false;
                    }
                    var arguments = new Expression[] { current }.Concat(target.Arguments).ToArray();
                    return TryMapBorrowedReturnOrigins(
                        flowedFunction,
                        flowedReturnOrigins,
                        arguments,
                        functions,
                        locals,
                        out origins);
                }

                origins = EmptyBorrowOrigins();
                return false;
            }
            return TryInferBorrowedTextOrigins(current, functions, locals, out origins);
        }

        if (expression is IfExpression conditional && conditional.Else is not null)
        {
            var union = new HashSet<string>(StringComparer.Ordinal);
            CollectBlockBorrowedTextOrigins(conditional.Then, functions, locals, union);
            CollectBlockBorrowedTextOrigins(conditional.Else, functions, locals, union);
            origins = union;
            return union.Count > 0;
        }

        if (expression is WhenExpression when)
        {
            var union = new HashSet<string>(StringComparer.Ordinal);
            foreach (var arm in when.Arms)
            {
                CollectBlockBorrowedTextOrigins(arm.Body, functions, locals, union);
            }
            CollectBlockBorrowedTextOrigins(when.Else, functions, locals, union);
            origins = union;
            return union.Count > 0;
        }

        origins = EmptyBorrowOrigins();
        return false;
    }

    private void CollectBlockBorrowedTextOrigins(
        BlockBody block,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> parentLocals,
        HashSet<string> union)
    {
        var locals = new Dictionary<string, IReadOnlySet<string>>(parentLocals, StringComparer.Ordinal);
        foreach (var statement in block.Statements)
        {
            if (statement is BindingStatement binding
                && TryInferBorrowedTextOrigins(binding.Value, functions, locals, out var bindingOrigins))
            {
                locals[binding.Name] = bindingOrigins;
            }
        }
        if (block.Value is not null
            && TryInferBorrowedTextOrigins(block.Value, functions, locals, out var origins))
        {
            union.UnionWith(origins);
        }
    }

    private bool TryMapBorrowedReturnOrigins(
        BoundFunction called,
        IReadOnlySet<string> returnOrigins,
        IReadOnlyList<Expression> arguments,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, IReadOnlySet<string>> locals,
        out IReadOnlySet<string> origins)
    {
        var parameters = FunctionParameters(called);
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var returnOrigin in returnOrigins)
        {
            var ordinal = parameters.FindIndex(parameter =>
                StringComparer.Ordinal.Equals(parameter, returnOrigin));
            if (ordinal < 0 || ordinal >= arguments.Count
                || !TryInferBorrowedTextOrigins(arguments[ordinal], functions, locals, out var argumentOrigins))
            {
                origins = EmptyBorrowOrigins();
                return false;
            }
            union.UnionWith(argumentOrigins);
        }
        origins = union;
        return union.Count > 0;
    }

    private static List<string> FunctionParameters(BoundFunction function)
    {
        var parameters = new List<string>();
        if (function.InputType is not null)
        {
            parameters.Add(function.InputName ?? "it");
        }
        parameters.AddRange((function.AdditionalParameters ?? []).Select(static parameter => parameter.Name));
        return parameters;
    }

    private bool TryGetBorrowedTextCallOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (expression is CallExpression call
            && TryGetFunction(call.Path, functions, out var called)
            && _borrowedTextReturnOrigins.TryGetValue(called, out var returnOrigins))
        {
            return TryMapCallSiteBorrowedOrigins(
                called, returnOrigins, call.Arguments, bindings, out origins);
        }

        if (expression is FlowExpression flow)
        {
            Expression current = flow.Source;
            for (var targetIndex = 0; targetIndex < flow.Targets.Count; targetIndex++)
            {
                var target = flow.Targets[targetIndex];
                if (target.Path.Count == 1 && target.Path[0] == "slice")
                {
                    if (targetIndex == flow.Targets.Count - 1
                        && TryGetConcreteBorrowOrigins(current, bindings, out origins))
                    {
                        return true;
                    }
                    continue;
                }
                if (TryGetFunction(target.Path, functions, out var flowedFunction)
                    && _borrowedTextReturnOrigins.TryGetValue(flowedFunction, out var flowedReturnOrigins))
                {
                    if (targetIndex != flow.Targets.Count - 1)
                    {
                        break;
                    }
                    var arguments = new Expression[] { current }.Concat(target.Arguments).ToArray();
                    return TryMapCallSiteBorrowedOrigins(
                        flowedFunction, flowedReturnOrigins, arguments, bindings, out origins);
                }
                break;
            }
        }

        origins = EmptyBorrowOrigins();
        return false;
    }

    private bool TryMapCallSiteBorrowedOrigins(
        BoundFunction called,
        IReadOnlySet<string> returnOrigins,
        IReadOnlyList<Expression> arguments,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        var parameters = FunctionParameters(called);
        var union = new HashSet<string>(StringComparer.Ordinal);
        foreach (var returnOrigin in returnOrigins)
        {
            var ordinal = parameters.FindIndex(parameter =>
                StringComparer.Ordinal.Equals(parameter, returnOrigin));
            if (ordinal < 0 || ordinal >= arguments.Count
                || !TryGetConcreteBorrowOrigins(arguments[ordinal], bindings, out var argumentOrigins))
            {
                origins = EmptyBorrowOrigins();
                return false;
            }
            union.UnionWith(argumentOrigins);
        }
        origins = union;
        return union.Count > 0;
    }

    private bool TryGetConcreteBorrowOrigins(
        Expression expression,
        IReadOnlyDictionary<string, BoundType> bindings,
        out IReadOnlySet<string> origins)
    {
        if (expression is NameExpression name && bindings.ContainsKey(name.Name))
        {
            if (_activeBorrowedTextOrigins.TryGetValue(name.Name, out origins!))
            {
                return true;
            }
            origins = new HashSet<string>(
                [CanonicalBorrowOriginName(name.Name)],
                StringComparer.Ordinal);
            return true;
        }
        origins = EmptyBorrowOrigins();
        return false;
    }

    private void RejectBorrowedTextOriginInvalidation(
        string? first,
        string? second,
        IReadOnlyList<string> consumed,
        IReadOnlyList<string> transferred,
        string? rebound,
        bool isRebind,
        int line,
        int column)
    {
        if (first is not null)
        {
            RejectBorrowedTextOriginMutation(first, line, column);
        }
        if (second is not null)
        {
            RejectBorrowedTextOriginMutation(second, line, column);
        }
        foreach (var name in consumed)
        {
            RejectBorrowedTextOriginMutation(name, line, column);
        }
        foreach (var name in transferred)
        {
            RejectBorrowedTextOriginMutation(name, line, column);
        }
        if (isRebind && rebound is not null)
        {
            RejectBorrowedTextOriginMutation(rebound, line, column);
        }
    }

    private void ExpireBorrowedTextOriginsBeforeStatement(
        IReadOnlyList<Statement> statements,
        int statementIndex,
        Expression? result,
        IReadOnlySet<string>? continuationNames)
    {
        foreach (var binding in _activeBorrowedTextOrigins.Keys.ToArray())
        {
            var isLive = continuationNames?.Contains(binding) == true;
            for (var index = statementIndex; index < statements.Count; index++)
            {
                if (StoragePlacementAnalyzer.ReferencesName(statements[index], binding))
                {
                    isLive = true;
                    break;
                }
            }

            if (!isLive
                && result is not null
                && StoragePlacementAnalyzer.ReferencesName(result, binding))
            {
                isLive = true;
            }

            if (!isLive)
            {
                _activeBorrowedTextOrigins.Remove(binding);
            }
        }
    }

    private HashSet<string> BorrowedTextContinuationAfterStatement(
        IReadOnlyList<Statement> statements,
        int statementIndex,
        Expression? result,
        IReadOnlySet<string>? continuationNames)
    {
        var live = continuationNames is null
            ? new HashSet<string>(StringComparer.Ordinal)
            : new HashSet<string>(continuationNames, StringComparer.Ordinal);
        foreach (var binding in _activeBorrowedTextOrigins.Keys)
        {
            for (var index = statementIndex + 1; index < statements.Count; index++)
            {
                if (StoragePlacementAnalyzer.ReferencesName(statements[index], binding))
                {
                    live.Add(binding);
                    break;
                }
            }

            if (result is not null && StoragePlacementAnalyzer.ReferencesName(result, binding))
            {
                live.Add(binding);
            }
        }
        return live;
    }

    private Dictionary<string, IReadOnlySet<string>> CaptureBorrowedTextOriginState() =>
        new(_activeBorrowedTextOrigins, StringComparer.Ordinal);

    private void RestoreBorrowedTextOriginState(IReadOnlyDictionary<string, IReadOnlySet<string>> state)
    {
        _activeBorrowedTextOrigins.Clear();
        foreach (var pair in state)
        {
            _activeBorrowedTextOrigins.Add(pair.Key, pair.Value);
        }
    }

    private void RejectBorrowedTextOriginMutation(string name, int line, int column)
    {
        name = CanonicalBorrowOriginName(name);
        var borrowed = _activeBorrowedTextOrigins
            .FirstOrDefault(pair => pair.Value.Contains(name));
        if (borrowed.Value is null)
        {
            return;
        }

        throw Error(
            line,
            column,
            $"cannot move or mutate origin '{name}' while borrowed Text view '{borrowed.Key}' is live in this scope");
    }

    private static IReadOnlySet<string> EmptyBorrowOrigins() =>
        new HashSet<string>(StringComparer.Ordinal);

    private static string CanonicalBorrowOriginName(string name) => name.TrimEnd('!');
}
