[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$validator = Join-Path $PSScriptRoot "verify-emit-context-constructor-closure.ps1"
& $validator -RepositoryRoot $RepositoryRoot

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "sollang-emit-context-closure-$([guid]::NewGuid().ToString('N'))"
$consumerRoot = Join-Path $temporaryRoot "examples\regression"
$contextPath = Join-Path $temporaryRoot "context.slg"
New-Item -ItemType Directory -Path $consumerRoot -Force | Out-Null
try {
    @"
public struct EmitContext {
    public first: Int
    public second: Int
}
"@ | Set-Content -LiteralPath $contextPath -Encoding utf8
    $consumerPath = Join-Path $consumerRoot "sample.slg"
    @"
main {
    emitterContext.EmitContext {
        first: 1
        second: 2
    } => context
}
"@ | Set-Content -LiteralPath $consumerPath -Encoding utf8
    & $validator -RepositoryRoot $temporaryRoot -ContextPath $contextPath -ConsumerRoot $consumerRoot | Out-Null

    @"
main {
    emitterContext.EmitContext {
        first: 1
    } => context
}
"@ | Set-Content -LiteralPath $consumerPath -Encoding utf8
    try {
        & $validator -RepositoryRoot $temporaryRoot -ContextPath $contextPath -ConsumerRoot $consumerRoot | Out-Null
        throw "missing-field negative control unexpectedly passed"
    }
    catch {
        if ($_.Exception.Message -notmatch 'missing=\[second\]') { throw }
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Host "[EmitContext constructor closure contract] PASS production closure plus missing-field negative control."
