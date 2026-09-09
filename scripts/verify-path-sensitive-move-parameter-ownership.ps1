[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Assert-Contains {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Pattern
    )

    $content = Get-Content -LiteralPath $Path -Raw
    if (-not $content.Contains($Pattern)) {
        throw "Ownership source contract missing from '$Path': $Pattern"
    }
}

$ownershipPath = Join-Path $repositoryRoot 'selfhost/llvm/text/ownership.slg'
$foundationPath = Join-Path $repositoryRoot 'selfhost/llvm/text/foundation.slg'
$transferPath = Join-Path $repositoryRoot 'selfhost/llvm/text/call_arguments.slg'
$returnsPath = Join-Path $repositoryRoot 'selfhost/llvm/text/function_returns.slg'
$fixturePath = Join-Path $repositoryRoot 'examples/regression/1326-path-sensitive-move-parameter-result.slg'
$zstdPath = Join-Path $repositoryRoot 'stdlib/std/compress/zstd.slg'

Assert-Contains $ownershipPath 'moveParameterNeedsPathOwnershipFlag parameterIndex: Int, functionIndex: Int'
Assert-Contains $ownershipPath 'candidateMove.regionIr != function.operand0'
Assert-Contains $foundationPath 'store i1 true, ptr %arg$(pathOwnedParameterIndex!)_owned, align 1'
Assert-Contains $transferPath 'store i1 false, ptr %arg$(moveEvent.bindingIr)_owned, align 1'
Assert-Contains $returnsPath '_still_owned = load i1, ptr %arg$(ownedParameterIndex!)_owned, align 1'
Assert-Contains $returnsPath 'br i1 %drop_arg$(ownedParameterOrdinal!)_still_owned'
Assert-Contains $fixturePath 'Err(error) {'
Assert-Contains $fixturePath 'Result<Wrapped, Int>.Ok(Wrapped { owner: owner })'
Assert-Contains $zstdPath 'huffmanTable: move huffman.Table'
Assert-Contains $zstdPath 'huffmanTable: huffmanTable'

Write-Output 'PASS: path-sensitive move-parameter ownership source contract is present.'
