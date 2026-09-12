[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SelfhostCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$fixture = Join-Path $root 'scripts/probes/borrowed-return-scalars/projection-alias.slg'
$managedSource = Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'
$managedBorrowSource = Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.BorrowOrigins.cs'
$managedCompiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$selfhost = if ([string]::IsNullOrWhiteSpace($SelfhostCompiler)) {
    Join-Path $root 'artifacts/incremental-selfhost/selfhost-slg-seed.exe'
} else {
    [IO.Path]::GetFullPath($SelfhostCompiler)
}
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/borrowed-projection-alias-parity-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'
$required = @($fixture, $managedSource, $managedBorrowSource, $managedCompiler, $selfhost, $PSCommandPath)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing input: $path" }
}
$hashes = [ordered]@{}
foreach ($path in $required) { $hashes[$path] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'managed-selfhost-borrowed-projection-alias-parity'
    completed = 0
    total = 6
    inputHashes = $hashes
    checks = @()
    resultPath = $resultPath
}
function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}

try {
    Save-Result
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $fixture
    if ($LASTEXITCODE -ne 0) { throw 'projection alias fixture authoritative format failed' }
    Complete-Check 'fixture-authoritative-format'

    $semantic = [IO.File]::ReadAllText($managedSource).Replace("`r`n", "`n")
    $bindingCalls = [regex]::Matches($semantic, 'TypeCanCarryBorrowedTextOrigin\([^\r\n]+\)[\s\S]{0,240}?TryGetBorrowedSourceCallSiteOrigins\(').Count
    if ($bindingCalls -ne 2) { throw "managed binding/flow borrowed-origin authority count drifted: $bindingCalls" }
    Complete-Check 'managed-binding-and-flow-share-source-origin-authority'

    $borrowAuthority = [IO.File]::ReadAllText($managedBorrowSource).Replace("`r`n", "`n")
    if (-not $borrowAuthority.Contains('if (TryGetConcreteBorrowOrigins(source, bindings, out origins))') -or
        -not $borrowAuthority.Contains('return TryGetBorrowedTextCallOrigins(source, functions, bindings, out origins);')) {
        throw 'managed concrete-place-first borrowed source authority drifted'
    }
    Complete-Check 'managed-concrete-place-first-authority'

    $managedVerifier = Join-Path $root 'scripts/verify-borrowed-return-boundaries.ps1'
    $managedResultText = (& pwsh -NoProfile -File $managedVerifier -CaseId projection-alias 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $managedResultText -notmatch '\(1/1\)') {
        throw "managed projection alias regression failed: $managedResultText"
    }
    $record.managedObservation = $managedResultText
    Complete-Check 'managed-native-exact-and-llvm'

    $selfhostLlvm = Join-Path $output 'selfhost.ll'
    $selfhostText = (& $selfhost windows $fixture 2>&1) -join "`n"
    $selfhostExit = $LASTEXITCODE
    [IO.File]::WriteAllText($selfhostLlvm, $selfhostText + "`n", [Text.UTF8Encoding]::new($false))
    if ($selfhostExit -ne 0 -or $selfhostText -match '(?m)^(warning|; sollang .*error)' -or $selfhostText -notmatch '(?m)^define ') {
        throw "selfhost projection alias emission failed or warned: $selfhostText"
    }
    $record.selfhost = [ordered]@{ compilerSha256=$hashes[$selfhost]; llvmSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $selfhostLlvm).Hash }
    Complete-Check 'selfhost-warning-zero-llvm-emission'

    & (Join-Path $llvm 'bin/llvm-as.exe') $selfhostLlvm -o (Join-Path $output 'selfhost.bc')
    if ($LASTEXITCODE -ne 0) { throw 'selfhost projection alias LLVM assembly failed' }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $selfhostLlvm
    Complete-Check 'selfhost-llvm-assembly-and-direct-call-closure'

    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -cne $hashes[$path]) { throw "input drift: $path" }
    }
    $record.inputsStable = $true
    if ($record.completed -ne $record.total) { throw "denominator mismatch: $($record.completed)/$($record.total)" }
    $record.status = 'passed'
    Save-Result
    Write-Output "PASS $($record.completed)/$($record.total); $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
