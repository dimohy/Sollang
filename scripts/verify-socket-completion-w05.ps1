[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/w05'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/w05-pending-reset.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/w05-pending-reset.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-w05-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @(
    $PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'),
    (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/Tooling/WindowsLinker.cs'),
    $compilerPath
)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "W05 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "W05 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }

[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'w05.exe'
$llvm = Join-Path $output 'w05.ll'
$bitcode = Join-Path $output 'w05.bc'
$resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) {
    if (Test-Path -LiteralPath $artifact) { throw "W05 output already exists and will not be reused: $artifact" }
}

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
$formatExitCode = $null
$compileExitCode = $null
$compileDiagnosticsClean = $false
$nativeExitCode = $null
$llvmAsExitCode = $null
$closureExitCode = $null
$stdout = @()
$orphanProcessIds = @()
$irAssertions = [ordered]@{
    overlappedResultCallCount = 0
    waiterReadsExactWsaError = $false
    dequeueMapsSocketErrorKind = $false
    payloadCopyFree = $false
    dequeueOwnerTransferVerified = $false
}

try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'W05 authoritative format' -TimeoutMilliseconds 120000
    $formatExitCode = $format.ExitCode
    if ($formatExitCode -ne 0) { Add-Failure 'W05_FORMAT' }

    $compile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath, 'build', $fixture, '-o', $exe, '--target', 'windows-x64', '--llvm', (Join-Path $root '.tools/llvm-22.1.8'), '-O0', '--keep-temps') -WorkingDirectory $root -Description 'W05 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode
    $compileText = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'W05_COMPILE' }
    if (-not $compileDiagnosticsClean) { Add-Failure 'W05_COMPILE_DIAGNOSTIC' }

    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'W05 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode = $assembled.ExitCode
        if ($llvmAsExitCode -ne 0) { Add-Failure 'W05_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'W05 V004' -TimeoutMilliseconds 120000
        $closureExitCode = $closure.ExitCode
        if ($closureExitCode -ne 0) { Add-Failure 'W05_V004' }

        $ir = [IO.File]::ReadAllText($llvm)
        $waiter = [regex]::Match($ir, 'define internal i32 @sollang_socket_completion_waiter\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $submit = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_submit\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $dequeue = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_dequeue\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        if ($waiter.Success) {
            $irAssertions.overlappedResultCallCount = ([regex]::Matches($waiter.Groups['body'].Value, 'call i32 @WSAGetOverlappedResult')).Count
            $irAssertions.waiterReadsExactWsaError = $waiter.Groups['body'].Value.Contains('call i32 @WSAGetLastError()', [StringComparison]::Ordinal)
        }
        if ($dequeue.Success) {
            $irAssertions.dequeueMapsSocketErrorKind = $dequeue.Groups['body'].Value.Contains('call i32 @sollang_socket_error_kind(i32 %completion_code)', [StringComparison]::Ordinal)
            $irAssertions.dequeueOwnerTransferVerified = $dequeue.Groups['body'].Value.Contains('store ptr null, ptr %entry_buffer_slot', [StringComparison]::Ordinal) -and $dequeue.Groups['body'].Value.Contains('store atomic i64 0, ptr %pending_record release', [StringComparison]::Ordinal)
        }
        $irAssertions.payloadCopyFree = $submit.Success -and $dequeue.Success -and $submit.Groups['body'].Value -notmatch '@llvm\.(memcpy|memmove)' -and $dequeue.Groups['body'].Value -notmatch '@llvm\.(memcpy|memmove)'
        if ($irAssertions.overlappedResultCallCount -ne 1) { Add-Failure 'W05_IR_OVERLAPPED_RESULT' }
        if (-not $irAssertions.waiterReadsExactWsaError) { Add-Failure 'W05_IR_EXACT_WSA_ERROR' }
        if (-not $irAssertions.dequeueMapsSocketErrorKind) { Add-Failure 'W05_IR_ERROR_KIND' }
        if (-not $irAssertions.payloadCopyFree) { Add-Failure 'W05_IR_PAYLOAD_COPY' }
        if (-not $irAssertions.dequeueOwnerTransferVerified) { Add-Failure 'W05_IR_OWNER_TRANSFER' }

        $process = [Diagnostics.Process]::new()
        $process.StartInfo = [Diagnostics.ProcessStartInfo]@{
            FileName = $exe; WorkingDirectory = $root; UseShellExecute = $false; CreateNoWindow = $true
            RedirectStandardOutput = $true; RedirectStandardError = $true
        }
        $peer = $null
        try {
            if (-not $process.Start()) { throw 'W05 native process could not start' }
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $portTask = $process.StandardOutput.ReadLineAsync()
            if (-not $portTask.Wait(5000)) { throw 'W05 did not publish peer port' }
            $portLine = $portTask.Result
            if ($portLine -notmatch '^peer-port=(\d+)$') { throw "W05 unexpected peer port line: $portLine" }
            $peer = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Stream, [Net.Sockets.ProtocolType]::Tcp)
            $peer.LingerState = [Net.Sockets.LingerOption]::new($true, 0)
            $peer.Connect([Net.IPAddress]::Loopback, [int]$Matches[1])
            $pendingTask = $process.StandardOutput.ReadLineAsync()
            if (-not $pendingTask.Wait(5000)) { throw 'W05 did not reach pending state' }
            $pendingLine = $pendingTask.Result
            Start-Sleep -Milliseconds 100
            $peer.Close()
            $peer = $null
            $remainingTask = $process.StandardOutput.ReadToEndAsync()
            if (-not $process.WaitForExit(5000)) { throw 'W05 native process did not terminate' }
            $process.WaitForExit()
            $nativeExitCode = $process.ExitCode
            $stderr = $stderrTask.GetAwaiter().GetResult()
            $remaining = $remainingTask.GetAwaiter().GetResult()
            $stdout = @($pendingLine) + @($remaining -split '\r?\n' | Where-Object { $_ -ne '' })
            $expected = @(Get-Content -LiteralPath $expectedPath)
            if ($nativeExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($stderr) -or ($stdout -join "`n") -cne ($expected -join "`n")) { Add-Failure 'W05_NATIVE_EXACT' }
        } finally {
            if ($null -ne $peer) { $peer.Dispose() }
            if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            $process.Dispose()
        }
    }
} catch {
    Add-Failure 'W05_RUNNER_EXCEPTION'
}

$orphanProcessIds = @(
    Get-CimInstance Win32_Process |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and [IO.Path]::GetFullPath($_.ExecutablePath) -ceq $exe } |
        ForEach-Object { [int]$_.ProcessId }
)
if ($orphanProcessIds.Count -ne 0) { Add-Failure 'W05_ORPHAN_PROCESS' }
$inputDrift = @()
foreach ($path in $inputs) {
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative }
}
if ($inputDrift.Count -ne 0) { Add-Failure 'W05_INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1; caseId = 'W05'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes
    formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean
    nativeExitCode = $nativeExitCode; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode
    stdout = $stdout; orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures)
}
$json = ($record | ConvertTo-Json -Depth 10) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "W05 result schema failure: $resultPath" }
if ($record.status -cne 'passed') { throw "W05 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion W05] PASS result=$resultPath"
