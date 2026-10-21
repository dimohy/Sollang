[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$Distribution = 'Ubuntu',
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/l06'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-completion-race.slg'
$cancelExpected = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-wins.stdout.txt'
$completionExpected = Join-Path $root 'scripts/probes/socket-completion/w06-completion-wins.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-l06-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @($PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $cancelExpected, $completionExpected,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "L06 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "L06 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'l06'; $llvm = Join-Path $output 'l06.ll'; $bitcode = Join-Path $output 'l06.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "L06 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
function Get-FunctionBody([string]$Ir, [string]$Name) {
    $escaped = [regex]::Escape($Name)
    $match = [regex]::Match($Ir, "(?m)^define internal [^\r\n]+ @$escaped\([^\r\n]*\) #0 \{(?<body>.*?)\r?\n\}", [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Groups['body'].Value }
    return ''
}

$formatExitCode = $null; $compileExitCode = $null; $compileDiagnosticsClean = $false; $llvmAsExitCode = $null; $closureExitCode = $null
$runs = [Collections.Generic.List[object]]::new(); $orphanProcessIds = @()
$irAssertions = [ordered]@{ cancelRequestRelease = $false; eventfdWake = $false; completionWinnerPreserved = $false; cancellationPublishCount = 0; successfulCompletionWins = $false; dequeueOwnerTransferVerified = $false; payloadCopyFree = $false }

function Invoke-RaceRun([string]$Variant, [bool]$SendPeerByte, [string]$ExpectedPath, [string]$WslExe) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = [Diagnostics.ProcessStartInfo]@{ FileName = 'wsl.exe'; WorkingDirectory = $root; UseShellExecute = $false; CreateNoWindow = $true; RedirectStandardOutput = $true; RedirectStandardError = $true }
    foreach ($argument in @('-d', $Distribution, '--', $WslExe)) { $process.StartInfo.ArgumentList.Add($argument) }
    $peer = $null
    try {
        if (-not $process.Start()) { throw "L06 $Variant process could not start" }
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $portTask = $process.StandardOutput.ReadLineAsync()
        if (-not $portTask.Wait(5000)) { throw "L06 $Variant did not publish peer port" }
        $portLine = $portTask.Result
        if ($portLine -notmatch '^peer-port=(\d+)$') { throw "L06 $Variant unexpected port line: $portLine" }
        $peer = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Stream, [Net.Sockets.ProtocolType]::Tcp)
        $peer.Connect([Net.IPAddress]::Loopback, [int]$Matches[1])
        $pendingTask = $process.StandardOutput.ReadLineAsync()
        if (-not $pendingTask.Wait(5000)) { throw "L06 $Variant did not reach pending" }
        $pendingLine = $pendingTask.Result
        $peerSent = if ($SendPeerByte) { $peer.Send([byte[]](77)) } else { 0 }
        if (-not $process.WaitForExit(10000)) { throw "L06 $Variant process did not terminate" }
        $process.WaitForExit()
        $stdout = [string[]](@($pendingLine) + @($process.StandardOutput.ReadToEnd() -split '\r?\n' | Where-Object { $_ -ne '' }))
        $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
        $expected = [string[]]@(Get-Content -LiteralPath $ExpectedPath)
        if ($process.ExitCode -ne 0 -or $stderr.Length -ne 0 -or ($stdout -join "`n") -cne ($expected -join "`n")) { Add-Failure "L06_$($Variant.ToUpperInvariant().Replace('-', '_'))_EXACT" }
        $runs.Add([ordered]@{ variant = $Variant; exitCode = $process.ExitCode; peerSent = $peerSent; stdout = $stdout; stderr = $stderr })
    } finally {
        if ($null -ne $peer) { $peer.Dispose() }
        if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
}

try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'L06 format' -TimeoutMilliseconds 120000
    $formatExitCode = $format.ExitCode; if ($formatExitCode -ne 0) { Add-Failure 'L06_FORMAT' }
    $compile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath, 'build', $fixture, '-o', $exe, '--target', 'linux-x64', '-O0', '--keep-temps') -WorkingDirectory $root -Description 'L06 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode; $compileText = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'L06_COMPILE' }; if (-not $compileDiagnosticsClean) { Add-Failure 'L06_COMPILE_DIAGNOSTIC' }
    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'L06 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode = $assembled.ExitCode; if ($llvmAsExitCode -ne 0) { Add-Failure 'L06_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'L06 V004' -TimeoutMilliseconds 120000
        $closureExitCode = $closure.ExitCode; if ($closureExitCode -ne 0) { Add-Failure 'L06_V004' }
        $ir = [IO.File]::ReadAllText($llvm); $cancel = Get-FunctionBody $ir 'sollang_platform_socket_completion_cancel_locked'; $waiter = Get-FunctionBody $ir 'sollang_socket_completion_waiter'; $dequeue = Get-FunctionBody $ir 'sollang_platform_socket_completion_dequeue_locked'
        $irAssertions.cancelRequestRelease = $cancel.Contains('store atomic i32 1, ptr %cancel_requested release', [StringComparison]::Ordinal)
        $irAssertions.eventfdWake = $cancel.Contains('call i64 @write(i32 %wakeup, ptr %signal, i64 8)', [StringComparison]::Ordinal)
        $irAssertions.completionWinnerPreserved = $cancel.Contains('%is_terminal = icmp eq i64 %active, 2', [StringComparison]::Ordinal) -and $cancel.Contains('br i1 %is_terminal, label %success, label %not_found', [StringComparison]::Ordinal)
        $irAssertions.cancellationPublishCount = ([regex]::Matches($waiter, 'call void @sollang_socket_completion_publish_locked\(ptr %state, ptr %cancel_entry, i32 125, i64 0\)')).Count
        $irAssertions.successfulCompletionWins = $dequeue.Contains('%terminal_cancelled = and i1 %cancel_requested_bool, %completion_failed', [StringComparison]::Ordinal)
        $irAssertions.dequeueOwnerTransferVerified = $dequeue.Contains('store ptr null, ptr %entry_buffer_slot', [StringComparison]::Ordinal) -and $dequeue.Contains('store atomic i64 0, ptr %pending_record release', [StringComparison]::Ordinal)
        $irAssertions.payloadCopyFree = ($waiter + $dequeue) -notmatch '@llvm\.(?:memcpy|memmove)'
        foreach ($entry in $irAssertions.GetEnumerator()) { if (($entry.Key -ceq 'cancellationPublishCount' -and $entry.Value -ne 1) -or ($entry.Key -cne 'cancellationPublishCount' -and -not $entry.Value)) { Add-Failure ("L06_IR_" + $entry.Key.ToUpperInvariant()) } }
        $wexe = (& wsl.exe -d $Distribution -- wslpath -a ($exe.Replace('\', '/'))).Trim()
        Invoke-RaceRun -Variant 'cancel-wins' -SendPeerByte $false -ExpectedPath $cancelExpected -WslExe $wexe
        Invoke-RaceRun -Variant 'completion-wins' -SendPeerByte $true -ExpectedPath $completionExpected -WslExe $wexe
        $orphanText = (& wsl.exe -d $Distribution -- sh -lc "pgrep -f -x '$wexe' || true") -join "`n"
        $orphanProcessIds = @($orphanText -split '\r?\n' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
        if ($orphanProcessIds.Count -ne 0) { Add-Failure 'L06_ORPHAN_PROCESS' }
    }
} catch { Add-Failure 'L06_RUNNER_EXCEPTION' }

$inputDrift = @(); foreach ($path in $inputs) { $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/'); if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative } }; if ($inputDrift.Count -ne 0) { Add-Failure 'L06_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion = 1; caseId = 'L06'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }; compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes; formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode; runs = @($runs); orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures) }
$json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "L06 result schema failure: $resultPath" }; if ($record.status -cne 'passed') { throw "L06 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion L06] PASS result=$resultPath"
