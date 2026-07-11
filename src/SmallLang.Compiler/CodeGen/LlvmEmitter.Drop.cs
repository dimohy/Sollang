using System.Globalization;
using SmallLang.Compiler.Semantics;

namespace SmallLang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitOwnedDropHelpers()
    {
        var needsHelpers = _program.MainBindings.Values.Any(IsCustomOwnedType)
            || _program.Functions.Values.Any(function => IsCustomOwnedType(function.ReturnType)
                || (function.InputType is { } input && IsCustomOwnedType(input)))
            || _program.Types.Structs.Any(definition => IsCustomOwnedType(definition.Id))
            || _program.Types.Enums.Any(definition => IsCustomOwnedType(definition.Id));
        if (!needsHelpers)
        {
            return;
        }

        foreach (var box in _program.Types.Boxes.OrderBy(static box => box.Id))
        {
            EmitBoxDropHelper(box);
        }
        foreach (var structure in _program.Types.Structs
                     .Where(definition => _program.Types.ContainsOwnedStorage(definition.Id))
                     .OrderBy(static definition => definition.Id))
        {
            EmitStructDropHelper(structure);
        }
        foreach (var enumeration in _program.Types.Enums
                     .Where(definition => _program.Types.ContainsOwnedStorage(definition.Id))
                     .OrderBy(static definition => definition.Id))
        {
            EmitEnumDropHelper(enumeration);
        }
    }

    private bool IsCustomOwnedType(BoundType type)
    {
        return _program.Types.IsBox(type)
            || ((_program.Types.IsStruct(type) || _program.Types.IsEnum(type))
                && _program.Types.ContainsOwnedStorage(type));
    }

    private void EmitBoxDropHelper(BoundBoxDefinition box)
    {
        EmitFunctionLine($"define internal void {DropSymbol(box.Id)}(ptr %value) #0 {{");
        EmitFunctionLine("entry:");
        _currentBlockLabel = "entry";
        if (_program.Types.ContainsOwnedStorage(box.ElementType))
        {
            var loaded = NextTemp("drop_box_value");
            EmitLoad(loaded, LlvmType(box.ElementType), "%value", RuntimeAlignment(box.ElementType));
            EmitOwnedDropCall(box.ElementType, loaded);
        }
        EmitCall(target: null, "void", "smalllang_free", "ptr %value");
        EmitInstruction("ret void");
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private void EmitStructDropHelper(BoundStructDefinition structure)
    {
        var llvmType = LlvmStructType(structure.Id);
        EmitFunctionLine($"define internal void {DropSymbol(structure.Id)}({llvmType} %value) #0 {{");
        EmitFunctionLine("entry:");
        _currentBlockLabel = "entry";
        foreach (var field in structure.Fields.Where(field => _program.Types.ContainsOwnedStorage(field.Type)))
        {
            var extracted = NextTemp("drop_field");
            EmitAssign(
                extracted,
                $"extractvalue {llvmType} %value, {field.Index.ToString(CultureInfo.InvariantCulture)}");
            EmitOwnedDropCall(field.Type, extracted);
        }
        EmitInstruction("ret void");
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private void EmitEnumDropHelper(BoundEnumDefinition enumeration)
    {
        var llvmType = LlvmEnumType(enumeration.Id);
        var ownedVariants = enumeration.Variants
            .Where(variant => variant.PayloadType is { } payload
                && _program.Types.ContainsOwnedStorage(payload))
            .ToArray();
        var endLabel = NextLabel("drop_enum_end");

        EmitFunctionLine($"define internal void {DropSymbol(enumeration.Id)}({llvmType} %value) #0 {{");
        EmitFunctionLine("entry:");
        _currentBlockLabel = "entry";
        var tag = NextTemp("drop_enum_tag");
        EmitAssign(tag, $"extractvalue {llvmType} %value, 0");
        var labels = ownedVariants.Select(variant =>
            (Variant: variant, Label: NextLabel("drop_enum_variant"))).ToArray();
        var cases = string.Join(
            " ",
            labels.Select(item =>
                $"i32 {item.Variant.Tag.ToString(CultureInfo.InvariantCulture)}, label %{item.Label}"));
        EmitInstruction($"switch i32 {tag}, label %{endLabel} [ {cases} ]");

        foreach (var (variant, label) in labels)
        {
            EmitLabel(label);
            _currentBlockLabel = label;
            var slot = NextTemp("drop_enum_slot");
            EmitAlloca(slot, llvmType, 8);
            EmitStore(llvmType, "%value", slot, 8);
            var payloadAddress = NextTemp("drop_enum_payload_addr");
            EmitAssign(payloadAddress, $"getelementptr inbounds {llvmType}, ptr {slot}, i32 0, i32 1");
            var payloadType = variant.PayloadType!.Value;
            var payload = NextTemp("drop_enum_payload");
            EmitLoad(payload, LlvmType(payloadType), payloadAddress, RuntimeAlignment(payloadType));
            EmitOwnedDropCall(payloadType, payload);
            EmitBranch(endLabel);
        }

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        EmitInstruction("ret void");
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private void EmitOwnedDropCall(BoundType type, string valueName)
    {
        EmitCall(target: null, "void", DropSymbol(type)[1..], $"{LlvmType(type)} {valueName}");
    }

    private static string DropSymbol(BoundType type)
    {
        return "@smalllang_drop_" + ((int)type).ToString(CultureInfo.InvariantCulture);
    }
}
