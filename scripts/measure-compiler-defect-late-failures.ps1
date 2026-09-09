[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^C\d{4}-\d{2}-\d{2}-\d+$')][string]$DefectId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidenceDirectory = Join-Path $repositoryRoot "scripts\contracts\evidence\$DefectId"
$baselinePath = Join-Path $evidenceDirectory 'baseline.json'
$candidatePath = Join-Path $evidenceDirectory 'candidate.json'
foreach ($requiredPath in @($baselinePath, $candidatePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "$DefectId late-failure measurement is missing receipt: $requiredPath"
    }
}

$baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
$candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
if ($baseline.defectId -cne $DefectId -or $candidate.defectId -cne $DefectId) {
    throw "$DefectId late-failure measurement receipt identity drift"
}
if ($baseline.inputFingerprint -cne $candidate.inputFingerprint) {
    throw "$DefectId late-failure measurement input fingerprint drift"
}
if ($baseline.exitCode -eq 0) {
    throw "$DefectId baseline does not preserve an observed failure"
}
if ($candidate.exitCode -ne 0 -or $candidate.expectedExitCode -ne 0) {
    throw "$DefectId candidate does not preserve a successful consumer execution"
}

[ordered]@{
    schemaVersion = 1
    defectId = $DefectId
    inputFingerprint = $baseline.inputFingerprint
    metric = 'lateFailures'
    before = 1
    after = 0
} | ConvertTo-Json -Compress
