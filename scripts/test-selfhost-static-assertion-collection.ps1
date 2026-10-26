[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$verifier = Join-Path $RepositoryRoot 'scripts/verify-selfhost-compiler-contracts.ps1'
$tokens = $null
$parseErrors = $null
$tree = [Management.Automation.Language.Parser]::ParseFile($verifier, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Static assertion verifier has syntax errors' }
$names = @('Register-StaticAssertionFailure', 'Assert-Contains', 'Assert-NotContains', 'Assert-Matches', 'Assert-NotMatches', 'Assert-MatchCount')
$functions = @($tree.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $names }, $false))
if ($functions.Count -ne $names.Count) { throw 'Static assertion helper inventory differs' }
. ([scriptblock]::Create(($functions.Extent.Text -join "`n")))
$CollectStaticAssertionFailures = $false
$staticAssertionFailures = [Collections.Generic.List[string]]::new()
$positive = @(
    { Assert-Contains 'alpha beta' 'beta' 'contains' },
    { Assert-NotContains 'alpha' 'beta' 'not contains' },
    { Assert-Matches 'value=42' '^value=\d+$' 'matches' },
    { Assert-NotMatches 'alpha' '\d' 'not matches' },
    { Assert-MatchCount 'aa aa' 'aa' 2 'count' }
)
$negative = @(
    { Assert-Contains 'alpha' 'beta' 'contains' },
    { Assert-NotContains 'alpha beta' 'beta' 'not contains' },
    { Assert-Matches 'alpha' '^value=\d+$' 'matches' },
    { Assert-NotMatches 'value=42' '\d' 'not matches' },
    { Assert-MatchCount 'aa aa' 'aa' 1 'count' }
)
$completed = 0
foreach ($probe in $positive) { & $probe; $completed++ }
foreach ($probe in $negative) {
    $rejected = $false
    try { & $probe } catch { $rejected = $true }
    if (-not $rejected) { throw 'Default assertion path accepted a negative control' }
    $completed++
}
if ($staticAssertionFailures.Count -ne 0) { throw 'Fail-fast mode accumulated failures' }
$CollectStaticAssertionFailures = $true
foreach ($probe in $negative) {
    $before = $staticAssertionFailures.Count
    & $probe
    if ($staticAssertionFailures.Count -ne $before + 1) { throw 'Collection mode lost an assertion failure' }
    $completed++
}
foreach ($probe in $positive) { & $probe }
if ($staticAssertionFailures.Count -ne 5) { throw 'Positive controls changed the failure count' }
$rejected = $false
try { & $verifier -CollectStaticAssertionFailures } catch {
    if ($_.Exception.Message -ne 'STATIC_ASSERTION_COLLECTION_REQUIRES_STATIC_ONLY') { throw }
    $rejected = $true
}
if (-not $rejected) { throw 'Collection mode entered full verification' }
$completed++
@{ status = 'passed'; completed = $completed; total = 16; defaultFailuresRejected = 5; collectedFailures = 5; fullModeRejected = $true } | ConvertTo-Json
