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
        throw "Async Result propagation contract source is missing: $RelativePath"
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

$asyncEmitter = Read-RequiredFile 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Async.cs'
$enumEmitter = Read-RequiredFile 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Enums.cs'
$fixture = Read-RequiredFile 'examples/regression/1691-async-result-propagation.slg'
$expected = (Read-RequiredFile 'examples/regression/expected/1691-async-result-propagation.stdout.txt').Replace("`r`n", "`n")

foreach ($required in @(
    'private void EmitPropagatedResultReturn(BoundFunction function, RuntimeValue value)',
    'if (function.IsAsync)',
    'StoreAsyncResult(function, value);',
    'EmitRet("i1", "true");'
)) {
    Assert-Contains $asyncEmitter $required 'async completed-return invariant'
}
Assert-Contains $enumEmitter 'EmitPropagatedResultReturn(function, propagated);' 'postfix Result error completion'

foreach ($required in @(
    'increment value: Int -> async Result<Int, Text>',
    'value -> parse? => parsed',
    '41 -> increment -> await',
    '-1 -> increment -> await'
)) {
    Assert-Contains $fixture $required 'async Result propagation fixture'
}
if ($expected -ne "async-result=42`nasync-error=negative`n") {
    throw 'Async Result propagation expected output must cover both Ok and propagated Err paths.'
}

Write-Host '[async Result propagation contract] PASS worker completion, sync Unit preservation, and Ok/Err fixture coverage.'
