using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using Sollang.Compiler.CodeGen;

namespace Sollang.Compiler.Cli;

internal sealed record IncrementalFrontendCacheProbe(
    IncrementalCacheLocation Location,
    string Status,
    int SourceCount,
    LlvmCodegenOutput? Output,
    byte[]? SourceGenerationKey);

internal static class IncrementalFrontendCache
{
    private const ulong Magic = 6002245291164258120;
    private const ulong Schema = 1;
    private const int DigestLength = 32;
    private const int MaximumRecordCount = 1_000_000;
    private const int MaximumPathBytes = 1024 * 1024;
    private const long MaximumContentBytes = 1024L * 1024 * 1024;
    private const byte RootKind = 0;
    private const byte ManifestKind = 1;
    private const byte StandardLibraryKind = 2;
    private const byte UserSourceKind = 3;

    private static readonly StringComparer PathComparer = OperatingSystem.IsWindows()
        ? StringComparer.OrdinalIgnoreCase
        : StringComparer.Ordinal;

    public static IncrementalFrontendCacheProbe Open(CliOptions options)
    {
        var location = IncrementalCodegenCache.Locate(options);
        if (!File.Exists(location.SourceSnapshotPath))
        {
            return new IncrementalFrontendCacheProbe(location, "cold", 0, null, null);
        }
        if (!File.Exists(location.CodegenPath))
        {
            return new IncrementalFrontendCacheProbe(location, "miss: codegen generation is missing", 0, null, null);
        }

        try
        {
            var validated = ValidateSnapshot(location, options);
            var codegenDigest = ComputeFileSha256(location.CodegenPath);
            if (!CryptographicOperations.FixedTimeEquals(validated.CodegenDigest, codegenDigest))
            {
                throw new InvalidDataException("codegen generation does not match the source snapshot");
            }
            var output = IncrementalCodegenCache.ReadExact(location);
            return new IncrementalFrontendCacheProbe(
                location,
                "exact hit",
                validated.SourceCount,
                output,
                validated.SourceGenerationKey);
        }
        catch (FrontendCacheMissException error)
        {
            return new IncrementalFrontendCacheProbe(location, "miss: " + error.Message, 0, null, null);
        }
        catch (Exception error) when (error is IOException
                                      or InvalidDataException
                                      or DecoderFallbackException
                                      or CryptographicException)
        {
            return new IncrementalFrontendCacheProbe(location, "rejected: " + error.Message, 0, null, null);
        }
    }

    public static void Publish(
        LoadedCompilation compilation,
        CliOptions options,
        IncrementalCacheLocation location)
    {
        var directory = Path.GetDirectoryName(location.SourceSnapshotPath)
            ?? throw new InvalidOperationException("frontend cache path has no directory");
        Directory.CreateDirectory(directory);
        var temporaryPath = location.SourceSnapshotPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
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
                var roots = options.SourcePaths.Select(Path.GetFullPath).ToArray();
                var manifests = ManifestPaths(options).ToArray();
                var sources = compilation.Sources
                    .OrderByDescending(static source => source.IsStandardLibrary)
                    .ThenBy(static source => source.Path, PathComparer)
                    .ToArray();
                WriteUInt64(stream, checksum, Magic);
                WriteUInt64(stream, checksum, Schema);
                WriteUInt64(stream, checksum, location.CompilerHash);
                WriteUInt64(stream, checksum, location.TargetHash);
                WriteUInt64(stream, checksum, location.ConfigurationHash);
                WriteBytes(stream, checksum, ComputeFileSha256(location.CodegenPath));
                WriteUInt64(stream, checksum, checked((ulong)roots.Length));
                WriteUInt64(stream, checksum, checked((ulong)manifests.Length));
                WriteUInt64(stream, checksum, checked((ulong)sources.Length));
                WriteUInt64(
                    stream,
                    checksum,
                    checked((ulong)sources.Count(static source => source.IsStandardLibrary)));

                foreach (var root in roots)
                {
                    WriteRecord(stream, checksum, RootKind, root, []);
                }
                foreach (var manifest in manifests)
                {
                    WriteRecord(stream, checksum, ManifestKind, manifest, File.ReadAllBytes(manifest));
                }
                foreach (var source in sources)
                {
                    WriteRecord(
                        stream,
                        checksum,
                        source.IsStandardLibrary ? StandardLibraryKind : UserSourceKind,
                        Path.GetFullPath(source.Path),
                        source.SourceBytes);
                }

                stream.Write(checksum.GetHashAndReset());
                stream.Flush(flushToDisk: true);
            }
            File.Move(temporaryPath, location.SourceSnapshotPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    private static ValidatedSnapshot ValidateSnapshot(IncrementalCacheLocation location, CliOptions options)
    {
        var fileLength = new FileInfo(location.SourceSnapshotPath).Length;
        if (fileLength < 9 * sizeof(ulong) + 2 * DigestLength)
        {
            throw new InvalidDataException("source snapshot is truncated");
        }
        using var stream = new FileStream(
            location.SourceSnapshotPath,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 64 * 1024,
            FileOptions.SequentialScan);
        using var checksum = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        if (ReadUInt64(stream, checksum) != Magic)
        {
            throw new InvalidDataException("source snapshot magic mismatch");
        }
        if (ReadUInt64(stream, checksum) != Schema)
        {
            throw new InvalidDataException("source snapshot schema mismatch");
        }
        if (ReadUInt64(stream, checksum) != location.CompilerHash
            || ReadUInt64(stream, checksum) != location.TargetHash
            || ReadUInt64(stream, checksum) != location.ConfigurationHash)
        {
            throw new FrontendCacheMissException("compiler, target, or configuration changed");
        }
        var codegenDigest = new byte[DigestLength];
        ReadBytes(stream, checksum, codegenDigest);

        var rootCount = CheckedCount(ReadUInt64(stream, checksum), "root");
        var manifestCount = CheckedCount(ReadUInt64(stream, checksum), "manifest");
        var sourceCount = CheckedCount(ReadUInt64(stream, checksum), "source");
        var standardLibraryCount = CheckedCount(ReadUInt64(stream, checksum), "standard-library source");
        if (standardLibraryCount > sourceCount)
        {
            throw new InvalidDataException("source snapshot standard-library count is invalid");
        }

        var roots = options.SourcePaths.Select(Path.GetFullPath).ToArray();
        if (roots.Length != rootCount)
        {
            throw new FrontendCacheMissException("root source set changed");
        }
        var manifests = ManifestPaths(options).ToArray();
        if (manifests.Length != manifestCount)
        {
            throw new FrontendCacheMissException("project manifest set changed");
        }
        var currentStandardLibrary = CompilerApp.DiscoverStandardLibraryPaths(options.SourcePaths[0]);
        if (currentStandardLibrary.Count != standardLibraryCount)
        {
            throw new FrontendCacheMissException("standard-library source set changed");
        }

        var seenPaths = new HashSet<string>(PathComparer);
        for (var index = 0; index < rootCount; index++)
        {
            var record = ReadRecordHeader(stream, checksum, RootKind);
            if (record.ContentLength != 0 || !PathComparer.Equals(record.Path, roots[index]))
            {
                throw new FrontendCacheMissException("root source set changed");
            }
        }
        for (var index = 0; index < manifestCount; index++)
        {
            var record = ReadRecordHeader(stream, checksum, ManifestKind);
            if (!PathComparer.Equals(record.Path, manifests[index]))
            {
                throw new FrontendCacheMissException("project manifest set changed");
            }
            CompareContent(stream, checksum, record, "project manifest");
        }

        var standardLibraryIndex = 0;
        var cachedUserPaths = new HashSet<string>(PathComparer);
        for (var index = 0; index < sourceCount; index++)
        {
            var kind = ReadByte(stream, checksum);
            if (kind is not StandardLibraryKind and not UserSourceKind)
            {
                throw new InvalidDataException("source snapshot record kind is invalid");
            }
            var record = ReadRecordHeaderAfterKind(stream, checksum, kind);
            if (!seenPaths.Add(record.Path))
            {
                throw new InvalidDataException("source snapshot contains a duplicate source path");
            }
            if (kind == StandardLibraryKind)
            {
                if (standardLibraryIndex >= currentStandardLibrary.Count
                    || !PathComparer.Equals(record.Path, currentStandardLibrary[standardLibraryIndex]))
                {
                    throw new FrontendCacheMissException("standard-library source set changed");
                }
                standardLibraryIndex++;
            }
            else
            {
                cachedUserPaths.Add(record.Path);
            }
            CompareContent(stream, checksum, record, kind == StandardLibraryKind ? "standard-library source" : "source");
        }
        if (standardLibraryIndex != currentStandardLibrary.Count
            || roots.Any(root => !cachedUserPaths.Contains(root)))
        {
            throw new FrontendCacheMissException("source set changed");
        }

        if (stream.Position != fileLength - DigestLength)
        {
            throw new InvalidDataException("source snapshot declared lengths do not reach the checksum");
        }
        Span<byte> declaredDigest = stackalloc byte[DigestLength];
        stream.ReadExactly(declaredDigest);
        if (stream.Position != fileLength
            || !CryptographicOperations.FixedTimeEquals(checksum.GetHashAndReset(), declaredDigest))
        {
            throw new InvalidDataException("source snapshot checksum mismatch");
        }
        return new ValidatedSnapshot(sourceCount, codegenDigest, declaredDigest.ToArray());
    }

    private static IEnumerable<string> ManifestPaths(CliOptions options)
    {
        if (options.Project is null)
        {
            return [];
        }
        var projectManifests = options.Project.Packages
            .Select(static package => Path.GetFullPath(package.Manifest.Path))
            .ToList();
        if (options.Project.Workspace is not null)
        {
            projectManifests.Add(Path.GetFullPath(options.Project.Workspace.Path));
        }
        return projectManifests.Order(PathComparer);
    }

    private static void WriteRecord(
        Stream stream,
        IncrementalHash checksum,
        byte kind,
        string path,
        ReadOnlySpan<byte> content)
    {
        var pathBytes = Encoding.UTF8.GetBytes(Path.GetFullPath(path));
        if (pathBytes.Length > MaximumPathBytes || content.Length > MaximumContentBytes)
        {
            throw new InvalidDataException("source snapshot record is too large");
        }
        WriteByte(stream, checksum, kind);
        WriteUInt64(stream, checksum, checked((ulong)pathBytes.Length));
        WriteUInt64(stream, checksum, checked((ulong)content.Length));
        WriteBytes(stream, checksum, pathBytes);
        WriteBytes(stream, checksum, content);
    }

    private static SnapshotRecord ReadRecordHeader(
        Stream stream,
        IncrementalHash checksum,
        byte expectedKind)
    {
        var kind = ReadByte(stream, checksum);
        if (kind != expectedKind)
        {
            throw new InvalidDataException("source snapshot record order is invalid");
        }
        return ReadRecordHeaderAfterKind(stream, checksum, kind);
    }

    private static SnapshotRecord ReadRecordHeaderAfterKind(
        Stream stream,
        IncrementalHash checksum,
        byte kind)
    {
        var pathLength = CheckedLength(ReadUInt64(stream, checksum), MaximumPathBytes, "path");
        var contentLength = CheckedLength(ReadUInt64(stream, checksum), MaximumContentBytes, "content");
        var pathBytes = new byte[pathLength];
        ReadBytes(stream, checksum, pathBytes);
        var path = Path.GetFullPath(new UTF8Encoding(false, true).GetString(pathBytes));
        return new SnapshotRecord(kind, path, contentLength);
    }

    private static void CompareContent(
        Stream snapshot,
        IncrementalHash checksum,
        SnapshotRecord record,
        string description)
    {
        if (!File.Exists(record.Path))
        {
            throw new FrontendCacheMissException($"{description} is missing: {record.Path}");
        }
        using var current = new FileStream(
            record.Path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 64 * 1024,
            FileOptions.SequentialScan);
        if (current.Length != record.ContentLength)
        {
            throw new FrontendCacheMissException($"{description} changed: {record.Path}");
        }
        var snapshotBuffer = new byte[64 * 1024];
        var currentBuffer = new byte[snapshotBuffer.Length];
        var remaining = record.ContentLength;
        while (remaining > 0)
        {
            var count = (int)Math.Min(snapshotBuffer.Length, remaining);
            snapshot.ReadExactly(snapshotBuffer.AsSpan(0, count));
            checksum.AppendData(snapshotBuffer, 0, count);
            current.ReadExactly(currentBuffer.AsSpan(0, count));
            if (!snapshotBuffer.AsSpan(0, count).SequenceEqual(currentBuffer.AsSpan(0, count)))
            {
                throw new FrontendCacheMissException($"{description} changed: {record.Path}");
            }
            remaining -= count;
        }
    }

    private static int CheckedCount(ulong value, string description)
    {
        if (value > MaximumRecordCount)
        {
            throw new InvalidDataException($"source snapshot {description} count is invalid");
        }
        return (int)value;
    }

    private static int CheckedLength(ulong value, long maximum, string description)
    {
        if (value > (ulong)Math.Min(maximum, int.MaxValue))
        {
            throw new InvalidDataException($"source snapshot {description} length is invalid");
        }
        return (int)value;
    }

    private static void WriteUInt64(Stream stream, IncrementalHash checksum, ulong value)
    {
        Span<byte> bytes = stackalloc byte[sizeof(ulong)];
        BinaryPrimitives.WriteUInt64LittleEndian(bytes, value);
        WriteBytes(stream, checksum, bytes);
    }

    private static ulong ReadUInt64(Stream stream, IncrementalHash checksum)
    {
        Span<byte> bytes = stackalloc byte[sizeof(ulong)];
        ReadBytes(stream, checksum, bytes);
        return BinaryPrimitives.ReadUInt64LittleEndian(bytes);
    }

    private static void WriteByte(Stream stream, IncrementalHash checksum, byte value)
    {
        Span<byte> bytes = stackalloc byte[1] { value };
        WriteBytes(stream, checksum, bytes);
    }

    private static byte ReadByte(Stream stream, IncrementalHash checksum)
    {
        Span<byte> bytes = stackalloc byte[1];
        ReadBytes(stream, checksum, bytes);
        return bytes[0];
    }

    private static void WriteBytes(Stream stream, IncrementalHash checksum, ReadOnlySpan<byte> bytes)
    {
        stream.Write(bytes);
        checksum.AppendData(bytes);
    }

    private static void ReadBytes(Stream stream, IncrementalHash checksum, Span<byte> bytes)
    {
        stream.ReadExactly(bytes);
        checksum.AppendData(bytes);
    }

    private static byte[] ComputeFileSha256(string path)
    {
        using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 64 * 1024,
            FileOptions.SequentialScan);
        return SHA256.HashData(stream);
    }

    private sealed record SnapshotRecord(byte Kind, string Path, int ContentLength);

    private sealed record ValidatedSnapshot(
        int SourceCount,
        byte[] CodegenDigest,
        byte[] SourceGenerationKey);

    private sealed class FrontendCacheMissException(string message) : Exception(message);
}
