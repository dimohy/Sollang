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
$source = Join-Path $root 'examples/regression/1829-map-function-return.slg'
$readSource = Join-Path $root 'examples/regression/1831-map-read-function-return.slg'
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clang = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C515 output already exists: $output" }
$inputs = @($managed, $selfhost, $source, $readSource, $llvmAs, $clang, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'))
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C515_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$managedDir = Join-Path $output 'managed'
$selfhostDir = Join-Path $output 'selfhost'
[IO.Directory]::CreateDirectory($managedDir) | Out-Null
[IO.Directory]::CreateDirectory($selfhostDir) | Out-Null

$managedExe = Join-Path $managedDir 'map-return.exe'
$managedBuild = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $managedExe) `
    -Description 'C515 managed mapped return build'
if ($managedBuild.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $managedExe)) {
    throw "C515_MANAGED_BUILD: $($managedBuild.Stderr)$($managedBuild.Stdout)"
}
$managedRun = Invoke-VerificationProcessCapture -FilePath $managedExe `
    -WorkingDirectory $managedDir -Description 'C515 managed mapped return runtime'

$selfhostEmit = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $source) -Description 'C515 selfhost mapped return emission'
$llvmPath = Join-Path $selfhostDir 'map-return.ll'
[IO.File]::WriteAllText($llvmPath, $selfhostEmit.Stdout, [Text.UTF8Encoding]::new($false))
if ($selfhostEmit.ExitCode -ne 0 -or -not $selfhostEmit.Stdout.Contains('target triple')) {
    throw "C515_SELFHOST_EMISSION: $($selfhostEmit.Stderr)$($selfhostEmit.Stdout)"
}
$llvmAssembly = Invoke-VerificationProcessCapture -FilePath $llvmAs `
    -ArgumentList @($llvmPath, '-o', (Join-Path $selfhostDir 'map-return.bc')) `
    -Description 'C515 selfhost LLVM assembly'
if ($llvmAssembly.ExitCode -ne 0) { throw "C515_LLVM_ASSEMBLY: $($llvmAssembly.Stderr)" }
$selfhostExe = Join-Path $selfhostDir 'map-return.exe'
$link = Invoke-VerificationProcessCapture -FilePath $clang `
    -ArgumentList @('-O0', '-Wno-override-module', $llvmPath, '-o', $selfhostExe) `
    -Description 'C515 selfhost native link'
if ($link.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $selfhostExe)) {
    throw "C515_SELFHOST_LINK: $($link.Stderr)"
}
$selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhostExe `
    -WorkingDirectory $selfhostDir -Description 'C515 selfhost mapped return runtime'

$managedData = Join-Path $managedDir 'data.bin'
$selfhostData = Join-Path $selfhostDir 'data.bin'
$managedBytes = if (Test-Path -LiteralPath $managedData) { [IO.File]::ReadAllBytes($managedData) } else { [byte[]]@() }
$selfhostBytes = if (Test-Path -LiteralPath $selfhostData) { [IO.File]::ReadAllBytes($selfhostData) } else { [byte[]]@() }
$writePassed = $managedRun.ExitCode -eq 0 -and $selfhostRun.ExitCode -eq 0 -and
    $managedBytes.Length -eq 16 -and $selfhostBytes.Length -eq 16 -and
    [Convert]::ToHexString($managedBytes) -ceq [Convert]::ToHexString($selfhostBytes) -and
    -not $managedBuild.Stderr.Contains('warning') -and -not $selfhostEmit.Stderr.Contains('warning') -and
    -not $link.Stderr.Contains('warning')

$managedReadDir = Join-Path $output 'managed-read'
$selfhostReadDir = Join-Path $output 'selfhost-read'
[IO.Directory]::CreateDirectory($managedReadDir) | Out-Null
[IO.Directory]::CreateDirectory($selfhostReadDir) | Out-Null
$readInput = [byte[]](7, 0, 0, 0)
[IO.File]::WriteAllBytes((Join-Path $managedReadDir 'data.bin'), $readInput)
[IO.File]::WriteAllBytes((Join-Path $selfhostReadDir 'data.bin'), $readInput)
$managedReadExe = Join-Path $managedReadDir 'map-read-return.exe'
$managedReadBuild = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $readSource, '--target', 'windows-x64', '-o', $managedReadExe) `
    -Description 'C515 managed read map return build'
if ($managedReadBuild.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $managedReadExe)) {
    throw "C515_MANAGED_READ_BUILD: $($managedReadBuild.Stderr)$($managedReadBuild.Stdout)"
}
$managedReadRun = Invoke-VerificationProcessCapture -FilePath $managedReadExe `
    -WorkingDirectory $managedReadDir -Description 'C515 managed read map runtime'
$selfhostReadEmit = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $readSource) -Description 'C515 selfhost read map emission'
$readLlvmPath = Join-Path $selfhostReadDir 'map-read-return.ll'
[IO.File]::WriteAllText($readLlvmPath, $selfhostReadEmit.Stdout, [Text.UTF8Encoding]::new($false))
if ($selfhostReadEmit.ExitCode -ne 0 -or -not $selfhostReadEmit.Stdout.Contains('target triple')) {
    throw "C515_SELFHOST_READ_EMISSION: $($selfhostReadEmit.Stderr)$($selfhostReadEmit.Stdout)"
}
$readAssembly = Invoke-VerificationProcessCapture -FilePath $llvmAs `
    -ArgumentList @($readLlvmPath, '-o', (Join-Path $selfhostReadDir 'map-read-return.bc')) `
    -Description 'C515 read map LLVM assembly'
if ($readAssembly.ExitCode -ne 0) { throw "C515_READ_LLVM_ASSEMBLY: $($readAssembly.Stderr)" }
$selfhostReadExe = Join-Path $selfhostReadDir 'map-read-return.exe'
$readLink = Invoke-VerificationProcessCapture -FilePath $clang `
    -ArgumentList @('-O0', '-Wno-override-module', $readLlvmPath, '-o', $selfhostReadExe) `
    -Description 'C515 read map native link'
if ($readLink.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $selfhostReadExe)) {
    throw "C515_SELFHOST_READ_LINK: $($readLink.Stderr)"
}
$selfhostReadRun = Invoke-VerificationProcessCapture -FilePath $selfhostReadExe `
    -WorkingDirectory $selfhostReadDir -Description 'C515 selfhost read map runtime'
$readPassed = $managedReadRun.ExitCode -eq 0 -and $selfhostReadRun.ExitCode -eq 0 -and
    $managedReadRun.Stdout -ceq "byte count=4`n" -and
    $selfhostReadRun.Stdout -ceq $managedReadRun.Stdout -and
    -not $managedReadBuild.Stderr.Contains('warning') -and
    -not $selfhostReadEmit.Stderr.Contains('warning') -and
    -not $readLink.Stderr.Contains('warning')
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
$failures = @()
if (-not $writePassed) { $failures += 'C515_WRITE_MAPPED_RETURN_MISMATCH' }
if (-not $readPassed) { $failures += 'C515_READ_MAPPED_RETURN_MISMATCH' }
if (-not $stable) { $failures += 'C515_INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1
    status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = [int]$writePassed + [int]$readPassed
    total = 2
    inputStable = $stable
    inputHashes = $hashes
    inputHashesEnd = $endHashes
    managedBuildExit = $managedBuild.ExitCode
    managedRuntimeExit = $managedRun.ExitCode
    selfhostEmitExit = $selfhostEmit.ExitCode
    llvmAssemblyExit = $llvmAssembly.ExitCode
    nativeLinkExit = $link.ExitCode
    selfhostRuntimeExit = $selfhostRun.ExitCode
    managedReadBuildExit = $managedReadBuild.ExitCode
    managedReadRuntimeExit = $managedReadRun.ExitCode
    managedReadOutput = $managedReadRun.Stdout
    selfhostReadEmitExit = $selfhostReadEmit.ExitCode
    readAssemblyExit = $readAssembly.ExitCode
    readLinkExit = $readLink.ExitCode
    selfhostReadRuntimeExit = $selfhostReadRun.ExitCode
    selfhostReadOutput = $selfhostReadRun.Stdout
    managedDataSha256 = if ($managedBytes.Length -eq 16) { (Get-FileHash -LiteralPath $managedData -Algorithm SHA256).Hash } else { $null }
    selfhostDataSha256 = if ($selfhostBytes.Length -eq 16) { (Get-FileHash -LiteralPath $selfhostData -Algorithm SHA256).Hash } else { $null }
    failureIds = $failures
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C515 mapped return failed: $($failures -join ', '); result=$result" }
Write-Host "[C515 mapped return] PASS 2/2 cases; result=$result"
