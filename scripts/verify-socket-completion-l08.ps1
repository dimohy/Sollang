[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$Distribution = 'Ubuntu',
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/l08'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/l08-bounded-fair-batch.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/l08-bounded-fair-batch.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-l08-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @($PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "L08 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "L08 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'l08'; $llvm = Join-Path $output 'l08.ll'; $bitcode = Join-Path $output 'l08.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "L08 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
function Get-FunctionBody([string]$Ir, [string]$Name) {
    $escaped = [regex]::Escape($Name); $match = [regex]::Match($Ir, "(?m)^define internal [^\r\n]+ @$escaped\([^\r\n]*\) #0 \{(?<body>.*?)\r?\n\}", [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Groups['body'].Value }; return ''
}

$formatExitCode = $null; $compileExitCode = $null; $compileDiagnosticsClean = $false; $llvmAsExitCode = $null; $closureExitCode = $null
$run = [ordered]@{ exitCode = $null; peerSent = @(); stdout = @(); stderr = '' }; $orphanProcessIds = @()
$irAssertions = [ordered]@{ batchCapacityStored = $false; oneEventWaitBound = $false; registrationScopedScan = $false; oneShotRearm = $false; terminalReturnsToWait = $false; dequeueOwnerTransferVerified = $false; payloadCopyFree = $false }

try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'L08 format' -TimeoutMilliseconds 120000
    $formatExitCode = $format.ExitCode; if ($formatExitCode -ne 0) { Add-Failure 'L08_FORMAT' }
    $compile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath, 'build', $fixture, '-o', $exe, '--target', 'linux-x64', '-O0', '--keep-temps') -WorkingDirectory $root -Description 'L08 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode; $compileText = $compile.Stdout + "`n" + $compile.Stderr; $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'L08_COMPILE' }; if (-not $compileDiagnosticsClean) { Add-Failure 'L08_COMPILE_DIAGNOSTIC' }
    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'L08 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode = $assembled.ExitCode; if ($llvmAsExitCode -ne 0) { Add-Failure 'L08_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'L08 V004' -TimeoutMilliseconds 120000
        $closureExitCode = $closure.ExitCode; if ($closureExitCode -ne 0) { Add-Failure 'L08_V004' }
        $ir = [IO.File]::ReadAllText($llvm); $create = Get-FunctionBody $ir 'sollang_platform_socket_completion_create'; $waiter = Get-FunctionBody $ir 'sollang_socket_completion_waiter'; $dequeue = Get-FunctionBody $ir 'sollang_platform_socket_completion_dequeue'
        $irAssertions.batchCapacityStored = $create.Contains('store i64 %batch, ptr %batch_slot', [StringComparison]::Ordinal)
        $irAssertions.oneEventWaitBound = ([regex]::Matches($waiter, 'call i32 @epoll_wait\(')).Count -eq 1 -and $waiter.Contains('call i32 @epoll_wait(i32 %epoll, ptr %completion_table, i32 1, i32 -1)', [StringComparison]::Ordinal)
        $irAssertions.registrationScopedScan = $waiter.Contains('%registration_index = sub i64 %registration_base, 1', [StringComparison]::Ordinal) -and $waiter.Contains('%registration_matches = icmp eq i64 %pending_registration, %registration_index', [StringComparison]::Ordinal)
        $irAssertions.oneShotRearm = $waiter.Contains('%rearm_mask = or i32 %ready_bit, 1073741824', [StringComparison]::Ordinal) -and $waiter.Contains('call i32 @epoll_ctl(i32 %epoll, i32 3, i32 %rearm_socket, ptr %rearm_event)', [StringComparison]::Ordinal)
        $irAssertions.terminalReturnsToWait = $waiter.Contains('store atomic i64 2, ptr %pending_entry release', [StringComparison]::Ordinal) -and [regex]::IsMatch($waiter, '(?m)^signal:\r?\n\s+call void @sollang_platform_io_signal_completion\(\)\r?\n\s+br label %wait$')
        $irAssertions.dequeueOwnerTransferVerified = $dequeue.Contains('store ptr null, ptr %entry_buffer_slot', [StringComparison]::Ordinal) -and $dequeue.Contains('store atomic i64 0, ptr %pending_record release', [StringComparison]::Ordinal)
        $irAssertions.payloadCopyFree = ($waiter + $dequeue) -notmatch '@llvm\.(?:memcpy|memmove)'
        foreach ($entry in $irAssertions.GetEnumerator()) { if (-not $entry.Value) { Add-Failure ("L08_IR_" + $entry.Key.ToUpperInvariant()) } }

        $wexe = (& wsl.exe -d $Distribution -- wslpath -a ($exe.Replace('\', '/'))).Trim(); $process = [Diagnostics.Process]::new()
        $process.StartInfo = [Diagnostics.ProcessStartInfo]@{ FileName = 'wsl.exe'; WorkingDirectory = $root; UseShellExecute = $false; CreateNoWindow = $true; RedirectStandardOutput = $true; RedirectStandardError = $true }
        foreach ($argument in @('-d', $Distribution, '--', $wexe)) { $process.StartInfo.ArgumentList.Add($argument) }
        $peers = [Collections.Generic.List[Net.Sockets.Socket]]::new()
        try {
            if (-not $process.Start()) { throw 'L08 process could not start' }; $stderrTask = $process.StandardError.ReadToEndAsync(); $portTask = $process.StandardOutput.ReadLineAsync()
            if (-not $portTask.Wait(5000)) { throw 'L08 did not publish peer port' }; $portLine = $portTask.Result; if ($portLine -notmatch '^peer-port=(\d+)$') { throw "L08 unexpected port line: $portLine" }; $port = [int]$Matches[1]
            foreach ($ordinal in 1..2) { $peer = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Stream, [Net.Sockets.ProtocolType]::Tcp); $peer.Connect([Net.IPAddress]::Loopback, $port); $peers.Add($peer) }
            $pendingTask = $process.StandardOutput.ReadLineAsync(); if (-not $pendingTask.Wait(5000)) { throw 'L08 did not reach pending' }; $pendingLine = $pendingTask.Result
            $peerSent = @($peers[0].Send([byte[]](81)), $peers[1].Send([byte[]](82)))
            if (-not $process.WaitForExit(10000)) { throw 'L08 process did not terminate' }; $process.WaitForExit()
            $stdout = [string[]](@($pendingLine) + @($process.StandardOutput.ReadToEnd() -split '\r?\n' | Where-Object { $_ -ne '' })); $stderr = $stderrTask.GetAwaiter().GetResult().Trim(); $run = [ordered]@{ exitCode = $process.ExitCode; peerSent = $peerSent; stdout = $stdout; stderr = $stderr }
            $expected = [string[]]@(Get-Content -LiteralPath $expectedPath); if ($process.ExitCode -ne 0 -or $stderr.Length -ne 0 -or ($peerSent -join ',') -cne '1,1' -or ($stdout -join "`n") -cne ($expected -join "`n")) { Add-Failure 'L08_EXACT' }
        } finally {
            foreach ($peer in $peers) { $peer.Dispose() }; if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }; $process.Dispose()
        }
        $orphanText = (& wsl.exe -d $Distribution -- sh -lc "pgrep -f -x '$wexe' || true") -join "`n"; $orphanProcessIds = @($orphanText -split '\r?\n' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }); if ($orphanProcessIds.Count -ne 0) { Add-Failure 'L08_ORPHAN_PROCESS' }
    }
} catch { Add-Failure 'L08_RUNNER_EXCEPTION' }

$inputDrift = @(); foreach ($path in $inputs) { $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/'); if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative } }; if ($inputDrift.Count -ne 0) { Add-Failure 'L08_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion = 1; caseId = 'L08'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }; compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes; formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode; run = $run; orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures) }
$json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false)); if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "L08 result schema failure: $resultPath" }; if ($record.status -cne 'passed') { throw "L08 failed: $($record.failureIds -join ', '); result=$resultPath" }; Write-Host "[socket completion L08] PASS result=$resultPath"
