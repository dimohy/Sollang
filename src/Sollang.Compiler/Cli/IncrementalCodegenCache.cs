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
    private const ulong EnvelopeChecksumSeed = 7809847782465536322;
    private const ulong FragmentChecksumSeed = 16320118547808316911;
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
            .ToArray();
        for (var index = 1; index < modules.Length; index++)
        {
            if (LlvmCodegenUnit.StableIdentity(modules[index - 1].Identity)
                == LlvmCodegenUnit.StableIdentity(modules[index].Identity))
            {
                throw new InvalidDataException(
                    $"module identity collision between '{modules[index - 1].Identity}' "
                    + $"and '{modules[index].Identity}'");
            }
        }

        var modulesByName = modules.ToDictionary(static module => module.Identity, StringComparer.Ordinal);
        var ambientStandardLibrary = HashFields(modules
            .Where(static module => module.IsStandardLibrary)
            .SelectMany(static module => new[]
            {
                module.Identity,
                Hex(module.InterfaceHash)
            }));
        var emissionHashes = BuildEmissionHashes(boundProgram);
        var moduleKeys = new Dictionary<string, LlvmCodegenKey>(StringComparer.Ordinal);
        foreach (var module in modules)
        {
            var dependencyInterfaces = CollectDependencyInterfaces(module, modulesByName);
            var implementationKey = HashFields([
                "module-implementation",
                module.Identity,
                Hex(module.ImplementationHash),
                Hex(ambientStandardLibrary),
                Hex(emissionHashes.GetValueOrDefault(module.Identity, HashFields([]))),
                .. dependencyInterfaces
            ]);
            moduleKeys[module.Identity] = new LlvmCodegenKey(module.InterfaceHash, implementationKey);
        }
        foreach (var emission in emissionHashes.OrderBy(static pair => pair.Key, StringComparer.Ordinal))
        {
            moduleKeys.TryAdd(
                emission.Key,
                new LlvmCodegenKey(
                    HashFields(["synthetic-interface", emission.Key]),
                    HashFields([
                        "synthetic-implementation",
                        emission.Key,
                        Hex(ambientStandardLibrary),
                        Hex(emission.Value)
                    ])));
        }

        var wholeInterfaceHash = HashFields([
            "whole-interface",
            .. modules.SelectMany(static module => new[]
            {
                module.Identity,
                Hex(module.InterfaceHash)
            })
        ]);
        var wholeImplementationHash = HashFields([
            "whole-implementation",
            .. moduleKeys.OrderBy(static pair => LlvmCodegenUnit.StableIdentity(pair.Key))
                .SelectMany(static pair => new[]
                {
                    pair.Key,
                    Hex(pair.Value.InterfaceHash),
                    Hex(pair.Value.ImplementationHash)
                })
        ]);
        var prefixKey = new LlvmCodegenKey(
            HashFields(["prefix-interface", Hex(wholeInterfaceHash)]),
            HashFields(["prefix-implementation", Hex(wholeImplementationHash)]));
        var suffixKey = new LlvmCodegenKey(
            HashFields(["suffix-interface", Hex(wholeInterfaceHash)]),
            HashFields(["suffix-implementation", Hex(wholeImplementationHash)]));

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
        var configurationName = options.OptimizationLevel ?? "-O0";
        var outputDirectory = System.IO.Path.GetDirectoryName(options.OutputPath)
            ?? Directory.GetCurrentDirectory();
        var cacheDirectory = System.IO.Path.Combine(outputDirectory, ".sollang-cache");
        var outputName = System.IO.Path.GetFileNameWithoutExtension(options.OutputPath);
        var configuration = configurationName.TrimStart('-').ToLowerInvariant();
        var baseName = $"{SanitizeFileName(outputName)}.{targetName}.{configuration}";
        return new IncrementalCacheLocation(
            System.IO.Path.Combine(cacheDirectory, baseName + ".cgu"),
            System.IO.Path.Combine(cacheDirectory, baseName + ".sources"),
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
                if (sawModule && moduleHash <= previousModuleHash)
                {
                    throw new InvalidDataException("codegen module order is not canonical");
                }
                previousModuleHash = moduleHash;
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
        if (words[2] != compilerHash || words[3] != targetHash || words[4] != configurationHash)
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
                        || previousKind == (int)LlvmCodegenUnitKind.Module && moduleHash <= previousModuleHash)
                    {
                        throw new InvalidDataException("artifact module identity or order is invalid");
                    }
                    previousModuleHash = moduleHash;
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
        var ordered = sources.OrderBy(static source => source.Path, StringComparer.OrdinalIgnoreCase).ToArray();
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
            static group => HashFields(group
                .OrderBy(static function => function.Name, StringComparer.Ordinal)
                .SelectMany(FunctionEmissionFields)),
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

    private static IEnumerable<string> FunctionEmissionFields(BoundFunction function)
    {
        yield return "function";
        yield return function.Name;
        yield return ((int?)function.InputType)?.ToString(CultureInfo.InvariantCulture) ?? "-";
        yield return ((int)function.InputOwnership).ToString(CultureInfo.InvariantCulture);
        yield return ((int)function.ReturnType).ToString(CultureInfo.InvariantCulture);
        yield return ((int?)function.BlockInputType)?.ToString(CultureInfo.InvariantCulture) ?? "-";
        yield return ((int?)function.BlockResultType)?.ToString(CultureInfo.InvariantCulture) ?? "-";
        yield return function.IsAsync ? "async" : "sync";
        yield return ((int?)function.SpecializedType)?.ToString(CultureInfo.InvariantCulture) ?? "-";
        yield return ((int?)function.SpecializedSecondaryType)?.ToString(CultureInfo.InvariantCulture) ?? "-";
        yield return ((int?)function.SpecializedTertiaryType)?.ToString(CultureInfo.InvariantCulture) ?? "-";
        yield return function.SpecializedValue?.ToString(CultureInfo.InvariantCulture) ?? "-";
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            yield return parameter.Name;
            yield return ((int)parameter.Type).ToString(CultureInfo.InvariantCulture);
            yield return ((int)parameter.Ownership).ToString(CultureInfo.InvariantCulture);
        }
    }

    private static IEnumerable<string> PublicInterfaceFields(SollangProgram program)
    {
        foreach (var structure in program.Structs.OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            yield return "struct";
            yield return structure.Name;
            yield return structure.DeclaringTypeName ?? "";
            yield return structure.IsPublic ? "public" : "private";
            foreach (var field in structure.Fields)
            {
                yield return field.Name;
                yield return field.TypeName;
            }
        }
        foreach (var enumeration in program.Enums.OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            yield return "enum";
            yield return enumeration.Name;
            yield return enumeration.IsPublic ? "public" : "private";
            foreach (var variant in enumeration.Variants)
            {
                yield return variant.Name;
                yield return variant.PayloadType ?? "";
            }
        }
        foreach (var trait in program.Traits.Where(static value => value.IsPublic)
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            yield return "trait";
            yield return trait.Name;
            foreach (var associated in trait.AssociatedTypes)
            {
                yield return associated.Name;
            }
            foreach (var method in trait.Methods)
            {
                yield return method.Name;
                yield return ((int)method.SelfOwnership).ToString(CultureInfo.InvariantCulture);
                yield return method.ReturnType;
            }
        }
        foreach (var function in program.Functions.Where(static value => value.IsPublic)
                     .OrderBy(static value => value.Name, StringComparer.Ordinal))
        {
            yield return "function";
            yield return function.Name;
            yield return function.InputType ?? "";
            yield return ((int)function.InputOwnership).ToString(CultureInfo.InvariantCulture);
            yield return function.ReturnType;
            yield return function.BlockInputType ?? "";
            yield return function.BlockResultType ?? "";
            yield return function.IsAsync ? "async" : "sync";
            yield return function.GenericParameterName ?? "";
            yield return function.SecondaryGenericParameterName ?? "";
            yield return function.TertiaryGenericParameterName ?? "";
            yield return function.GenericTraitBound ?? "";
            yield return function.GenericAssociatedTypeName ?? "";
            yield return function.GenericAssociatedTypeConstraint ?? "";
            foreach (var effect in (function.Effects ?? []).Order(StringComparer.Ordinal))
            {
                yield return effect;
            }
            foreach (var parameter in function.AdditionalParameters ?? [])
            {
                yield return parameter.Name;
                yield return parameter.TypeName;
                yield return ((int)parameter.Ownership).ToString(CultureInfo.InvariantCulture);
            }
            foreach (var associated in (function.ImplAssociatedTypes ?? new Dictionary<string, string>())
                         .OrderBy(static pair => pair.Key, StringComparer.Ordinal))
            {
                yield return associated.Key;
                yield return associated.Value;
            }
        }
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

    private static ulong Mix(ulong hash, ulong value) => unchecked(
        (hash + 11400714819323198485UL) * (hash + 13787848793156543929UL)
        + (value + 10723151780598845931UL) * (value + 7146057691288625177UL)
        + 1099511628211UL);

    private static ulong FingerprintMix(ulong hash, ulong value) =>
        unchecked(hash * 1099511628211UL + value + 97UL);

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

    private static string TargetName(CompilationTarget target) => target switch
    {
        CompilationTarget.WindowsX64 => "windows-x64",
        CompilationTarget.LinuxX64 => "linux-x64",
        CompilationTarget.Wasm32Browser => "wasm32-browser",
        _ => throw new ArgumentOutOfRangeException(nameof(target))
    };

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
    ulong CompilerHash,
    ulong TargetHash,
    ulong ConfigurationHash);
