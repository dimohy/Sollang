[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$stdlibRoot = Join-Path $RepositoryRoot "stdlib"
$publicRoot = Join-Path $stdlibRoot "std"
$runtimeRoot = Join-Path $stdlibRoot "sys\runtime"
$requiredDomains = @(
    "clock",
    "console",
    "dns",
    "integer_file",
    "mouse_event",
    "parallel",
    "path",
    "process",
    "random",
    "sequence",
    "socket",
    "time"
)

foreach ($root in @($publicRoot, $runtimeRoot)) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "required standard-library source root is missing: $root"
    }
}

$monolithPath = Join-Path $stdlibRoot "sys\runtime.slg"
if (Test-Path -LiteralPath $monolithPath) {
    throw "runtime ABI monolith must stay removed: $monolithPath"
}

$publicIntrinsics = @(Get-ChildItem -LiteralPath $publicRoot -Recurse -File -Filter "*.slg" |
    Select-String -SimpleMatch "= intrinsic")
if ($publicIntrinsics.Count -gt 0) {
    $locations = $publicIntrinsics | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
    throw "public std sources contain runtime ABI declarations:`n$($locations -join "`n")"
}

$runtimeFiles = @(Get-ChildItem -LiteralPath $runtimeRoot -File -Filter "*.slg" |
    Sort-Object -Property Name)
foreach ($domain in $requiredDomains) {
    $requiredPath = Join-Path $runtimeRoot "$domain.slg"
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "required runtime ABI fragment is missing: $requiredPath"
    }
}

foreach ($file in $runtimeFiles) {
    $lines = Get-Content -LiteralPath $file.FullName
    $namespaceLine = $lines | Where-Object { $_ -match '^namespace\s+[A-Za-z_][A-Za-z0-9_.]*\s*$' } |
        Select-Object -First 1
    if ($null -eq $namespaceLine) {
        throw "runtime ABI fragment has no namespace: $($file.FullName)"
    }
    $namespace = ([regex]::Match($namespaceLine, '^namespace\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)\s*$')).Groups['name'].Value
    $contractPath = Join-Path $stdlibRoot (($namespace -replace '\.', '\') + '.slg')
    if ($namespace -ne 'sys.runtime' -and
        -not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
        throw "runtime ABI fragment '$($file.FullName)' has no public contract source '$contractPath'"
    }
    if (-not ($lines -match '= intrinsic')) {
        throw "runtime ABI fragment contains no intrinsic declaration: $($file.FullName)"
    }
}

Write-Host "[runtime intrinsic layout] PASS $($runtimeFiles.Count) ABI fragments; public std sources contain 0 intrinsic declarations."
