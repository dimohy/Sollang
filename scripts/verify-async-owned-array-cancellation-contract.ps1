[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)

function Read-RequiredFile {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Async owned-array cancellation contract source is missing: $RelativePath"
    }
    [IO.File]::ReadAllText($path)
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Description
    )
    if (-not $Text.Contains($Expected, [StringComparison]::Ordinal)) {
        throw "$Description is missing: $Expected"
    }
}

$irEmitter = Read-RequiredFile 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Ir.cs'
$fixture = Read-RequiredFile 'examples/regression/1692-async-owned-array-cancellation.slg'
$expected = (Read-RequiredFile 'examples/regression/expected/1692-async-owned-array-cancellation.stdout.txt').Replace("`r`n", "`n")

Assert-Contains $irEmitter '_currentBlockLabel = label;' 'basic-block authority update'
foreach ($required in @(
    'operations: move [OperationSlot; ~] -> async CompletionBatch',
    'reactor: AsyncReactor',
    'operations: [OperationSlot; ~]',
    'cancelled -> cancel',
    'task -> await => completion'
)) {
    Assert-Contains $fixture $required 'async affine reactor-shape fixture'
}
if ($expected -ne "completed=0,slots=1`n") {
    throw 'Async owned-array cancellation expected output is stale.'
}

Write-Host '[async owned-array cancellation contract] PASS block authority and affine cancel/await coverage.'
