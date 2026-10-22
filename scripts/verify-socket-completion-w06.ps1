[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/w06'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'verification-compiler-build.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-completion-race.slg'
$cancelExpected = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-wins.stdout.txt'
$completionExpected = Join-Path $root 'scripts/probes/socket-completion/w06-completion-wins.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-w06-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @((Join-Path $PSScriptRoot 'verification-process.ps1'), (Join-Path $PSScriptRoot 'verification-compiler-build.ps1'), (Join-Path $PSScriptRoot 'contracts/verification-compiler-build.json'), $PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $cancelExpected, $completionExpected,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "W06 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "W06 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'w06.exe'; $llvm = $exe + '.ll'; $bitcode = Join-Path $output 'w06.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "W06 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
$formatExitCode = $null; $compileExitCode = $null; $compileDiagnosticsClean = $false; $llvmAsExitCode = $null; $closureExitCode = $null
$runs = [Collections.Generic.List[object]]::new(); $orphanProcessIds = @()
$irAssertions = [ordered]@{ cancelCallCount = 0; cancelMarkerPrecedesNativeCancel = $false; completionWonRecognized = $false; successfulCompletionWins = $false; terminalPublishCount = 0; dequeueOwnerTransferVerified = $false; payloadCopyFree = $false }

function Invoke-RaceRun([string]$Variant, [bool]$SendPeerByte, [string]$ExpectedPath) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = [Diagnostics.ProcessStartInfo]@{ FileName = $exe; WorkingDirectory = $root; UseShellExecute = $false; CreateNoWindow = $true; RedirectStandardOutput = $true; RedirectStandardError = $true }
    $peer = $null
    try {
        if (-not $process.Start()) { throw "W06 $Variant process could not start" }
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $portTask = $process.StandardOutput.ReadLineAsync()
        if (-not $portTask.Wait(5000)) { throw "W06 $Variant did not publish peer port" }
        $portLine = $portTask.Result
        if ($portLine -notmatch '^peer-port=(\d+)$') { throw "W06 $Variant unexpected port line: $portLine" }
        $peer = [Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Stream, [Net.Sockets.ProtocolType]::Tcp)
        $peer.Connect([Net.IPAddress]::Loopback, [int]$Matches[1])
        $pendingTask = $process.StandardOutput.ReadLineAsync()
        if (-not $pendingTask.Wait(5000)) { throw "W06 $Variant did not reach pending" }
        $pendingLine = $pendingTask.Result
        $peerSent = if ($SendPeerByte) { $peer.Send([byte[]](77)) } else { 0 }
        if (-not $process.WaitForExit(5000)) { throw "W06 $Variant process did not terminate" }
        $process.WaitForExit()
        $stdout = [string[]](@($pendingLine) + @($process.StandardOutput.ReadToEnd() -split '\r?\n' | Where-Object { $_ -ne '' }))
        $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
        $expected = [string[]]@(Get-Content -LiteralPath $ExpectedPath)
        if ($process.ExitCode -ne 0 -or $stderr.Length -ne 0 -or ($stdout -join "`n") -cne ($expected -join "`n")) { Add-Failure "W06_$($Variant.ToUpperInvariant().Replace('-', '_'))_EXACT" }
        $runs.Add([ordered]@{ variant = $Variant; exitCode = $process.ExitCode; peerSent = $peerSent; stdout = $stdout; stderr = $stderr })
    } finally {
        if ($null -ne $peer) { $peer.Dispose() }
        if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
}

try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Compiler', $compilerPath, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'W06 format' -TimeoutMilliseconds 120000 -ExecutionRecordPath (Join-Path $output 'format.execution.json')
    $formatExitCode = $format.ExitCode; if ($formatExitCode -ne 0) { Add-Failure 'W06_FORMAT' }
    $compile = Invoke-VerificationCompilerBuild -Compiler $compilerPath -Source $fixture -Output $exe -Target 'windows-x64' -WorkingDirectory $root -Description 'W06 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode; $compileText = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'W06_COMPILE' }; if (-not $compileDiagnosticsClean) { Add-Failure 'W06_COMPILE_DIAGNOSTIC' }
    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'W06 llvm-as' -TimeoutMilliseconds 120000 -ExecutionRecordPath (Join-Path $output 'llvm-as.execution.json')
        $llvmAsExitCode = $assembled.ExitCode; if ($llvmAsExitCode -ne 0) { Add-Failure 'W06_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'W06 V004' -TimeoutMilliseconds 120000 -ExecutionRecordPath (Join-Path $output 'v004.execution.json')
        $closureExitCode = $closure.ExitCode; if ($closureExitCode -ne 0) { Add-Failure 'W06_V004' }
        $ir = [IO.File]::ReadAllText($llvm)
        $cancel = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_cancel\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $waiter = [regex]::Match($ir, 'define internal i32 @sollang_socket_completion_waiter\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $dequeue = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_dequeue\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        if ($cancel.Success) { $body = $cancel.Groups['body'].Value; $irAssertions.cancelCallCount = ([regex]::Matches($body, 'call i32 @CancelIoEx')).Count; $irAssertions.cancelMarkerPrecedesNativeCancel = $body.IndexOf('store atomic i32 1, ptr %cancel_requested release', [StringComparison]::Ordinal) -lt $body.IndexOf('call i32 @CancelIoEx', [StringComparison]::Ordinal); $irAssertions.completionWonRecognized = $body.Contains('%completion_won = icmp eq i32 %cancel_error, 1168', [StringComparison]::Ordinal) }
        if ($waiter.Success) { $irAssertions.terminalPublishCount = ([regex]::Matches($waiter.Groups['body'].Value, 'store atomic i64 2, ptr %pending_record release')).Count }
        if ($dequeue.Success) { $body = $dequeue.Groups['body'].Value; $irAssertions.successfulCompletionWins = $body.Contains('%terminal_cancelled = and i1 %cancel_requested_bool, %completion_failed', [StringComparison]::Ordinal); $irAssertions.dequeueOwnerTransferVerified = $body.Contains('store ptr null, ptr %entry_buffer_slot', [StringComparison]::Ordinal) -and $body.Contains('store atomic i64 0, ptr %pending_record release', [StringComparison]::Ordinal) }
        $irAssertions.payloadCopyFree = $dequeue.Success -and $dequeue.Groups['body'].Value -notmatch '@llvm\.(memcpy|memmove)'
        if ($irAssertions.cancelCallCount -ne 1) { Add-Failure 'W06_IR_CANCEL' }; if (-not $irAssertions.cancelMarkerPrecedesNativeCancel) { Add-Failure 'W06_IR_CANCEL_ORDER' }; if (-not $irAssertions.completionWonRecognized) { Add-Failure 'W06_IR_COMPLETION_WON' }; if (-not $irAssertions.successfulCompletionWins) { Add-Failure 'W06_IR_SUCCESS_WINS' }; if ($irAssertions.terminalPublishCount -ne 1) { Add-Failure 'W06_IR_TERMINAL_PUBLISH' }; if (-not $irAssertions.dequeueOwnerTransferVerified) { Add-Failure 'W06_IR_OWNER_TRANSFER' }; if (-not $irAssertions.payloadCopyFree) { Add-Failure 'W06_IR_PAYLOAD_COPY' }
        Invoke-RaceRun -Variant 'cancel-wins' -SendPeerByte $false -ExpectedPath $cancelExpected
        Invoke-RaceRun -Variant 'completion-wins' -SendPeerByte $true -ExpectedPath $completionExpected
    }
} catch { Add-Failure 'W06_RUNNER_EXCEPTION'; [IO.File]::WriteAllText((Join-Path $output 'runner-exception.txt'), $_.Exception.ToString(), [Text.UTF8Encoding]::new($false)) }

$orphanProcessIds = @(Get-CimInstance Win32_Process | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and [IO.Path]::GetFullPath($_.ExecutablePath) -ceq $exe } | ForEach-Object { [int]$_.ProcessId })
if ($orphanProcessIds.Count -ne 0) { Add-Failure 'W06_ORPHAN_PROCESS' }
$inputDrift = @(); foreach ($path in $inputs) { $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/'); if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative } }; if ($inputDrift.Count -ne 0) { Add-Failure 'W06_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion = 1; caseId = 'W06'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }; compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes; formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode; runs = @($runs); orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures) }
$json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "W06 result schema failure: $resultPath" }; if ($record.status -cne 'passed') { throw "W06 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion W06] PASS result=$resultPath"
