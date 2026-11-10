[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LlvmPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$LlvmPath = [System.IO.Path]::GetFullPath($LlvmPath)
if (-not (Test-Path -LiteralPath $LlvmPath -PathType Leaf)) {
    throw "LLVM direct-call closure input is missing: $LlvmPath"
}

$llvm = [System.IO.File]::ReadAllText($LlvmPath)
$functionRecords = [regex]::Matches(
    $llvm,
    '(?m)^(?<kind>define|declare)\s+[^\r\n]*?@(?<symbol>[-a-zA-Z$._0-9]+)\(')
$duplicateFunctions = @($functionRecords |
    Group-Object { $_.Groups['symbol'].Value } |
    Where-Object Count -gt 1 |
    ForEach-Object Name |
    Sort-Object)
if ($duplicateFunctions.Count -gt 0) {
    throw "sollang compiler verification failure V005: emitted LLVM repeats function declarations or definitions: $($duplicateFunctions -join ', '). Emit each target-runtime symbol from one canonical declaration owner; do not wait for llvm-as to report a late redefinition."
}

$defined = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$declaredOrDefined = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$functionRecords |
    ForEach-Object { [void]$declaredOrDefined.Add($_.Groups['symbol'].Value) }
$functionRecords |
    Where-Object {
        $_.Groups['kind'].Value -eq 'define' -and
        $_.Groups['symbol'].Value -match '^sollang_m-?\d+_s-?\d+(?:_g\d+)?$'
    } |
    ForEach-Object { [void]$defined.Add($_.Groups['symbol'].Value) }

$unresolved = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
[regex]::Matches(
    $llvm,
    '(?m)^\s*(?:%[-a-zA-Z$._0-9]+\s*=\s*)?(?:(?:musttail|tail|notail)\s+)?(?:call|invoke)\s+[^\r\n]*?@(?<symbol>(?:sollang_m-?\d+_s-?\d+(?:_g\d+)?|sollang_runtime_[-a-zA-Z$._0-9]+))\(') |
    ForEach-Object {
        $symbol = $_.Groups['symbol'].Value
        $isResolved = if ($symbol.StartsWith('sollang_runtime_', [System.StringComparison]::Ordinal)) {
            $declaredOrDefined.Contains($symbol)
        } else {
            $defined.Contains($symbol)
        }
        if (-not $isResolved) {
            [void]$unresolved.Add($symbol)
        }
    }

if ($unresolved.Count -gt 0) {
    throw "sollang compiler verification failure V004: emitted LLVM contains internal Sollang calls without definitions or runtime calls without declarations: $($unresolved -join ', '). A bodyless runtime intrinsic must lower to its canonical runtime opcode instead of surviving as declare @sollang_m*_s*; keep derived callbacks and user-function emission on the same executable reachability closure, and emit each used sollang_runtime_* helper from its target capability owner."
}

# Generated scalar/value SSA names are stable `%vN` identities. Validate them
# per function so a definition in a different function cannot mask a missing
# local producer, while still allowing ordinary LLVM forward references.
if (-not ('Sollang.Verification.LlvmClosureScanner' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;

namespace Sollang.Verification
{
    // Keep the guard's patterns and per-function ownership rules in one scan.
    // Tight .NET loops avoid a PowerShell callback for every LLVM line/value.
    public static class LlvmClosureScanner
    {
        private const RegexOptions Options = RegexOptions.Compiled;
        private static readonly Regex Bodies = new Regex(@"(?ms)^define\s+[^\r\n]*?@(?<function>[-a-zA-Z$._0-9]+)\((?<parameters>[^\r\n]*)\)\s*[^\r\n]*\{(?<body>.*?)^\}", Options);
        private static readonly Regex Lines = new Regex(@"\r?\n", Options);
        private static readonly Regex Quoted = new Regex("\"(?:\\\\.|[^\"\\\\])*\"", Options);
        private static readonly Regex Comments = new Regex(@";.*$", Options);
        private static readonly Regex Definitions = new Regex(@"(?m)^\s*%(?<name>v\d+)\s*=", Options);
        private static readonly Regex Values = new Regex(@"(?<![-a-zA-Z$._0-9])%(?<name>v\d+)(?![-a-zA-Z$._0-9])", Options);
        private const string NativePattern = @"sollang_native_(?:function_m\d+_s\d+|library_m\d+_a\d+)";
        private static readonly Regex NativeDefinitions = new Regex(@"(?m)^@(?<symbol>" + NativePattern + @")\s*=", Options);
        private static readonly Regex NativeUses = new Regex(@"@(?<symbol>" + NativePattern + @")", Options);

        public static string[] FindUndefinedSsa(string llvm)
        {
            var undefined = new SortedSet<string>(StringComparer.Ordinal);
            foreach (Match function in Bodies.Matches(llvm))
            {
                var lines = Lines.Split(function.Groups["body"].Value);
                for (int index = 0; index < lines.Length; index++)
                    lines[index] = Comments.Replace(Quoted.Replace(lines[index], "\"\""), "");
                string body = string.Join("\n", lines);
                var defined = new HashSet<string>(StringComparer.Ordinal);
                foreach (Match value in Values.Matches(function.Groups["parameters"].Value))
                    defined.Add(value.Groups["name"].Value);
                foreach (Match value in Definitions.Matches(body))
                    defined.Add(value.Groups["name"].Value);
                foreach (Match value in Values.Matches(body))
                {
                    string name = value.Groups["name"].Value;
                    if (!defined.Contains(name))
                        undefined.Add(function.Groups["function"].Value + ":%" + name);
                }
            }
            return new List<string>(undefined).ToArray();
        }

        public static string[] FindUndefinedNativeGlobals(string llvm, string path)
        {
            var defined = new HashSet<string>(StringComparer.Ordinal);
            foreach (Match definition in NativeDefinitions.Matches(llvm))
                defined.Add(definition.Groups["symbol"].Value);
            var undefined = new SortedSet<string>(StringComparer.Ordinal);
            foreach (string line in File.ReadLines(path))
            {
                if (line.TrimStart().StartsWith(";", StringComparison.Ordinal)
                    || line.IndexOf(" c\"", StringComparison.Ordinal) >= 0
                    || line.IndexOf("@sollang_native_", StringComparison.Ordinal) < 0)
                    continue;
                foreach (Match use in NativeUses.Matches(line))
                {
                    string symbol = use.Groups["symbol"].Value;
                    if (!defined.Contains(symbol))
                        undefined.Add(symbol);
                }
            }
            return new List<string>(undefined).ToArray();
        }
    }
}
'@
}
$undefinedSsa = [Sollang.Verification.LlvmClosureScanner]::FindUndefinedSsa($llvm)
if ($undefinedSsa.Count -gt 0) {
    throw "sollang compiler verification failure V004: emitted LLVM uses generated SSA values without definitions in the same function: $($undefinedSsa -join ', '). Materialize each scheduled value in its owning control or callback path before consuming it; do not let another function's same-numbered SSA mask the missing producer."
}

$unresolvedNativeGlobals = [Sollang.Verification.LlvmClosureScanner]::FindUndefinedNativeGlobals($llvm, $LlvmPath)
if ($unresolvedNativeGlobals.Count -gt 0) {
    throw "sollang compiler verification failure V007: emitted LLVM uses native-library state globals without definitions: $($unresolvedNativeGlobals -join ', '). Classify call targets by the exact NativeFunctionDeclaration CST identity, not by the shared bodyless intrinsic flag, and emit every reachable native library/function global before use."
}

Write-Host "[LLVM direct-call closure] PASS $LlvmPath"
