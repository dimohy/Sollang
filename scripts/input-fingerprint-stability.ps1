Set-StrictMode -Version Latest

function Assert-InputFingerprintStable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedFingerprint,
        [Parameter(Mandatory = $true)]
        [string]$CurrentFingerprint,
        [Parameter(Mandatory = $true)]
        [string]$Phase
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedFingerprint) -or
        [string]::IsNullOrWhiteSpace($CurrentFingerprint) -or
        $ExpectedFingerprint.Trim() -cne $CurrentFingerprint.Trim()) {
        throw "$Phase inputs changed during verification; discard the stale candidate and rebuild from a stable source snapshot"
    }
}
