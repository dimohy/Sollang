using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeBox EmitBoxExpression(BoxExpression expression)
    {
        var value = EmitExpression(expression.Value);
        var definition = _program.Types.Boxes.FirstOrDefault(box => box.ElementType == value.Type)
            ?? throw new SmallLangException($"type {value.Type} cannot be boxed");
        var stackAllocated = _currentStackFramePlan.TryGetAllocation(expression, out _);
        if (!stackAllocated && !_platform.SupportsHeapAllocation)
        {
            throw new SmallLangException("box values require heap allocation; wasm32-browser does not support them yet");
        }

        var pointer = stackAllocated
            ? EmitStackLifetimeStart(expression)
            : EmitHeapAllocate(definition.Size.ToString(System.Globalization.CultureInfo.InvariantCulture));
        var materialized = MaterializeAggregateValue(value);
        EmitStore(materialized.TypeName, materialized.ValueName, pointer, definition.Alignment);
        return new RuntimeBox(
            definition.Id,
            definition.ElementType,
            pointer,
            stackAllocated ? RuntimeContainerStorage.Stack : RuntimeContainerStorage.Heap);
    }
}
