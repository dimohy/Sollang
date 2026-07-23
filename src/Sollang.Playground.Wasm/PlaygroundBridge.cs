using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.JSInterop;
using Sollang.Compiler.Browser;

namespace Sollang.Playground.Wasm;

public static class PlaygroundBridge
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    [JSInvokable("CompileAndRun")]
    public static string CompileAndRun(string source) =>
        JsonSerializer.Serialize(BrowserPlaygroundCompiler.CompileAndRun(source), JsonOptions);
}
