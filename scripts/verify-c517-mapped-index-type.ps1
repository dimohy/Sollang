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
$source = Join-Path $root 'examples/regression/diagnostics/map-index-interpolation-int.slg'
$conversionSource = Join-Path $root 'examples/regression/diagnostics/map-index-interpolation-int-conversion.slg'
$golden = Join-Path $root 'examples/regression/diagnostics/map-index-interpolation-int.stderr.contains.txt'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C517 output already exists: $output" }
$inputs = @($managed, $selfhost, $source, $conversionSource, $golden, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'))
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C517_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$product = Join-Path $output 'signed-index.exe'
$managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $product) `
    -Description 'C517 managed mapped interpolation index type'
$selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $source) -Description 'C517 selfhost mapped interpolation index type'
$conversionProduct = Join-Path $output 'signed-conversion-index.exe'
$managedConversion = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $conversionSource, '--target', 'windows-x64', '-o', $conversionProduct) `
    -Description 'C517 managed mapped interpolation conversion index type'
$selfhostConversion = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $conversionSource) -Description 'C517 selfhost mapped interpolation conversion index type'
$expected = [IO.File]::ReadAllText($golden).Trim()
$managedText = $managedRun.Stdout + $managedRun.Stderr
$selfhostText = $selfhostRun.Stdout + $selfhostRun.Stderr
$managedConversionText = $managedConversion.Stdout + $managedConversion.Stderr
$selfhostConversionText = $selfhostConversion.Stdout + $selfhostConversion.Stderr
$bindingPassed = $managedRun.ExitCode -eq 1 -and $selfhostRun.ExitCode -eq 1 -and
    $managedText.Contains($expected, [StringComparison]::Ordinal) -and
    $selfhostText.Contains($expected, [StringComparison]::Ordinal) -and
    -not $selfhostText.Contains('target triple') -and
    -not (Test-Path -LiteralPath $product)
$conversionPassed = $managedConversion.ExitCode -eq 1 -and $selfhostConversion.ExitCode -eq 1 -and
    $managedConversionText.Contains($expected, [StringComparison]::Ordinal) -and
    $selfhostConversionText.Contains($expected, [StringComparison]::Ordinal) -and
    -not $selfhostConversionText.Contains('target triple') -and
    -not (Test-Path -LiteralPath $conversionProduct)
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
$failures = @()
if (-not $bindingPassed) { $failures += 'C517_MAPPED_INDEX_BINDING_TYPE_MISMATCH' }
if (-not $conversionPassed) { $failures += 'C517_MAPPED_INDEX_CONVERSION_TYPE_MISMATCH' }
if (-not $stable) { $failures += 'C517_INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1
    status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = [int]$bindingPassed + [int]$conversionPassed
    total = 2
    inputStable = $stable
    inputHashes = $hashes
    inputHashesEnd = $endHashes
    managedExit = $managedRun.ExitCode
    selfhostExit = $selfhostRun.ExitCode
    managedText = $managedText
    selfhostText = $selfhostText
    managedConversionExit = $managedConversion.ExitCode
    selfhostConversionExit = $selfhostConversion.ExitCode
    managedConversionText = $managedConversionText
    selfhostConversionText = $selfhostConversionText
    failureIds = $failures
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C517 mapped index type failed: $($failures -join ', '); result=$result" }
Write-Host "[C517 mapped index type] PASS 2/2 cases; result=$result"
