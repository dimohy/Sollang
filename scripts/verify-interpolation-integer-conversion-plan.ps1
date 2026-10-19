[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$managedPath = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs'
$selfhostPath = Join-Path $root 'selfhost/llvm/text/foundation.slg'
$selfhostSignedPath = Join-Path $root 'selfhost/llvm/text/ownership.slg'
$managed = Get-Content -LiteralPath $managedPath -Raw
$selfhost = Get-Content -LiteralPath $selfhostPath -Raw
$selfhostSigned = Get-Content -LiteralPath $selfhostSignedPath -Raw
$requiredManaged = @(
    'EmitCheckedIntegerConversion(checkedInteger, targetType)',
    'sourceMin < targetMin',
    'sourceMax > targetMax',
    'targetType == BoundType.CodePoint && sourceMax >= 0xD800 && sourceMin <= 0xDFFF'
)
$requiredSelfhost = @(
    'sourceSigned and (not targetSigned or sourceWidth > targetWidth!)',
    'sourceUpperBits! > targetUpperBits!',
    'targetBuiltin == 14 and sourceUpperBits! >= 16',
    'emitInterpolationIntegerConversionChecks(nodeIndex, nodes, sourceModule, ownerIndex, beforeIndex, context, state)'
)
foreach ($marker in $requiredManaged) {
    if (-not $managed.Contains($marker, [StringComparison]::Ordinal)) { throw "C# range decision missing: $marker" }
}
foreach ($marker in $requiredSelfhost) {
    if (-not $selfhost.Contains($marker, [StringComparison]::Ordinal)) { throw "SLG range decision missing: $marker" }
}
if (-not $selfhostSigned.Contains('symbol == 7 or symbol == 12', [StringComparison]::Ordinal)) {
    throw 'SLG signedness decision must include Size'
}

# Builtin symbol, underlying bit width (0 means pointer width), and signedness.
$types = @(
    @{ symbol = 2; width = 32; signed = $true }, @{ symbol = 3; width = 8; signed = $true },
    @{ symbol = 4; width = 16; signed = $true }, @{ symbol = 5; width = 32; signed = $true },
    @{ symbol = 6; width = 64; signed = $true }, @{ symbol = 7; width = 64; signed = $true },
    @{ symbol = 8; width = 8; signed = $false }, @{ symbol = 9; width = 16; signed = $false },
    @{ symbol = 10; width = 32; signed = $false }, @{ symbol = 11; width = 64; signed = $false },
    @{ symbol = 12; width = 0; signed = $true }, @{ symbol = 13; width = 0; signed = $false },
    @{ symbol = 14; width = 32; signed = $false }
)

$differences = [System.Collections.Generic.List[string]]::new()
$total = 0
foreach ($pointerWidth in @(32, 64)) {
    foreach ($source in $types) {
        foreach ($target in $types) {
            $sourceWidth = if ($source.width -eq 0) { $pointerWidth } else { $source.width }
            $targetWidth = if ($target.width -eq 0) { $pointerWidth } else { $target.width }
            $sourceMin = if ($source.symbol -eq 14) { [Numerics.BigInteger]::Zero }
                elseif ($source.signed) { -[Numerics.BigInteger]::Pow(2, $sourceWidth - 1) }
                else { [Numerics.BigInteger]::Zero }
            $sourceMax = if ($source.symbol -eq 14) { [Numerics.BigInteger]1114111 }
                elseif ($source.signed) { [Numerics.BigInteger]::Pow(2, $sourceWidth - 1) - 1 }
                else { [Numerics.BigInteger]::Pow(2, $sourceWidth) - 1 }
            $targetMin = if ($target.symbol -eq 14) { [Numerics.BigInteger]::Zero }
                elseif ($target.signed) { -[Numerics.BigInteger]::Pow(2, $targetWidth - 1) }
                else { [Numerics.BigInteger]::Zero }
            $targetMax = if ($target.symbol -eq 14) { [Numerics.BigInteger]1114111 }
                elseif ($target.signed) { [Numerics.BigInteger]::Pow(2, $targetWidth - 1) - 1 }
                else { [Numerics.BigInteger]::Pow(2, $targetWidth) - 1 }
            $sourceUpperBits = if ($source.symbol -eq 14) { 21 } elseif ($source.signed) { $sourceWidth - 1 } else { $sourceWidth }
            $targetUpperBits = if ($target.symbol -eq 14) { 21 } elseif ($target.signed) { $targetWidth - 1 } else { $targetWidth }
            $lowerPlan = $source.signed -and (-not $target.signed -or $sourceWidth -gt $targetWidth)
            $upperPlan = $sourceUpperBits -gt $targetUpperBits
            $surrogatePlan = $target.symbol -eq 14 -and $sourceUpperBits -ge 16
            $lowerExpected = $sourceMin -lt $targetMin
            $upperExpected = $sourceMax -gt $targetMax
            $surrogateExpected = $target.symbol -eq 14 -and $sourceMax -ge 55296 -and $sourceMin -le 57343
            if ($lowerPlan -ne $lowerExpected -or $upperPlan -ne $upperExpected -or $surrogatePlan -ne $surrogateExpected) {
                $differences.Add("pointer=$pointerWidth source=$($source.symbol) target=$($target.symbol) lower=$lowerPlan/$lowerExpected upper=$upperPlan/$upperExpected surrogate=$surrogatePlan/$surrogateExpected")
            }
            $total++
        }
    }
}

$scratch = Join-Path $root 'artifacts/scratch'
$fullOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { [IO.Path]::GetFullPath($OutputPath) }
    else { [IO.Path]::GetFullPath((Join-Path $root $OutputPath)) }
if (-not $fullOutput.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputPath must be inside $scratch"
}
if (Test-Path -LiteralPath $fullOutput) { throw "OutputPath already exists: $fullOutput" }
$record = [ordered]@{
    schemaVersion = 1
    status = if ($differences.Count -eq 0 -and $total -eq 338) { 'passed' } else { 'failed' }
    completed = $total - $differences.Count
    total = $total
    managedSourceSha256 = (Get-FileHash -LiteralPath $managedPath -Algorithm SHA256).Hash
    selfhostSourceSha256 = (Get-FileHash -LiteralPath $selfhostPath -Algorithm SHA256).Hash
    selfhostSignedSourceSha256 = (Get-FileHash -LiteralPath $selfhostSignedPath -Algorithm SHA256).Hash
    differences = @($differences)
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fullOutput -Encoding utf8
if ($record.status -cne 'passed') { throw "Integer conversion range plan failed: $($differences.Count) mismatch(es)" }
Write-Output "[interpolation integer range plan] PASS $($record.completed)/$($record.total); result=$fullOutput"
