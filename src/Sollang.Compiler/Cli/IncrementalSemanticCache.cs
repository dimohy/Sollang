using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.Cli;

internal sealed class IncrementalSemanticCache
{
    private const ulong Magic = 6002245291165495635;
    private const ulong Schema = 1;
    private const int DigestLength = 32;
    private const int HeaderWords = 7;
    private const int MaximumRecords = 1_000_000;
    private const int MaximumIdentityBytes = 1024 * 1024;
    private const long MaximumArtifactBytes = 1024L * 1024 * 1024;

    private readonly IncrementalCacheLocation _location;
    private readonly string[] _functions;
    private readonly KeyValuePair<string, string>[] _calls;

    private IncrementalSemanticCache(
        IncrementalCacheLocation location,
        string[] functions,
        KeyValuePair<string, string>[] calls,
        string status,
        int mappedFunctions,
        int mappedCalls)
    {
        _location = location;
        _functions = functions;
        _calls = calls;
        Status = status;
        MappedFunctions = mappedFunctions;
        MappedCalls = mappedCalls;
    }

    public string Status { get; }
    public int MappedFunctions { get; }
    public int TotalFunctions => _functions.Length;
    public int MappedCalls { get; }
    public int TotalCalls => _calls.Length;
    public string Path => _location.SemanticPath;

    public static IncrementalSemanticCache Open(
        IncrementalCacheLocation location,
        BoundProgram program)
    {
        var functions = program.StableFunctionIdentities.Values
            .Distinct(StringComparer.Ordinal)
            .Order(StringComparer.Ordinal)
            .ToArray();
        var calls = program.StableCallSiteIdentities
            .Select(pair => new KeyValuePair<string, string>(
                pair.Value,
                program.StableFunctionIdentities[program.ResolvedGenericCalls[pair.Key]]))
            .OrderBy(static pair => pair.Key, StringComparer.Ordinal)
            .ToArray();
        EnsureUniqueCalls(calls);

        if (!File.Exists(location.SemanticPath))
        {
            return new IncrementalSemanticCache(location, functions, calls, "cold", 0, 0);
        }
        try
        {
            var old = Read(location);
            var oldFunctions = old.Functions.ToHashSet(StringComparer.Ordinal);
            var oldCalls = old.Calls.ToDictionary(
                static pair => pair.Key,
                static pair => pair.Value,
                StringComparer.Ordinal);
            var mappedFunctions = functions.Count(oldFunctions.Contains);
            var mappedCalls = calls.Count(pair =>
                oldCalls.TryGetValue(pair.Key, out var target)
                && StringComparer.Ordinal.Equals(target, pair.Value));
            return new IncrementalSemanticCache(
                location,
                functions,
                calls,
                "loaded",
                mappedFunctions,
                mappedCalls);
        }
        catch (SemanticCacheMissException error)
        {
            return new IncrementalSemanticCache(
                location, functions, calls, "miss: " + error.Message, 0, 0);
        }
        catch (Exception error) when (error is IOException
                                      or InvalidDataException
                                      or DecoderFallbackException
                                      or CryptographicException)
        {
            return new IncrementalSemanticCache(
                location, functions, calls, "rejected: " + error.Message, 0, 0);
        }
    }

    public void Publish()
    {
        var directory = System.IO.Path.GetDirectoryName(_location.SemanticPath)
            ?? throw new InvalidOperationException("semantic cache path has no directory");
        Directory.CreateDirectory(directory);
        var temporaryPath = _location.SemanticPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var stream = new FileStream(
                       temporaryPath,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None,
                       bufferSize: 64 * 1024,
                       FileOptions.WriteThrough))
            using (var checksum = IncrementalHash.CreateHash(HashAlgorithmName.SHA256))
            {
                WriteUInt64(stream, checksum, Magic);
                WriteUInt64(stream, checksum, Schema);
                WriteUInt64(stream, checksum, _location.CompilerHash);
                WriteUInt64(stream, checksum, _location.TargetHash);
                WriteUInt64(stream, checksum, _location.ConfigurationHash);
                WriteUInt64(stream, checksum, checked((ulong)_functions.Length));
                WriteUInt64(stream, checksum, checked((ulong)_calls.Length));
                foreach (var function in _functions)
                {
                    WriteString(stream, checksum, function);
                }
                foreach (var call in _calls)
                {
                    WriteString(stream, checksum, call.Key);
                    WriteString(stream, checksum, call.Value);
                }
                stream.Write(checksum.GetHashAndReset());
                stream.Flush(flushToDisk: true);
            }
            File.Move(temporaryPath, _location.SemanticPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    private static DecodedSemanticCache Read(IncrementalCacheLocation location)
    {
        var length = new FileInfo(location.SemanticPath).Length;
        if (length < HeaderWords * sizeof(ulong) + DigestLength
            || length > MaximumArtifactBytes)
        {
            throw new InvalidDataException("semantic generation length is invalid");
        }
        using var stream = new FileStream(
            location.SemanticPath,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 64 * 1024,
            FileOptions.SequentialScan);
        using var checksum = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        if (ReadUInt64(stream, checksum) != Magic || ReadUInt64(stream, checksum) != Schema)
        {
            throw new InvalidDataException("semantic generation magic or schema mismatch");
        }
        if (ReadUInt64(stream, checksum) != location.CompilerHash
            || ReadUInt64(stream, checksum) != location.TargetHash
            || ReadUInt64(stream, checksum) != location.ConfigurationHash)
        {
            throw new SemanticCacheMissException("compiler, target, or configuration changed");
        }
        var functionCount = CheckedCount(ReadUInt64(stream, checksum));
        var callCount = CheckedCount(ReadUInt64(stream, checksum));
        var functions = new string[functionCount];
        string? previous = null;
        for (var index = 0; index < functionCount; index++)
        {
            var identity = ReadString(stream, checksum);
            if (previous is not null && StringComparer.Ordinal.Compare(previous, identity) >= 0)
            {
                throw new InvalidDataException("semantic function identities are not canonical");
            }
            functions[index] = identity;
            previous = identity;
        }
        var calls = new KeyValuePair<string, string>[callCount];
        previous = null;
        for (var index = 0; index < callCount; index++)
        {
            var identity = ReadString(stream, checksum);
            var target = ReadString(stream, checksum);
            if (previous is not null && StringComparer.Ordinal.Compare(previous, identity) >= 0)
            {
                throw new InvalidDataException("semantic call-site identities are not canonical");
            }
            calls[index] = new KeyValuePair<string, string>(identity, target);
            previous = identity;
        }
        if (stream.Position != length - DigestLength)
        {
            throw new InvalidDataException("semantic generation declared lengths do not reach the checksum");
        }
        Span<byte> declared = stackalloc byte[DigestLength];
        stream.ReadExactly(declared);
        if (!CryptographicOperations.FixedTimeEquals(checksum.GetHashAndReset(), declared))
        {
            throw new InvalidDataException("semantic generation checksum mismatch");
        }
        return new DecodedSemanticCache(functions, calls);
    }

    private static void EnsureUniqueCalls(IReadOnlyList<KeyValuePair<string, string>> calls)
    {
        for (var index = 1; index < calls.Count; index++)
        {
            if (StringComparer.Ordinal.Equals(calls[index - 1].Key, calls[index].Key))
            {
                throw new InvalidOperationException(
                    $"stable semantic call-site identity collision: {calls[index].Key}");
            }
        }
    }

    private static int CheckedCount(ulong value)
    {
        if (value > MaximumRecords)
        {
            throw new InvalidDataException("semantic generation record count is invalid");
        }
        return (int)value;
    }

    private static void WriteString(Stream stream, IncrementalHash checksum, string value)
    {
        var bytes = Encoding.UTF8.GetBytes(value);
        if (bytes.Length > MaximumIdentityBytes)
        {
            throw new InvalidDataException("semantic identity is too large");
        }
        WriteUInt64(stream, checksum, checked((ulong)bytes.Length));
        stream.Write(bytes);
        checksum.AppendData(bytes);
    }

    private static string ReadString(Stream stream, IncrementalHash checksum)
    {
        var length = ReadUInt64(stream, checksum);
        if (length > MaximumIdentityBytes)
        {
            throw new InvalidDataException("semantic identity length is invalid");
        }
        var bytes = new byte[(int)length];
        stream.ReadExactly(bytes);
        checksum.AppendData(bytes);
        return new UTF8Encoding(false, true).GetString(bytes);
    }

    private static void WriteUInt64(Stream stream, IncrementalHash checksum, ulong value)
    {
        Span<byte> bytes = stackalloc byte[sizeof(ulong)];
        BinaryPrimitives.WriteUInt64LittleEndian(bytes, value);
        stream.Write(bytes);
        checksum.AppendData(bytes);
    }

    private static ulong ReadUInt64(Stream stream, IncrementalHash checksum)
    {
        Span<byte> bytes = stackalloc byte[sizeof(ulong)];
        stream.ReadExactly(bytes);
        checksum.AppendData(bytes);
        return BinaryPrimitives.ReadUInt64LittleEndian(bytes);
    }

    private sealed record DecodedSemanticCache(
        IReadOnlyList<string> Functions,
        IReadOnlyList<KeyValuePair<string, string>> Calls);

    private sealed class SemanticCacheMissException(string message) : Exception(message);
}
