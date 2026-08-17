using Sollang.Compiler.Syntax;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Semantics;

internal sealed record BoundProgram(
    TypeDefinitionTable Types,
    IReadOnlyDictionary<string, BoundTraitDefinition> Traits,
    IReadOnlyDictionary<string, BoundFunction> Functions,
    IReadOnlyDictionary<object, BoundFunction> ResolvedGenericCalls,
    IReadOnlyDictionary<object, BoundDynTraitConversion> DynTraitConversions,
    IReadOnlyDictionary<object, BoundDynTraitDispatch> DynTraitDispatches,
    IReadOnlyList<Statement> MainStatements,
    IReadOnlyDictionary<string, BoundType> MainBindings,
    IReadOnlyDictionary<BoundFunction, IReadOnlyDictionary<string, BoundType>> FunctionBindings,
    IReadOnlyDictionary<BoundFunction, IReadOnlyDictionary<string, BoundType>> FunctionCapturedBindings,
    StackFramePlan MainStackFrame,
    IReadOnlyDictionary<BoundFunction, StackFramePlan> FunctionStackFrames,
    IReadOnlyDictionary<BoundFunction, string> StableFunctionIdentities,
    IReadOnlyDictionary<object, string> StableCallSiteIdentities,
    byte[] StableDeclarationFingerprint,
    int ReusedSemanticFunctions,
    int TotalSemanticFunctions,
    bool ReusedMainSemantics,
    IReadOnlySet<Statement> DeferredStreamDeclarations,
    IReadOnlyDictionary<Statement, BlockFunctionPipelineStatement> DeferredStreamConsumers,
    IReadOnlyDictionary<Statement, BoundEventStreamPipeline> EventStreamConsumers,
    IReadOnlyDictionary<Statement, BoundPartitionPipeline> PartitionConsumers,
    IReadOnlyDictionary<Statement, BoundStreamJoinPipeline> StreamJoinConsumers,
    IReadOnlyDictionary<StreamJoinExpression, BoundStreamJoin> StreamJoins,
    IReadOnlyDictionary<BranchExpression, BoundParallelBranch> ParallelBranches,
    IReadOnlyList<SemanticWarning> Warnings);

internal sealed record BoundParallelBranch(
    TypeId SourceType,
    TypeId ResultType,
    IReadOnlyList<IReadOnlyList<BoundFunction>> ArmTargets,
    IReadOnlyDictionary<string, TypeId> Captures);

internal sealed record BoundStreamJoinPipeline(
    StreamJoinExpression Expression,
    BoundStreamJoin Join,
    BlockFunctionPipelineStatement Consumer);

internal sealed record BoundStreamJoin(
    StreamJoinPolicy Policy,
    TypeId InputProductType,
    IReadOnlyList<BoundStreamJoinInput> Inputs,
    TypeId OutputElementType,
    TypeId ResultType,
    bool IsEvent,
    int BufferCapacityPerInput);

internal sealed record BoundStreamJoinInput(
    string FieldName,
    TypeId StreamType,
    TypeId ElementType,
    bool IsEvent);

internal sealed record BoundEventStreamPipeline(
    Expression Source,
    IReadOnlyList<BlockFunctionCallStatement> Calls,
    TypeId SourceElementType,
    bool IsEvent);

internal sealed record BoundPartitionPipeline(
    Expression Source,
    string ItemName,
    IReadOnlyList<BoundPartitionRoute> Routes,
    TypeId SourceElementType,
    bool IsEvent);

internal sealed record BoundPartitionRoute(
    string Label,
    Expression? Condition,
    BlockFunctionPipelineStatement Consumer,
    int Line,
    int Column);

internal sealed record BoundDynTraitConversion(
    BoundType DynType,
    BoundType ConcreteType,
    BoundTraitDefinition Trait,
    IReadOnlyList<BoundFunction> Methods);

internal sealed record BoundDynTraitDispatch(
    BoundType DynType,
    BoundTraitDefinition Trait,
    BoundTraitMethod Method,
    int MethodIndex);

internal sealed record BoundFunction(
    string Name,
    string? InputName,
    BoundType? InputType,
    BoundFunctionInputOwnership InputOwnership,
    BoundType ReturnType,
    string? BlockInputName,
    BoundType? BlockInputType,
    IReadOnlyDictionary<string, BoundFunction> LocalFunctions,
    Expression? Body,
    IReadOnlyList<Statement> BlockBody,
    int Line,
    int Column,
    BoundFunctionKind Kind,
    bool IsStandardLibrary,
    bool IsLocal,
    string? TraitName = null,
    string? GenericParameterName = null,
    string? SecondaryGenericParameterName = null,
    string? TertiaryGenericParameterName = null,
    string? GenericTraitBound = null,
    string? GenericAssociatedTypeName = null,
    TypeId? GenericAssociatedTypeConstraint = null,
    IReadOnlyDictionary<string, TypeId>? ImplAssociatedTypes = null,
    TypeId? SpecializedType = null,
    TypeId? SpecializedSecondaryType = null,
    TypeId? SpecializedTertiaryType = null,
    bool IsValueGeneric = false,
    int? SpecializedValue = null,
    bool HasValueGenericFixedArrayInput = false,
    string ModuleName = "",
    bool IsPublic = false,
    bool IsAsync = false,
    string? BlockInputTypeTemplate = null,
    IReadOnlySet<string>? Effects = null,
    BoundType? BlockResultType = null,
    string? BlockResultTypeTemplate = null,
    string? InputTypeTemplate = null,
    string? ReturnTypeTemplate = null,
    IReadOnlyList<BoundFunctionParameter>? AdditionalParameters = null,
    IReadOnlyList<BoundFunctionParameter>? AdditionalBlockParameters = null,
    BoundType? StreamElementType = null,
    string? StreamElementTypeTemplate = null,
    string? NativeLibrary = null,
    string? NativeSymbol = null,
    ComFunctionMetadata? Com = null,
    NativeErrorConvention NativeError = NativeErrorConvention.Direct,
    BoundType? NativeSuccessType = null,
    IReadOnlyList<GenericParameterDeclaration>? GenericParameters = null,
    IReadOnlyDictionary<string, BoundType>? SpecializedGenericTypes = null);

internal sealed record BoundFunctionParameter(
    string Name,
    BoundType Type,
    BoundFunctionInputOwnership Ownership,
    int Line,
    int Column,
    string? TypeTemplate = null);

internal sealed record BoundTraitMethod(
    string Name,
    BoundFunctionInputOwnership SelfOwnership,
    TypeId? ReturnType,
    string? ReturnAssociatedTypeName,
    int Line,
    int Column);

internal sealed record BoundTraitAssociatedType(string Name, int Line, int Column);

internal sealed record BoundTraitDefinition(
    string Name,
    IReadOnlyList<BoundTraitAssociatedType> AssociatedTypes,
    IReadOnlyList<BoundTraitMethod> Methods,
    int Line,
    int Column,
    string ModuleName = "",
    bool IsPublic = false);

internal enum BoundFunctionInputOwnership
{
    Default,
    Move,
    MutableBorrow
}

internal enum BoundFunctionKind
{
    User,
    UserBlock,
    RuntimePrint,
    RuntimePrintLine,
    RuntimePrintErrorLine,
    RuntimeFlushStandardOutput,
    RuntimeReadInt,
    RuntimeSeedRandom,
    RuntimeRandomBelow,
    RuntimeSecureRandomBytes,
    RuntimeOpenIntWriter,
    RuntimeWriteInt,
    RuntimeCloseIntWriter,
    RuntimeOpenIntReader,
    RuntimeClosestInt,
    RuntimeCloseIntReader,
    RuntimeNowMillis,
    RuntimeSleep,
    RuntimeArguments,
    RuntimeEnvironment,
    RuntimeParallel,
    RuntimeTryParallel,
    RuntimeLimitParallelWorkers,
    RuntimeParallelWorkers,
    RuntimeParallelPeakWorkers,
    RuntimeRunProcess,
    RuntimeRunProcessToFile,
    RuntimeExitProcess,
    RuntimeBorrowSourceText,
    RuntimeBorrowSourceBytes,
    RuntimeMapSourceText,
    RuntimeReadStandardInputSourceText,
    RuntimeReadStandardInputChunk,
    RuntimeMapSourcePath,
    RuntimePathText,
    RuntimePathStyle,
    RuntimePathQuery,
    RuntimeWriteScalar,
    RuntimeReadScalar,
    RuntimeReadScalarAsync,
    RuntimeOpenFile,
    RuntimeOpenWriteFile,
    RuntimeOpenFileAsync,
    RuntimeOpenWriteFileAsync,
    RuntimeReadDirectory,
    RuntimeCreateDirectory,
    RuntimeWriteScalarAt,
    RuntimeWriteScalarAtAsync,
    RuntimeSyncFileAsync,
    RuntimeSyncFile,
    RuntimeAtomicReplaceFile,
    RuntimeSocketListen,
    RuntimeSocketAccept,
    RuntimeSocketConnect,
    RuntimeSocketReceive,
    RuntimeSocketSend,
    RuntimeSocketSendText,
    RuntimeSocketShutdown,
    RuntimeSocketBindDatagram,
    RuntimeSocketLocalPort,
    RuntimeSocketSendTo,
    RuntimeSocketReceiveFrom,
    RuntimeRangeStream,
    RuntimeMouseEvents,
    Native
}

internal enum TypeId
{
    Unit,
    Text,
    Int,
    Bool,
    Int8,
    Int16,
    Int64,
    UInt8,
    UInt16,
    UInt32,
    UInt64,
    Size,
    UIntSize,
    CodePoint,
    Arguments,
    Arena,
    MappedBytes,
    MutableMappedBytes,
    Float32,
    Float64,
    IntSlice,
    StaticIntArray,
    StaticTextArray,
    DynamicIntArray,
    IntDictionaryView,
    IntDictionary,
    TaskInt,
    Duration,
    BoxDuration,
    File,
    FileWriter,
    SourceText,
    RunToFileRequest,
    AtomicReplaceRequest,
    Path,
    PathStyle,
    DynamicUInt8Array,
    DirectoryRaw,
    DirectoryEntryKind,
    DirectoryEntry,
    DynamicDirectoryEntryArray,
    DirectoryRawResult,
    DirectoryReadResult,
    Range,
    MouseEvent,
    MouseEventKind,
    EventOverflowPolicy,
    FixedUInt8Array12,
    FixedUInt8Array16,
    FixedUInt8Array32,
    GenericParameter = 512,
    SecondaryGenericParameter = 513,
    TertiaryGenericParameter = 514,
    FirstUserDefined = 1024
}

internal sealed record BoundStructField(string Name, TypeId Type, int Index, int Line, int Column);

internal sealed record BoundStructDefinition(
    TypeId Id,
    string Name,
    IReadOnlyList<BoundStructField> Fields,
    int Line,
    int Column,
    string ModuleName = "",
    bool IsPublic = false,
    string? DeclaringTypeName = null,
    bool IsAbi = false,
    ComInterfaceMetadata? ComInterface = null,
    NativeHandleMetadata? NativeHandle = null,
    bool IsProduct = false)
{
    public BoundStructField GetField(string name)
    {
        return Fields.FirstOrDefault(field => field.Name == name)
            ?? throw new KeyNotFoundException($"struct '{Name}' has no field '{name}'");
    }
}

internal sealed record BoundEnumVariant(string Name, TypeId? PayloadType, int Tag, int Line, int Column);

internal sealed record BoundEnumDefinition(
    TypeId Id,
    string Name,
    IReadOnlyList<BoundEnumVariant> Variants,
    int PayloadWords,
    int Line,
    int Column,
    string ModuleName = "",
    bool IsPublic = false);

internal sealed record BoundBoxDefinition(TypeId Id, TypeId ElementType, int Size, int Alignment);

internal sealed record BoundReferenceDefinition(TypeId Id, TypeId ElementType);

internal sealed record BoundSliceDefinition(TypeId Id, TypeId ElementType);

internal sealed record BoundDynTraitDefinition(TypeId Id, string TraitName);

internal sealed record BoundStaticArrayDefinition(
    TypeId Id,
    TypeId ElementType,
    int ElementSize,
    int ElementAlignment,
    int? FixedLength = null);

internal sealed record BoundDynamicArrayDefinition(
    TypeId Id,
    TypeId ElementType,
    int ElementSize,
    int ElementAlignment);

internal sealed record BoundBoundedArrayDefinition(
    TypeId Id,
    TypeId ElementType,
    int Capacity,
    int ElementSize,
    int ElementAlignment,
    int DataOffset,
    int Size,
    int Alignment);

internal sealed record BoundDictionaryDefinition(
    TypeId Id,
    TypeId KeyType,
    TypeId ValueType,
    int KeySize,
    int KeyAlignment,
    int ValueOffset,
    int ValueSize,
    int ValueAlignment,
    int EntryStride);

internal sealed record BoundBoundedDictionaryDefinition(
    TypeId Id,
    TypeId KeyType,
    TypeId ValueType,
    int MaxEntries,
    int BucketCapacity,
    int ControlsOffset,
    int EntriesOffset,
    int StorageSize,
    int Size,
    int Alignment,
    BoundDictionaryDefinition Layout);

internal sealed record BoundBitSetDefinition(
    TypeId Id,
    int BitCount,
    int WordCount,
    int Size,
    int Alignment);

internal sealed class TypeDefinitionTable
{
    private readonly Dictionary<string, TypeId> _names;
    private readonly Dictionary<TypeId, BoundStructDefinition> _structs;
    private readonly Dictionary<TypeId, BoundEnumDefinition> _enums;
    private readonly Dictionary<TypeId, BoundBoxDefinition> _boxes;
    private readonly Dictionary<TypeId, BoundReferenceDefinition> _references;
    private readonly Dictionary<TypeId, TypeId> _referencesByElement;
    private readonly Dictionary<TypeId, BoundSliceDefinition> _slices = [];
    private readonly Dictionary<TypeId, TypeId> _slicesByElement = [];
    private readonly Dictionary<TypeId, BoundDynTraitDefinition> _dynTraits = [];
    private readonly Dictionary<string, TypeId> _dynTraitsByName = new(StringComparer.Ordinal);
    private readonly Dictionary<TypeId, BoundStaticArrayDefinition> _staticArrays = [];
    private readonly Dictionary<TypeId, TypeId> _staticArraysByElement = [];
    private readonly Dictionary<TypeId, TypeId> _reservedStaticArraysByElement = [];
    private readonly Dictionary<(TypeId Element, int Length), TypeId> _fixedStaticArraysByShape = [];
    private readonly Dictionary<(TypeId Element, int Length), TypeId> _reservedFixedStaticArraysByShape = [];
    private readonly HashSet<TypeId> _reservedParametricTypeIds = [];
    private readonly Dictionary<TypeId, BoundDynamicArrayDefinition> _dynamicArrays = [];
    private readonly Dictionary<TypeId, TypeId> _dynamicArraysByElement = [];
    private readonly Dictionary<TypeId, BoundBoundedArrayDefinition> _boundedArrays = [];
    private readonly Dictionary<(TypeId Element, int Capacity), TypeId> _boundedArraysByShape = [];
    private readonly Dictionary<TypeId, BoundDictionaryDefinition> _dictionaries = [];
    private readonly Dictionary<(TypeId Key, TypeId Value), TypeId> _dictionariesByTypes = [];
    private readonly Dictionary<TypeId, BoundBoundedDictionaryDefinition> _boundedDictionaries = [];
    private readonly Dictionary<(TypeId Key, TypeId Value, int Capacity), TypeId> _boundedDictionariesByShape = [];
    private readonly Dictionary<TypeId, BoundBitSetDefinition> _bitSets = [];
    private readonly Dictionary<int, TypeId> _bitSetsByBitCount = [];
    private readonly Dictionary<TypeId, TypeId> _binaryHeaps = [];
    private readonly Dictionary<TypeId, TypeId> _binaryHeapsByElement = [];
    private readonly Dictionary<TypeId, TypeId> _deques = [];
    private readonly Dictionary<TypeId, TypeId> _dequesByElement = [];
    private readonly Dictionary<TypeId, TypeId> _sets = [];
    private readonly Dictionary<TypeId, TypeId> _setsByElement = [];
    private readonly Dictionary<TypeId, TypeId> _optionsByValue = [];
    private readonly Dictionary<(TypeId Ok, TypeId Error), TypeId> _resultsByTypes = [];
    private readonly Dictionary<TypeId, TypeId> _optionValues = [];
    private readonly Dictionary<TypeId, (TypeId Ok, TypeId Error)> _resultTypes = [];
    private readonly Dictionary<TypeId, TypeId> _tasksByValue = [];
    private readonly Dictionary<TypeId, TypeId> _taskValues = [];
    private readonly Dictionary<TypeId, TypeId> _streamsByValue = [];
    private readonly Dictionary<TypeId, TypeId> _streamValues = [];
    private readonly Dictionary<TypeId, TypeId> _eventStreamsByValue = [];
    private readonly Dictionary<TypeId, TypeId> _eventStreamValues = [];
    private readonly Dictionary<string, TypeId> _productsByShape = new(StringComparer.Ordinal);
    private int _nextParametricTypeId;
    private readonly int _pointerSize;

    public TypeDefinitionTable(
        IReadOnlyDictionary<string, TypeId> names,
        IReadOnlyDictionary<TypeId, BoundStructDefinition> structs,
        IReadOnlyDictionary<TypeId, BoundEnumDefinition> enums,
        IReadOnlyDictionary<TypeId, BoundBoxDefinition> boxes,
        IReadOnlyDictionary<TypeId, BoundReferenceDefinition> references,
        int pointerSize)
    {
        _names = new Dictionary<string, TypeId>(names, StringComparer.Ordinal);
        _structs = new Dictionary<TypeId, BoundStructDefinition>(structs);
        _enums = new Dictionary<TypeId, BoundEnumDefinition>(enums);
        _boxes = new Dictionary<TypeId, BoundBoxDefinition>(boxes);
        _references = new Dictionary<TypeId, BoundReferenceDefinition>(references);
        _referencesByElement = references.Values.ToDictionary(
            static reference => reference.ElementType,
            static reference => reference.Id);
        _pointerSize = pointerSize;
        foreach (var definition in _enums.Values.Where(static definition =>
                     definition.Name is "sys.directory.RawResult" or "sys.directory.ReadResult"))
        {
            var ok = definition.Variants.First(static variant => variant.Name == "Ok").PayloadType!.Value;
            var error = definition.Variants.First(static variant => variant.Name == "Err").PayloadType!.Value;
            _resultsByTypes.TryAdd((ok, error), definition.Id);
            _resultTypes.TryAdd(definition.Id, (ok, error));
        }
        _tasksByValue.Add(TypeId.Int, TypeId.TaskInt);
        _taskValues.Add(TypeId.TaskInt, TypeId.Int);
        _nextParametricTypeId = _names.Values
            .Concat(_boxes.Keys)
            .Concat(_references.Keys)
            .Select(static type => (int)type)
            .DefaultIfEmpty((int)TypeId.FirstUserDefined)
            .Max() + 1;
    }

    public IReadOnlyCollection<BoundStructDefinition> Structs => _structs.Values.ToArray();

    public IReadOnlyCollection<BoundEnumDefinition> Enums => _enums.Values.ToArray();

    public IReadOnlyCollection<BoundBoxDefinition> Boxes => _boxes.Values.ToArray();

    public IReadOnlyCollection<BoundReferenceDefinition> References => _references.Values.ToArray();

    public IReadOnlyCollection<BoundSliceDefinition> Slices => _slices.Values.ToArray();

    public IReadOnlyCollection<BoundDynTraitDefinition> DynTraits => _dynTraits.Values.ToArray();

    public IReadOnlyCollection<BoundStaticArrayDefinition> StaticArrays => _staticArrays.Values.ToArray();

    public IReadOnlyCollection<BoundDynamicArrayDefinition> DynamicArrays => _dynamicArrays.Values.ToArray();

    public IReadOnlyCollection<BoundBoundedArrayDefinition> BoundedArrays => _boundedArrays.Values.ToArray();

    public IReadOnlyCollection<BoundDictionaryDefinition> Dictionaries => _dictionaries.Values.ToArray();

    public IReadOnlyCollection<BoundBoundedDictionaryDefinition> BoundedDictionaries => _boundedDictionaries.Values.ToArray();

    public IReadOnlyCollection<BoundBitSetDefinition> BitSets => _bitSets.Values.ToArray();

    public bool TryResolve(string name, out TypeId type) => _names.TryGetValue(name, out type);

    public void AddAlias(string name, TypeId type) => _names.TryAdd(name, type);

    public bool IsStruct(TypeId type) => _structs.ContainsKey(type);

    public bool IsProduct(TypeId type) =>
        _structs.TryGetValue(type, out var definition) && definition.IsProduct;

    public TypeId GetOrAddProduct(
        IReadOnlyList<(string? Label, TypeId Type)> fields,
        string displayName,
        int line,
        int column)
    {
        if (fields.Count < 2)
        {
            throw new ArgumentException("product types require at least two fields", nameof(fields));
        }

        var shape = string.Join('|', fields.Select(static field =>
        {
            var label = field.Label ?? string.Empty;
            return $"{label.Length}:{label}:{(int)field.Type}";
        }));
        if (_productsByShape.TryGetValue(shape, out var existing))
        {
            _names.TryAdd(displayName, existing);
            return existing;
        }

        var id = AllocateParametricTypeId();
        var boundFields = fields.Select((field, index) => new BoundStructField(
            field.Label ?? $"_{index}", field.Type, index, line, column)).ToArray();
        _structs.Add(id, new BoundStructDefinition(
            id, displayName, boundFields, line, column,
            ModuleName: string.Empty, IsPublic: true, IsProduct: true));
        _productsByShape.Add(shape, id);
        _names.TryAdd(displayName, id);
        return id;
    }

    public bool IsEnum(TypeId type) => _enums.ContainsKey(type);

    public bool IsBox(TypeId type) => _boxes.ContainsKey(type);

    public bool IsReference(TypeId type) => _references.ContainsKey(type);

    public bool IsSlice(TypeId type) => type == TypeId.IntSlice || _slices.ContainsKey(type);

    public bool IsDynTrait(TypeId type) => _dynTraits.ContainsKey(type);

    public TypeId GetOrAddDynTrait(string traitName)
    {
        if (_dynTraitsByName.TryGetValue(traitName, out var existing))
        {
            return existing;
        }

        var id = AllocateParametricTypeId();
        _dynTraits.Add(id, new BoundDynTraitDefinition(id, traitName));
        _dynTraitsByName.Add(traitName, id);
        _names.TryAdd("dyn " + traitName, id);
        return id;
    }

    public BoundDynTraitDefinition GetDynTrait(TypeId type) =>
        _dynTraits.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a dyn trait");

    public TypeId GetOrAddReference(TypeId elementType)
    {
        if (_referencesByElement.TryGetValue(elementType, out var existing))
        {
            return existing;
        }

        var id = AllocateParametricTypeId();
        _references.Add(id, new BoundReferenceDefinition(id, elementType));
        _referencesByElement.Add(elementType, id);
        return id;
    }

    public bool IsStaticArray(TypeId type) => _staticArrays.ContainsKey(type);

    public bool IsDynamicArray(TypeId type) => _dynamicArrays.ContainsKey(type);

    public bool IsBoundedArray(TypeId type) => _boundedArrays.ContainsKey(type);

    public bool IsDictionary(TypeId type) => _dictionaries.ContainsKey(type) || _boundedDictionaries.ContainsKey(type);

    public bool IsBoundedDictionary(TypeId type) => _boundedDictionaries.ContainsKey(type);

    public bool IsBitSet(TypeId type) => _bitSets.ContainsKey(type);

    public bool IsBinaryHeap(TypeId type) => _binaryHeaps.ContainsKey(type);

    public bool IsDeque(TypeId type) => _deques.ContainsKey(type);

    public bool IsSet(TypeId type) => _sets.ContainsKey(type);

    public TypeId GetOrAddStaticArray(TypeId elementType)
    {
        if (_staticArraysByElement.TryGetValue(elementType, out var existing))
        {
            return existing;
        }

        if (_reservedStaticArraysByElement.TryGetValue(elementType, out var reserved))
        {
            RegisterStaticArrays(new Dictionary<TypeId, (TypeId ElementType, int? Length)>
            {
                [reserved] = (elementType, null)
            });
            return reserved;
        }

        var id = AllocateParametricTypeId();
        var size = InlineSizeOf(elementType);
        var alignment = Math.Min(Math.Max(size, 1), 8);
        _staticArrays.Add(id, new BoundStaticArrayDefinition(id, elementType, size, alignment));
        _staticArraysByElement.Add(elementType, id);
        return id;
    }

    public TypeId GetOrAddFixedStaticArray(TypeId elementType, int length)
    {
        if (length < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(length));
        }
        if (_fixedStaticArraysByShape.TryGetValue((elementType, length), out var existing))
        {
            return existing;
        }

        if (_reservedFixedStaticArraysByShape.TryGetValue((elementType, length), out var reserved))
        {
            RegisterFixedStaticArrays(new Dictionary<TypeId, (TypeId ElementType, int Length)>
            {
                [reserved] = (elementType, length)
            });
            return reserved;
        }

        var id = AllocateParametricTypeId();
        var size = InlineSizeOf(elementType);
        var alignment = Math.Min(Math.Max(size, 1), 8);
        _staticArrays.Add(id, new BoundStaticArrayDefinition(id, elementType, size, alignment, length));
        _fixedStaticArraysByShape.Add((elementType, length), id);
        return id;
    }

    public void RegisterFixedStaticArrays(
        IReadOnlyDictionary<TypeId, (TypeId ElementType, int Length)> definitions)
    {
        RegisterStaticArrays(definitions.ToDictionary(
            static pair => pair.Key,
            static pair => (pair.Value.ElementType, (int?)pair.Value.Length)));
    }

    public void RegisterStaticArrays(
        IReadOnlyDictionary<TypeId, (TypeId ElementType, int? Length)> definitions)
    {
        foreach (var (id, shape) in definitions)
        {
            if (shape.Length is null
                && _staticArraysByElement.TryGetValue(shape.ElementType, out var existingStatic))
            {
                if (existingStatic != id)
                    throw new InvalidOperationException(
                        $"static array element type '{(int)shape.ElementType}' already has type id '{(int)existingStatic}'");
                continue;
            }
            if (shape.Length is { } length
                && _fixedStaticArraysByShape.TryGetValue((shape.ElementType, length), out var existing))
            {
                if (existing != id)
                {
                    throw new InvalidOperationException(
                        $"fixed array shape '{(int)shape.ElementType};{length}' already has type id '{(int)existing}'");
                }
                continue;
            }

            if (IsTypeIdInUse(id))
            {
                throw new InvalidOperationException(
                    $"cannot register static array type id '{(int)id}' because that id is already in use");
            }

            var size = InlineSizeOf(shape.ElementType);
            var alignment = Math.Min(Math.Max(size, 1), 8);
            _staticArrays.Add(
                id,
                new BoundStaticArrayDefinition(id, shape.ElementType, size, alignment, shape.Length));
            if (shape.Length is { } fixedLength)
            {
                _fixedStaticArraysByShape.Add((shape.ElementType, fixedLength), id);
                _reservedFixedStaticArraysByShape.Remove((shape.ElementType, fixedLength));
            }
            else
            {
                _staticArraysByElement.Add(shape.ElementType, id);
                _reservedStaticArraysByElement.Remove(shape.ElementType);
            }
            _reservedParametricTypeIds.Remove(id);
            _nextParametricTypeId = Math.Max(_nextParametricTypeId, (int)id + 1);
        }
    }

    public bool TryReserveStaticArray(TypeId id, TypeId elementType, int? length)
    {
        if (length is null)
        {
            if (_staticArraysByElement.TryGetValue(elementType, out var existing)
                || _reservedStaticArraysByElement.TryGetValue(elementType, out existing))
            {
                if (existing != id)
                    return false;
                return false;
            }
            if (!TryReserveTypeId(id))
                return false;
            _reservedStaticArraysByElement.Add(elementType, id);
        }
        else
        {
            var shape = (elementType, length.Value);
            if (_fixedStaticArraysByShape.TryGetValue(shape, out var existing)
                || _reservedFixedStaticArraysByShape.TryGetValue(shape, out existing))
            {
                if (existing != id)
                    return false;
                return false;
            }
            if (!TryReserveTypeId(id))
                return false;
            _reservedFixedStaticArraysByShape.Add(shape, id);
        }
        return true;
    }

    private bool TryReserveTypeId(TypeId id)
    {
        return !IsTypeIdInUse(id) && _reservedParametricTypeIds.Add(id);
    }

    public bool TryGetStaticArrayForElement(TypeId elementType, out TypeId arrayType) =>
        _staticArraysByElement.TryGetValue(elementType, out arrayType);

    public TypeId GetOrAddDynamicArray(TypeId elementType)
    {
        if (_dynamicArraysByElement.TryGetValue(elementType, out var existing))
        {
            return existing;
        }

        var id = AllocateParametricTypeId();
        var size = InlineSizeOf(elementType);
        var alignment = Math.Min(Math.Max(size, 1), 8);
        _dynamicArrays.Add(id, new BoundDynamicArrayDefinition(id, elementType, size, alignment));
        _dynamicArraysByElement.Add(elementType, id);
        return id;
    }

    public void RegisterDynamicArray(TypeId id, TypeId elementType)
    {
        if (_dynamicArraysByElement.TryGetValue(elementType, out var existing))
        {
            if (existing != id)
            {
                throw new InvalidOperationException($"dynamic array element type '{(int)elementType}' already has type id '{(int)existing}'");
            }
            return;
        }

        var size = InlineSizeOf(elementType);
        var alignment = Math.Min(Math.Max(size, 1), 8);
        _dynamicArrays.Add(id, new BoundDynamicArrayDefinition(id, elementType, size, alignment));
        _dynamicArraysByElement.Add(elementType, id);
        _nextParametricTypeId = Math.Max(_nextParametricTypeId, (int)id + 1);
    }

    public void RegisterDynamicArrays(IReadOnlyDictionary<TypeId, TypeId> definitions)
    {
        // Declare every recursive container identity before measuring element
        // layouts. An element struct may itself contain another predeclared
        // dynamic array, so sizing while registering one-by-one makes layout
        // depend on dictionary iteration order.
        foreach (var (id, elementType) in definitions)
        {
            if (_dynamicArraysByElement.TryGetValue(elementType, out var existing))
            {
                if (existing != id)
                {
                    throw new InvalidOperationException(
                        $"dynamic array element type '{(int)elementType}' already has type id '{(int)existing}'");
                }
                continue;
            }

            _dynamicArrays.Add(id, new BoundDynamicArrayDefinition(id, elementType, 0, 1));
            _dynamicArraysByElement.Add(elementType, id);
            _nextParametricTypeId = Math.Max(_nextParametricTypeId, (int)id + 1);
        }

        foreach (var (id, elementType) in definitions)
        {
            var size = InlineSizeOf(elementType);
            var alignment = Math.Min(Math.Max(size, 1), 8);
            _dynamicArrays[id] = new BoundDynamicArrayDefinition(
                id, elementType, size, alignment);
        }
    }

    public void RegisterBoundedArrays(
        IReadOnlyDictionary<TypeId, (TypeId ElementType, int Capacity)> definitions)
    {
        foreach (var (id, shape) in definitions)
        {
            var elementSize = InlineSizeOf(shape.ElementType);
            var elementAlignment = Math.Min(Math.Max(elementSize, 1), 8);
            var dataOffset = AlignUp(8, elementAlignment);
            var alignment = Math.Max(8, elementAlignment);
            var size = AlignUp(checked(dataOffset + checked(elementSize * shape.Capacity)), alignment);
            _boundedArrays.Add(id, new BoundBoundedArrayDefinition(
                id, shape.ElementType, shape.Capacity, elementSize, elementAlignment,
                dataOffset, size, alignment));
            _boundedArraysByShape.Add((shape.ElementType, shape.Capacity), id);
            _nextParametricTypeId = Math.Max(_nextParametricTypeId, (int)id + 1);
        }
    }

    public void RegisterBoundedDictionaries(
        IReadOnlyDictionary<TypeId, (TypeId KeyType, TypeId ValueType, int MaxEntries)> definitions)
    {
        foreach (var (id, shape) in definitions)
        {
            var heapDictionaryType = GetOrAddDictionary(shape.KeyType, shape.ValueType);
            var layout = _dictionaries[heapDictionaryType];
            var minimumBuckets = checked((shape.MaxEntries * 8 + 6) / 7);
            var bucketCapacity = 16;
            while (bucketCapacity < minimumBuckets)
            {
                bucketCapacity = checked(bucketCapacity * 2);
            }
            var entriesOffset = AlignUp(checked(bucketCapacity + 16),
                Math.Max(layout.KeyAlignment, layout.ValueAlignment));
            var alignment = Math.Max(8, Math.Max(layout.KeyAlignment, layout.ValueAlignment));
            var storageSize = AlignUp(
                checked(entriesOffset + checked(bucketCapacity * layout.EntryStride)), alignment);
            var size = AlignUp(checked(8 + storageSize), alignment);
            _boundedDictionaries.Add(id, new BoundBoundedDictionaryDefinition(
                id, shape.KeyType, shape.ValueType, shape.MaxEntries, bucketCapacity,
                ControlsOffset: 0, entriesOffset, storageSize, size, alignment, layout));
            _boundedDictionariesByShape.Add(
                (shape.KeyType, shape.ValueType, shape.MaxEntries), id);
            _nextParametricTypeId = Math.Max(_nextParametricTypeId, (int)id + 1);
        }
    }

    public bool TryGetDynamicArrayForElement(TypeId elementType, out TypeId arrayType) =>
        _dynamicArraysByElement.TryGetValue(elementType, out arrayType);

    public TypeId GetOrAddBoundedArray(TypeId elementType, int capacity)
    {
        if (capacity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(capacity), "bounded array capacity must be positive");
        }
        if (_boundedArraysByShape.TryGetValue((elementType, capacity), out var existing))
        {
            return existing;
        }

        var elementSize = InlineSizeOf(elementType);
        var elementAlignment = Math.Min(Math.Max(elementSize, 1), 8);
        var dataOffset = AlignUp(8, elementAlignment);
        var alignment = Math.Max(8, elementAlignment);
        var size = AlignUp(checked(dataOffset + checked(elementSize * capacity)), alignment);
        var id = AllocateParametricTypeId();
        _boundedArrays.Add(id, new BoundBoundedArrayDefinition(
            id, elementType, capacity, elementSize, elementAlignment,
            dataOffset, size, alignment));
        _boundedArraysByShape.Add((elementType, capacity), id);
        return id;
    }

    public BoundBoundedArrayDefinition GetBoundedArray(TypeId type) =>
        _boundedArrays.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a bounded array");

    public TypeId GetOrAddDictionary(TypeId keyType, TypeId valueType)
    {
        if (_dictionariesByTypes.TryGetValue((keyType, valueType), out var existing))
        {
            return existing;
        }

        var keySize = InlineSizeOf(keyType);
        var keyAlignment = Math.Min(Math.Max(keySize, 1), 8);
        var valueSize = InlineSizeOf(valueType);
        var valueAlignment = Math.Min(Math.Max(valueSize, 1), 8);
        var valueOffset = AlignUp(keySize, valueAlignment);
        var entryAlignment = Math.Max(keyAlignment, valueAlignment);
        var stride = AlignUp(checked(valueOffset + valueSize), entryAlignment);
        var id = AllocateParametricTypeId();
        _dictionaries.Add(id, new BoundDictionaryDefinition(
            id, keyType, valueType, keySize, keyAlignment,
            valueOffset, valueSize, valueAlignment, stride));
        _dictionariesByTypes.Add((keyType, valueType), id);
        return id;
    }

    public TypeId GetOrAddBoundedDictionary(TypeId keyType, TypeId valueType, int maxEntries)
    {
        if (maxEntries <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxEntries), "bounded dictionary capacity must be positive");
        }
        if (_boundedDictionariesByShape.TryGetValue((keyType, valueType, maxEntries), out var existing))
        {
            return existing;
        }

        var heapDictionaryType = GetOrAddDictionary(keyType, valueType);
        var layout = _dictionaries[heapDictionaryType];
        var minimumBuckets = checked((maxEntries * 8 + 6) / 7);
        var bucketCapacity = 16;
        while (bucketCapacity < minimumBuckets)
        {
            bucketCapacity = checked(bucketCapacity * 2);
        }
        var controlsOffset = 0;
        var entriesOffset = AlignUp(checked(bucketCapacity + 16),
            Math.Max(layout.KeyAlignment, layout.ValueAlignment));
        var alignment = Math.Max(8, Math.Max(layout.KeyAlignment, layout.ValueAlignment));
        var storageSize = AlignUp(checked(entriesOffset + checked(bucketCapacity * layout.EntryStride)), alignment);
        var size = AlignUp(checked(8 + storageSize), alignment);
        var id = AllocateParametricTypeId();
        _boundedDictionaries.Add(id, new BoundBoundedDictionaryDefinition(
            id, keyType, valueType, maxEntries, bucketCapacity,
            controlsOffset, entriesOffset, storageSize, size, alignment, layout));
        _boundedDictionariesByShape.Add((keyType, valueType, maxEntries), id);
        return id;
    }

    public BoundBoundedDictionaryDefinition GetBoundedDictionary(TypeId type) =>
        _boundedDictionaries.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a bounded dictionary");

    public bool TryGetDictionaryForTypes(TypeId keyType, TypeId valueType, out TypeId dictionaryType) =>
        _dictionariesByTypes.TryGetValue((keyType, valueType), out dictionaryType);

    public BoundDictionaryDefinition GetDictionary(TypeId type) =>
        _dictionaries.TryGetValue(type, out var definition)
            ? definition
            : _boundedDictionaries.TryGetValue(type, out var bounded)
                ? bounded.Layout
                : throw new KeyNotFoundException($"type id '{(int)type}' is not a dictionary");

    public TypeId GetOrAddBitSet(int bitCount)
    {
        if (bitCount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(bitCount), "BitSet size must be positive");
        }
        if (_bitSetsByBitCount.TryGetValue(bitCount, out var existing))
        {
            return existing;
        }
        var wordCount = checked((bitCount + 63) / 64);
        var id = AllocateParametricTypeId();
        _bitSets.Add(id, new BoundBitSetDefinition(id, bitCount, wordCount,
            checked(wordCount * 8), Alignment: 8));
        _bitSetsByBitCount.Add(bitCount, id);
        _names.TryAdd($"BitSet<{bitCount}>", id);
        return id;
    }

    public BoundBitSetDefinition GetBitSet(TypeId type) =>
        _bitSets.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a BitSet");

    public TypeId GetOrAddBinaryHeap(TypeId elementType)
    {
        if (_binaryHeapsByElement.TryGetValue(elementType, out var existing))
        {
            return existing;
        }
        var id = AllocateParametricTypeId();
        var size = InlineSizeOf(elementType);
        var alignment = Math.Min(Math.Max(size, 1), 8);
        _dynamicArrays.Add(id, new BoundDynamicArrayDefinition(id, elementType, size, alignment));
        _binaryHeaps.Add(id, elementType);
        _binaryHeapsByElement.Add(elementType, id);
        _names.TryAdd($"BinaryHeap<{DisplayTypeName(elementType)}>", id);
        return id;
    }

    public TypeId GetBinaryHeapElement(TypeId type) =>
        _binaryHeaps.TryGetValue(type, out var elementType)
            ? elementType
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a BinaryHeap");

    public TypeId GetOrAddDeque(TypeId elementType)
    {
        if (_dequesByElement.TryGetValue(elementType, out var existing))
        {
            return existing;
        }
        var id = AllocateParametricTypeId();
        var size = InlineSizeOf(elementType);
        var alignment = Math.Min(Math.Max(size, 1), 8);
        _dynamicArrays.Add(id, new BoundDynamicArrayDefinition(id, elementType, size, alignment));
        _deques.Add(id, elementType);
        _dequesByElement.Add(elementType, id);
        _names.TryAdd($"Deque<{DisplayTypeName(elementType)}>", id);
        return id;
    }

    public TypeId GetDequeElement(TypeId type) =>
        _deques.TryGetValue(type, out var elementType)
            ? elementType
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a Deque");

    public TypeId GetOrAddSet(TypeId elementType)
    {
        if (_setsByElement.TryGetValue(elementType, out var existing))
        {
            return existing;
        }
        var keySize = InlineSizeOf(elementType);
        var keyAlignment = Math.Min(Math.Max(keySize, 1), 8);
        var id = AllocateParametricTypeId();
        _dictionaries.Add(id, new BoundDictionaryDefinition(
            id, elementType, BoundType.Unit,
            keySize, keyAlignment,
            ValueOffset: keySize, ValueSize: 0, ValueAlignment: 1,
            EntryStride: AlignUp(keySize, keyAlignment)));
        _sets.Add(id, elementType);
        _setsByElement.Add(elementType, id);
        _names.TryAdd($"Set<{DisplayTypeName(elementType)}>", id);
        return id;
    }

    public TypeId GetSetElement(TypeId type) =>
        _sets.TryGetValue(type, out var elementType)
            ? elementType
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a Set");

    private string DisplayTypeName(TypeId type) =>
        _names.FirstOrDefault(item => item.Value == type).Key ?? ((int)type).ToString();

    public TypeId GetOrAddOption(TypeId valueType, string displayName)
    {
        if (_optionsByValue.TryGetValue(valueType, out var existing))
        {
            _names.TryAdd(displayName, existing);
            return existing;
        }
        var id = AllocateParametricTypeId();
        var payloadWords = (InlineSizeOf(valueType) + 7) / 8;
        _enums.Add(id, new BoundEnumDefinition(id, displayName, [
            new BoundEnumVariant("None", null, 0, 0, 0),
            new BoundEnumVariant("Some", valueType, 1, 0, 0)
        ], payloadWords, 0, 0, ModuleName: "", IsPublic: true));
        _optionsByValue.Add(valueType, id);
        _optionValues.Add(id, valueType);
        _names.TryAdd(displayName, id);
        return id;
    }

    public TypeId GetOrAddResult(TypeId okType, TypeId errorType, string displayName)
    {
        if (_resultsByTypes.TryGetValue((okType, errorType), out var existing))
        {
            _names.TryAdd(displayName, existing);
            return existing;
        }
        var id = AllocateParametricTypeId();
        var payloadWords = (Math.Max(InlineSizeOf(okType), InlineSizeOf(errorType)) + 7) / 8;
        _enums.Add(id, new BoundEnumDefinition(id, displayName, [
            new BoundEnumVariant("Ok", okType, 0, 0, 0),
            new BoundEnumVariant("Err", errorType, 1, 0, 0)
        ], payloadWords, 0, 0, ModuleName: "", IsPublic: true));
        _resultsByTypes.Add((okType, errorType), id);
        _resultTypes.Add(id, (okType, errorType));
        _names.TryAdd(displayName, id);
        return id;
    }

    public bool TryGetOptionValue(TypeId type, out TypeId valueType) =>
        _optionValues.TryGetValue(type, out valueType);

    public bool TryGetResultTypes(TypeId type, out (TypeId Ok, TypeId Error) types) =>
        _resultTypes.TryGetValue(type, out types);

    public TypeId GetOrAddTask(TypeId valueType)
    {
        if (_tasksByValue.TryGetValue(valueType, out var existing))
        {
            return existing;
        }

        var id = AllocateParametricTypeId();
        _tasksByValue.Add(valueType, id);
        _taskValues.Add(id, valueType);
        return id;
    }

    public bool IsTask(TypeId type) => _taskValues.ContainsKey(type);

    public bool TryGetTaskValue(TypeId type, out TypeId valueType) =>
        _taskValues.TryGetValue(type, out valueType);

    public TypeId GetOrAddStream(TypeId valueType)
    {
        if (_streamsByValue.TryGetValue(valueType, out var existing))
        {
            return existing;
        }

        var id = AllocateParametricTypeId();
        _streamsByValue.Add(valueType, id);
        _streamValues.Add(id, valueType);
        return id;
    }

    public bool IsStream(TypeId type) => _streamValues.ContainsKey(type);

    public bool TryGetStreamValue(TypeId type, out TypeId valueType) =>
        _streamValues.TryGetValue(type, out valueType);

    public TypeId GetOrAddEventStream(TypeId valueType)
    {
        if (_eventStreamsByValue.TryGetValue(valueType, out var existing))
        {
            return existing;
        }

        var id = AllocateParametricTypeId();
        _eventStreamsByValue.Add(valueType, id);
        _eventStreamValues.Add(id, valueType);
        return id;
    }

    public bool IsEventStream(TypeId type) => _eventStreamValues.ContainsKey(type);

    public bool TryGetEventStreamValue(TypeId type, out TypeId valueType) =>
        _eventStreamValues.TryGetValue(type, out valueType);

    public bool ContainsOwnedStorage(TypeId type)
    {
        return ContainsOwnedStorage(type, new HashSet<TypeId>());
    }

    private bool ContainsOwnedStorage(TypeId type, HashSet<TypeId> visiting)
    {
        if (_boundedArrays.TryGetValue(type, out var boundedArray))
        {
            return ContainsOwnedStorage(boundedArray.ElementType, visiting);
        }
        if (_boundedDictionaries.TryGetValue(type, out var boundedDictionary))
        {
            return ContainsOwnedStorage(boundedDictionary.KeyType, visiting)
                || ContainsOwnedStorage(boundedDictionary.ValueType, visiting);
        }
        if (type is TypeId.DynamicIntArray or TypeId.IntDictionary or TypeId.Arena
            or TypeId.File or TypeId.FileWriter
            or TypeId.SourceText or TypeId.MappedBytes or TypeId.MutableMappedBytes
            || IsTask(type) || IsBox(type) || IsDynTrait(type)
            || IsStream(type) || IsEventStream(type)
            || IsStaticArray(type) || IsDynamicArray(type) || _dictionaries.ContainsKey(type))
        {
            return true;
        }
        if (_structs.TryGetValue(type, out var nativeOwner)
            && nativeOwner.Name is "sys.socket.TcpListener" or "sys.socket.TcpStream" or "sys.socket.UdpSocket")
        {
            return true;
        }
        if (!visiting.Add(type))
        {
            return false;
        }

        try
        {
            if (_structs.TryGetValue(type, out var structure))
            {
                return structure.ComInterface is not null
                    || structure.NativeHandle is not null
                    || structure.Fields.Any(field => ContainsOwnedStorage(field.Type, visiting));
            }
            if (_enums.TryGetValue(type, out var enumeration))
            {
                return enumeration.Variants.Any(variant => variant.PayloadType is { } payload
                    && ContainsOwnedStorage(payload, visiting));
            }

            return false;
        }
        finally
        {
            visiting.Remove(type);
        }
    }

    public BoundStructDefinition GetStruct(TypeId type)
    {
        return _structs.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a struct");
    }

    public BoundEnumDefinition GetEnum(TypeId type)
    {
        return _enums.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not an enum");
    }

    public BoundBoxDefinition GetBox(TypeId type)
    {
        return _boxes.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a box");
    }

    public BoundReferenceDefinition GetReference(TypeId type)
    {
        return _references.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a reference");
    }

    public TypeId GetOrAddSlice(TypeId elementType)
    {
        if (elementType == TypeId.Int)
        {
            return TypeId.IntSlice;
        }
        if (_slicesByElement.TryGetValue(elementType, out var existing))
        {
            return existing;
        }

        var id = AllocateParametricTypeId();
        _slices.Add(id, new BoundSliceDefinition(id, elementType));
        _slicesByElement.Add(elementType, id);
        return id;
    }

    public TypeId GetSliceElement(TypeId type)
    {
        if (type == TypeId.IntSlice)
        {
            return TypeId.Int;
        }
        return _slices.TryGetValue(type, out var definition)
            ? definition.ElementType
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a slice");
    }

    public BoundStaticArrayDefinition GetStaticArray(TypeId type)
    {
        return _staticArrays.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a static array");
    }

    public BoundDynamicArrayDefinition GetDynamicArray(TypeId type)
    {
        return _dynamicArrays.TryGetValue(type, out var definition)
            ? definition
            : throw new KeyNotFoundException($"type id '{(int)type}' is not a dynamic array");
    }

    public int InlineSizeOf(TypeId type)
    {
        if (_bitSets.TryGetValue(type, out var bitSet))
        {
            return bitSet.Size;
        }
        if (_boundedDictionaries.TryGetValue(type, out var boundedDictionary))
        {
            return boundedDictionary.Size;
        }
        if (_boundedArrays.TryGetValue(type, out var boundedArray))
        {
            return boundedArray.Size;
        }
        if (type is TypeId.DynamicIntArray or TypeId.IntDictionary)
        {
            return 24;
        }
        if (IsDynamicArray(type) || IsDictionary(type))
        {
            return 24;
        }
        if (IsStaticArray(type))
        {
            return checked(_pointerSize * 2);
        }
        if (_boxes.ContainsKey(type) || _references.ContainsKey(type))
        {
            return _pointerSize;
        }
        if (_dynTraits.ContainsKey(type))
        {
            return checked(_pointerSize * 2);
        }
        if (type == TypeId.SourceText)
        {
            return 32;
        }
        if (type is TypeId.MappedBytes or TypeId.MutableMappedBytes)
        {
            return 40;
        }
        if (_structs.TryGetValue(type, out var structure))
        {
            var offset = 0;
            var maxAlignment = 1;
            foreach (var field in structure.Fields)
            {
                var size = InlineSizeOf(field.Type);
                var alignment = AlignmentOf(field.Type);
                offset = AlignUp(offset, alignment);
                offset += size;
                maxAlignment = Math.Max(maxAlignment, alignment);
            }
            return AlignUp(offset, maxAlignment);
        }
        if (_enums.TryGetValue(type, out var enumeration))
        {
            return 8 + enumeration.PayloadWords * 8;
        }
        return type switch
        {
            TypeId.Unit => 0,
            TypeId.Bool => 1,
            TypeId.Int8 or TypeId.UInt8 => 1,
            TypeId.Int16 or TypeId.UInt16 => 2,
            TypeId.Int or TypeId.UInt32 or TypeId.Float32 => 4,
            TypeId.CodePoint => 4,
            TypeId.Int64 or TypeId.UInt64 or TypeId.Float64 => 8,
            TypeId.Size or TypeId.UIntSize => _pointerSize,
            TypeId.Text => 16,
            TypeId.Arguments => 8,
            TypeId.Arena => 24,
            TypeId.SourceText => 32,
            TypeId.MappedBytes or TypeId.MutableMappedBytes => 40,
            _ when IsTask(type) => 16,
            _ when IsStream(type) || IsEventStream(type) => checked(_pointerSize * 3),
            TypeId.GenericParameter or TypeId.SecondaryGenericParameter or TypeId.TertiaryGenericParameter => 8,
            _ => throw new InvalidOperationException($"type {type} has no inline size")
        };
    }

    public int AlignmentOf(TypeId type)
    {
        if (_bitSets.TryGetValue(type, out var bitSet))
        {
            return bitSet.Alignment;
        }
        if (_boundedDictionaries.TryGetValue(type, out var boundedDictionary))
        {
            return boundedDictionary.Alignment;
        }
        if (_boundedArrays.TryGetValue(type, out var boundedArray))
        {
            return boundedArray.Alignment;
        }
        if (IsStaticArray(type))
        {
            return _pointerSize;
        }
        if (_structs.TryGetValue(type, out var structure))
        {
            return structure.Fields.Count == 0
                ? 1
                : structure.Fields.Max(field => AlignmentOf(field.Type));
        }
        if (_boxes.ContainsKey(type) || _references.ContainsKey(type))
        {
            return _pointerSize;
        }
        if (_dynTraits.ContainsKey(type)
            || IsDynamicArray(type)
            || IsDictionary(type)
            || IsTask(type)
            || IsStream(type)
            || IsEventStream(type))
        {
            return _pointerSize;
        }

        return type switch
        {
            TypeId.Unit or TypeId.Bool or TypeId.Int8 or TypeId.UInt8 => 1,
            TypeId.Int16 or TypeId.UInt16 => 2,
            TypeId.Int or TypeId.UInt32 or TypeId.Float32 or TypeId.CodePoint => 4,
            TypeId.Int64 or TypeId.UInt64 or TypeId.Float64 => 8,
            TypeId.Size or TypeId.UIntSize => _pointerSize,
            TypeId.Text or TypeId.Arguments or TypeId.Arena
                or TypeId.SourceText or TypeId.MappedBytes or TypeId.MutableMappedBytes => _pointerSize,
            _ when _enums.ContainsKey(type) => 8,
            _ => Math.Min(Math.Max(InlineSizeOf(type), 1), 8)
        };
    }

    public int FieldOffsetOf(TypeId structType, int fieldIndex)
    {
        var structure = GetStruct(structType);
        var offset = 0;
        foreach (var field in structure.Fields)
        {
            offset = AlignUp(offset, AlignmentOf(field.Type));
            if (field.Index == fieldIndex)
            {
                return offset;
            }
            offset = checked(offset + InlineSizeOf(field.Type));
        }
        throw new ArgumentOutOfRangeException(nameof(fieldIndex));
    }

    private TypeId AllocateParametricTypeId()
    {
        while (_reservedParametricTypeIds.Contains((TypeId)_nextParametricTypeId))
            _nextParametricTypeId++;
        return (TypeId)_nextParametricTypeId++;
    }

    private bool IsTypeIdInUse(TypeId id) =>
        _structs.ContainsKey(id)
        || _enums.ContainsKey(id)
        || _boxes.ContainsKey(id)
        || _references.ContainsKey(id)
        || _slices.ContainsKey(id)
        || _dynTraits.ContainsKey(id)
        || _staticArrays.ContainsKey(id)
        || _dynamicArrays.ContainsKey(id)
        || _boundedArrays.ContainsKey(id)
        || _dictionaries.ContainsKey(id)
        || _boundedDictionaries.ContainsKey(id)
        || _bitSets.ContainsKey(id)
        || _binaryHeaps.ContainsKey(id)
        || _deques.ContainsKey(id)
        || _sets.ContainsKey(id)
        || _optionValues.ContainsKey(id)
        || _resultTypes.ContainsKey(id)
        || _taskValues.ContainsKey(id)
        || _streamValues.ContainsKey(id)
        || _eventStreamValues.ContainsKey(id);

    private static int AlignUp(int value, int alignment) =>
        checked((value + alignment - 1) / alignment * alignment);
}
