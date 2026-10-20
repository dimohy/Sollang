[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Receipt,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$output = [IO.Path]::GetFullPath($OutputPath, $root)
if (Test-Path -LiteralPath $output) { throw "Exact stderr result already exists: $output" }
if ($Receipt.Count -eq 0) { throw 'Exact stderr verification requires at least one receipt' }

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($relative in $Receipt) {
    $path = [IO.Path]::GetFullPath($relative, $root)
    $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($record.gate -cne 'compiler-parity-negative-fixture' -or
        $record.state -cne 'passed' -or -not $record.inputsStable -or
        -not $record.managed.nonzeroExit -or -not $record.selfhost.nonzeroExit -or
        -not $record.managed.noEmittedProducts -or -not $record.selfhost.noEmittedProducts) {
        throw "Exact stderr verification requires a stable passed negative pair: $path"
    }
    foreach ($input in @(
        @{ Path = $record.source; Hash = $record.sourceSha256 },
        @{ Path = $record.expected; Hash = $record.expectedSha256 },
        @{ Path = $record.managedCompilerPath; Hash = $record.managedCompilerSha256 },
        @{ Path = $record.selfhostCompilerPath; Hash = $record.selfhostCompilerSha256 }
    )) {
        if (-not (Test-Path -LiteralPath $input.Path -PathType Leaf) -or
            (Get-FileHash -LiteralPath $input.Path -Algorithm SHA256).Hash -cne $input.Hash) {
            throw "Exact stderr receipt input changed: $($input.Path)"
        }
    }
    $managed = [IO.File]::ReadAllText($record.logs.managedStderr).Replace("`r`n", "`n")
    $selfhost = [IO.File]::ReadAllText($record.logs.selfhostStderr).Replace("`r`n", "`n")
    $equal = $managed -ceq $selfhost
    $classification = if ($equal) { 'EXACT' }
        elseif ($selfhost.StartsWith('; sollang workers = ', [StringComparison]::Ordinal)) { 'EXTRA_WORKER_PREFIX_AND_FORMAT' }
        elseif ($selfhost.Contains('; sollang semantic error:', [StringComparison]::Ordinal)) { 'CHANNEL_FORMAT_MISMATCH' }
        else { 'STDERR_MISMATCH' }
    $rows.Add([ordered]@{
        receipt = $relative
        sourceSha256 = $record.sourceSha256
        managedCompilerSha256 = $record.managedCompilerSha256
        selfhostCompilerSha256 = $record.selfhostCompilerSha256
        exact = $equal
        classification = $classification
        managedStderrSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($managed)))
        selfhostStderrSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($selfhost)))
    })
}

$matched = @($rows | Where-Object { $_.exact }).Count
$result = [ordered]@{
    schemaVersion = 1
    comparison = 'whole-stderr-ordinal-after-crlf-normalization'
    status = if ($matched -eq $rows.Count) { 'passed' } else { 'mismatched' }
    completed = $matched
    total = $rows.Count
    cases = @($rows)
}
$directory = [IO.Path]::GetDirectoryName($output)
[IO.Directory]::CreateDirectory($directory) | Out-Null
[IO.File]::WriteAllText($output, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Host "[negative stderr exact] $($result.status) $matched/$($rows.Count); result=$output"
if ($matched -ne $rows.Count) { exit 1 }
