[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root 'scripts/contracts/unicode-identifier-bmp.json'
$sourcePath = Join-Path $root 'selfhost/syntax/unicode_identifier.slg'
$projectPath = Join-Path $root 'scripts/tools/unicode-identifier-table/unicode-identifier-table.csproj'
$programPath = Join-Path $root 'scripts/tools/unicode-identifier-table/Program.cs'
$lexerPath = Join-Path $root 'selfhost/syntax/lexer.slg'
$interpolationPath = Join-Path $root 'selfhost/ir/interpolation.slg'
$inputs = @($contractPath, $sourcePath, $projectPath, $programPath, $lexerPath, $interpolationPath)
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C486 input missing: $path" }
}
$result = [IO.Path]::GetFullPath($ResultPath, $root)
if (Test-Path -LiteralPath $result) { throw "C486 result already exists: $result" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $result) -PathType Container)) {
    throw "C486 result parent missing: $result"
}
$start = [ordered]@{}
foreach ($path in $inputs) { $start[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }

$generatedLines = @(& dotnet run --project $projectPath -c Release --no-launch-profile --verbosity quiet 2>&1)
if ($LASTEXITCODE -ne 0) { throw "C486 .NET 11 table generator failed: $($generatedLines -join ' ')" }
$generated = $generatedLines[-1] | ConvertFrom-Json
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$source = [IO.File]::ReadAllText($sourcePath)
$letter = [regex]::Match($source, '(?m)^letterRanges: -> Text => "([0-9A-F]+)"$')
$continuation = [regex]::Match($source, '(?m)^continuationRanges: -> Text => "([0-9A-F]+)"$')
if (-not $letter.Success -or -not $continuation.Success) { throw 'C486 SLG interval literals missing' }
foreach ($field in @('letterRangesHex', 'continuationRangesHex', 'letterRangeCount', 'continuationRangeCount')) {
    if ($generated.$field -cne $contract.$field) { throw "C486 managed category mismatch: $field" }
}
if ($letter.Groups[1].Value -cne $contract.letterRangesHex -or
    $continuation.Groups[1].Value -cne $contract.continuationRangesHex) {
    throw 'C486 SLG category data differs from the managed contract'
}
$lexer = [IO.File]::ReadAllText($lexerPath)
$interpolation = [IO.File]::ReadAllText($interpolationPath)
if ($lexer -cnotmatch 'unicodeIdentifier\.startWidth' -or
    $lexer -cnotmatch 'unicodeIdentifier\.continueWidth' -or
    $interpolation -cnotmatch 'unicodeIdentifier\.startWidth' -or
    $interpolation -cnotmatch 'unicodeIdentifier\.continueWidth') {
    throw 'C486 lexer and interpolation must use the same scalar classifier'
}
$stable = $true
foreach ($path in $inputs) {
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $start[$path]) { $stable = $false }
}
if (-not $stable) { throw 'C486 category verification input drift' }
$receipt = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    runtime = $generated.runtime
    letterRanges = $contract.letterRangeCount
    continuationRanges = $contract.continuationRangeCount
    consumers = 2
    inputStable = $true
    inputHashes = $start
}
$receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $result -Encoding utf8
Write-Host "[C486 Unicode ranges] PASS letters $($contract.letterRangeCount), continuation $($contract.continuationRangeCount), consumers 2; result=$result"
