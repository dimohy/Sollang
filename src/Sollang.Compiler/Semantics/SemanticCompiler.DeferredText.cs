using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private readonly Dictionary<IReadOnlyDictionary<string, BoundType>, HashSet<string>>
        _deferredUserBlockResults = new(ReferenceEqualityComparer.Instance);

    private void RejectDeferredUserBlockResultStorage(
        BlockFunctionCallStatement call, BoundFunction function,
        IReadOnlyDictionary<string, BoundType> bindings)
    {
        if (function.Kind != BoundFunctionKind.UserBlock)
            return;

        // A user block is inlined. Yield retains the callback's representation;
        // it does not create an ordinary Text view with backing storage.
        var locals = new Dictionary<string, bool>(StringComparer.Ordinal)
        {
            [function.InputName ?? "it"] = CallerValue(call.Source)
        };
        var parameters = function.AdditionalParameters ?? [];
        var arguments = call.Arguments ?? [];
        for (var index = 0; index < parameters.Count; index++)
            locals[parameters[index].Name] = CallerValue(arguments[index]);
        CheckStatements(function.BlockBody, locals, producer: true);
        var deferredResult = function.Body is not null && IsDeferred(function.Body, locals, producer: true);
        if (deferredResult && call.ResultName is not null && !call.ResultIsSynthetic)
            throw Error(call.Line, call.Column,
                "deferred interpolation cannot be stored directly; materialize it into an explicit Arena owner");

        if (deferredResult && call.ResultName is not null)
        {
            if (!_deferredUserBlockResults.TryGetValue(bindings, out var results))
                _deferredUserBlockResults.Add(bindings, results = new HashSet<string>(StringComparer.Ordinal));
            results.Add(call.ResultName);
        }

        bool CallerValue(Expression expression) => IsUnmaterializedDeferredText(expression)
            || (expression is NameExpression name
                && _deferredUserBlockResults.TryGetValue(bindings, out var results)
                && results.Contains(name.Name));

        bool IsDeferred(Expression expression, Dictionary<string, bool> scope, bool producer) => expression switch
        {
            NameExpression name => scope.GetValueOrDefault(name.Name),
            StringExpression text => text.Segments.OfType<InterpolationSegment>().Any(),
            FlowExpression flow => FlowResult(flow, scope, producer),
            IfExpression conditional => BodyResult(conditional.Then, scope, producer)
                | (conditional.Else is not null && BodyResult(conditional.Else, scope, producer)),
            WhenExpression selection => selection.Arms.Select(arm => BodyResult(arm.Body, scope, producer))
                .Append(BodyResult(selection.Else, scope, producer)).Aggregate(false, (result, value) => result | value),
            EnumMatchExpression match => match.Arms.Select(arm => BodyResult(arm.Body, scope, producer))
                .Append(match.Else is not null && BodyResult(match.Else, scope, producer))
                .Aggregate(false, (result, value) => result | value),
            _ => false
        };

        bool FlowResult(FlowExpression flow, Dictionary<string, bool> scope, bool producer)
        {
            var deferred = IsDeferred(flow.Source, scope, producer);
            foreach (var target in flow.Targets)
            {
                // This is the same reserved yield decision used by InferFlowExpression.
                // Calls to materialize or ordinary consumers end this representation.
                deferred = producer && target.Path.Count == 1 && target.Path[0] == "yield"
                    && CallbackResult(target, deferred, scope);
            }
            return deferred;
        }

        bool CallbackResult(FlowTarget yield, bool input, Dictionary<string, bool> producerScope)
        {
            var scope = new Dictionary<string, bool>(StringComparer.Ordinal) { [call.ItemName] = input };
            var roles = call.AdditionalItemNames ?? [];
            for (var index = 0; index < roles.Count; index++)
                scope[roles[index]] = IsDeferred(yield.Arguments[index], producerScope, producer: true);
            CheckStatements(call.Body, scope, producer: false);
            return function.BlockResultType == BoundType.Text
                && call.Body.LastOrDefault() is ExpressionStatement value
                && IsDeferred(value.Expression, scope, producer: false);
        }

        bool BodyResult(BlockBody body, Dictionary<string, bool> parent, bool producer)
        {
            var scope = new Dictionary<string, bool>(parent, StringComparer.Ordinal);
            CheckStatements(body.Statements, scope, producer);
            return body.Value is not null && IsDeferred(body.Value, scope, producer);
        }

        void CheckStatements(IReadOnlyList<Statement> statements, Dictionary<string, bool> scope, bool producer)
        {
            foreach (var statement in statements)
            {
                switch (statement)
                {
                    case BindingStatement binding:
                        if (IsDeferred(binding.Value, scope, producer))
                            throw Error(binding.Line, binding.Column,
                                "deferred interpolation cannot be stored directly; materialize it into an explicit Arena owner");
                        scope[binding.Name] = false;
                        break;
                    case ExpressionStatement expression:
                        _ = IsDeferred(expression.Expression, scope, producer);
                        break;
                    case BlockFunctionCallStatement block:
                        CheckStatements(block.Body, new Dictionary<string, bool>(scope, StringComparer.Ordinal), producer);
                        break;
                }
            }
        }
    }
}
