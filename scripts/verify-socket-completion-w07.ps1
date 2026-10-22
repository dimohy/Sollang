[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/w07'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'verification-compiler-build.ps1')
. (Join-Path $PSScriptRoot 'verification-socket-completion-ir.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-w07-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @((Join-Path $PSScriptRoot 'verification-socket-completion-ir.ps1'), (Join-Path $PSScriptRoot 'verification-process.ps1'), (Join-Path $PSScriptRoot 'verification-compiler-build.ps1'), (Join-Path $PSScriptRoot 'contracts/verification-compiler-build.json'), $PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "W07 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
$compilerKind = (Resolve-VerificationCompilerInvocation -Compiler $compilerPath).Kind
$releaseDescriptor = Get-VerificationSocketReleaseCall -CompilerKind $compilerKind -Operand '%descriptor'
$releaseBuffer = Get-VerificationSocketReleaseCall -CompilerKind $compilerKind -Operand '%completed_buffer'
$releaseState = Get-VerificationSocketReleaseCall -CompilerKind $compilerKind -Operand '%state'
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "W07 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'w07.exe'; $llvm = $exe + '.ll'; $bitcode = Join-Path $output 'w07.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "W07 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
$formatExitCode = $null; $compileExitCode = $null; $compileDiagnosticsClean = $false; $llvmAsExitCode = $null; $closureExitCode = $null
$run = [ordered]@{ exitCode = $null; stdout = @(); stderr = ''; peerObservedEof = $false }
$orphanProcessIds = @()
$irAssertions = [ordered]@{
    socketWaitingStatusDistinct = $false; taskCancelRequestsWithoutFree = $false; cancelCallbackTwoPhase = $false
    cancelMarkerPrecedesNativeCancel = $false; completionWonRecognized = $false; terminalPublishCount = 0
    closeJoinsBeforeOwnerCleanup = $false; payloadCopyFree = $false
}

try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Compiler', $compilerPath, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'W07 format' -TimeoutMilliseconds 120000 -ExecutionRecordPath (Join-Path $output 'format.execution.json')
    $formatExitCode = $format.ExitCode; if ($formatExitCode -ne 0) { Add-Failure 'W07_FORMAT' }
    $compile = Invoke-VerificationCompilerBuild -Compiler $compilerPath -Source $fixture -Output $exe -Target 'windows-x64' -WorkingDirectory $root -Description 'W07 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode; $compileText = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'W07_COMPILE' }
    if (-not $compileDiagnosticsClean) { Add-Failure 'W07_COMPILE_DIAGNOSTIC' }
    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'W07 llvm-as' -TimeoutMilliseconds 120000 -ExecutionRecordPath (Join-Path $output 'llvm-as.execution.json')
        $llvmAsExitCode = $assembled.ExitCode; if ($llvmAsExitCode -ne 0) { Add-Failure 'W07_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'W07 V004' -TimeoutMilliseconds 120000 -ExecutionRecordPath (Join-Path $output 'v004.execution.json')
        $closureExitCode = $closure.ExitCode; if ($closureExitCode -ne 0) { Add-Failure 'W07_V004' }

        $ir = [IO.File]::ReadAllText($llvm)
        $worker = [regex]::Match($ir, 'define internal i1 @sollang_socket_completion_dequeue_task_worker\(.*?\)(?: #[0-9]+)? \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $taskCancel = [regex]::Match($ir, 'define internal i1 @sollang_task_cancel\(.*?\)(?: #[0-9]+)? \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $callback = [regex]::Match($ir, 'define internal void @sollang_socket_completion_dequeue_task_cancel\(.*?\)(?: #[0-9]+)? \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $request = [regex]::Match($ir, 'define internal void @sollang_platform_socket_completion_request_cancel_all\(.*?\)(?: #[0-9]+)? \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $waiter = [regex]::Match($ir, 'define internal i32 @sollang_socket_completion_waiter\(.*?\)(?: #[0-9]+)? \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $close = [regex]::Match($ir, 'define internal void @sollang_platform_socket_completion_close\(.*?\)(?: #[0-9]+)? \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $dequeue = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_dequeue\(.*?\)(?: #[0-9]+)? \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $irAssertions.socketWaitingStatusDistinct = $worker.Success -and $worker.Groups['body'].Value.Contains('store i32 7, ptr %status_slot', [StringComparison]::Ordinal)
        if ($taskCancel.Success) {
            $body = $taskCancel.Groups['body'].Value
            $irAssertions.taskCancelRequestsWithoutFree = Test-VerificationSocketCancelRequest -Body $body
        }
        if ($callback.Success) {
            $body = $callback.Groups['body'].Value
            $irAssertions.cancelCallbackTwoPhase = $body.Contains('br i1 %requesting, label %request, label %inspect_final', [StringComparison]::Ordinal) -and $body.Contains('call void @sollang_platform_socket_completion_request_cancel_all', [StringComparison]::Ordinal) -and $body.Contains('call void @sollang_platform_socket_completion_close', [StringComparison]::Ordinal) -and $body.IndexOf($releaseDescriptor, [StringComparison]::Ordinal) -gt $body.IndexOf('call void @sollang_platform_socket_completion_close', [StringComparison]::Ordinal)
        }
        if ($request.Success) {
            $body = $request.Groups['body'].Value
            $irAssertions.cancelMarkerPrecedesNativeCancel = $body.IndexOf('store atomic i32 1, ptr %cancel_requested_slot release', [StringComparison]::Ordinal) -ge 0 -and $body.IndexOf('store atomic i32 1, ptr %cancel_requested_slot release', [StringComparison]::Ordinal) -lt $body.IndexOf('call i32 @CancelIoEx', [StringComparison]::Ordinal)
            $irAssertions.completionWonRecognized = $body.Contains('%completion_already_won = icmp eq i32 %cancel_error, 1168', [StringComparison]::Ordinal)
        }
        if ($waiter.Success) { $irAssertions.terminalPublishCount = ([regex]::Matches($waiter.Groups['body'].Value, 'store atomic i64 2, ptr %pending_record release')).Count }
        if ($close.Success) {
            $body = $close.Groups['body'].Value
            $joinIndex = $body.IndexOf('call i32 @WaitForSingleObject(ptr %waiter, i32 -1)', [StringComparison]::Ordinal)
            $ownerFreeIndex = $body.IndexOf($releaseBuffer, [StringComparison]::Ordinal)
            $stateFreeIndex = $body.IndexOf($releaseState, [StringComparison]::Ordinal)
            $irAssertions.closeJoinsBeforeOwnerCleanup = $joinIndex -ge 0 -and $ownerFreeIndex -gt $joinIndex -and $stateFreeIndex -gt $ownerFreeIndex -and ([regex]::Matches($body, [regex]::Escape($releaseBuffer))).Count -eq 1
        }
        $irAssertions.payloadCopyFree = $dequeue.Success -and $dequeue.Groups['body'].Value -notmatch '@llvm\.(memcpy|memmove)'
        foreach ($entry in $irAssertions.GetEnumerator()) { if (($entry.Value -is [bool]) -and -not $entry.Value) { Add-Failure ("W07_IR_" + $entry.Key.ToUpperInvariant()) } }
        if ($irAssertions.terminalPublishCount -ne 1) { Add-Failure 'W07_IR_TERMINAL_PUBLISH' }

        $process = [Diagnostics.Process]::new()
        $process.StartInfo = [Diagnostics.ProcessStartInfo]@{ FileName = $exe; WorkingDirectory = $root; UseShellExecute = $false; CreateNoWindow = $true; RedirectStandardOutput = $true; RedirectStandardError = $true }
        $peer = $null
        try {
            if (-not $process.Start()) { throw 'W07 process could not start' }
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $portTask = $process.StandardOutput.ReadLineAsync()
            if (-not $portTask.Wait(5000)) { throw 'W07 did not publish peer port' }
            $portLine = $portTask.Result
            if ($portLine -notmatch '^peer-port=(\d+)$') { throw "W07 unexpected port line: $portLine" }
            $peer = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Stream, [Net.Sockets.ProtocolType]::Tcp)
            $peer.Connect([Net.IPAddress]::Loopback, [int]$Matches[1])
            if (-not $process.WaitForExit(5000)) { throw 'W07 process did not terminate' }
            $process.WaitForExit()
            $stdout = [string[]]@($process.StandardOutput.ReadToEnd() -split '\r?\n' | Where-Object { $_ -ne '' })
            $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
            $peerObservedEof = $peer.Poll(1000000, [Net.Sockets.SelectMode]::SelectRead) -and $peer.Available -eq 0
            $run = [ordered]@{ exitCode = $process.ExitCode; stdout = $stdout; stderr = $stderr; peerObservedEof = $peerObservedEof }
            $expected = [string[]]@(Get-Content -LiteralPath $expectedPath)
            if ($process.ExitCode -ne 0 -or $stderr.Length -ne 0 -or ($stdout -join "`n") -cne ($expected -join "`n") -or -not $peerObservedEof) { Add-Failure 'W07_EXACT' }
        } finally {
            if ($null -ne $peer) { $peer.Dispose() }
            if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            $process.Dispose()
        }
    }
} catch { Add-Failure 'W07_RUNNER_EXCEPTION'; [IO.File]::WriteAllText((Join-Path $output 'runner-exception.txt'), $_.Exception.ToString(), [Text.UTF8Encoding]::new($false)) }

$orphanProcessIds = @(Get-CimInstance Win32_Process | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and [IO.Path]::GetFullPath($_.ExecutablePath) -ceq $exe } | ForEach-Object { [int]$_.ProcessId })
if ($orphanProcessIds.Count -ne 0) { Add-Failure 'W07_ORPHAN_PROCESS' }
$inputDrift = @(); foreach ($path in $inputs) { $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/'); if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative } }
if ($inputDrift.Count -ne 0) { Add-Failure 'W07_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion = 1; caseId = 'W07'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }; compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes; formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode; run = $run; orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures) }
$json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "W07 result schema failure: $resultPath" }
if ($record.status -cne 'passed') { throw "W07 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion W07] PASS result=$resultPath"
