[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Test output already exists' }
[IO.Directory]::CreateDirectory($output) | Out-Null
$verifier = Join-Path $PSScriptRoot 'verify-regression-fixture-names.ps1'
$cases = [Collections.Generic.List[object]]::new()
function Check-IdentityCase {
    param([string]$Id, [string[]]$Names, [string[]]$Legacy = @(),
          [string]$ExpectedFailure = '', [int]$Schema = 1, [switch]$NoContract)
    $root = Join-Path $output $Id
    $fixtures = Join-Path $root 'examples/regression'
    $contracts = Join-Path $root 'scripts/contracts'
    [IO.Directory]::CreateDirectory($fixtures) | Out-Null
    [IO.Directory]::CreateDirectory($contracts) | Out-Null
    foreach ($name in $Names) { [IO.File]::WriteAllText((Join-Path $fixtures $name), "main { }`n") }
    if (-not $NoContract) {
        $contract = @{ schemaVersion = $Schema; identityPolicy = 'numeric-new-with-retained-legacy'
            legacyRevision = ('a' * 40); legacyFixtureNames = @($Legacy) }
        [IO.File]::WriteAllText((Join-Path $contracts 'regression-fixture-identities.json'),
            ($contract | ConvertTo-Json -Depth 5))
    }
    $failure = ''
    try { & $verifier -RepositoryRoot $root | Out-Null }
    catch { $failure = $_.Exception.Message }
    if (($ExpectedFailure -eq '' -and $failure -ne '') -or
        ($ExpectedFailure -ne '' -and -not $failure.Contains($ExpectedFailure))) {
        throw "Identity control failed: $Id; $failure"
    }
    $cases.Add(@{ id = $Id; status = 'passed'; expectedFailure = $ExpectedFailure })
}
$failure = $null
try {
    Check-IdentityCase 'numeric-new' @('01-valid.slg')
    Check-IdentityCase 'retained-identity' @('01-valid.slg', 'legacy-case.slg') @('legacy-case.slg')
    Check-IdentityCase 'unregistered-name' @('legacy-case.slg') @() 'REGRESSION_FIXTURE_ID_UNREGISTERED'
    Check-IdentityCase 'new-name-not-grandfathered' @('legacy-case.slg', 'new-case.slg') @('legacy-case.slg') 'REGRESSION_FIXTURE_ID_UNREGISTERED'
    Check-IdentityCase 'stale-registration' @('01-valid.slg') @('legacy-case.slg') 'REGRESSION_FIXTURE_LEGACY_ID_MISSING'
    Check-IdentityCase 'duplicate-registration' @('legacy-case.slg') @('legacy-case.slg', 'legacy-case.slg') 'REGRESSION_FIXTURE_LEGACY_ID_INVALID'
    Check-IdentityCase 'path-traversal-registration' @('01-valid.slg') @('../legacy.slg') 'REGRESSION_FIXTURE_LEGACY_ID_INVALID'
    Check-IdentityCase 'numeric-registration-rejected' @('01-valid.slg') @('01-valid.slg') 'REGRESSION_FIXTURE_LEGACY_ID_INVALID'
    Check-IdentityCase 'malformed-new-name' @('12-Upper.slg') @() 'REGRESSION_FIXTURE_ID_UNREGISTERED'
    Check-IdentityCase 'unsupported-schema' @('01-valid.slg') @() 'REGRESSION_FIXTURE_IDENTITY_CONTRACT_INVALID' -Schema 2
    Check-IdentityCase 'missing-contract' @('01-valid.slg') @() 'REGRESSION_FIXTURE_IDENTITY_CONTRACT_MISSING' -NoContract
} catch { $failure = $_.Exception.ToString() }
$result = @{ status = $(if ($null -eq $failure) { 'passed' } else { 'failed' })
    completed = $cases.Count; total = 11; cases = @($cases.ToArray()); failure = $failure }
[IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 8))
if ($failure) { throw $failure }
Write-Output "[regression fixture identities] PASS $($cases.Count)/11"
