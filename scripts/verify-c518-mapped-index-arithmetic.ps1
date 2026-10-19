[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$SelfhostCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$PositiveFixture = 'examples/regression/1836-map-read-return-uintsize-arithmetic-index.slg',
    [string]$NegativeFixture = 'examples/regression/diagnostics/map-index-interpolation-int-arithmetic.slg',
    [string]$AdditionalNegativeFixture = '',
    [string]$ExpectedOutput = 'byte=11',
    [string]$NegativeDiagnostic = 'index must be UIntSize',
    [string[]]$SelfhostAdditionalSources = @(),
    [string[]]$RuntimeArguments = @(),
    [string[]]$NativeLinkLibraries = @(),
    [string]$UnitId = 'C518',
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$managed = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$selfhost = (Resolve-Path -LiteralPath $SelfhostCompiler).Path
$positiveSource = Join-Path $root $PositiveFixture
$negativeSource = Join-Path $root $NegativeFixture
$additionalNegativeSource = if ([string]::IsNullOrWhiteSpace($AdditionalNegativeFixture)) { '' } else {
    Join-Path $root $AdditionalNegativeFixture
}
$selfhostSources = @($SelfhostAdditionalSources | ForEach-Object { Join-Path $root $_ })
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clang = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "$UnitId output already exists: $output" }
$inputs = @($managed, $selfhost, $positiveSource, $negativeSource, $llvmAs, $clang,
    $PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1')) + $selfhostSources
if ($additionalNegativeSource.Length -gt 0) { $inputs += $additionalNegativeSource }
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "${UnitId}_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$managedDir = Join-Path $output 'managed-positive'
$selfhostDir = Join-Path $output 'selfhost-positive'
[IO.Directory]::CreateDirectory($managedDir) | Out-Null
[IO.Directory]::CreateDirectory($selfhostDir) | Out-Null
$data = [byte[]](7, 9, 11, 0)
[IO.File]::WriteAllBytes((Join-Path $managedDir 'data.bin'), $data)
[IO.File]::WriteAllBytes((Join-Path $selfhostDir 'data.bin'), $data)

$managedExe = Join-Path $managedDir 'probe.exe'
$managedBuild = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $positiveSource, '--target', 'windows-x64', '-o', $managedExe) `
    -Description "$UnitId managed mapped index build"
if ($managedBuild.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $managedExe)) {
    throw "${UnitId}_MANAGED_POSITIVE_BUILD: $($managedBuild.Stderr)$($managedBuild.Stdout)"
}
$managedRun = Invoke-VerificationProcessCapture -FilePath $managedExe `
    -ArgumentList $RuntimeArguments -WorkingDirectory $managedDir -Description "$UnitId managed mapped index runtime"
$selfhostEmit = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList (@('windows', $positiveSource) + $selfhostSources) -Description "$UnitId selfhost mapped index emission"
$llvmPath = Join-Path $selfhostDir 'probe.ll'
[IO.File]::WriteAllText($llvmPath, $selfhostEmit.Stdout, [Text.UTF8Encoding]::new($false))
if ($selfhostEmit.ExitCode -ne 0 -or -not $selfhostEmit.Stdout.Contains('target triple')) {
    throw "${UnitId}_SELFHOST_POSITIVE_EMISSION: $($selfhostEmit.Stderr)$($selfhostEmit.Stdout)"
}
$assembly = Invoke-VerificationProcessCapture -FilePath $llvmAs `
    -ArgumentList @($llvmPath, '-o', (Join-Path $selfhostDir 'probe.bc')) `
    -Description "$UnitId selfhost mapped index assembly"
if ($assembly.ExitCode -ne 0) { throw "${UnitId}_POSITIVE_ASSEMBLY: $($assembly.Stderr)" }
$selfhostExe = Join-Path $selfhostDir 'probe.exe'
$link = Invoke-VerificationProcessCapture -FilePath $clang `
    -ArgumentList (@('-O0', '-Wno-override-module', $llvmPath, '-o', $selfhostExe) + $NativeLinkLibraries) `
    -Description "$UnitId selfhost mapped index native link"
if ($link.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $selfhostExe)) {
    throw "${UnitId}_POSITIVE_LINK: $($link.Stderr)"
}
$selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhostExe `
    -ArgumentList $RuntimeArguments -WorkingDirectory $selfhostDir -Description "$UnitId selfhost mapped index runtime"
$positivePassed = $managedRun.ExitCode -eq 0 -and $selfhostRun.ExitCode -eq 0 -and
    $managedRun.Stdout -ceq "$ExpectedOutput`n" -and $selfhostRun.Stdout -ceq $managedRun.Stdout -and
    -not $managedBuild.Stderr.Contains('warning') -and -not $selfhostEmit.Stderr.Contains('warning') -and
    -not $link.Stderr.Contains('warning')

$negativeProduct = Join-Path $output 'signed-arithmetic.exe'
$managedNegative = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $negativeSource, '--target', 'windows-x64', '-o', $negativeProduct) `
    -Description "$UnitId managed invalid mapped index type"
$selfhostNegative = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList (@('windows', $negativeSource) + $selfhostSources) -Description "$UnitId selfhost invalid mapped index type"
$managedNegativeText = $managedNegative.Stdout + $managedNegative.Stderr
$selfhostNegativeText = $selfhostNegative.Stdout + $selfhostNegative.Stderr
$negativePassed = $managedNegative.ExitCode -eq 1 -and $selfhostNegative.ExitCode -eq 1 -and
    $managedNegativeText.Contains($NegativeDiagnostic, [StringComparison]::Ordinal) -and
    $selfhostNegativeText.Contains($NegativeDiagnostic, [StringComparison]::Ordinal) -and
    -not $selfhostNegativeText.Contains('target triple') -and -not (Test-Path -LiteralPath $negativeProduct)
$additionalNegativePassed = $false
$managedAdditional = $null
$selfhostAdditional = $null
if ($additionalNegativeSource.Length -gt 0) {
    $additionalProduct = Join-Path $output 'additional-invalid-index.exe'
    $managedAdditional = Invoke-VerificationProcessCapture -FilePath $managed `
        -ArgumentList @('build', $additionalNegativeSource, '--target', 'windows-x64', '-o', $additionalProduct) `
        -Description "$UnitId managed additional invalid mapped index"
    $selfhostAdditional = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList (@('windows', $additionalNegativeSource) + $selfhostSources) `
        -Description "$UnitId selfhost additional invalid mapped index"
    $managedAdditionalText = $managedAdditional.Stdout + $managedAdditional.Stderr
    $selfhostAdditionalText = $selfhostAdditional.Stdout + $selfhostAdditional.Stderr
    $additionalNegativePassed = $managedAdditional.ExitCode -eq 1 -and $selfhostAdditional.ExitCode -eq 1 -and
        $managedAdditionalText.Contains($NegativeDiagnostic, [StringComparison]::Ordinal) -and
        $selfhostAdditionalText.Contains($NegativeDiagnostic, [StringComparison]::Ordinal) -and
        -not $selfhostAdditionalText.Contains('target triple') -and -not (Test-Path -LiteralPath $additionalProduct)
}
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
$failures = @()
if (-not $positivePassed) { $failures += "${UnitId}_POSITIVE_MISMATCH" }
if (-not $negativePassed) { $failures += "${UnitId}_NEGATIVE_MISMATCH" }
if ($additionalNegativeSource.Length -gt 0 -and -not $additionalNegativePassed) {
    $failures += "${UnitId}_ADDITIONAL_NEGATIVE_MISMATCH"
}
if (-not $stable) { $failures += "${UnitId}_INPUT_DRIFT" }
$total = 2 + [int]($additionalNegativeSource.Length -gt 0)
$record = [ordered]@{
    schemaVersion = 1
    unit = $UnitId
    status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = [int]$positivePassed + [int]$negativePassed + [int]$additionalNegativePassed
    total = $total
    inputStable = $stable
    negativeDiagnostic = $NegativeDiagnostic
    nativeLinkLibraries = $NativeLinkLibraries
    inputHashes = $hashes
    inputHashesEnd = $endHashes
    managedPositiveBuildExit = $managedBuild.ExitCode
    selfhostPositiveEmitExit = $selfhostEmit.ExitCode
    llvmAssemblyExit = $assembly.ExitCode
    nativeLinkExit = $link.ExitCode
    managedPositiveRuntimeExit = $managedRun.ExitCode
    selfhostPositiveRuntimeExit = $selfhostRun.ExitCode
    managedPositiveOutput = $managedRun.Stdout
    selfhostPositiveOutput = $selfhostRun.Stdout
    managedNegativeExit = $managedNegative.ExitCode
    selfhostNegativeExit = $selfhostNegative.ExitCode
    managedNegativeText = $managedNegativeText
    selfhostNegativeText = $selfhostNegativeText
    managedAdditionalExit = if ($null -ne $managedAdditional) { $managedAdditional.ExitCode } else { $null }
    selfhostAdditionalExit = if ($null -ne $selfhostAdditional) { $selfhostAdditional.ExitCode } else { $null }
    failureIds = $failures
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "$UnitId mapped index pair failed: $($failures -join ', '); result=$result" }
Write-Host "[$UnitId mapped index pair] PASS $total/$total cases; result=$result"
