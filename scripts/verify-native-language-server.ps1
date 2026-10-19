param(
    [string]$ManagedCompiler = "",
    [string]$NativeCompiler = "",
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [string]$Distribution = "Ubuntu",
    [string]$FocusedContract = "",
    [string]$JsonAdmissionContract = "",
    [ValidateSet("paired", "managed", "native")]
    [string]$CompilerMode = "paired"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ManagedCompiler)) {
    $ManagedCompiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($NativeCompiler)) {
    $NativeCompiler = Join-Path $repoRoot "artifacts\lsp-debug.exe"
}

$ManagedCompiler = (Resolve-Path $ManagedCompiler).Path
$NativeCompiler = (Resolve-Path $NativeCompiler).Path
$utf8 = [Text.UTF8Encoding]::new($false)
$managedVersion = (& dotnet $ManagedCompiler --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $managedVersion -notmatch '^Sollang (?<version>\d+\.\d+\.\d+)$') {
    throw "managed compiler version contract is unavailable"
}
$expectedVersion = $Matches["version"]

function Convert-ToWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Start-LanguageServer {
    param([bool]$Native)

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    if ($Native) {
        if ($Target -eq "linux-x64") {
            $startInfo.FileName = "wsl.exe"
            $startInfo.ArgumentList.Add("-d")
            $startInfo.ArgumentList.Add($Distribution)
            $startInfo.ArgumentList.Add("--")
            $startInfo.ArgumentList.Add((Convert-ToWslPath $NativeCompiler))
        }
        else {
            $startInfo.FileName = $NativeCompiler
        }
    }
    else {
        $startInfo.FileName = "dotnet"
        $startInfo.ArgumentList.Add($ManagedCompiler)
    }
    $startInfo.ArgumentList.Add("language-server")
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    [Diagnostics.Process]::Start($startInfo)
}

function Invoke-LanguageServerArgumentFailure {
    param([bool]$Native)

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    if ($Native) {
        if ($Target -eq "linux-x64") {
            $startInfo.FileName = "wsl.exe"
            $startInfo.ArgumentList.Add("-d")
            $startInfo.ArgumentList.Add($Distribution)
            $startInfo.ArgumentList.Add("--")
            $startInfo.ArgumentList.Add((Convert-ToWslPath $NativeCompiler))
        }
        else {
            $startInfo.FileName = $NativeCompiler
        }
    }
    else {
        $startInfo.FileName = "dotnet"
        $startInfo.ArgumentList.Add($ManagedCompiler)
    }
    $startInfo.ArgumentList.Add("language-server")
    $startInfo.ArgumentList.Add("unexpected")
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output = ($stdout + $stderr).Trim()
    }
}

function ConvertTo-LspFrame {
    param([string]$Body)

    $payload = $utf8.GetBytes($Body)
    $header = $utf8.GetBytes("Content-Length: $($payload.Length)`r`n`r`n")
    $frame = [byte[]]::new($header.Length + $payload.Length)
    [Array]::Copy($header, 0, $frame, 0, $header.Length)
    [Array]::Copy($payload, 0, $frame, $header.Length, $payload.Length)
    $frame
}

function Write-Fragmented {
    param(
        [IO.Stream]$Stream,
        [byte[]]$Bytes
    )

    $sizes = 1, 2, 3, 5, 8, 13
    $offset = 0
    $sizeIndex = 0
    while ($offset -lt $Bytes.Length) {
        $count = [Math]::Min($sizes[$sizeIndex % $sizes.Length], $Bytes.Length - $offset)
        $Stream.Write($Bytes, $offset, $count)
        $Stream.Flush()
        $offset += $count
        $sizeIndex++
    }
}

function Read-Exact {
    param(
        [IO.Stream]$Stream,
        [int]$Count,
        [Threading.CancellationToken]$CancellationToken
    )

    $bytes = [byte[]]::new($Count)
    $offset = 0
    while ($offset -lt $Count) {
        $read = $Stream.ReadAsync(
            $bytes,
            $offset,
            $Count - $offset,
            $CancellationToken).GetAwaiter().GetResult()
        if ($read -eq 0) {
            throw "unexpected EOF while reading an LSP frame"
        }
        $offset += $read
    }
    $bytes
}

function Read-LiveFrame {
    param(
        [IO.Stream]$Stream,
        [int]$TimeoutMilliseconds = 5000
    )

    $cancellation = [Threading.CancellationTokenSource]::new($TimeoutMilliseconds)
    try {
        $headerBytes = [Collections.Generic.List[byte]]::new()
        while ($true) {
            $next = Read-Exact $Stream 1 $cancellation.Token
            $headerBytes.Add($next[0])
            $count = $headerBytes.Count
            if ($count -ge 4 -and $headerBytes[$count - 4] -eq 13 -and $headerBytes[$count - 3] -eq 10 -and $headerBytes[$count - 2] -eq 13 -and $headerBytes[$count - 1] -eq 10) {
                break
            }
        }
        $header = [Text.Encoding]::ASCII.GetString($headerBytes.ToArray())
        $match = [regex]::Match($header, "(?im)^Content-Length:\s*(\d+)\s*$")
        if (-not $match.Success) {
            throw "LSP response omitted Content-Length"
        }
        $length = [int]$match.Groups[1].Value
        $payload = Read-Exact $Stream $length $cancellation.Token
        $utf8.GetString($payload)
    }
    finally {
        $cancellation.Dispose()
    }
}

function Read-AllFrames {
    param([byte[]]$Bytes)

    $frames = [Collections.Generic.List[string]]::new()
    $offset = 0
    while ($offset -lt $Bytes.Length) {
        $headerEnd = -1
        for ($index = $offset; $index + 3 -lt $Bytes.Length; $index++) {
            if ($Bytes[$index] -eq 13 -and $Bytes[$index + 1] -eq 10 -and $Bytes[$index + 2] -eq 13 -and $Bytes[$index + 3] -eq 10) {
                $headerEnd = $index
                break
            }
        }
        if ($headerEnd -lt 0) {
            throw "truncated LSP response header at byte $offset"
        }
        $header = [Text.Encoding]::ASCII.GetString($Bytes, $offset, $headerEnd - $offset)
        $match = [regex]::Match($header, "(?im)^Content-Length:\s*(\d+)\s*$")
        if (-not $match.Success) {
            throw "LSP response omitted Content-Length at byte $offset"
        }
        $length = [int]$match.Groups[1].Value
        $payloadStart = $headerEnd + 4
        if ($payloadStart + $length -gt $Bytes.Length) {
            throw "truncated LSP response payload at byte $payloadStart"
        }
        $frames.Add($utf8.GetString($Bytes, $payloadStart, $length))
        $offset = $payloadStart + $length
    }
    $frames.ToArray()
}

function Assert-StreamingInitialize {
    param([bool]$Native)

    $process = Start-LanguageServer $Native
    try {
        $initialize = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
        Write-Fragmented $process.StandardInput.BaseStream (ConvertTo-LspFrame $initialize)
        $body = Read-LiveFrame $process.StandardOutput.BaseStream
        $json = [Text.Json.Nodes.JsonNode]::Parse($body)
        if ($json["id"].GetValue[int]() -ne 1 -or $json["result"]["serverInfo"]["version"].GetValue[string]() -ne $expectedVersion) {
            throw "initialize response did not match the $expectedVersion contract"
        }

        Write-Fragmented $process.StandardInput.BaseStream (
            ConvertTo-LspFrame '{"jsonrpc":"2.0","id":2,"method":"shutdown","params":null}')
        Write-Fragmented $process.StandardInput.BaseStream (
            ConvertTo-LspFrame '{"jsonrpc":"2.0","method":"exit"}')
        $process.StandardInput.Close()
        $remaining = [IO.MemoryStream]::new()
        $process.StandardOutput.BaseStream.CopyTo($remaining)
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "streaming language server exited with $($process.ExitCode): $($process.StandardError.ReadToEnd())"
        }
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill($true)
        }
        $process.Dispose()
    }
}

function Invoke-FullSession {
    param([bool]$Native)

    $uri = "file:///한글-😀.slg"
    $messages = @(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}',
        (@{
            jsonrpc = "2.0"
            method = "textDocument/didOpen"
            params = @{ textDocument = @{ uri = $uri; languageId = "sollang"; version = 1; text = 'main { "ok" -> println }' } }
        } | ConvertTo-Json -Compress -Depth 8),
        (@{
            jsonrpc = "2.0"
            method = "textDocument/didChange"
            params = @{ textDocument = @{ uri = $uri; version = 2 }; contentChanges = @(@{ text = 'main { "😀" @ }' }) }
        } | ConvertTo-Json -Compress -Depth 8),
        (@{
            jsonrpc = "2.0"
            method = "textDocument/didChange"
            params = @{ textDocument = @{ uri = $uri; version = 3 }; contentChanges = @(@{ text = 'main{"ok"->println}' }) }
        } | ConvertTo-Json -Compress -Depth 8),
        (@{
            jsonrpc = "2.0"
            id = "fmt"
            method = "textDocument/formatting"
            params = @{ textDocument = @{ uri = $uri }; options = @{ tabSize = 4; insertSpaces = $true } }
        } | ConvertTo-Json -Compress -Depth 8),
        '{"jsonrpc":"2.0","id":7,"method":"sollang/unknown","params":{}}',
        (@{
            jsonrpc = "2.0"
            method = "textDocument/didClose"
            params = @{ textDocument = @{ uri = $uri } }
        } | ConvertTo-Json -Compress -Depth 8),
        '{"jsonrpc":"2.0","id":2,"method":"shutdown","params":null}',
        '{"jsonrpc":"2.0","method":"exit"}'
    )

    $process = Start-LanguageServer $Native
    try {
        foreach ($message in $messages) {
            Write-Fragmented $process.StandardInput.BaseStream (ConvertTo-LspFrame $message)
        }
        $process.StandardInput.Close()
        $stdout = [IO.MemoryStream]::new()
        $process.StandardOutput.BaseStream.CopyTo($stdout)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "language server exited with $($process.ExitCode): $stderr"
        }
        Read-AllFrames $stdout.ToArray()
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill($true)
        }
        $process.Dispose()
    }
}

function Invoke-RawSession {
    param(
        [bool]$Native,
        [byte[]]$InputBytes
    )

    $process = Start-LanguageServer $Native
    try {
        if ($InputBytes.Length -gt 0) {
            Write-Fragmented $process.StandardInput.BaseStream $InputBytes
        }
        $process.StandardInput.Close()
        $stdout = [IO.MemoryStream]::new()
        $process.StandardOutput.BaseStream.CopyTo($stdout)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = $stdout.ToArray()
            Stderr = $stderr
        }
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill($true)
        }
        $process.Dispose()
    }
}

function Assert-NativeFullSessionPrefixes {
    param(
        [string]$Uri,
        [string]$CaseName
    )

    $initialize = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
    $didOpen = @{
        jsonrpc = "2.0"
        method = "textDocument/didOpen"
        params = @{ textDocument = @{ uri = $Uri; languageId = "sollang"; version = 1; text = 'main { "ok" -> println }' } }
    } | ConvertTo-Json -Compress -Depth 8
    $operations = @(
        $didOpen,
        (@{
            jsonrpc = "2.0"
            method = "textDocument/didChange"
            params = @{ textDocument = @{ uri = $Uri; version = 2 }; contentChanges = @(@{ text = 'main { "😀" @ }' }) }
        } | ConvertTo-Json -Compress -Depth 8),
        (@{
            jsonrpc = "2.0"
            method = "textDocument/didChange"
            params = @{ textDocument = @{ uri = $Uri; version = 3 }; contentChanges = @(@{ text = 'main{"ok"->println}' }) }
        } | ConvertTo-Json -Compress -Depth 8),
        (@{
            jsonrpc = "2.0"
            id = "fmt"
            method = "textDocument/formatting"
            params = @{ textDocument = @{ uri = $Uri }; options = @{ tabSize = 4; insertSpaces = $true } }
        } | ConvertTo-Json -Compress -Depth 8),
        '{"jsonrpc":"2.0","id":7,"method":"sollang/unknown","params":{}}',
        (@{
            jsonrpc = "2.0"
            method = "textDocument/didClose"
            params = @{ textDocument = @{ uri = $Uri } }
        } | ConvertTo-Json -Compress -Depth 8)
    )
    $shutdown = '{"jsonrpc":"2.0","id":2,"method":"shutdown","params":null}'
    $exit = '{"jsonrpc":"2.0","method":"exit"}'

    for ($prefixCount = 1; $prefixCount -le $operations.Count; $prefixCount++) {
        $messages = [Collections.Generic.List[string]]::new()
        $messages.Add($initialize)
        for ($index = 0; $index -lt $prefixCount; $index++) {
            $messages.Add($operations[$index])
        }
        $messages.Add($shutdown)
        $messages.Add($exit)

        $process = Start-LanguageServer $true
        try {
            foreach ($message in $messages) {
                Write-Fragmented $process.StandardInput.BaseStream (ConvertTo-LspFrame $message)
            }
            $process.StandardInput.Close()
            $stdout = [IO.MemoryStream]::new()
            $process.StandardOutput.BaseStream.CopyTo($stdout)
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) {
                throw "native language server $CaseName prefix $prefixCount/$($operations.Count) exited with $($process.ExitCode); last operation contains '$($operations[$prefixCount - 1])'; stdout bytes $($stdout.Length); stderr: $stderr"
            }
        }
        finally {
            if (-not $process.HasExited) {
                $process.Kill($true)
            }
            $process.Dispose()
        }
    }
}

function Assert-EquivalentFrames {
    param(
        [string[]]$Managed,
        [string[]]$Native
    )

    if ($Managed.Count -ne 8 -or $Native.Count -ne 8) {
        throw "expected 8 responses, managed=$($Managed.Count), native=$($Native.Count)"
    }
    for ($index = 0; $index -lt $Managed.Count; $index++) {
        $managedJson = [Text.Json.Nodes.JsonNode]::Parse($Managed[$index])
        $nativeJson = [Text.Json.Nodes.JsonNode]::Parse($Native[$index])
        if (-not [Text.Json.Nodes.JsonNode]::DeepEquals($managedJson, $nativeJson)) {
            throw "LSP response $index differs.`nmanaged: $($Managed[$index])`nnative:  $($Native[$index])"
        }
    }

    $diagnostic = [Text.Json.Nodes.JsonNode]::Parse($Managed[2])
    $position = $diagnostic["params"]["diagnostics"][0]["range"]["start"]
    if ($position["line"].GetValue[int]() -ne 0 -or $position["character"].GetValue[int]() -ne 12) {
        throw "UTF-16 diagnostic position mismatch: $position"
    }
    $formatting = [Text.Json.Nodes.JsonNode]::Parse($Managed[4])
    if ($formatting["result"].AsArray().Count -eq 0) {
        throw "formatting response did not contain an edit"
    }
    $unknown = [Text.Json.Nodes.JsonNode]::Parse($Managed[5])
    if ($unknown["error"]["code"].GetValue[int]() -ne -32601) {
        throw "unknown-method response did not use JSON-RPC -32601"
    }
}

function Invoke-FocusedPositionCases {
    param([string]$FocusedContract, [string]$CompilerMode)
    $contract = Get-Content -LiteralPath $FocusedContract -Raw | ConvertFrom-Json
    if ($contract.schemaVersion -ne 1 -or $contract.cases.Count -eq 0) {
        throw "LSP_FOCUSED_CONTRACT_INVALID"
    }
    $expectedById = @{}
    foreach ($case in $contract.cases) {
        if ($case.id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
            $expectedById.ContainsKey($case.id) -or
            $case.kind -notin @("diagnostic", "formatting") -or
            $case.source -isnot [string] -or $case.expected -isnot [array]) {
            throw "LSP_FOCUSED_CASE_INVALID"
        }
        $expectedById[$case.id] = [Text.Json.Nodes.JsonNode]::Parse((ConvertTo-Json -InputObject $case.expected -Compress -Depth 20))
    }
    $results = [Collections.Generic.List[object]]::new()
    $variants = switch ($CompilerMode) {
        "managed" { @($false) }
        "native" { @($true) }
        "paired" { @($false, $true) }
    }
    foreach ($native in $variants) {
        foreach ($case in $contract.cases) {
            $uri = "file:///focused-$($case.id).slg"
            $messages = [Collections.Generic.List[string]]::new()
            $messages.Add((@{
                jsonrpc = "2.0"
                method = "textDocument/didOpen"
                params = @{ textDocument = @{ uri = $uri; languageId = "sollang"; version = 1; text = $case.source } }
            } | ConvertTo-Json -Compress -Depth 8))
            if ($case.kind -eq "formatting") {
                $messages.Add((@{
                    jsonrpc = "2.0"; id = "fmt"; method = "textDocument/formatting"
                    params = @{ textDocument = @{ uri = $uri }; options = @{ tabSize = 4; insertSpaces = $true } }
                } | ConvertTo-Json -Compress -Depth 8))
            } elseif ($case.kind -ne "diagnostic") { throw "LSP_FOCUSED_CASE_KIND_INVALID" }
            $messages.Add('{"jsonrpc":"2.0","id":"close","method":"shutdown","params":null}')
            $messages.Add('{"jsonrpc":"2.0","method":"exit"}')
            $inputBytes = [Collections.Generic.List[byte]]::new()
            foreach ($message in $messages) { $inputBytes.AddRange([byte[]](ConvertTo-LspFrame $message)) }
            $session = Invoke-RawSession $native $inputBytes.ToArray()
            $frameFailure = ""
            try { $frames = @(Read-AllFrames $session.Stdout) }
            catch {
                $frames = @()
                $frameFailure = $_.Exception.Message
            }
            $frameIndex = if ($case.kind -eq "formatting") { 1 } else { 0 }
            $expectedFrameCount = if ($case.kind -eq "formatting") { 3 } else { 2 }
            $actual = $null
            if ($frames.Count -eq $expectedFrameCount) {
                $frame = [Text.Json.Nodes.JsonNode]::Parse($frames[$frameIndex])
                if ($case.kind -eq "formatting") {
                    $actual = $frame["result"]
                } else {
                    $actual = $frame["params"]["diagnostics"]
                }
            }
            $expected = $expectedById[$case.id]
            $passed = $session.ExitCode -eq 0 -and $session.Stderr -eq "" -and $frameFailure -eq "" -and
                $null -ne $actual -and [Text.Json.Nodes.JsonNode]::DeepEquals($actual, $expected)
            $results.Add([pscustomobject]@{
                id = $case.id; compiler = $(if ($native) { "native" } else { "managed" })
                passed = $passed; exit = $session.ExitCode; stderr = $session.Stderr
                frames = $frames; expected = $case.expected
                frameFailure = $frameFailure
                stdoutBase64 = [Convert]::ToBase64String($session.Stdout)
            })
        }
    }
    $completed = @($results | Where-Object passed).Count
    [pscustomobject]@{ completed = $completed; total = $results.Count; cases = $results } | ConvertTo-Json -Depth 25
    if ($completed -ne $results.Count) { throw "LSP_FOCUSED_POSITION_ORACLE_MISMATCH" }
    return
}

function Invoke-JsonAdmissionCases {
    param([string]$ContractPath, [string]$Mode)
    $contract = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json
    if ($contract.schemaVersion -ne 1 -or $contract.cases.Count -eq 0) { throw "LSP_JSON_CONTRACT_INVALID" }
    $ids = [Collections.Generic.HashSet[string]]::new()
    foreach ($case in $contract.cases) {
        if ($case.id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or -not $ids.Add($case.id) -or
            $case.payload -isnot [string] -or $case.expectedRuntimeExit -notin @(0, 1) -or
            $case.expectedStderr -isnot [string]) { throw "LSP_JSON_CASE_INVALID" }
    }
    $modes = switch ($Mode) { "managed" { @($false) }; "native" { @($true) }; default { @($false, $true) } }
    $results = @()
    foreach ($native in $modes) {
        foreach ($case in $contract.cases) {
            $actual = Invoke-RawSession $native (ConvertTo-LspFrame $case.payload)
            $passed = $actual.ExitCode -eq $case.expectedRuntimeExit -and $actual.Stdout.Length -eq 0 -and
                $actual.Stderr.Replace("`r`n", "`n") -ceq $case.expectedStderr
            $results += [pscustomobject]@{ id = $case.id; compiler = $(if ($native) { "native" } else { "managed" })
                passed = $passed; exit = $actual.ExitCode; stdout = $actual.Stdout; stderr = $actual.Stderr }
        }
    }
    $completed = @($results | Where-Object passed).Count
    [pscustomobject]@{ completed = $completed; total = $results.Count; cases = $results } | ConvertTo-Json -Depth 10
    if ($completed -ne $results.Count) { throw "LSP_JSON_ADMISSION_MISMATCH" }
}

if (-not [string]::IsNullOrWhiteSpace($JsonAdmissionContract)) {
    Invoke-JsonAdmissionCases $JsonAdmissionContract $CompilerMode
    return
}

if (-not [string]::IsNullOrWhiteSpace($FocusedContract)) {
    Invoke-FocusedPositionCases $FocusedContract $CompilerMode
    return
}

Assert-StreamingInitialize $false
Write-Output "[1/4] PASS managed streaming initialize"
Assert-StreamingInitialize $true
Write-Output "[2/4] PASS native streaming initialize"
Assert-NativeFullSessionPrefixes "file:///ascii.slg" "ASCII URI"
Assert-NativeFullSessionPrefixes "file:///한글-😀.slg" "Unicode URI"
Write-Output "[native LSP prefixes] PASS ASCII and Unicode incremental full-session operation prefixes"
$managedFrames = Invoke-FullSession $false
$nativeFrames = Invoke-FullSession $true
Assert-EquivalentFrames $managedFrames $nativeFrames
Write-Output "[3/4] PASS managed/native full message parity"

$exitFrame = ConvertTo-LspFrame '{"jsonrpc":"2.0","method":"exit"}'
$emptyInput = [byte[]]::new(0)
$incompleteInput = $utf8.GetBytes("Content-Length: 10`r`n`r`n{}")
$invalidHeader = $utf8.GetBytes("Header: value`r`n`r`n")
$invalidJson = ConvertTo-LspFrame '{"jsonrpc":'
$rawCases = @(
    @{ Name = "exit-before-shutdown"; Input = $exitFrame; Exit = 1; Error = "" },
    @{ Name = "clean-eof"; Input = $emptyInput; Exit = 0; Error = "" },
    @{ Name = "incomplete-frame"; Input = $incompleteInput; Exit = 1; Error = "sollang: incomplete LSP message" },
    @{ Name = "invalid-header"; Input = $invalidHeader; Exit = 1; Error = "sollang: invalid LSP header" },
    @{ Name = "invalid-json"; Input = $invalidJson; Exit = 1; Error = "sollang: invalid LSP message" }
)
foreach ($case in $rawCases) {
    $managed = Invoke-RawSession $false $case.Input
    $native = Invoke-RawSession $true $case.Input
    if ($managed.ExitCode -ne $case.Exit -or $native.ExitCode -ne $case.Exit) {
        throw "$($case.Name) exit mismatch: managed=$($managed.ExitCode), native=$($native.ExitCode)"
    }
    if ($managed.Stdout.Length -ne 0 -or $native.Stdout.Length -ne 0) {
        throw "$($case.Name) unexpectedly wrote stdout"
    }
    if ($managed.Stderr.Trim() -ne $case.Error -or $native.Stderr.Trim() -ne $case.Error) {
        throw "$($case.Name) stderr mismatch: managed='$($managed.Stderr.Trim())', native='$($native.Stderr.Trim())'"
    }
}

$nativeArgument = Invoke-LanguageServerArgumentFailure $true
$managedArgument = Invoke-LanguageServerArgumentFailure $false
if ($nativeArgument.ExitCode -ne 1 -or $managedArgument.ExitCode -ne 1 -or $nativeArgument.Output -ne "sollang: usage: sollang language-server" -or $managedArgument.Output -ne "sollang: usage: sollang language-server") {
    throw "language-server argument rejection differs: managed='$($managedArgument.Output)', native='$($nativeArgument.Output)'"
}
Write-Output "[4/4] PASS framing, EOF, shutdown, and argument parity"
Invoke-FocusedPositionCases (Join-Path $PSScriptRoot "contracts\lsp-newline-positions.json") "paired"
Invoke-FocusedPositionCases (Join-Path $PSScriptRoot "contracts\lsp-diagnostic-messages.json") "paired"

Invoke-JsonAdmissionCases (Join-Path $PSScriptRoot "contracts\lsp-json-admission.json") "paired"
