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
                    || function.InputType != BoundType.SourceText
                    || function.InputOwnership != BoundFunctionInputOwnership.Default
                    || function.ReturnType != BoundType.Text)
                {
                    continue;
                }

                var inputName = function.InputName ?? "it";
                if (TryInferFunctionBorrowedTextOrigin(function, functions, inputName, out var origin)
                    && StringComparer.Ordinal.Equals(origin, inputName))
                {
                    _borrowedTextReturnOrigins.Add(function, inputName);
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

    private bool TryInferFunctionBorrowedTextOrigin(
        BoundFunction function,
        IReadOnlyDictionary<string, BoundFunction> functions,
        string inputName,
        out string origin)
    {
        var locals = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            [inputName] = inputName
        };
        foreach (var statement in function.BlockBody)
        {
            if (statement is ReturnStatement)
            {
                origin = "";
                return false;
            }
            if (statement is BindingStatement binding
                && TryInferBorrowedTextOrigin(binding.Value, functions, locals, out var bindingOrigin))
            {
                locals[binding.Name] = bindingOrigin;
            }
        }

        if (function.Body is not null)
        {
            return TryInferBorrowedTextOrigin(function.Body, functions, locals, out origin);
        }
        origin = "";
        return false;
    }

    private bool TryInferBorrowedTextOrigin(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, string> locals,
        out string origin)
    {
        if (expression is NameExpression name && locals.TryGetValue(name.Name, out origin!))
        {
            return true;
        }

        if (expression is CallExpression call
            && call.Arguments.Count > 0
            && TryGetFunction(call.Path, functions, out var called)
            && _borrowedTextReturnOrigins.ContainsKey(called)
            && TryInferBorrowedTextOrigin(call.Arguments[0], functions, locals, out origin))
        {
            return true;
        }

        if (expression is FlowExpression flow
            && TryInferBorrowedTextOrigin(flow.Source, functions, locals, out origin))
        {
            var retainedBorrow = false;
            foreach (var target in flow.Targets)
            {
                var path = string.Join('.', target.Path);
                if (path == "slice")
                {
                    retainedBorrow = true;
                    continue;
                }
                if (TryGetFunction(target.Path, functions, out var flowedFunction)
                    && _borrowedTextReturnOrigins.ContainsKey(flowedFunction))
                {
                    retainedBorrow = true;
                    continue;
                }

                origin = "";
                return false;
            }
            return retainedBorrow;
        }

        origin = "";
        return false;
    }

    private bool TryGetBorrowedTextCallOrigin(
        Expression expression,
        IReadOnlyDictionary<string, BoundFunction> functions,
        IReadOnlyDictionary<string, BoundType> bindings,
        out string origin)
    {
        if (expression is CallExpression call
            && call.Arguments.Count > 0
            && call.Arguments[0] is NameExpression argument
            && TryGetFunction(call.Path, functions, out var called)
            && _borrowedTextReturnOrigins.ContainsKey(called))
        {
            origin = CanonicalBorrowOriginName(argument.Name);
            return bindings.ContainsKey(argument.Name);
        }

        if (expression is FlowExpression flow && flow.Source is NameExpression source)
        {
            var borrowed = false;
            foreach (var target in flow.Targets)
            {
                if (target.Path.Count == 1 && target.Path[0] == "slice")
                {
                    borrowed = true;
                    continue;
                }
                if (TryGetFunction(target.Path, functions, out var flowedFunction)
                    && _borrowedTextReturnOrigins.ContainsKey(flowedFunction))
                {
                    borrowed = true;
                    continue;
                }
                if (borrowed)
                {
                    origin = "";
                    return false;
                }
            }
            if (borrowed && bindings.ContainsKey(source.Name))
            {
                origin = CanonicalBorrowOriginName(source.Name);
                return true;
            }
        }

        origin = "";
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

    private Dictionary<string, string> CaptureBorrowedTextOriginState() =>
        new(_activeBorrowedTextOrigins, StringComparer.Ordinal);

    private void RestoreBorrowedTextOriginState(IReadOnlyDictionary<string, string> state)
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
            .FirstOrDefault(pair => StringComparer.Ordinal.Equals(pair.Value, name));
        if (!StringComparer.Ordinal.Equals(borrowed.Value, name))
        {
            return;
        }

        throw Error(
            line,
            column,
            $"cannot move or mutate origin '{name}' while borrowed Text view '{borrowed.Key}' is live in this scope");
    }

    private static string CanonicalBorrowOriginName(string name) => name.TrimEnd('!');
}
