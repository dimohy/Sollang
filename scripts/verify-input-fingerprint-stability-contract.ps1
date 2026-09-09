[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "input-fingerprint-stability.ps1")

Assert-InputFingerprintStable -ExpectedFingerprint "ABC" -CurrentFingerprint "ABC" -Phase "positive control"

$rejected = $false
try {
    Assert-InputFingerprintStable -ExpectedFingerprint "ABC" -CurrentFingerprint "DEF" -Phase "negative control"
} catch {
    if ($_.Exception.Message -notmatch "inputs changed during verification") {
        throw
    }
    $rejected = $true
}
if (-not $rejected) {
    throw "input fingerprint stability negative control accepted a changed source snapshot"
}

Write-Host "[input fingerprint stability] PASS stable positive and changed-input negative controls."
