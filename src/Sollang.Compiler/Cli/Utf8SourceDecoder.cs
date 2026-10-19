using System.Buffers;
using System.Text;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Cli;

internal static class Utf8SourceDecoder
{
    private static readonly UTF8Encoding StrictUtf8 = new(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true);

    public static string Decode(byte[] sourceBytes)
    {
        var offset = sourceBytes.Length >= 3
            && sourceBytes[0] == 0xEF
            && sourceBytes[1] == 0xBB
            && sourceBytes[2] == 0xBF
            ? 3
            : 0;
        try
        {
            return StrictUtf8.GetString(sourceBytes.AsSpan(offset));
        }
        catch (DecoderFallbackException)
        {
            var (line, column) = FirstInvalidLocation(sourceBytes.AsSpan(offset));
            throw new SollangException($"lex error at {line}:{column}: unexpected character '\uFFFD'");
        }
    }

    private static (int Line, int Column) FirstInvalidLocation(ReadOnlySpan<byte> sourceBytes)
    {
        var line = 1;
        var column = 1;
        for (var index = 0; index < sourceBytes.Length;)
        {
            var status = Rune.DecodeFromUtf8(sourceBytes[index..], out var scalar, out var consumed);
            if (status != OperationStatus.Done)
            {
                return (line, column);
            }
            if (scalar.Value == '\r')
            {
                line++;
                column = 1;
                index += consumed;
                if (index < sourceBytes.Length && sourceBytes[index] == (byte)'\n')
                {
                    index++;
                }
                continue;
            }
            if (scalar.Value == '\n')
            {
                line++;
                column = 1;
            }
            else
            {
                column += scalar.Utf16SequenceLength;
            }
            index += consumed;
        }
        return (line, column);
    }
}
