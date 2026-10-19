[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$Distribution = 'Ubuntu',
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/l01'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/l01-direct-receive.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/l01-direct-receive.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-l01-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @($PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "L01 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "L01 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'l01'; $llvm = Join-Path $output 'l01.ll'; $bitcode = Join-Path $output 'l01.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "L01 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
$formatExitCode = $null; $compileExitCode = $null; $compileDiagnosticsClean = $false; $llvmAsExitCode = $null; $closureExitCode = $null; $nativeExitCode = $null
$stdout = @(); $stderr = ''; $orphanProcessIds = @()
$irAssertions = [ordered]@{ pollDeclarationCount = 0; nonblockingPrecedesEpoll = $false; directReceivePresent = $false; directSendPresent = $false; wouldBlockPreservesPendingOwner = $false; payloadCopyFree = $false; registrationOwnerRetainedUntilClose = $false }

try {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $fixture) -WorkingDirectory $root -Description 'L01 format' -TimeoutMilliseconds 120000
    $formatExitCode = $format.ExitCode; if ($formatExitCode -ne 0) { Add-Failure 'L01_FORMAT' }
    $compile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath, 'build', $fixture, '-o', $exe, '--target', 'linux-x64', '-O0', '--keep-temps') -WorkingDirectory $root -Description 'L01 compile' -TimeoutMilliseconds 120000
    $compileExitCode = $compile.ExitCode; $compileText = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText, '(?im)^(warning|note|error)\b')
    if ($compileExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) { Add-Failure 'L01_COMPILE' }
    if (-not $compileDiagnosticsClean) { Add-Failure 'L01_COMPILE_DIAGNOSTIC' }
    if ($compileExitCode -eq 0 -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
        $assembled = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'L01 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode = $assembled.ExitCode; if ($llvmAsExitCode -ne 0) { Add-Failure 'L01_LLVM_AS' }
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'L01 V004' -TimeoutMilliseconds 120000
        $closureExitCode = $closure.ExitCode; if ($closureExitCode -ne 0) { Add-Failure 'L01_V004' }
        $ir = [IO.File]::ReadAllText($llvm)
        $submit = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_submit\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $close = [regex]::Match($ir, 'define internal void @sollang_platform_socket_completion_close\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
        $irAssertions.pollDeclarationCount = ([regex]::Matches($ir, '(?m)^declare i32 @poll\(')).Count
        if ($submit.Success) {
            $body = $submit.Groups['body'].Value
            $fcntlIndex = $body.IndexOf('@fcntl', [StringComparison]::Ordinal)
            $epollIndex = $body.IndexOf('@epoll_ctl', [StringComparison]::Ordinal)
            $irAssertions.nonblockingPrecedesEpoll = $fcntlIndex -ge 0 -and $epollIndex -gt $fcntlIndex
            $irAssertions.directReceivePresent = $body.Contains('call i64 @recv(', [StringComparison]::Ordinal)
            $irAssertions.directSendPresent = $body.Contains('call i64 @send(', [StringComparison]::Ordinal)
            $irAssertions.wouldBlockPreservesPendingOwner = $body.Contains('%would_block = icmp eq i32 %issue_error, 11', [StringComparison]::Ordinal) -and $body.Contains('store ptr %buffer, ptr %buffer_slot', [StringComparison]::Ordinal) -and $body.Contains('store atomic i64 1, ptr %pending_entry release', [StringComparison]::Ordinal)
            $irAssertions.payloadCopyFree = $body -notmatch '@llvm\.(memcpy|memmove)'
        }
        $irAssertions.registrationOwnerRetainedUntilClose = $close.Success -and $close.Groups['body'].Value.Contains('call i32 @close(i32 %registered_socket)', [StringComparison]::Ordinal) -and $close.Groups['body'].Value.IndexOf('call i32 @close(i32 %registered_socket)', [StringComparison]::Ordinal) -lt $close.Groups['body'].Value.IndexOf('call void @sollang_free(ptr %registration_table)', [StringComparison]::Ordinal)
        foreach ($entry in $irAssertions.GetEnumerator()) { if (($entry.Value -is [bool]) -and -not $entry.Value) { Add-Failure ("L01_IR_" + $entry.Key.ToUpperInvariant()) } }
        if ($irAssertions.pollDeclarationCount -ne 1) { Add-Failure 'L01_IR_POLL_DECLARATION' }

        $wslExe = (& wsl.exe -d $Distribution -- wslpath -a ($exe.Replace('\', '/'))).Trim()
        $native = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d', $Distribution, '--', $wslExe) -WorkingDirectory $root -Description 'L01 native' -TimeoutMilliseconds 20000
        $nativeExitCode = $native.ExitCode; $stdout = [string[]]@($native.Stdout -split '\r?\n' | Where-Object { $_ -ne '' }); $stderr = $native.Stderr.Trim()
        $expected = [string[]]@(Get-Content -LiteralPath $expectedPath)
        if ($nativeExitCode -ne 0 -or $stderr.Length -ne 0 -or ($stdout -join "`n") -cne ($expected -join "`n")) { Add-Failure 'L01_EXACT' }
        $orphanText = (& wsl.exe -d $Distribution -- sh -lc "pgrep -f -x '$wslExe' || true") -join "`n"
        $orphanProcessIds = @($orphanText -split '\r?\n' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
        if ($orphanProcessIds.Count -ne 0) { Add-Failure 'L01_ORPHAN_PROCESS' }
    }
} catch { Add-Failure 'L01_RUNNER_EXCEPTION' }

$inputDrift = @(); foreach ($path in $inputs) { $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/'); if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift += $relative } }
if ($inputDrift.Count -ne 0) { Add-Failure 'L01_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion = 1; caseId = 'L01'; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }; compilerSha256 = $compilerSha256; inputStable = $inputDrift.Count -eq 0; inputDrift = $inputDrift; inputHashes = $inputHashes; formatExitCode = $formatExitCode; compileExitCode = $compileExitCode; compileDiagnosticsClean = $compileDiagnosticsClean; llvmAsExitCode = $llvmAsExitCode; closureExitCode = $closureExitCode; nativeExitCode = $nativeExitCode; stdout = $stdout; stderr = $stderr; orphanProcessIds = $orphanProcessIds; irAssertions = $irAssertions; failureIds = @($failures) }
$json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schemaPath)) { throw "L01 result schema failure: $resultPath" }
if ($record.status -cne 'passed') { throw "L01 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion L01] PASS result=$resultPath"
