using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal static class FunctionControlFlowFacts
{
    public static bool HasEarlyReturn(BoundFunction function) =>
        function.BlockBody.Any(ContainsReturn)
        || (function.Body is not null && ContainsReturn(function.Body));

    public static bool AllPathsReturn(Expression expression) => !MayReachContinuation(expression);

    public static bool MayReachContinuation(BlockBody block)
    {
        foreach (var statement in block.Statements)
        {
            if (!MayReachContinuation(statement))
            {
                return false;
            }
        }

        return block.Value is null || MayReachContinuation(block.Value);
    }

    private static bool MayReachContinuation(Statement statement) => statement switch
    {
        ReturnStatement => false,
        BindingStatement binding => MayReachContinuation(binding.Value),
        IndexAssignmentStatement assignment =>
            MayReachContinuation(assignment.Index) && MayReachContinuation(assignment.Value),
        FieldAssignmentStatement assignment => MayReachContinuation(assignment.Value),
        ExpressionStatement expression => MayReachContinuation(expression.Expression),
        // Returns inside a callback body do not make invocation of the block
        // function itself unconditional; the callee controls whether it runs.
        BlockFunctionCallStatement or BlockFunctionPipelineStatement => true,
        _ => true
    };

    private static bool MayReachContinuation(Expression expression) => expression switch
    {
        IfExpression { Else: { } alternative } conditional =>
            MayReachContinuation(conditional.Then) || MayReachContinuation(alternative),
        IfExpression => true,
        WhenExpression selection =>
            selection.Arms.Any(arm => MayReachContinuation(arm.Body))
            || MayReachContinuation(selection.Else),
        EnumMatchExpression selection =>
            selection.Arms.Any(arm => MayReachContinuation(arm.Body))
            || (selection.Else is not null && MayReachContinuation(selection.Else)),
        _ => true
    };

    public static bool RequiresStandaloneStandardLibraryEmission(BoundFunction function)
    {
        return HasEarlyReturn(function)
            || function.BlockBody.Any(ContainsStackCandidate)
            || (function.Body is not null && ContainsStackCandidate(function.Body));
    }

    private static bool ContainsStackCandidate(Statement statement) => statement switch
    {
        BindingStatement binding => ContainsStackCandidate(binding.Value),
        IndexAssignmentStatement assignment => ContainsStackCandidate(assignment.Index) || ContainsStackCandidate(assignment.Value),
        FieldAssignmentStatement assignment => ContainsStackCandidate(assignment.Value),
        BlockFunctionCallStatement block => ContainsStackCandidate(block.Source) || block.Body.Any(ContainsStackCandidate),
        BlockFunctionPipelineStatement pipeline => pipeline.Calls.Any(ContainsStackCandidate),
        ExpressionStatement expression => ContainsStackCandidate(expression.Expression),
        GuardLoopControlStatement guard => ContainsStackCandidate(guard.Condition),
        ReturnStatement { Value: { } value } => ContainsStackCandidate(value),
        _ => false
    };

    private static bool ContainsStackCandidate(BlockBody? block)
    {
        return block is not null
            && (block.Statements.Any(ContainsStackCandidate)
                || (block.Value is not null && ContainsStackCandidate(block.Value)));
    }

    private static bool ContainsStackCandidate(Expression expression) => expression switch
    {
        ArrayLiteralExpression or TypedEmptyArrayExpression
            or ArrayRepeatExpression or DictionaryLiteralExpression
            or TypedEmptyDictionaryExpression => true,
        IfExpression conditional => ContainsStackCandidate(conditional.Condition)
            || ContainsStackCandidate(conditional.Then)
            || ContainsStackCandidate(conditional.Else),
        WhenExpression whenExpression => (whenExpression.Subject is not null && ContainsStackCandidate(whenExpression.Subject))
            || whenExpression.Arms.Any(arm => ContainsStackCandidate(arm.Condition) || ContainsStackCandidate(arm.Body))
            || ContainsStackCandidate(whenExpression.Else),
        EnumMatchExpression match => ContainsStackCandidate(match.Subject)
            || match.Arms.Any(arm => ContainsStackCandidate(arm.Condition) || ContainsStackCandidate(arm.Body))
            || ContainsStackCandidate(match.Else),
        FoldExpression fold => ContainsStackCandidate(fold.Source)
            || ContainsStackCandidate(fold.Initial)
            || ContainsStackCandidate(fold.Body),
        CompileTimeEachExpression each => ContainsStackCandidate(each.Source)
            || ContainsStackCandidate(each.Selector)
            || (each.DictionaryValueSelector is not null && ContainsStackCandidate(each.DictionaryValueSelector)),
        FlowExpression flow => ContainsStackCandidate(flow.Source)
            || flow.Targets.SelectMany(target => target.Arguments).Any(ContainsStackCandidate),
        BranchExpression branch => ContainsStackCandidate(branch.Source)
            || branch.Arms.SelectMany(arm => arm.Targets).SelectMany(target => target.Arguments).Any(ContainsStackCandidate),
        TapExpression tap => ContainsStackCandidate(tap.Source)
            || tap.Targets.SelectMany(target => target.Arguments).Any(ContainsStackCandidate),
        PartitionExpression partition => ContainsStackCandidate(partition.Source)
            || partition.Arms.Any(arm => arm.Condition is not null && ContainsStackCandidate(arm.Condition)),
        StreamJoinExpression join => ContainsStackCandidate(join.Source),
        CallExpression call => call.Arguments.Any(ContainsStackCandidate),
        IndexExpression index => ContainsStackCandidate(index.Source) || ContainsStackCandidate(index.Index),
        StructLiteralExpression structure => structure.Fields.Any(field => ContainsStackCandidate(field.Value)),
        ProductExpression product => product.Elements.Any(element => ContainsStackCandidate(element.Value)),
        FieldAccessExpression field => ContainsStackCandidate(field.Source),
        // `?` emits an error return from the function that owns it. Inlining it
        // into a caller with a different Result success type would return the
        // callee's LLVM enum from the caller, so it requires a real boundary.
        TryExpression => true,
        BoxExpression box => ContainsStackCandidate(box.Value),
        MapExpression map => ContainsStackCandidate(map.Path)
            || (map.Offset is not null && ContainsStackCandidate(map.Offset))
            || (map.Length is not null && ContainsStackCandidate(map.Length))
            || (map.FileSize is not null && ContainsStackCandidate(map.FileSize)),
        AddExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        SubtractExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        MultiplyExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        DivideExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        ModuloExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        CompareExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        AndExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        OrExpression binary => ContainsStackCandidate(binary.Left) || ContainsStackCandidate(binary.Right),
        NegateExpression unary => ContainsStackCandidate(unary.Value),
        NotExpression unary => ContainsStackCandidate(unary.Value),
        RangeExpression range => ContainsStackCandidate(range.Start) || ContainsStackCandidate(range.End),
        SubjectCompareExpression subject => ContainsStackCandidate(subject.Right),
        SubjectRangeExpression subject => ContainsStackCandidate(subject.Start) || ContainsStackCandidate(subject.End),
        StringExpression text => text.Segments.OfType<InterpolationSegment>().Any(segment => ContainsStackCandidate(segment.Expression)),
        _ => false
    };

    private static bool ContainsReturn(Statement statement) => statement switch
    {
        ReturnStatement => true,
        BindingStatement binding => ContainsReturn(binding.Value),
        IndexAssignmentStatement assignment => ContainsReturn(assignment.Index) || ContainsReturn(assignment.Value),
        FieldAssignmentStatement assignment => ContainsReturn(assignment.Value),
        BlockFunctionCallStatement block => ContainsReturn(block.Source) || block.Body.Any(ContainsReturn),
        BlockFunctionPipelineStatement pipeline => pipeline.Calls.Any(ContainsReturn),
        ExpressionStatement expression => ContainsReturn(expression.Expression),
        GuardLoopControlStatement guard => ContainsReturn(guard.Condition),
        _ => false
    };

    private static bool ContainsReturn(BlockBody? block)
    {
        return block is not null
            && (block.Statements.Any(ContainsReturn)
                || (block.Value is not null && ContainsReturn(block.Value)));
    }

    private static bool ContainsReturn(Expression expression) => expression switch
    {
        IfExpression conditional => ContainsReturn(conditional.Condition)
            || ContainsReturn(conditional.Then)
            || ContainsReturn(conditional.Else),
        WhenExpression whenExpression => (whenExpression.Subject is not null && ContainsReturn(whenExpression.Subject))
            || whenExpression.Arms.Any(arm => ContainsReturn(arm.Condition) || ContainsReturn(arm.Body))
            || ContainsReturn(whenExpression.Else),
        EnumMatchExpression match => ContainsReturn(match.Subject)
            || match.Arms.Any(arm => ContainsReturn(arm.Condition) || ContainsReturn(arm.Body))
            || ContainsReturn(match.Else),
        FoldExpression fold => ContainsReturn(fold.Source)
            || ContainsReturn(fold.Initial)
            || ContainsReturn(fold.Body),
        CompileTimeEachExpression each => ContainsReturn(each.Source)
            || ContainsReturn(each.Selector)
            || (each.DictionaryValueSelector is not null && ContainsReturn(each.DictionaryValueSelector)),
        FlowExpression flow => ContainsReturn(flow.Source)
            || flow.Targets.SelectMany(target => target.Arguments).Any(ContainsReturn),
        BranchExpression branch => ContainsReturn(branch.Source)
            || branch.Arms.SelectMany(arm => arm.Targets).SelectMany(target => target.Arguments).Any(ContainsReturn),
        TapExpression tap => ContainsReturn(tap.Source)
            || tap.Targets.SelectMany(target => target.Arguments).Any(ContainsReturn),
        PartitionExpression partition => ContainsReturn(partition.Source)
            || partition.Arms.Any(arm => arm.Condition is not null && ContainsReturn(arm.Condition)),
        StreamJoinExpression join => ContainsReturn(join.Source),
        CallExpression call => call.Arguments.Any(ContainsReturn),
        ArrayLiteralExpression array => array.Elements.Any(ContainsReturn),
        ArrayRepeatExpression repeat => ContainsReturn(repeat.Value),
        DictionaryLiteralExpression dictionary => dictionary.Entries.Any(entry =>
            ContainsReturn(entry.Key) || ContainsReturn(entry.Value)),
        IndexExpression index => ContainsReturn(index.Source) || ContainsReturn(index.Index),
        StructLiteralExpression structure => structure.Fields.Any(field => ContainsReturn(field.Value)),
        ProductExpression product => product.Elements.Any(element => ContainsReturn(element.Value)),
        FieldAccessExpression field => ContainsReturn(field.Source),
        TryExpression attempt => ContainsReturn(attempt.Value),
        BoxExpression box => ContainsReturn(box.Value),
        MapExpression map => ContainsReturn(map.Path)
            || (map.Offset is not null && ContainsReturn(map.Offset))
            || (map.Length is not null && ContainsReturn(map.Length))
            || (map.FileSize is not null && ContainsReturn(map.FileSize)),
        AddExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        SubtractExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        MultiplyExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        DivideExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        ModuloExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        CompareExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        AndExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        OrExpression binary => ContainsReturn(binary.Left) || ContainsReturn(binary.Right),
        NegateExpression unary => ContainsReturn(unary.Value),
        NotExpression unary => ContainsReturn(unary.Value),
        RangeExpression range => ContainsReturn(range.Start) || ContainsReturn(range.End),
        SubjectCompareExpression subject => ContainsReturn(subject.Right),
        SubjectRangeExpression subject => ContainsReturn(subject.Start) || ContainsReturn(subject.End),
        StringExpression text => text.Segments.OfType<InterpolationSegment>().Any(segment => ContainsReturn(segment.Expression)),
        _ => false
    };
}
