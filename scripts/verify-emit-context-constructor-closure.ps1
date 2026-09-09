[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ContextPath = "",
    [string]$ConsumerRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
if ([string]::IsNullOrWhiteSpace($ContextPath)) {
    $ContextPath = Join-Path $root "selfhost\llvm\emitter\context.slg"
}
if ([string]::IsNullOrWhiteSpace($ConsumerRoot)) {
    $ConsumerRoot = Join-Path $root "examples\regression"
}

$contextLines = [IO.File]::ReadAllLines([IO.Path]::GetFullPath($ContextPath))
$headerIndex = [Array]::FindIndex(
    $contextLines,
    [Predicate[string]] { param($line) $line -ceq "public struct EmitContext {" })
if ($headerIndex -lt 0) { throw "authoritative EmitContext declaration is missing" }

$requiredFields = [Collections.Generic.List[string]]::new()
for ($index = $headerIndex + 1; $index -lt $contextLines.Length; $index++) {
    $line = $contextLines[$index]
    if ($line -ceq "}") { break }
    if ($line -match '^    public ([A-Za-z_][A-Za-z0-9_]*):') {
        $requiredFields.Add($Matches[1])
    }
}
if ($requiredFields.Count -eq 0) { throw "authoritative EmitContext has no fields" }
if (($requiredFields | Select-Object -Unique).Count -ne $requiredFields.Count) {
    throw "authoritative EmitContext contains duplicate fields"
}

$constructors = 0
foreach ($file in Get-ChildItem -LiteralPath ([IO.Path]::GetFullPath($ConsumerRoot)) -Recurse -File -Filter "*.slg") {
    $lines = [IO.File]::ReadAllLines($file.FullName)
    for ($index = 0; $index -lt $lines.Length; $index++) {
        if ($lines[$index] -notmatch '^    emitterContext\.EmitContext \{$') { continue }
        $constructors++
        $fields = [Collections.Generic.List[string]]::new()
        for ($cursor = $index + 1; $cursor -lt $lines.Length; $cursor++) {
            if ($lines[$cursor] -match '^    \}') { break }
            if ($lines[$cursor] -match '^        ([A-Za-z_][A-Za-z0-9_]*):') {
                $fields.Add($Matches[1])
            }
        }
        $duplicates = @($fields | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
        $missing = @($requiredFields | Where-Object { $_ -notin $fields })
        $unknown = @($fields | Where-Object { $_ -notin $requiredFields })
        if ($duplicates.Count -gt 0 -or $missing.Count -gt 0 -or $unknown.Count -gt 0) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace("\", "/")
            throw "EmitContext constructor closure failed: $relative duplicates=[$($duplicates -join ',')] missing=[$($missing -join ',')] unknown=[$($unknown -join ',')]"
        }
    }
}
if ($constructors -eq 0) { throw "no direct EmitContext constructors were found" }

Write-Host "[EmitContext constructor closure] PASS $constructors/$constructors constructors with $($requiredFields.Count)/$($requiredFields.Count) fields."
