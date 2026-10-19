[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$SelfhostCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$managed = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$selfhost = (Resolve-Path -LiteralPath $SelfhostCompiler).Path
$source = Join-Path $root 'examples/regression/1833-map-read-return-index-interpolation.slg'
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clang = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C516 output already exists: $output" }
$inputs = @($managed, $selfhost, $source, $llvmAs, $clang, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'))
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C516_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$managedDir = Join-Path $output 'managed'
$selfhostDir = Join-Path $output 'selfhost'
[IO.Directory]::CreateDirectory($managedDir) | Out-Null
[IO.Directory]::CreateDirectory($selfhostDir) | Out-Null
$inputBytes = [byte[]](7, 0, 0, 0)
[IO.File]::WriteAllBytes((Join-Path $managedDir 'data.bin'), $inputBytes)
[IO.File]::WriteAllBytes((Join-Path $selfhostDir 'data.bin'), $inputBytes)

$managedExe = Join-Path $managedDir 'probe.exe'
$managedBuild = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $managedExe) `
    -Description 'C516 managed mapped index interpolation build'
if ($managedBuild.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $managedExe)) {
    throw "C516_MANAGED_BUILD: $($managedBuild.Stderr)$($managedBuild.Stdout)"
}
$managedRun = Invoke-VerificationProcessCapture -FilePath $managedExe `
    -WorkingDirectory $managedDir -Description 'C516 managed mapped index interpolation runtime'

$selfhostEmit = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $source) -Description 'C516 selfhost mapped index interpolation emission'
$llvmPath = Join-Path $selfhostDir 'probe.ll'
[IO.File]::WriteAllText($llvmPath, $selfhostEmit.Stdout, [Text.UTF8Encoding]::new($false))
if ($selfhostEmit.ExitCode -ne 0 -or -not $selfhostEmit.Stdout.Contains('target triple')) {
    throw "C516_SELFHOST_EMISSION: $($selfhostEmit.Stderr)$($selfhostEmit.Stdout)"
}
$assembly = Invoke-VerificationProcessCapture -FilePath $llvmAs `
    -ArgumentList @($llvmPath, '-o', (Join-Path $selfhostDir 'probe.bc')) `
    -Description 'C516 selfhost LLVM assembly'
if ($assembly.ExitCode -ne 0) { throw "C516_LLVM_ASSEMBLY: $($assembly.Stderr)" }
$selfhostExe = Join-Path $selfhostDir 'probe.exe'
$link = Invoke-VerificationProcessCapture -FilePath $clang `
    -ArgumentList @('-O0', '-Wno-override-module', $llvmPath, '-o', $selfhostExe) `
    -Description 'C516 selfhost native link'
if ($link.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $selfhostExe)) {
    throw "C516_SELFHOST_LINK: $($link.Stderr)"
}
$selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhostExe `
    -WorkingDirectory $selfhostDir -Description 'C516 selfhost mapped index interpolation runtime'
$passed = $managedRun.ExitCode -eq 0 -and $selfhostRun.ExitCode -eq 0 -and
    $managedRun.Stdout -ceq "byte=7`n" -and $selfhostRun.Stdout -ceq $managedRun.Stdout -and
    $selfhostEmit.Stdout.Contains('_in_bounds = icmp ult i64') -and
    $selfhostEmit.Stdout.Contains('_mapped0_invalid:') -and
    $selfhostEmit.Stdout.Contains(' = load i8, ptr %v9_expression0_ptr, align 1') -and
    -not $managedBuild.Stderr.Contains('warning') -and -not $selfhostEmit.Stderr.Contains('warning') -and
    -not $link.Stderr.Contains('warning')
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
$failures = @()
if (-not $passed) { $failures += 'C516_MAPPED_INDEX_INTERPOLATION_MISMATCH' }
if (-not $stable) { $failures += 'C516_INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1
    status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = [int]$passed
    total = 1
    inputStable = $stable
    inputHashes = $hashes
    inputHashesEnd = $endHashes
    managedBuildExit = $managedBuild.ExitCode
    selfhostEmitExit = $selfhostEmit.ExitCode
    llvmAssemblyExit = $assembly.ExitCode
    nativeLinkExit = $link.ExitCode
    managedRuntimeExit = $managedRun.ExitCode
    selfhostRuntimeExit = $selfhostRun.ExitCode
    managedOutput = $managedRun.Stdout
    selfhostOutput = $selfhostRun.Stdout
    failureIds = $failures
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C516 mapped index interpolation failed: $($failures -join ', '); result=$result" }
Write-Host "[C516 mapped index interpolation] PASS 1/1 case; result=$result"
