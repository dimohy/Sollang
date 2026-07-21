using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Lexing;
using Sollang.Compiler.Parsing;

namespace Sollang.Compiler.Cli;

internal static partial class LanguageServer
{
    private static readonly Dictionary<string, string> Documents = new(StringComparer.Ordinal);

    public static int Run(string[] args)
    {
        if (args.Length != 0)
        {
            throw new SollangException("usage: sollang language-server");
        }

        var input = Console.OpenStandardInput();
        var output = Console.OpenStandardOutput();
        var shutdown = false;
        while (ReadMessage(input) is { } message)
        {
            using (message)
            {
                var root = message.RootElement;
                if (!root.TryGetProperty("method", out var methodElement)) continue;
                var method = methodElement.GetString();
                root.TryGetProperty("id", out var id);
                switch (method)
                {
                    case "initialize":
                        WriteResult(output, id, new
                        {
                            capabilities = new
                            {
                                textDocumentSync = 1,
                                documentFormattingProvider = true
                            },
                            serverInfo = new { name = "sollang", version = "0.1" }
                        });
                        break;
                    case "shutdown":
                        shutdown = true;
                        WriteResult(output, id, result: null);
                        break;
                    case "exit":
                        return shutdown ? 0 : 1;
                    case "textDocument/didOpen":
                    {
                        var document = root.GetProperty("params").GetProperty("textDocument");
                        UpdateDocument(output, document.GetProperty("uri").GetString()!, document.GetProperty("text").GetString()!);
                        break;
                    }
                    case "textDocument/didChange":
                    {
                        var parameters = root.GetProperty("params");
                        var uri = parameters.GetProperty("textDocument").GetProperty("uri").GetString()!;
                        var changes = parameters.GetProperty("contentChanges");
                        if (changes.GetArrayLength() > 0)
                        {
                            UpdateDocument(output, uri, changes[0].GetProperty("text").GetString()!);
                        }
                        break;
                    }
                    case "textDocument/didClose":
                    {
                        var uri = root.GetProperty("params").GetProperty("textDocument").GetProperty("uri").GetString()!;
                        Documents.Remove(uri);
                        PublishDiagnostics(output, uri, []);
                        break;
                    }
                    case "textDocument/formatting":
                    {
                        var uri = root.GetProperty("params").GetProperty("textDocument").GetProperty("uri").GetString()!;
                        if (!Documents.TryGetValue(uri, out var source))
                        {
                            WriteResult(output, id, Array.Empty<object>());
                            break;
                        }
                        try
                        {
                            var formatted = SourceFormatter.Format(source);
                            WriteResult(output, id, FormattingEdits(source, formatted));
                        }
                        catch (SollangException)
                        {
                            WriteResult(output, id, Array.Empty<object>());
                        }
                        break;
                    }
                    default:
                        if (id.ValueKind != JsonValueKind.Undefined)
                        {
                            WriteError(output, id, -32601, $"method not found: {method}");
                        }
                        break;
                }
            }
        }
        return 0;
    }

    private static void UpdateDocument(Stream output, string uri, string text)
    {
        Documents[uri] = text;
        try
        {
            _ = new Parser(new Lexer(text).Lex()).Parse();
            PublishDiagnostics(output, uri, []);
        }
        catch (SollangException exception)
        {
            var match = DiagnosticLocation().Match(exception.Message);
            var line = match.Success ? Math.Max(0, int.Parse(match.Groups[1].Value) - 1) : 0;
            var column = match.Success ? Math.Max(0, int.Parse(match.Groups[2].Value) - 1) : 0;
            PublishDiagnostics(output, uri,
            [
                new
                {
                    range = new
                    {
                        start = new { line, character = column },
                        end = new { line, character = column + 1 }
                    },
                    severity = 1,
                    source = "sollang",
                    message = exception.Message
                }
            ]);
        }
    }

    private static object[] FormattingEdits(string source, string formatted)
    {
        if (string.Equals(source, formatted, StringComparison.Ordinal)) return [];
        var prefix = 0;
        var maximumPrefix = Math.Min(source.Length, formatted.Length);
        while (prefix < maximumPrefix && source[prefix] == formatted[prefix]) prefix++;
        var suffix = 0;
        while (suffix < source.Length - prefix
            && suffix < formatted.Length - prefix
            && source[source.Length - suffix - 1] == formatted[formatted.Length - suffix - 1])
        {
            suffix++;
        }
        return
        [
            new
            {
                range = new
                {
                    start = PositionAt(source, prefix),
                    end = PositionAt(source, source.Length - suffix)
                },
                newText = formatted[prefix..(formatted.Length - suffix)]
            }
        ];
    }

    private static object PositionAt(string source, int offset)
    {
        var line = 0;
        var character = 0;
        for (var index = 0; index < offset; index++)
        {
            var value = source[index];
            if (value == '\n') { line++; character = 0; }
            else character++;
        }
        return new { line, character };
    }

    private static void PublishDiagnostics(Stream output, string uri, object[] diagnostics) =>
        WriteNotification(output, "textDocument/publishDiagnostics", new { uri, diagnostics });

    private static JsonDocument? ReadMessage(Stream input)
    {
        int? contentLength = null;
        while (ReadHeaderLine(input) is { } line)
        {
            if (line.Length == 0) break;
            const string prefix = "Content-Length:";
            if (line.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
                && int.TryParse(line[prefix.Length..].Trim(), out var length))
            {
                contentLength = length;
            }
        }
        if (contentLength is null) return null;
        var payload = new byte[contentLength.Value];
        var offset = 0;
        while (offset < payload.Length)
        {
            var read = input.Read(payload, offset, payload.Length - offset);
            if (read == 0) throw new EndOfStreamException("incomplete LSP message");
            offset += read;
        }
        return JsonDocument.Parse(payload);
    }

    private static string? ReadHeaderLine(Stream input)
    {
        var bytes = new List<byte>();
        while (true)
        {
            var value = input.ReadByte();
            if (value < 0) return bytes.Count == 0 ? null : Encoding.ASCII.GetString(bytes.ToArray());
            if (value == '\n') return Encoding.ASCII.GetString(bytes.ToArray()).TrimEnd('\r');
            bytes.Add((byte)value);
        }
    }

    private static void WriteResult(Stream output, JsonElement id, object? result) =>
        Write(output, new { jsonrpc = "2.0", id = IdValue(id), result });

    private static void WriteError(Stream output, JsonElement id, int code, string message) =>
        Write(output, new { jsonrpc = "2.0", id = IdValue(id), error = new { code, message } });

    private static void WriteNotification(Stream output, string method, object parameters) =>
        Write(output, new { jsonrpc = "2.0", method, @params = parameters });

    private static object? IdValue(JsonElement id) => id.ValueKind switch
    {
        JsonValueKind.Number when id.TryGetInt64(out var value) => value,
        JsonValueKind.String => id.GetString(),
        JsonValueKind.Null => null,
        _ => null
    };

    private static void Write(Stream output, object value)
    {
        var payload = JsonSerializer.SerializeToUtf8Bytes(value);
        var header = Encoding.ASCII.GetBytes($"Content-Length: {payload.Length}\r\n\r\n");
        output.Write(header);
        output.Write(payload);
        output.Flush();
    }

    [GeneratedRegex(@"(?:lex|parse) error at (\d+):(\d+):", RegexOptions.CultureInvariant)]
    private static partial Regex DiagnosticLocation();
}
