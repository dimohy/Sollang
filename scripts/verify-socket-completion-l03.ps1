[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$Distribution = 'Ubuntu',
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/l03'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/l03-partial-send.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/l03-partial-send.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-l03-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @($PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "L03 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "L03 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'l03'; $llvm = Join-Path $output 'l03.ll'; $bitcode = Join-Path $output 'l03.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "L03 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
function Get-FunctionBody([string]$Ir, [string]$Name) {
    $escaped = [regex]::Escape($Name)
    $match = [regex]::Match($Ir, "(?m)^define internal [^\r\n]+ @$escaped\([^\r\n]*\) #0 \{(?<body>.*?)\r?\n\}", [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Groups['body'].Value }
    return ''
}
$formatExitCode = $null; $compileExitCode = $null; $compileDiagnosticsClean = $false; $llvmAsExitCode = $null; $closureExitCode = $null; $nativeExitCode = $null
$stdout = @(); $stderr = ''; $orphanProcessIds = @()
$irAssertions = [ordered]@{ directSendPresent = $false; rangeOffsetApplied = $false; rangeLengthApplied = $false; payloadCopyFree = $false; ownerTransferVerified = $false }
try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'L03 format' -TimeoutMilliseconds 120000
    $formatExitCode = $format.ExitCode; if ($formatExitCode -ne 0) { Add-Failure 'L03_FORMAT' }
    $compile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath, 'build', $fixture, '-o', $exe, '--target', 'linux-x64', '-O0', '--keep-temps') -WorkingDirectory $root -Description 'L03 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode; $compileText = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'L03_COMPILE' }
    if (-not $compileDiagnosticsClean) { Add-Failure 'L03_COMPILE_DIAGNOSTIC' }
    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'L03 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode = $assembled.ExitCode; if ($llvmAsExitCode -ne 0) { Add-Failure 'L03_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'L03 V004' -TimeoutMilliseconds 120000
        $closureExitCode = $closure.ExitCode; if ($closureExitCode -ne 0) { Add-Failure 'L03_V004' }
        $ir = [IO.File]::ReadAllText($llvm)
        $submit = Get-FunctionBody $ir 'sollang_platform_socket_completion_submit'
        $waiter = Get-FunctionBody $ir 'sollang_socket_completion_waiter'
        $dequeue = Get-FunctionBody $ir 'sollang_platform_socket_completion_dequeue'
        $irAssertions.directSendPresent = $submit.Contains('call i64 @send(i32 %registered_socket, ptr %data, i64 %range_length, i32 0)', [StringComparison]::Ordinal)
        $irAssertions.rangeOffsetApplied = $submit.Contains('getelementptr i8, ptr %buffer, i64 %range_offset', [StringComparison]::Ordinal)
        $irAssertions.rangeLengthApplied = $submit.Contains('i64 %range_length, i32 0)', [StringComparison]::Ordinal)
        $irAssertions.payloadCopyFree = ($submit + $waiter + $dequeue) -notmatch '@llvm\.(?:memcpy|memmove)'
        $irAssertions.ownerTransferVerified = $dequeue.Contains('store ptr %entry_buffer, ptr %descriptor_buffer_slot', [StringComparison]::Ordinal) -and $dequeue.Contains('store ptr null, ptr %entry_buffer_slot', [StringComparison]::Ordinal)
        foreach ($entry in $irAssertions.GetEnumerator()) { if (-not $entry.Value) { Add-Failure ("L03_IR_" + $entry.Key.ToUpperInvariant()) } }
        $wslExe = (& wsl.exe -d $Distribution -- wslpath -a ($exe.Replace('\', '/'))).Trim()
        $native = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d', $Distribution, '--', $wslExe) -WorkingDirectory $root -Description 'L03 native' -TimeoutMilliseconds 20000
        $nativeExitCode = $native.ExitCode; $stdout = [string[]]@($native.Stdout -split '\r?\n' | Where-Object { $_ -ne '' }); $stderr = $native.Stderr.Trim()
        $expected = [string[]]@(Get-Content -LiteralPath $expectedPath)
        if ($nativeExitCode -ne 0 -or $stderr.Length -ne 0 -or ($stdout -join "`n") -cne ($expected -join "`n")) { Add-Failure 'L03_EXACT' }
        $orphanText = (& wsl.exe -d $Distribution -- sh -lc "pgrep -f -x '$wslExe' || true") -join "`n"
        $orphanProcessIds = @($orphanText -split '\r?\n' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
        if ($orphanProcessIds.Count -ne 0) { Add-Failure 'L03_ORPHAN_PROCESS' }
    }
} catch { Add-Failure 'L03_RUNNER_EXCEPTION' }
$inputDrift = @(); foreach ($path in $inputs) { $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/'); if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative } }
if ($inputDrift.Count -ne 0) { Add-Failure 'L03_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion = 1; caseId = 'L03'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }; compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes; formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode; nativeExitCode = $nativeExitCode; stdout = $stdout; stderr = $stderr; orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures) }
$json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "L03 result schema failure: $resultPath" }
if ($record.status -cne 'passed') { throw "L03 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion L03] PASS result=$resultPath"
