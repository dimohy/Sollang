[CmdletBinding()]
param(
    [switch]$Check,
    [string]$Compiler = "",
    [string[]]$Source = @()
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
$Compiler = [System.IO.Path]::GetFullPath($Compiler)
if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw "formatter compiler is missing: $Compiler"
}

$sourceRoots = @(
    (Join-Path $repoRoot "selfhost"),
    (Join-Path $repoRoot "stdlib"),
    (Join-Path $repoRoot "syntax\generated")
)
if ($PSBoundParameters.ContainsKey('Source')) {
    if ($Source.Count -eq 0) { throw 'focused format requires at least one explicit source' }
    $allowedRoots = @($sourceRoots) + @(
        (Join-Path $repoRoot 'examples\user'),
        (Join-Path $repoRoot 'examples\regression'),
        (Join-Path $repoRoot 'scripts\contracts\fixtures'),
        (Join-Path $repoRoot 'scripts\probes')
    )
    $sources = @($Source | ForEach-Object {
        $path = [IO.Path]::GetFullPath($_, $repoRoot)
        $allowed = $false
        foreach ($root in $allowedRoots) {
            $prefix = [IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $allowed = $true; break }
        }
        if (-not $allowed -or [IO.Path]::GetExtension($path) -cne '.slg') {
            throw "focused format source is outside the permitted SLG roots: $path"
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "focused format source is missing: $path"
        }
        $path
    } | Sort-Object -Unique)
} else {
    $sources = @($sourceRoots |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File -Filter "*.slg" } |
        Sort-Object -Property FullName -Unique |
        ForEach-Object { $_.FullName })
}
if ($sources.Count -eq 0) {
    throw "no authoritative Sollang sources were found"
}

$managedCompiler = [System.IO.Path]::GetExtension($Compiler) -eq ".dll"
$batchSize = 32
for ($offset = 0; $offset -lt $sources.Count; $offset += $batchSize) {
    $last = [Math]::Min($offset + $batchSize - 1, $sources.Count - 1)
    $batch = @($sources[$offset..$last])
    $arguments = @("format")
    if ($Check) { $arguments += "--check" }
    $arguments += $batch
    if ($managedCompiler) {
        & dotnet $Compiler @arguments
    } else {
        & $Compiler @arguments
    }
    if ($LASTEXITCODE -ne 0) {
        $failed = [System.Collections.Generic.List[string]]::new()
        foreach ($path in $batch) {
            $individualArguments = @("format")
            if ($Check) { $individualArguments += "--check" }
            $individualArguments += $path
            if ($managedCompiler) {
                & dotnet $Compiler @individualArguments
            } else {
                & $Compiler @individualArguments
            }
            if ($LASTEXITCODE -ne 0) { $failed.Add($path) }
        }
        Write-Error "Authoritative Sollang format failures:`n$($failed -join "`n")" -ErrorAction Continue
        $verb = if ($Check) { "check" } else { "write" }
        throw "authoritative Sollang format $verb failed for batch beginning at $($batch[0])"
    }
}

$verb = if ($Check) { "verified" } else { "formatted" }
Write-Host "[authoritative format] PASS $verb $($sources.Count) sources."
