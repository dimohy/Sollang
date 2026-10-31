using System.Buffers.Binary;
using System.Globalization;
using System.Text;
using Sollang.Compiler.CodeGen;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Cli;

internal sealed class IncrementalCodegenCache
{
    private const ulong Magic = 6002245291164258119;
    private const ulong Schema = 1;
    private static readonly ulong EnvelopeChecksumSeed = Shared.CodegenCachePolicy.EnvelopeChecksumSeed();
    private static readonly ulong FragmentChecksumSeed = Shared.CodegenCachePolicy.FragmentChecksumSeed();
    private const int HeaderWords = 8;
    private const int RecordHeaderWords = 8;
    private const int MaximumUnitCount = 1_000_000;
    private const int MaximumIdentityBytes = 1024 * 1024;
    private const long MaximumFragmentBytes = 1024L * 1024 * 1024;

    private readonly IncrementalCacheLocation _location;

    private IncrementalCodegenCache(
        IncrementalCacheLocation location,
        LlvmCodegenKey prefixKey,
        LlvmCodegenKey suffixKey,
        IReadOnlyDictionary<string, LlvmCodegenKey> moduleKeys,
        IReadOnlyDictionary<(LlvmCodegenUnitKind Kind, string Identity, LlvmCodegenKey CacheKey), string> fragments,
        string loadStatus)
    {
        _location = location;
        LoadStatus = loadStatus;
        Reuse = new LlvmCodegenReuse(prefixKey, suffixKey, moduleKeys, fragments);
    }

    public LlvmCodegenReuse Reuse { get; }

    public string LoadStatus { get; }

    public string Path => _location.CodegenPath;

    public IncrementalCacheLocation Location => _location;

    public static IncrementalCodegenCache Open(
        LoadedCompilation compilation,
        BoundProgram boundProgram,
        CliOptions options)
    {
        var location = Locate(options);
        var modules = compilation.Sources
            .GroupBy(static source => source.ModuleName, StringComparer.Ordinal)
            .Select(static group => CreateModuleIdentity(group.Key, group.ToArray()))
            .OrderBy(static module => LlvmCodegenUnit.StableIdentity(module.Identity))
            .ThenBy(static module => module.Identity, StringComparer.Ordinal)
            .ToArray();

        var modulesByName = modules.ToDictionary(static module => module.Identity, StringComparer.Ordinal);
        var ambientStandardLibrary = HashFields(modules
            .Where(static module => module.IsStandardLibrary)
            .SelectMany(static module => new[]
            {
                module.Identity,
                Hex(module.InterfaceHash)
            }));
        var typeUniverseHash = BuildTypeUniverseHash(boundProgram.Types);
        var emissionHashes = BuildEmissionHashes(boundProgram);
        var moduleKeys = new Dictionary<string, LlvmCodegenKey>(StringComparer.Ordinal);
        foreach (var module in modules)
        {
            var dependencyInterfaces = CollectDependencyInterfaces(module, modulesByName);
            var implementationKey = HashRule(Shared.CodegenCacheKeyPolicy.ModuleImplementation(), part => part switch
            {
                Shared.CodegenKeyPart.Identity => [module.Identity],
                Shared.CodegenKeyPart.SourceImplementation => [Hex(module.ImplementationHash)],
                Shared.CodegenKeyPart.AmbientStandardLibrary => [Hex(ambientStandardLibrary)],
                Shared.CodegenKeyPart.TypeUniverse => [Hex(typeUniverseHash)],
                Shared.CodegenKeyPart.Emissions => [Hex(emissionHashes.GetValueOrDefault(module.Identity, HashFields([])))],
                Shared.CodegenKeyPart.DependencyInterfaces => dependencyInterfaces,
                _ => throw UnexpectedKeyPart(part)
            });
            moduleKeys[module.Identity] = new LlvmCodegenKey(module.InterfaceHash, implementationKey);
        }
        foreach (var emission in emissionHashes.OrderBy(static pair => pair.Key, StringComparer.Ordinal))
        {
            moduleKeys.TryAdd(
                emission.Key,
                new LlvmCodegenKey(
                    HashRule(Shared.CodegenCacheKeyPolicy.SyntheticInterface(), part => part switch
                    {
                        Shared.CodegenKeyPart.Identity => [emission.Key],
                        _ => throw UnexpectedKeyPart(part)
                    }),
                    HashRule(Shared.CodegenCacheKeyPolicy.SyntheticImplementation(), part => part switch
                    {
                        Shared.CodegenKeyPart.Identity => [emission.Key],
                        Shared.CodegenKeyPart.AmbientStandardLibrary => [Hex(ambientStandardLibrary)],
                        Shared.CodegenKeyPart.TypeUniverse => [Hex(typeUniverseHash)],
                        Shared.CodegenKeyPart.Emissions => [Hex(emission.Value)],
                        _ => throw UnexpectedKeyPart(part)
                    })));
        }

        var wholeInterfaceHash = HashRule(Shared.CodegenCacheKeyPolicy.WholeInterface(), part => part switch
        {
            Shared.CodegenKeyPart.ModuleInterfaces => modules.SelectMany(static module => new[]
                { module.Identity, Hex(module.InterfaceHash) }),
            _ => throw UnexpectedKeyPart(part)
        });
        var wholeImplementationHash = HashRule(Shared.CodegenCacheKeyPolicy.WholeImplementation(), part => part switch
        {
            Shared.CodegenKeyPart.ModuleImplementations => moduleKeys.OrderBy(static pair => LlvmCodegenUnit.StableIdentity(pair.Key))
                .ThenBy(static pair => pair.Key, StringComparer.Ordinal)
                .SelectMany(static pair => new[]
                {
                    pair.Key,
                    Hex(pair.Value.InterfaceHash),
                    Hex(pair.Value.ImplementationHash)
                }),
            _ => throw UnexpectedKeyPart(part)
        });
        var prefixKey = new LlvmCodegenKey(
            HashRule(Shared.CodegenCacheKeyPolicy.PrefixInterface(), part => part == Shared.CodegenKeyPart.WholeInterface
                ? [Hex(wholeInterfaceHash)] : throw UnexpectedKeyPart(part)),
            HashRule(Shared.CodegenCacheKeyPolicy.PrefixImplementation(), part => part == Shared.CodegenKeyPart.WholeImplementation
                ? [Hex(wholeImplementationHash)] : throw UnexpectedKeyPart(part)));
        var suffixKey = new LlvmCodegenKey(
            HashRule(Shared.CodegenCacheKeyPolicy.SuffixInterface(), part => part == Shared.CodegenKeyPart.WholeInterface
                ? [Hex(wholeInterfaceHash)] : throw UnexpectedKeyPart(part)),
            HashRule(Shared.CodegenCacheKeyPolicy.SuffixImplementation(), part => part == Shared.CodegenKeyPart.WholeImplementation
                ? [Hex(wholeImplementationHash)] : throw UnexpectedKeyPart(part)));

        IReadOnlyDictionary<(LlvmCodegenUnitKind Kind, string Identity, LlvmCodegenKey CacheKey), string> fragments;
        string loadStatus;
        if (!File.Exists(location.CodegenPath))
        {
            fragments = new Dictionary<(LlvmCodegenUnitKind, string, LlvmCodegenKey), string>();
            loadStatus = "cold";
        }
        else
        {
            try
            {
                fragments = Read(
                    location.CodegenPath,
                    location.CompilerHash,
                    location.TargetHash,
                    location.ConfigurationHash).Fragments;
                loadStatus = "loaded";
            }
            catch (Exception error) when (error is IOException or InvalidDataException or DecoderFallbackException)
            {
                fragments = new Dictionary<(LlvmCodegenUnitKind, string, LlvmCodegenKey), string>();
                loadStatus = "rejected: " + error.Message;
            }
        }

        return new IncrementalCodegenCache(
            location,
            prefixKey,
            suffixKey,
            moduleKeys,
            fragments,
            loadStatus);
    }

    public void Publish(LlvmCodegenOutput output)
    {
        var words = Encode(
            output,
            _location.CompilerHash,
            _location.TargetHash,
            _location.ConfigurationHash);
        var directory = System.IO.Path.GetDirectoryName(_location.CodegenPath)
            ?? throw new InvalidOperationException("codegen cache path has no directory");
        Directory.CreateDirectory(directory);
        var temporaryPath = _location.CodegenPath + "." + Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture) + ".tmp";
        try
        {
            using (var stream = new FileStream(
                       temporaryPath,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None,
                       bufferSize: 64 * 1024,
                       FileOptions.WriteThrough))
            {
                Span<byte> bytes = stackalloc byte[sizeof(ulong)];
                foreach (var word in words)
                {
                    BinaryPrimitives.WriteUInt64LittleEndian(bytes, word);
                    stream.Write(bytes);
                }
                stream.Flush(flushToDisk: true);
            }
            File.Move(temporaryPath, _location.CodegenPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    public static IncrementalCacheLocation Locate(CliOptions options)
    {
        var compilerHash = HashFields([
            "sollang-codegen-unit-schema-1",
            typeof(CompilerApp).Assembly.ManifestModule.ModuleVersionId.ToString("N")
        ]);
        var targetName = TargetName(options.Target);
        var configurationName = (options.OptimizationLevel ?? "-O0")
            + (options.OutputKind == CompilationOutputKind.SharedLibrary ? "-library" : "-executable");
        var outputDirectory = System.IO.Path.GetDirectoryName(options.OutputPath)
            ?? Directory.GetCurrentDirectory();
        var cacheDirectory = System.IO.Path.Combine(outputDirectory, ".sollang-cache");
        var outputName = System.IO.Path.GetFileNameWithoutExtension(options.OutputPath);
        var configuration = configurationName.TrimStart('-').ToLowerInvariant();
        var baseName = $"{SanitizeFileName(outputName)}.{targetName}.{configuration}";
        return new IncrementalCacheLocation(
            System.IO.Path.Combine(cacheDirectory, baseName + ".cgu"),
            System.IO.Path.Combine(cacheDirectory, baseName + ".sources"),
            System.IO.Path.Combine(cacheDirectory, baseName + ".product"),
            System.IO.Path.Combine(cacheDirectory, baseName + ".semantic"),
            compilerHash,
            HashFields([targetName]),
            HashFields([configurationName]));
    }

    public static LlvmCodegenOutput ReadExact(IncrementalCacheLocation location)
    {
        var decoded = Read(
            location.CodegenPath,
            location.CompilerHash,
            location.TargetHash,
            location.ConfigurationHash);
        return new LlvmCodegenOutput(decoded.Units);
    }

    private static IReadOnlyList<ulong> Encode(
        LlvmCodegenOutput output,
        ulong compilerHash,
        ulong targetHash,
        ulong configurationHash)
    {
        if (output.Units.Count is < 2 or > MaximumUnitCount
            || output.Units[0].Kind != LlvmCodegenUnitKind.SharedPrefix
            || output.Units[^1].Kind != LlvmCodegenUnitKind.SharedSuffix)
        {
            throw new InvalidDataException("codegen unit shape is invalid");
        }
        var words = new List<ulong>(HeaderWords + output.Units.Count * RecordHeaderWords)
        {
            Magic,
            Schema,
            compilerHash,
            targetHash,
            configurationHash,
            (ulong)output.Units.Count,
            0,
            0
        };
        ulong previousModuleHash = 0;
        var previousModuleIdentity = "";
        var sawModule = false;
        for (var index = 0; index < output.Units.Count; index++)
        {
            var unit = output.Units[index];
            var identityBytes = Encoding.UTF8.GetBytes(unit.Identity);
            var moduleHash = unit.Kind == LlvmCodegenUnitKind.Module
                ? LlvmCodegenUnit.StableIdentity(identityBytes)
                : 0;
            if (unit.Kind == LlvmCodegenUnitKind.Module)
            {
                if (sawModule && LlvmCodegenUnit.CompareIdentities(
                        previousModuleHash, previousModuleIdentity, moduleHash, unit.Identity) >= 0)
                {
                    throw new InvalidDataException("codegen module order is not canonical");
                }
                previousModuleHash = moduleHash;
                previousModuleIdentity = unit.Identity;
                sawModule = true;
            }
            else if (identityBytes.Length != 0
                     || unit.Kind == LlvmCodegenUnitKind.SharedPrefix && index != 0
                     || unit.Kind == LlvmCodegenUnitKind.SharedSuffix && index != output.Units.Count - 1)
            {
                throw new InvalidDataException("shared codegen unit identity is invalid");
            }

            var fragmentBytes = Encoding.UTF8.GetBytes(unit.Text);
            var fragmentWords = PackBytes(fragmentBytes);
            words.Add((ulong)unit.Kind);
            words.Add(moduleHash);
            words.Add(unit.CacheKey.InterfaceHash);
            words.Add(unit.CacheKey.ImplementationHash);
            words.Add((ulong)identityBytes.Length);
            words.Add((ulong)fragmentBytes.Length);
            words.Add((ulong)fragmentWords.Count);
            words.Add(FragmentChecksum(fragmentWords, fragmentBytes.Length));
            foreach (var value in identityBytes)
            {
                words.Add(value);
            }
            words.AddRange(fragmentWords);
        }
        words[6] = (ulong)words.Count;
        words[7] = Checksum(words, HeaderWords, words.Count - HeaderWords, EnvelopeChecksumSeed);
        return words;
    }

    private static DecodedCodegenCache Read(
        string path,
        ulong compilerHash,
        ulong targetHash,
        ulong configurationHash)
    {
        var fileLength = new FileInfo(path).Length;
        if (fileLength < HeaderWords * sizeof(ulong) || fileLength % sizeof(ulong) != 0)
        {
            throw new InvalidDataException("artifact is truncated or not word aligned");
        }
        var wordCount64 = fileLength / sizeof(ulong);
        if (wordCount64 > int.MaxValue)
        {
            throw new InvalidDataException("artifact is too large");
        }
        var words = new ulong[(int)wordCount64];
        using (var stream = File.OpenRead(path))
        {
            Span<byte> bytes = stackalloc byte[sizeof(ulong)];
            for (var index = 0; index < words.Length; index++)
            {
                stream.ReadExactly(bytes);
                words[index] = BinaryPrimitives.ReadUInt64LittleEndian(bytes);
            }
        }

        if (words[0] != Magic)
        {
            throw new InvalidDataException("artifact magic mismatch");
        }
        if (words[1] != Schema)
        {
            throw new InvalidDataException("artifact schema mismatch");
        }
        if (!Shared.CodegenCachePolicy.MatchesContext(
                words[2] == compilerHash, words[3] == targetHash, words[4] == configurationHash))
        {
            throw new InvalidDataException("artifact context mismatch");
        }
        if (words[6] != (ulong)words.Length)
        {
            throw new InvalidDataException("artifact declared length mismatch");
        }
        var envelopeChecksum = Checksum(words, HeaderWords, words.Length - HeaderWords, EnvelopeChecksumSeed);
        if (words[7] != envelopeChecksum)
        {
            throw new InvalidDataException("artifact envelope checksum mismatch");
        }
        if (words[5] is < 2 or > MaximumUnitCount)
        {
            throw new InvalidDataException("artifact unit count is invalid");
        }

        var unitCount = (int)words[5];
        var result = new Dictionary<(LlvmCodegenUnitKind Kind, string Identity, LlvmCodegenKey CacheKey), string>();
        var units = new List<LlvmCodegenUnit>(unitCount);
        var wordIndex = HeaderWords;
        var prefixCount = 0;
        var suffixCount = 0;
        var previousKind = -1;
        ulong previousModuleHash = 0;
        var previousModuleIdentity = "";
        for (var unitIndex = 0; unitIndex < unitCount; unitIndex++)
        {
            EnsureReadable(wordIndex, RecordHeaderWords, words.Length);
            if (words[wordIndex] > (ulong)LlvmCodegenUnitKind.SharedSuffix)
            {
                throw new InvalidDataException("artifact unit kind is invalid");
            }
            var kind = (LlvmCodegenUnitKind)words[wordIndex];
            var moduleHash = words[wordIndex + 1];
            var cacheKey = new LlvmCodegenKey(words[wordIndex + 2], words[wordIndex + 3]);
            var identityLength = CheckedLength(words[wordIndex + 4], MaximumIdentityBytes, "identity");
            var fragmentByteLength = CheckedLength(words[wordIndex + 5], MaximumFragmentBytes, "fragment");
            var fragmentWordLength = CheckedLength(words[wordIndex + 6], int.MaxValue, "fragment words");
            if (fragmentWordLength != RequiredWords(fragmentByteLength))
            {
                throw new InvalidDataException("artifact fragment word length is invalid");
            }
            var declaredFragmentChecksum = words[wordIndex + 7];
            var identityStart = checked(wordIndex + RecordHeaderWords);
            EnsureReadable(identityStart, identityLength, words.Length);
            var fragmentStart = checked(identityStart + identityLength);
            EnsureReadable(fragmentStart, fragmentWordLength, words.Length);

            if ((int)kind < previousKind)
            {
                throw new InvalidDataException("artifact unit order is invalid");
            }
            var identityBytes = new byte[identityLength];
            for (var identityIndex = 0; identityIndex < identityLength; identityIndex++)
            {
                var value = words[identityStart + identityIndex];
                if (value > byte.MaxValue)
                {
                    throw new InvalidDataException("artifact module identity is invalid");
                }
                identityBytes[identityIndex] = (byte)value;
            }
            var identity = new UTF8Encoding(false, true).GetString(identityBytes);
            switch (kind)
            {
                case LlvmCodegenUnitKind.SharedPrefix:
                    prefixCount++;
                    if (moduleHash != 0 || identityLength != 0 || unitIndex != 0)
                    {
                        throw new InvalidDataException("artifact prefix is invalid");
                    }
                    break;
                case LlvmCodegenUnitKind.Module:
                    if (LlvmCodegenUnit.StableIdentity(identityBytes) != moduleHash
                        || previousKind == (int)LlvmCodegenUnitKind.Module
                        && LlvmCodegenUnit.CompareIdentities(
                            previousModuleHash, previousModuleIdentity, moduleHash, identity) >= 0)
                    {
                        throw new InvalidDataException("artifact module identity or order is invalid");
                    }
                    previousModuleHash = moduleHash;
                    previousModuleIdentity = identity;
                    break;
                case LlvmCodegenUnitKind.SharedSuffix:
                    suffixCount++;
                    if (moduleHash != 0 || identityLength != 0 || unitIndex != unitCount - 1)
                    {
                        throw new InvalidDataException("artifact suffix is invalid");
                    }
                    break;
            }

            var packedFragment = words.AsSpan(fragmentStart, fragmentWordLength);
            if (FragmentChecksum(packedFragment, fragmentByteLength) != declaredFragmentChecksum)
            {
                throw new InvalidDataException("artifact fragment checksum mismatch");
            }
            if (fragmentWordLength > 0 && fragmentByteLength % sizeof(ulong) != 0)
            {
                var usedBits = (fragmentByteLength % sizeof(ulong)) * 8;
                if (packedFragment[^1] >> usedBits != 0)
                {
                    throw new InvalidDataException("artifact fragment padding is not zero");
                }
            }
            var fragmentBytes = UnpackBytes(packedFragment, fragmentByteLength);
            var fragment = new UTF8Encoding(false, true).GetString(fragmentBytes);
            if (!result.TryAdd((kind, identity, cacheKey), fragment))
            {
                throw new InvalidDataException("artifact contains a duplicate unit");
            }
            units.Add(new LlvmCodegenUnit(kind, identity, cacheKey, fragment, Reused: true));
            previousKind = (int)kind;
            wordIndex = checked(fragmentStart + fragmentWordLength);
        }
        if (wordIndex != words.Length || prefixCount != 1 || suffixCount != 1)
        {
            throw new InvalidDataException("artifact envelope shape is invalid");
        }
        return new DecodedCodegenCache(result, units);
    }

    private static ModuleIdentity CreateModuleIdentity(
        string identity,
        IReadOnlyList<CompilationSource> sources)
    {
        // Match exact-source semantic generations; case-distinct paths must not
        // retain an input-order tie on case-sensitive source namespaces.
        var ordered = sources.OrderBy(static source => source.Path, StringComparer.Ordinal).ToArray();
        var implementationHash = HashBinaryFields(ordered.Select(static source => source.SourceBytes));
        var interfaceHash = HashFields(ordered.SelectMany(static source => PublicInterfaceFields(source.Program)));
        var imports = ordered
            .SelectMany(static source => source.Program.Imports)
            .Select(static import => string.Join('.', import.Path))
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();
        return new ModuleIdentity(
            identity,
            implementationHash,
            interfaceHash,
            imports,
            ordered.All(static source => source.IsStandardLibrary));
    }

    private static IReadOnlyList<string> CollectDependencyInterfaces(
        ModuleIdentity module,
        IReadOnlyDictionary<string, ModuleIdentity> modules)
    {
        var dependencies = new Dictionary<string, ulong>(StringComparer.Ordinal);
        var visited = new HashSet<string>(StringComparer.Ordinal) { module.Identity };
        var pending = new Stack<string>(module.Imports.OrderDescending(StringComparer.Ordinal));
        while (pending.TryPop(out var name))
        {
            if (!visited.Add(name) || !modules.TryGetValue(name, out var dependency))
            {
                continue;
            }
            dependencies.Add(name, dependency.InterfaceHash);
            foreach (var nested in dependency.Imports.OrderDescending(StringComparer.Ordinal))
            {
                pending.Push(nested);
            }
        }
        return dependencies
            .OrderBy(static pair => pair.Key, StringComparer.Ordinal)
            .SelectMany(static pair => new[] { pair.Key, Hex(pair.Value) })
            .ToArray();
    }

    private static IReadOnlyDictionary<string, ulong> BuildEmissionHashes(BoundProgram program)
    {
        var functions = EnumerateFunctions(program.Functions.Values)
            .Where(static function => function.Kind == BoundFunctionKind.User)
            .GroupBy(static function => function.ModuleName ?? "", StringComparer.Ordinal);
        return functions.ToDictionary(
            static group => group.Key,
            group => HashFields(group
                .OrderBy(static function => function.Name, StringComparer.Ordinal)
                .Select(function => program.StableFunctionIdentities[function])),
            StringComparer.Ordinal);
    }

    private static IEnumerable<BoundFunction> EnumerateFunctions(IEnumerable<BoundFunction> functions)
    {
        foreach (var function in functions)
        {
            yield return function;
            foreach (var local in EnumerateFunctions(function.LocalFunctions.Values))
            {
                yield return local;
            }
        }
    }

    private static IEnumerable<string> PublicInterfaceFields(SollangProgram program)
    {
        foreach (var part in Shared.CodegenCacheKeyPolicy.InterfaceDeclarations().Parts)
            foreach (var field in PublicDeclarationFields(program, part))
                yield return field;
    }

    private static IEnumerable<string> PublicDeclarationFields(SollangProgram program, Shared.CodegenKeyPart part)
    {
        switch (part)
        {
            case Shared.CodegenKeyPart.InterfaceStructs:
                foreach (var structure in program.Structs.Where(static value => value.IsPublic)
                             .OrderBy(static value => value.Name, StringComparer.Ordinal))
                    foreach (var field in RuleFields(Shared.CodegenCacheKeyPolicy.StructInterface(), part => part switch
                    {
                        Shared.CodegenKeyPart.Identity => [structure.Name],
                        Shared.CodegenKeyPart.DeclarationContainer => [structure.DeclaringTypeName ?? ""],
                        Shared.CodegenKeyPart.Visibility => [structure.IsPublic ? "public" : "private"],
                        Shared.CodegenKeyPart.StructFields => structure.Fields.SelectMany(static field => MemberFields(Shared.CodegenCacheKeyPolicy.NamedTypeFields(), field.Name, field.TypeName, null)),
                        _ => throw UnexpectedKeyPart(part)
                    })) yield return field;
                yield break;
            case Shared.CodegenKeyPart.InterfaceEnums:
                foreach (var enumeration in program.Enums.Where(static value => value.IsPublic)
                             .OrderBy(static value => value.Name, StringComparer.Ordinal))
                    foreach (var field in RuleFields(Shared.CodegenCacheKeyPolicy.EnumInterface(), part => part switch
                    {
                        Shared.CodegenKeyPart.Identity => [enumeration.Name],
                        Shared.CodegenKeyPart.Visibility => [enumeration.IsPublic ? "public" : "private"],
                        Shared.CodegenKeyPart.EnumVariants => enumeration.Variants.SelectMany(static variant => MemberFields(Shared.CodegenCacheKeyPolicy.NamedTypeFields(), variant.Name, variant.PayloadType ?? "", null)),
                        _ => throw UnexpectedKeyPart(part)
                    })) yield return field;
                yield break;
            case Shared.CodegenKeyPart.InterfaceTraits:
                foreach (var trait in program.Traits.Where(static value => value.IsPublic)
                             .OrderBy(static value => value.Name, StringComparer.Ordinal))
                    foreach (var field in RuleFields(Shared.CodegenCacheKeyPolicy.TraitInterface(), part => part switch
                    {
                        Shared.CodegenKeyPart.Identity => [trait.Name],
                        Shared.CodegenKeyPart.TraitAssociatedTypes => trait.AssociatedTypes.Select(static associated => associated.Name),
                        Shared.CodegenKeyPart.TraitMethods => TraitMethodFields(trait),
                        _ => throw UnexpectedKeyPart(part)
                    })) yield return field;
                yield break;
            case Shared.CodegenKeyPart.InterfaceFunctions:
                foreach (var function in program.Functions.Where(static value => value.IsPublic)
                             .OrderBy(static value => value.Name, StringComparer.Ordinal))
                    foreach (var field in RuleFields(Shared.CodegenCacheKeyPolicy.FunctionInterface(), part => part switch
                    {
                        Shared.CodegenKeyPart.Identity => [function.Name],
                        Shared.CodegenKeyPart.FunctionInput => MemberFields(Shared.CodegenCacheKeyPolicy.OwnedTypeFields(), null, function.InputType ?? "", function.InputOwnership),
                        Shared.CodegenKeyPart.FunctionReturn => [function.ReturnType],
                        Shared.CodegenKeyPart.FunctionBlock => FunctionBlockFields(Shared.CodegenCacheKeyPolicy.FunctionBlockFields(), function),
                        Shared.CodegenKeyPart.FunctionStream => [function.StreamElementType ?? ""],
                        Shared.CodegenKeyPart.FunctionAsync => [function.IsAsync ? "async" : "sync"],
                        Shared.CodegenKeyPart.FunctionGenerics => FunctionGenericFields(Shared.CodegenCacheKeyPolicy.FunctionGenericFields(), function),
                        Shared.CodegenKeyPart.FunctionEffects => (function.Effects ?? []).Order(StringComparer.Ordinal),
                        Shared.CodegenKeyPart.FunctionParameters => (function.AdditionalParameters ?? []).SelectMany(static parameter =>
                            MemberFields(Shared.CodegenCacheKeyPolicy.NamedOwnedTypeFields(), parameter.Name, parameter.TypeName, parameter.Ownership)),
                        Shared.CodegenKeyPart.FunctionAssociatedTypes => (function.ImplAssociatedTypes ?? new Dictionary<string, string>())
                            .OrderBy(static pair => pair.Key, StringComparer.Ordinal).SelectMany(static pair =>
                            MemberFields(Shared.CodegenCacheKeyPolicy.NamedTypeFields(), pair.Key, pair.Value, null)),
                        _ => throw UnexpectedKeyPart(part)
                    })) yield return field;
                yield break;
            default:
                throw UnexpectedKeyPart(part);
        }
    }

    private static IEnumerable<string> FunctionBlockFields(Shared.CodegenKeyRule rule, FunctionDeclaration function) =>
        PartFields(rule, part => part switch
        {
            Shared.CodegenKeyPart.BlockInput => [function.BlockInputType ?? ""],
            Shared.CodegenKeyPart.BlockResult => [function.BlockResultType ?? ""],
            _ => throw UnexpectedKeyPart(part)
        });

    private static IEnumerable<string> FunctionGenericFields(Shared.CodegenKeyRule rule, FunctionDeclaration function) =>
        PartFields(rule, part => part switch
        {
            Shared.CodegenKeyPart.GenericPrimary => [function.GenericParameterName ?? ""],
            Shared.CodegenKeyPart.GenericSecondary => [function.SecondaryGenericParameterName ?? ""],
            Shared.CodegenKeyPart.GenericTertiary => [function.TertiaryGenericParameterName ?? ""],
            Shared.CodegenKeyPart.GenericTraitBound => [function.GenericTraitBound ?? ""],
            Shared.CodegenKeyPart.GenericAssociatedName => [function.GenericAssociatedTypeName ?? ""],
            Shared.CodegenKeyPart.GenericAssociatedType => [function.GenericAssociatedTypeConstraint ?? ""],
            _ => throw UnexpectedKeyPart(part)
        });

    private static IEnumerable<string> MemberFieldValues(Shared.CodegenKeyPart part, string? name,
        string type, FunctionInputOwnership? ownership) => part switch
    {
        Shared.CodegenKeyPart.MemberName when name is not null => [name],
        Shared.CodegenKeyPart.MemberType => [type],
        Shared.CodegenKeyPart.MemberOwnership when ownership is { } value =>
            [((int)value).ToString(CultureInfo.InvariantCulture)],
        _ => throw UnexpectedKeyPart(part)
    };

    private static IEnumerable<string> MemberFields(Shared.CodegenKeyRule rule, string? name,
        string type, FunctionInputOwnership? ownership) =>
        PartFields(rule, part => MemberFieldValues(part, name, type, ownership));

    private static IEnumerable<string> TraitMethodFields(TraitDeclaration trait)
    {
        foreach (var method in trait.Methods)
            foreach (var field in PartFields(Shared.CodegenCacheKeyPolicy.TraitMethodFields(), part => part switch
            {
                Shared.CodegenKeyPart.MethodParameterCount =>
                    [method.AdditionalParameters.Count.ToString(CultureInfo.InvariantCulture)],
                Shared.CodegenKeyPart.MethodParameters => method.AdditionalParameters.SelectMany(static parameter =>
                    MemberFields(Shared.CodegenCacheKeyPolicy.OwnedTypeFields(), null, parameter.TypeName, parameter.Ownership)),
                _ => MemberFieldValues(part, method.Name, method.ReturnType, method.SelfOwnership)
            })) yield return field;
    }

    private static IReadOnlyList<ulong> PackBytes(ReadOnlySpan<byte> bytes)
    {
        var words = new ulong[RequiredWords(bytes.Length)];
        for (var index = 0; index < bytes.Length; index++)
        {
            words[index / sizeof(ulong)] |= (ulong)bytes[index] << ((index % sizeof(ulong)) * 8);
        }
        return words;
    }

    private static byte[] UnpackBytes(ReadOnlySpan<ulong> words, int byteLength)
    {
        var bytes = new byte[byteLength];
        for (var index = 0; index < byteLength; index++)
        {
            bytes[index] = (byte)(words[index / sizeof(ulong)] >> ((index % sizeof(ulong)) * 8));
        }
        return bytes;
    }

    private static int RequiredWords(int byteLength) =>
        checked((byteLength + sizeof(ulong) - 1) / sizeof(ulong));

    private static ulong FragmentChecksum(IReadOnlyList<ulong> words, int byteLength)
    {
        var hash = Mix(FragmentChecksumSeed, (ulong)byteLength);
        foreach (var word in words)
        {
            hash = Mix(hash, word);
        }
        return hash;
    }

    private static ulong FragmentChecksum(ReadOnlySpan<ulong> words, int byteLength)
    {
        var hash = Mix(FragmentChecksumSeed, (ulong)byteLength);
        foreach (var word in words)
        {
            hash = Mix(hash, word);
        }
        return hash;
    }

    private static ulong Checksum(
        IReadOnlyList<ulong> words,
        int start,
        int count,
        ulong seed)
    {
        var hash = seed;
        for (var index = 0; index < count; index++)
        {
            hash = Mix(hash, words[start + index]);
        }
        return hash;
    }

    private static ulong Mix(ulong hash, ulong value) => Shared.CodegenCachePolicy.ChecksumMix(hash, value);

    private static ulong FingerprintMix(ulong hash, ulong value) =>
        Shared.CodegenCachePolicy.FingerprintMix(hash, value);

    private static ulong HashFields(IEnumerable<string> fields)
    {
        var hash = EnvelopeChecksumSeed;
        foreach (var field in fields)
        {
            var bytes = Encoding.UTF8.GetBytes(field);
            hash = FingerprintMix(hash, (ulong)bytes.Length);
            foreach (var value in bytes)
            {
                hash = FingerprintMix(hash, value);
            }
            hash = FingerprintMix(hash, byte.MaxValue);
        }
        return hash;
    }

    private static InvalidOperationException UnexpectedKeyPart(Shared.CodegenKeyPart part) =>
        new("codegen key rule requests an unavailable input: " + part);

    private static ulong HashRule(Shared.CodegenKeyRule rule, Func<Shared.CodegenKeyPart, IEnumerable<string>> resolve) =>
        HashFields(RuleFields(rule, resolve));

    private static IEnumerable<string> RuleFields(Shared.CodegenKeyRule rule, Func<Shared.CodegenKeyPart, IEnumerable<string>> resolve)
    {
        yield return rule.Domain;
        foreach (var field in PartFields(rule, resolve)) yield return field;
    }

    private static IEnumerable<string> PartFields(Shared.CodegenKeyRule rule, Func<Shared.CodegenKeyPart, IEnumerable<string>> resolve)
    {
        foreach (var part in rule.Parts)
            foreach (var field in resolve(part)) yield return field;
    }

    private static ulong HashBinaryFields(IEnumerable<byte[]> fields)
    {
        var hash = EnvelopeChecksumSeed;
        foreach (var field in fields)
        {
            hash = FingerprintMix(hash, (ulong)field.LongLength);
            foreach (var value in field)
            {
                hash = FingerprintMix(hash, value);
            }
            hash = FingerprintMix(hash, byte.MaxValue);
        }
        return hash;
    }

    private static ulong BuildTypeUniverseHash(TypeDefinitionTable types)
    {
        var fields = new List<string> { "type-universe-1" };
        foreach (var definition in types.Structs.OrderBy(static value => (int)value.Id))
        {
            fields.Add($"struct:{(int)definition.Id}:{definition.Name}:{definition.ModuleName}");
            foreach (var field in definition.Fields.OrderBy(static value => value.Index))
            {
                fields.Add($"field:{field.Index}:{field.Name}:{(int)field.Type}");
            }
        }
        foreach (var definition in types.Enums.OrderBy(static value => (int)value.Id))
        {
            fields.Add($"enum:{(int)definition.Id}:{definition.Name}:{definition.ModuleName}:{definition.PayloadWords}");
            foreach (var variant in definition.Variants.OrderBy(static value => value.Tag))
            {
                fields.Add($"variant:{variant.Tag}:{variant.Name}:{(int?)variant.PayloadType ?? -1}");
            }
        }
        foreach (var definition in types.Boxes.OrderBy(static value => (int)value.Id))
        {
            fields.Add($"box:{(int)definition.Id}:{(int)definition.ElementType}:{definition.Size}:{definition.Alignment}");
        }
        foreach (var definition in types.References.OrderBy(static value => (int)value.Id))
        {
            fields.Add($"reference:{(int)definition.Id}:{(int)definition.ElementType}");
        }
        foreach (var definition in types.DynTraits.OrderBy(static value => (int)value.Id))
        {
            fields.Add($"dyn:{(int)definition.Id}:{definition.TraitName}");
        }
        foreach (var definition in types.StaticArrays.OrderBy(static value => (int)value.Id))
        {
            fields.Add(
                $"static-array:{(int)definition.Id}:{(int)definition.ElementType}:"
                + $"{definition.ElementSize}:{definition.ElementAlignment}:{definition.FixedLength}");
        }
        foreach (var definition in types.DynamicArrays.OrderBy(static value => (int)value.Id))
        {
            fields.Add(
                $"dynamic-array:{(int)definition.Id}:{(int)definition.ElementType}:"
                + $"{definition.ElementSize}:{definition.ElementAlignment}");
        }
        foreach (var definition in types.Dictionaries.OrderBy(static value => (int)value.Id))
        {
            fields.Add(
                $"dictionary:{(int)definition.Id}:{(int)definition.KeyType}:{(int)definition.ValueType}:"
                + $"{definition.KeySize}:{definition.KeyAlignment}:{definition.ValueOffset}:"
                + $"{definition.ValueSize}:{definition.ValueAlignment}:{definition.EntryStride}");
        }
        return HashFields(fields);
    }

    private static int CheckedLength(ulong value, long maximum, string description)
    {
        if (value > (ulong)Math.Min(maximum, int.MaxValue))
        {
            throw new InvalidDataException($"artifact {description} length is invalid");
        }
        return (int)value;
    }

    private static void EnsureReadable(int start, int count, int length)
    {
        if (start < 0 || count < 0 || start > length || count > length - start)
        {
            throw new InvalidDataException("artifact record is truncated");
        }
    }

    private static string Hex(ulong value) => value.ToString("x16", CultureInfo.InvariantCulture);

    private static string TargetName(CompilationTarget target)
    {
        var platform = target switch
        {
            CompilationTarget.WindowsX64 => "windows-x64",
            CompilationTarget.LinuxX64 => "linux-x64",
            CompilationTarget.Wasm32Browser => "wasm32-browser",
            _ => throw new ArgumentOutOfRangeException(nameof(target))
        };
        return $"{platform}.{TargetContract.For(target).CacheKey}";
    }

    private static string SanitizeFileName(string value)
    {
        var invalid = System.IO.Path.GetInvalidFileNameChars().ToHashSet();
        return new string(value.Select(character => invalid.Contains(character) ? '_' : character).ToArray());
    }

    private sealed record ModuleIdentity(
        string Identity,
        ulong ImplementationHash,
        ulong InterfaceHash,
        IReadOnlyList<string> Imports,
        bool IsStandardLibrary);

    private sealed record DecodedCodegenCache(
        IReadOnlyDictionary<(LlvmCodegenUnitKind Kind, string Identity, LlvmCodegenKey CacheKey), string> Fragments,
        IReadOnlyList<LlvmCodegenUnit> Units);
}

internal sealed record IncrementalCacheLocation(
    string CodegenPath,
    string SourceSnapshotPath,
    string ProductPath,
    string SemanticPath,
    ulong CompilerHash,
    ulong TargetHash,
    ulong ConfigurationHash);
