[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$compiler = (Resolve-Path -LiteralPath $CompilerPath).Path
$source = (Resolve-Path -LiteralPath (Join-Path $root 'selfhost/ir/interpolation.slg')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $output.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'C385 numeric boundary output must be under artifacts/scratch.'
}
if (Test-Path -LiteralPath $output) { throw "C385 numeric boundary output already exists: $output" }
[IO.Directory]::CreateDirectory($output) | Out-Null

$sourceSha = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$compilerSha = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
$astPath = Join-Path $output 'ast.txt'
$astError = Join-Path $output 'ast.stderr.txt'
$typedPath = Join-Path $output 'typed-ir.txt'
$typedError = Join-Path $output 'typed-ir.stderr.txt'
$failure = $null
$observed = @()
try {
    & $compiler ast-nodes $source > $astPath 2> $astError
    if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $astError).Length -ne 0) { throw 'AST extraction failed.' }
    & $compiler typed-ir-nodes $source > $typedPath 2> $typedError
    if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $typedError).Length -ne 0) { throw 'Typed IR extraction failed.' }

    $bytes = [IO.File]::ReadAllBytes($source)
    $astIds = [Collections.Generic.List[int]]::new()
    foreach ($line in [IO.File]::ReadLines($astPath)) {
        if ($line -match '^ast source 0 node (?<id>\d+) kind 19 parent -?\d+ start (?<start>\d+) length (?<length>\d+) ') {
            $start = [int]$Matches.start
            $length = [int]$Matches.length
            if ($start + $length -le $bytes.Length -and
                [Text.Encoding]::UTF8.GetString($bytes, $start, $length) -ceq 'fragmentEnd! < contentEnd') {
                $astIds.Add([int]$Matches.id)
            }
        }
    }
    if ($astIds.Count -lt 2) { throw "Expected interpolation boundary AST nodes; found $($astIds.Count)." }

    $nodes = [Collections.Generic.Dictionary[int,object]]::new()
    foreach ($line in [IO.File]::ReadLines($typedPath)) {
        if ($line -match '^node (?<id>\d+) kind \d+ parent -?\d+ source (?<source>-?\d+) ast (?<ast>-?\d+) .* type (?<typeId>-?\d+)/(?<kind>-?\d+)/(?<origin>-?\d+)/(?<module>-?\d+)/(?<symbol>-?\d+)/(?<flags>-?\d+) .* opcode (?<opcode>-?\d+) operands (?<left>-?\d+)/(?<right>-?\d+)/') {
            $nodes[[int]$Matches.id] = [pscustomobject]@{
                source = [int]$Matches.source
                ast = [int]$Matches.ast
                symbol = [int]$Matches.symbol
                opcode = [int]$Matches.opcode
                left = [int]$Matches.left
                right = [int]$Matches.right
            }
        }
    }
    foreach ($astId in $astIds) {
        $matches = @($nodes.Values | Where-Object { $_.source -eq 0 -and $_.ast -eq $astId -and $_.opcode -eq 29 })
        if ($matches.Count -eq 0) { continue }
        if ($matches.Count -ne 1) { throw "Expected one less-than IR node for AST $astId; found $($matches.Count)." }
        $comparison = $matches[0]
        if (-not $nodes.ContainsKey($comparison.left) -or -not $nodes.ContainsKey($comparison.right)) {
            throw "Comparison operands missing for AST $astId."
        }
        $leftType = $nodes[$comparison.left].symbol
        $rightType = $nodes[$comparison.right].symbol
        $observed += [ordered]@{ ast = $astId; leftTypeSymbol = $leftType; rightTypeSymbol = $rightType }
        if ($leftType -ne 13 -or $rightType -ne 13) {
            throw "Interpolation offset comparison AST $astId must use UIntSize/UIntSize; got $leftType/$rightType."
        }
    }
    if ($observed.Count -ne 2) { throw "Expected two interpolation boundary IR comparisons; found $($observed.Count)." }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $sourceSha) {
        throw 'Source changed during C385 numeric boundary verification.'
    }
} catch {
    $failure = $_.Exception.Message
}
$result = [ordered]@{
    schemaVersion = 1
    status = if ($null -eq $failure) { 'passed' } else { 'failed' }
    compilerSha256 = $compilerSha
    sourceSha256 = $sourceSha
    completed = $observed.Count
    total = 2
    comparisons = $observed
    failure = $failure
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
if ($null -ne $failure) { throw "$failure result=$resultPath" }
Write-Host "[C385 interpolation offsets] PASS 2/2 result=$resultPath"
