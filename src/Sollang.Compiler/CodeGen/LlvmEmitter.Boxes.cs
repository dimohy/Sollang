using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeBox EmitBoxExpression(BoxExpression expression)
    {
        var value = EmitExpression(expression.Value);
        var definition = _program.Types.Boxes.FirstOrDefault(box => box.ElementType == value.Type)
            ?? throw new SollangException($"type {value.Type} cannot be boxed");
        if (!_platform.SupportsHeapAllocation)
        {
            throw new SollangException("box values require heap allocation; wasm32-browser does not support them yet");
        }

        var pointer = EmitHeapAllocate(definition.Size.ToString(System.Globalization.CultureInfo.InvariantCulture));
        var materialized = MaterializeAggregateValue(value);
        EmitStore(materialized.TypeName, materialized.ValueName, pointer, definition.Alignment);
        return new RuntimeBox(definition.Id, definition.ElementType, pointer);
    }
}
