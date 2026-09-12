[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [switch]$MapLiteralContract,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string[]]$Source = @(
        "stdlib/std/net.slg",
        "stdlib/std/net/parse_error.slg"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$sourcePaths = @($Source | ForEach-Object {
    $path = [IO.Path]::GetFullPath((Join-Path $root $_))
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Expression lowering parity source must be under the repository root: $path"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Expression lowering parity source is missing: $path"
    }
    $path
})
if ($sourcePaths.Count -eq 0) {
    throw "Expression lowering parity requires at least one source"
}

$sequential = Invoke-VerificationProcessCapture `
    -FilePath $compilerPath `
    -ArgumentList (@("typed-ir-nodes") + $sourcePaths) `
    -Description "sequential Typed IR node inventory" `
    -TimeoutMilliseconds 120000
if ($sequential.ExitCode -ne 0) {
    throw "Sequential Typed IR inventory failed with exit code $($sequential.ExitCode).`n$($sequential.Stdout)$($sequential.Stderr)"
}
if (-not [string]::IsNullOrWhiteSpace($sequential.Stderr)) {
    throw "Sequential Typed IR inventory emitted diagnostics.`n$($sequential.Stderr)"
}
$parallel = Invoke-VerificationProcessCapture `
    -FilePath $compilerPath `
    -ArgumentList (@("typed-ir-nodes-parallel") + $sourcePaths) `
    -Description "production-parallel Typed IR node inventory" `
    -TimeoutMilliseconds 120000
if ($parallel.ExitCode -ne 0) {
    throw "Production-parallel Typed IR inventory failed with exit code $($parallel.ExitCode).`n$($parallel.Stdout)$($parallel.Stderr)"
}
if (-not [string]::IsNullOrWhiteSpace($parallel.Stderr)) {
    throw "Production-parallel Typed IR inventory emitted diagnostics.`n$($parallel.Stderr)"
}

$sequentialLines = @($sequential.Stdout.Replace("`r`n", "`n").TrimEnd("`n") -split "`n")
$parallelLines = @($parallel.Stdout.Replace("`r`n", "`n").TrimEnd("`n") -split "`n")
$difference = @(Compare-Object -ReferenceObject $sequentialLines -DifferenceObject $parallelLines -SyncWindow 0)
if ($difference.Count -ne 0) {
    $first = $difference | Select-Object -First 12 | Out-String
    throw "Sequential and production-parallel Typed IR inventories differ ($($difference.Count) line differences).`n$first"
}

Write-Host "[expression lowering mode parity] PASS $($sourcePaths.Count) sources and $($sequentialLines.Count) exact Typed IR nodes."

if ($MapLiteralContract) {
    $nodes = @{}
    foreach ($line in $sequentialLines) {
        if ($line -notmatch '^node (?<id>\d+) kind (?<kind>\d+) parent (?<parent>-?\d+) .* type (?<type>-?\d+)/(?<origin>-?\d+)/(?<typeKind>-?\d+)/(?<module>-?\d+)/(?<symbol>-?\d+)/\d+ .* opcode (?<opcode>-?\d+) operands (?<first>-?\d+)/(?<second>-?\d+)/(?<next>-?\d+) flags (?<flags>-?\d+)$') {
            throw "Unrecognized Typed IR diagnostic line: $line"
        }
        $node = @{}
        foreach ($field in @('id', 'kind', 'parent', 'origin', 'symbol', 'opcode', 'first', 'next', 'flags')) {
            $node[$field] = [int]$Matches[$field]
        }
        $nodes[$node.id] = $node
    }
    $maps = @($nodes.Values | Where-Object { $_.kind -eq 9 -and $_.opcode -in @(-306, -307) })
    if ($maps.Count -ne 2 -or @($maps | Where-Object opcode -eq -306).Count -ne 1) {
        throw 'Map literal fixture must retain both its read and write value producers'
    }
    $checked = 0
    foreach ($map in $maps) {
        $expectedFlags = if ($map.opcode -eq -306) { 3 } else { 4 }
        $expectedSymbols = if ($map.opcode -eq -306) { @(11, 13) } else { @(11) }
        if ($map.flags -ne $expectedFlags -or -not $nodes.ContainsKey($map.first)) {
            throw 'Map literal fixture lost a clause or its path'
        }
        $index = $nodes[$map.first].next
        foreach ($symbol in $expectedSymbols) {
            if (-not $nodes.ContainsKey($index)) { throw 'Map literal operand is missing' }
            $operand = $nodes[$index]
            if ($operand.parent -ne $map.id -or $operand.kind -ne 3 -or
                $operand.origin -ne 1 -or $operand.symbol -ne $symbol) {
                throw "Map literal at IR $index must retain builtin $symbol after common normalization"
            }
            $index = $operand.next
            $checked++
        }
        if ($index -ne -1) { throw 'Map literal chain contains an extra operand' }
    }
    $validation = Invoke-VerificationProcessCapture -FilePath $compilerPath `
        -ArgumentList (@('validate') + $sourcePaths) `
        -Description 'map pre-LLVM validation' -TimeoutMilliseconds 120000
    if ($validation.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($validation.Stderr) -or
        $validation.Stdout.Trim() -cne 'checked diagnostics = 0') {
        throw "Map pre-LLVM validation failed: $($validation.Stdout)$($validation.Stderr)"
    }
    Write-Host "[map literal contract] PASS $checked contextual literals and zero pre-LLVM diagnostics."
}
