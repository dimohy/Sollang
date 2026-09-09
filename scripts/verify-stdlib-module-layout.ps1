[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $PSScriptRoot "contracts\stdlib-module-layout.json"
$stdlibRoot = Join-Path $root "stdlib"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 2) {
    throw "unsupported stdlib module-layout contract schema"
}

foreach ($entry in $contract.canonicalModules) {
    $path = Join-Path $root ([string]$entry.path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "canonical stdlib module is missing: $($entry.module) at $path"
    }
    $namespace = (Get-Content -LiteralPath $path |
        Where-Object { $_ -match '^namespace\s+' } |
        Select-Object -First 1) -replace '^namespace\s+', ''
    if ($namespace.Trim() -cne [string]$entry.module) {
        throw "canonical module/path mismatch at ${path}: expected '$($entry.module)', got '$namespace'"
    }
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $stdlibRoot 'std') -Recurse -File -Filter '*.slg') {
    $relative = $file.FullName.Substring($stdlibRoot.Length + 1)
    $expected = ([IO.Path]::ChangeExtension($relative, $null) -replace '[\\/]', '.').TrimEnd('.')
    $namespace = (Get-Content -LiteralPath $file.FullName |
        Where-Object { $_ -match '^namespace\s+' } |
        Select-Object -First 1) -replace '^namespace\s+', ''
    if ($namespace.Trim() -cne $expected) {
        throw "stdlib path requires namespace '$expected' but '$($file.FullName)' declares '$namespace'"
    }
}

$activeRoots = @('stdlib', 'selfhost', 'examples', 'tests', 'src', 'scripts')
$activeFiles = Get-ChildItem ($activeRoots | ForEach-Object { Join-Path $RepositoryRoot $_ }) `
    -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch '[\\/](\.artifacts|artifacts|\.sollang-cache|bin|obj)[\\/]' -and
        $_.FullName -cne $contractPath -and
        ($_.Extension -in @('.slg', '.cs', '.ps1', '.txt', '.json'))
    }
foreach ($forbidden in $contract.forbiddenActiveNamespaces) {
    $escaped = [regex]::Escape([string]$forbidden)
    $matches = @($activeFiles | Select-String -Pattern "(?<![A-Za-z0-9_.])$escaped(?![A-Za-z0-9_])")
    if ($matches.Count -gt 0) {
        $locations = $matches | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
        throw "obsolete active namespace '$forbidden' remains:`n$($locations -join "`n")"
    }
}

$documentationFiles = @($contract.currentDocumentationFiles | ForEach-Object {
    $path = Join-Path $root ([string]$_ -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "current stdlib documentation file is missing: $path"
    }
    Get-Item -LiteralPath $path
})
foreach ($forbidden in $contract.forbiddenActiveNamespaces) {
    $escaped = [regex]::Escape([string]$forbidden)
    $pattern = "(?<![A-Za-z0-9_.])$escaped(?![A-Za-z0-9_])"
    $matches = @($documentationFiles | Select-String -Pattern $pattern)
    if ($matches.Count -gt 0) {
        $locations = $matches | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
        throw "obsolete current-facing stdlib namespace '$forbidden' remains:`n$($locations -join "`n")"
    }
}
foreach ($forbiddenPath in $contract.forbiddenCurrentPaths) {
    $escaped = [regex]::Escape([string]$forbiddenPath)
    $pattern = "(?<![A-Za-z0-9_./])$escaped(?![A-Za-z0-9_./])"
    $positiveControl = 'current path: `' + $forbiddenPath + '`'
    $negativeControl = "prefix/$forbiddenPath/suffix"
    if ($positiveControl -notmatch $pattern -or $negativeControl -match $pattern) {
        throw "obsolete current-facing path matcher failed its boundary control for '$forbiddenPath'"
    }
    $matches = @($documentationFiles | Select-String -Pattern $pattern)
    if ($matches.Count -gt 0) {
        $locations = $matches | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
        throw "obsolete current-facing stdlib path '$forbiddenPath' remains:`n$($locations -join "`n")"
    }
}

Write-Host "[stdlib module layout] PASS $($contract.canonicalModules.Count) canonical modules; obsolete active/current-facing namespaces: 0; obsolete current-facing paths: 0."
