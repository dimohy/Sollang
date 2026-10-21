[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$Distribution = 'Ubuntu',
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/l07'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-l07-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @($PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "L07 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "L07 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'l07'; $llvm = Join-Path $output 'l07.ll'; $bitcode = Join-Path $output 'l07.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "L07 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
function Get-FunctionBody([string]$Ir, [string]$Name) {
    $escaped = [regex]::Escape($Name)
    $match = [regex]::Match($Ir, "(?m)^define internal [^\r\n]+ @$escaped\([^\r\n]*\) #0 \{(?<body>.*?)\r?\n\}", [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Groups['body'].Value }
    return ''
}

$formatExitCode = $null; $compileExitCode = $null; $compileDiagnosticsClean = $false; $llvmAsExitCode = $null; $closureExitCode = $null
$run = [ordered]@{ exitCode = $null; stdout = @(); stderr = ''; peerObservedEof = $false }
$orphanProcessIds = @()
$irAssertions = [ordered]@{
    socketWaitingStatusDistinct = $false; taskCancelRequestsWithoutFree = $false; cancelCallbackTwoPhase = $false
    cancelAllReleaseAndWake = $false; cancellationPublishCount = 0; closeJoinsBeforeOwnerCleanup = $false
    epollRegistrationRemovedByClose = $false; payloadCopyFree = $false
}

try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'L07 format' -TimeoutMilliseconds 120000
    $formatExitCode = $format.ExitCode; if ($formatExitCode -ne 0) { Add-Failure 'L07_FORMAT' }
    $compile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath, 'build', $fixture, '-o', $exe, '--target', 'linux-x64', '-O0', '--keep-temps') -WorkingDirectory $root -Description 'L07 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode; $compileText = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'L07_COMPILE' }; if (-not $compileDiagnosticsClean) { Add-Failure 'L07_COMPILE_DIAGNOSTIC' }
    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'L07 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode = $assembled.ExitCode; if ($llvmAsExitCode -ne 0) { Add-Failure 'L07_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'L07 V004' -TimeoutMilliseconds 120000
        $closureExitCode = $closure.ExitCode; if ($closureExitCode -ne 0) { Add-Failure 'L07_V004' }
        $ir = [IO.File]::ReadAllText($llvm); $worker = Get-FunctionBody $ir 'sollang_socket_completion_dequeue_task_worker'; $taskCancel = Get-FunctionBody $ir 'sollang_task_cancel'; $callback = Get-FunctionBody $ir 'sollang_socket_completion_dequeue_task_cancel'; $request = Get-FunctionBody $ir 'sollang_platform_socket_completion_request_cancel_all_locked'; $waiter = Get-FunctionBody $ir 'sollang_socket_completion_waiter'; $close = Get-FunctionBody $ir 'sollang_platform_socket_completion_close'; $dequeue = Get-FunctionBody $ir 'sollang_platform_socket_completion_dequeue_locked'
        $irAssertions.socketWaitingStatusDistinct = $worker.Contains('store i32 7, ptr %status_slot', [StringComparison]::Ordinal)
        $cancelStart = $taskCancel.IndexOf('cancel_socket_completion:', [StringComparison]::Ordinal); $cancelEnd = $taskCancel.IndexOf('detach_child:', [StringComparison]::Ordinal); $cancelBlock = if ($cancelStart -ge 0 -and $cancelEnd -gt $cancelStart) { $taskCancel.Substring($cancelStart, $cancelEnd - $cancelStart) } else { '' }
        $irAssertions.taskCancelRequestsWithoutFree = $cancelBlock.Contains('store atomic i32 1, ptr %socket_cancel_phase_slot release', [StringComparison]::Ordinal) -and $cancelBlock.Contains('call void %socket_cancel_fn(ptr %handle)', [StringComparison]::Ordinal) -and -not $cancelBlock.Contains('call void @sollang_free(ptr %handle)', [StringComparison]::Ordinal)
        $irAssertions.cancelCallbackTwoPhase = $callback.Contains('br i1 %requesting, label %request, label %inspect_final', [StringComparison]::Ordinal) -and $callback.Contains('call void @sollang_platform_socket_completion_request_cancel_all', [StringComparison]::Ordinal) -and $callback.Contains('call void @sollang_platform_socket_completion_close', [StringComparison]::Ordinal) -and $callback.IndexOf('call void @sollang_free(ptr %descriptor)', [StringComparison]::Ordinal) -gt $callback.IndexOf('call void @sollang_platform_socket_completion_close', [StringComparison]::Ordinal)
        $irAssertions.cancelAllReleaseAndWake = $request.Contains('store atomic i32 1, ptr %cancel_slot release', [StringComparison]::Ordinal) -and $request.Contains('call i64 @write(i32 %wakeup, ptr %signal, i64 8)', [StringComparison]::Ordinal)
        $irAssertions.cancellationPublishCount = ([regex]::Matches($waiter, 'call void @sollang_socket_completion_publish_locked\(ptr %state, ptr %cancel_entry, i32 125, i64 0\)')).Count
        $joinIndex = $close.IndexOf('call i32 @pthread_join(i64 %waiter, ptr null)', [StringComparison]::Ordinal); $ownerFreeIndex = $close.IndexOf('call void @sollang_free(ptr %completed_buffer)', [StringComparison]::Ordinal); $stateFreeIndex = $close.IndexOf('call void @sollang_free(ptr %state)', [StringComparison]::Ordinal)
        $irAssertions.closeJoinsBeforeOwnerCleanup = $joinIndex -ge 0 -and $ownerFreeIndex -gt $joinIndex -and $stateFreeIndex -gt $ownerFreeIndex -and ([regex]::Matches($close, 'call void @sollang_free\(ptr %completed_buffer\)')).Count -eq 1
        $socketCloseIndex = $close.IndexOf('call i32 @close(i32 %registered_socket)', [StringComparison]::Ordinal); $epollCloseIndex = $close.IndexOf('call i32 @close(i32 %epoll)', [StringComparison]::Ordinal)
        $irAssertions.epollRegistrationRemovedByClose = $socketCloseIndex -gt $ownerFreeIndex -and $epollCloseIndex -gt $socketCloseIndex
        $irAssertions.payloadCopyFree = ($waiter + $dequeue) -notmatch '@llvm\.(?:memcpy|memmove)'
        foreach ($entry in $irAssertions.GetEnumerator()) { if (($entry.Key -ceq 'cancellationPublishCount' -and $entry.Value -ne 1) -or ($entry.Key -cne 'cancellationPublishCount' -and -not $entry.Value)) { Add-Failure ("L07_IR_" + $entry.Key.ToUpperInvariant()) } }

        $wexe = (& wsl.exe -d $Distribution -- wslpath -a ($exe.Replace('\', '/'))).Trim()
        $process = [Diagnostics.Process]::new(); $process.StartInfo = [Diagnostics.ProcessStartInfo]@{ FileName = 'wsl.exe'; WorkingDirectory = $root; UseShellExecute = $false; CreateNoWindow = $true; RedirectStandardOutput = $true; RedirectStandardError = $true }
        foreach ($argument in @('-d', $Distribution, '--', $wexe)) { $process.StartInfo.ArgumentList.Add($argument) }
        $peer = $null
        try {
            if (-not $process.Start()) { throw 'L07 process could not start' }
            $stderrTask = $process.StandardError.ReadToEndAsync(); $portTask = $process.StandardOutput.ReadLineAsync()
            if (-not $portTask.Wait(5000)) { throw 'L07 did not publish peer port' }; $portLine = $portTask.Result
            if ($portLine -notmatch '^peer-port=(\d+)$') { throw "L07 unexpected port line: $portLine" }
            $peer = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Stream, [Net.Sockets.ProtocolType]::Tcp); $peer.Connect([Net.IPAddress]::Loopback, [int]$Matches[1])
            if (-not $process.WaitForExit(10000)) { throw 'L07 process did not terminate' }; $process.WaitForExit()
            $stdout = [string[]]@($process.StandardOutput.ReadToEnd() -split '\r?\n' | Where-Object { $_ -ne '' }); $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
            $peerObservedEof = $peer.Poll(1000000, [Net.Sockets.SelectMode]::SelectRead) -and $peer.Available -eq 0
            $run = [ordered]@{ exitCode = $process.ExitCode; stdout = $stdout; stderr = $stderr; peerObservedEof = $peerObservedEof }
            $expected = [string[]]@(Get-Content -LiteralPath $expectedPath)
            if ($process.ExitCode -ne 0 -or $stderr.Length -ne 0 -or ($stdout -join "`n") -cne ($expected -join "`n") -or -not $peerObservedEof) { Add-Failure 'L07_EXACT' }
        } finally {
            if ($null -ne $peer) { $peer.Dispose() }; if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }; $process.Dispose()
        }
        $orphanText = (& wsl.exe -d $Distribution -- sh -lc "pgrep -f -x '$wexe' || true") -join "`n"; $orphanProcessIds = @($orphanText -split '\r?\n' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }); if ($orphanProcessIds.Count -ne 0) { Add-Failure 'L07_ORPHAN_PROCESS' }
    }
} catch { Add-Failure 'L07_RUNNER_EXCEPTION' }

$inputDrift = @(); foreach ($path in $inputs) { $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/'); if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative } }; if ($inputDrift.Count -ne 0) { Add-Failure 'L07_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion = 1; caseId = 'L07'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }; compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes; formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode; run = $run; orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures) }
$json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "L07 result schema failure: $resultPath" }; if ($record.status -cne 'passed') { throw "L07 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion L07] PASS result=$resultPath"
