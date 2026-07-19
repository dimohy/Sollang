using System.Buffers.Binary;
using System.Security.Cryptography;

namespace Sollang.Compiler.Cli;

internal sealed record IncrementalProductCacheProbe(string Status, bool IsExact);

internal static class IncrementalProductCache
{
    private const ulong Magic = 6002245291165308018;
    private const ulong Schema = 1;
    private const int DigestLength = 32;
    private const int PayloadLength = 5 * sizeof(ulong) + 3 * DigestLength;
    private const int ArtifactLength = PayloadLength + DigestLength;

    public static IncrementalProductCacheProbe Open(
        IncrementalCacheLocation location,
        string outputPath,
        ReadOnlySpan<byte> sourceGenerationKey)
    {
        if (!File.Exists(location.ProductPath))
        {
            return new IncrementalProductCacheProbe("cold", false);
        }
        if (!File.Exists(outputPath))
        {
            return new IncrementalProductCacheProbe("miss: output is missing", false);
        }

        try
        {
            var bytes = File.ReadAllBytes(location.ProductPath);
            if (bytes.Length != ArtifactLength)
            {
                throw new InvalidDataException("product generation length is invalid");
            }
            var payload = bytes.AsSpan(0, PayloadLength);
            var declaredChecksum = bytes.AsSpan(PayloadLength, DigestLength);
            Span<byte> actualChecksum = stackalloc byte[DigestLength];
            SHA256.HashData(payload, actualChecksum);
            if (!CryptographicOperations.FixedTimeEquals(declaredChecksum, actualChecksum))
            {
                throw new InvalidDataException("product generation checksum mismatch");
            }

            var offset = 0;
            if (ReadUInt64(payload, ref offset) != Magic
                || ReadUInt64(payload, ref offset) != Schema)
            {
                throw new InvalidDataException("product generation magic or schema mismatch");
            }
            if (ReadUInt64(payload, ref offset) != location.CompilerHash
                || ReadUInt64(payload, ref offset) != location.TargetHash
                || ReadUInt64(payload, ref offset) != location.ConfigurationHash)
            {
                return new IncrementalProductCacheProbe("miss: build context changed", false);
            }

            var sourceDigest = payload.Slice(offset, DigestLength);
            offset += DigestLength;
            var codegenDigest = payload.Slice(offset, DigestLength);
            offset += DigestLength;
            var productDigest = payload.Slice(offset, DigestLength);
            if (!CryptographicOperations.FixedTimeEquals(sourceDigest, sourceGenerationKey))
            {
                return new IncrementalProductCacheProbe("miss: source generation changed", false);
            }
            if (!MatchesFile(codegenDigest, location.CodegenPath))
            {
                return new IncrementalProductCacheProbe("miss: codegen generation changed", false);
            }
            if (!MatchesFile(productDigest, outputPath))
            {
                return new IncrementalProductCacheProbe("miss: output changed", false);
            }
            return new IncrementalProductCacheProbe("exact hit", true);
        }
        catch (Exception error) when (error is IOException
                                      or InvalidDataException
                                      or CryptographicException)
        {
            return new IncrementalProductCacheProbe("rejected: " + error.Message, false);
        }
    }

    public static void Publish(IncrementalCacheLocation location, string outputPath)
    {
        var directory = Path.GetDirectoryName(location.ProductPath)
            ?? throw new InvalidOperationException("product cache path has no directory");
        Directory.CreateDirectory(directory);
        var payload = new byte[PayloadLength];
        var offset = 0;
        WriteUInt64(payload, ref offset, Magic);
        WriteUInt64(payload, ref offset, Schema);
        WriteUInt64(payload, ref offset, location.CompilerHash);
        WriteUInt64(payload, ref offset, location.TargetHash);
        WriteUInt64(payload, ref offset, location.ConfigurationHash);
        ReadSourceGenerationKey(location.SourceSnapshotPath).CopyTo(payload.AsSpan(offset, DigestLength));
        offset += DigestLength;
        WriteDigest(payload, ref offset, location.CodegenPath);
        WriteDigest(payload, ref offset, outputPath);

        var temporaryPath = location.ProductPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var stream = new FileStream(
                       temporaryPath,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None,
                       bufferSize: 4096,
                       FileOptions.WriteThrough))
            {
                stream.Write(payload);
                stream.Write(SHA256.HashData(payload));
                stream.Flush(flushToDisk: true);
            }
            File.Move(temporaryPath, location.ProductPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    private static bool MatchesFile(ReadOnlySpan<byte> expected, string path)
    {
        if (!File.Exists(path))
        {
            return false;
        }
        using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 64 * 1024,
            FileOptions.SequentialScan);
        Span<byte> actual = stackalloc byte[DigestLength];
        SHA256.HashData(stream, actual);
        return CryptographicOperations.FixedTimeEquals(expected, actual);
    }

    private static byte[] ReadSourceGenerationKey(string path)
    {
        using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 4096,
            FileOptions.RandomAccess);
        if (stream.Length < DigestLength)
        {
            throw new InvalidDataException("source generation is truncated");
        }
        stream.Position = stream.Length - DigestLength;
        var key = new byte[DigestLength];
        stream.ReadExactly(key);
        return key;
    }

    private static ulong ReadUInt64(ReadOnlySpan<byte> payload, ref int offset)
    {
        var value = BinaryPrimitives.ReadUInt64LittleEndian(payload.Slice(offset, sizeof(ulong)));
        offset += sizeof(ulong);
        return value;
    }

    private static void WriteUInt64(Span<byte> payload, ref int offset, ulong value)
    {
        BinaryPrimitives.WriteUInt64LittleEndian(payload.Slice(offset, sizeof(ulong)), value);
        offset += sizeof(ulong);
    }

    private static void WriteDigest(Span<byte> payload, ref int offset, string path)
    {
        using var stream = new FileStream(
            path,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 64 * 1024,
            FileOptions.SequentialScan);
        SHA256.HashData(stream, payload.Slice(offset, DigestLength));
        offset += DigestLength;
    }
}
