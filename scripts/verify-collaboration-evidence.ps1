[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'collaboration-evidence.ps1')

$relative = 'artifacts/scratch/collaboration-evidence/' + [Guid]::NewGuid().ToString('N')
$directory = Join-Path $RepositoryRoot $relative
$null = New-Item -ItemType Directory -Path $directory -Force
$artifact = Join-Path $directory 'evidence.json'
$fixtureContent = '{"exitCode":0,"total":1,"passed":1,"forbiddenActions":0,"purpose":"Synthetic verifier fixture, not production evidence"}'
Set-Content -LiteralPath $artifact -Value $fixtureContent
$artifactHash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
$evidence = "$relative/evidence.json#sha256=$artifactHash"
$publicationPath = Join-Path $directory 'publication.json'
$publicationContent = '{"systemTarget":"agentic-shaping","ruleId":"AS-PS-001","status":"passed","exitCode":0,"total":1,"passed":1,"forbiddenActions":0,"synchronizedSurfaces":8,"git":{"stagedFiles":1,"approvedInitialFiles":1,"approvedAdditionalFiles":0,"unexpectedStagedFiles":0,"commitCreated":false,"pushPerformed":false}}'
Set-Content -LiteralPath $publicationPath -Value $publicationContent
$publicationHash = (Get-FileHash -LiteralPath $publicationPath -Algorithm SHA256).Hash.ToLowerInvariant()
$trace = [ordered]@{
    runId = 'synthetic-collaboration-evidence-control'
    phase = 'final'
    triggerKind = 'explicit-request'
    requestTargets = @('agentic-shaping')
    currentTaskComplete = $true
    forbiddenActions = @()
    actions = @(
        @{ target = 'agentic-shaping'; kind = 'hook-change'; evidence = @($evidence) },
        @{ target = 'agentic-shaping'; kind = 'evaluation-contract'; evidence = @($evidence) },
        @{ target = 'agentic-shaping'; kind = 'behavioral-verification'; evidence = @($evidence) }
    )
}
$tracePath = Join-Path $directory 'trace.json'
function Write-Trace {
    $trace | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tracePath
    $gate.evidenceTrace.sha256 = (Get-FileHash -LiteralPath $tracePath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$gate = [pscustomobject]@{
    name = 'agentic-shaping-hook-policy'
    status = 'complete'
    evidenceTrace = [pscustomobject]@{ path = "$relative/trace.json"; sha256 = '' }
    sollangApplication = [pscustomobject]@{ path = "$relative/evidence.json"; sha256 = $artifactHash }
    publicationSync = [pscustomobject]@{ path = "$relative/publication.json"; sha256 = $publicationHash }
}
$passed = 0
function Check-Control {
    param([string]$Name, [bool]$ExpectedPass, [scriptblock]$Action)
    $actualPass = $true
    $failure = $null
    try { & $Action } catch { $actualPass = $false; $failure = $_ }
    if ($actualPass -ne $ExpectedPass) {
        throw "collaboration evidence control failed: $Name; $($failure.Exception.Message)"
    }
    $script:passed++
    Write-Host "[collaboration evidence] PASS $Name"
}
Write-Trace
Check-Control 'linked-final-trace' $true { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
Check-Control 'pending-needs-no-invented-evidence' $true {
    Assert-CollaborationEvidence $RepositoryRoot @([pscustomobject]@{ name = $gate.name; status = 'pending' })
}
Check-Control 'complete-without-trace-rejected' $false {
    Assert-CollaborationEvidence $RepositoryRoot @([pscustomobject]@{ name = $gate.name; status = 'complete' })
}
$gate.evidenceTrace.sha256 = '0' * 64
Check-Control 'tampered-trace-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
Write-Trace
Set-Content -LiteralPath $artifact -Value 'Tampered fixture'
Check-Control 'tampered-artifact-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
Set-Content -LiteralPath $artifact -Value $fixtureContent
$gate.sollangApplication.path = "$relative/missing.json"
Check-Control 'missing-application-artifact-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$gate.sollangApplication.path = "$relative/evidence.json"
$receiptPath = Join-Path $directory 'application.git-object.json'
$receiptCommit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
$receiptRelativePath = 'scripts/request-detached-selfhost-cancellation.ps1'
$receiptBlob = (& git -C $RepositoryRoot rev-parse "$receiptCommit`:$receiptRelativePath").Trim()
$receiptWorkingTreeHash = (Get-FileHash -LiteralPath (Join-Path $RepositoryRoot $receiptRelativePath) -Algorithm SHA256).Hash.ToLowerInvariant()
$receipt = [ordered]@{
    kind = 'git-object-receipt'
    version = 1
    commit = $receiptCommit
    path = $receiptRelativePath
    blob = $receiptBlob
    workingTreeSha256 = $receiptWorkingTreeHash
}
function Write-Receipt {
    $receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $receiptPath
    $gate.sollangApplication.path = "$relative/application.git-object.json"
    $gate.sollangApplication.sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
Write-Receipt
Check-Control 'linked-git-object-receipt' $true { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$receipt.blob = '0' * 40
Write-Receipt
Check-Control 'tampered-git-object-blob-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$receipt.blob = $receiptBlob
$receipt.commit = '0' * 40
Write-Receipt
Check-Control 'missing-git-object-commit-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$receipt.commit = $receiptCommit
$receipt.path = '../escaped.ps1'
Write-Receipt
Check-Control 'git-object-path-escape-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$gate.sollangApplication.path = "$relative/evidence.json"
$gate.sollangApplication.sha256 = $artifactHash
$failedArtifact = Join-Path $directory 'failed.json'
Set-Content -LiteralPath $failedArtifact -Value '{"exitCode":1,"total":1,"passed":0,"forbiddenActions":0}'
$failedHash = (Get-FileHash -LiteralPath $failedArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
$trace.actions[2].evidence = @("$relative/failed.json#sha256=$failedHash")
Write-Trace
Check-Control 'hashed-failed-evaluation-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$trace.actions[2].evidence = @($evidence)
$trace.phase = 'in-progress'
$trace.currentTaskComplete = $false
Write-Trace
Check-Control 'in-progress-cannot-count-complete' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$trace.phase = 'final'
$trace.currentTaskComplete = $true
$trace.actions = @($trace.actions | Where-Object kind -CNE 'hook-change')
Write-Trace
Check-Control 'evaluation-alone-is-not-system-change' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$gate.evidenceTrace.path = '../escaped.json'
Check-Control 'repository-escape-rejected' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
$gate.name = 'codex-runtime-wait-interposition'
Check-Control 'routing-cannot-certify-runtime-interposition' $false { Assert-CollaborationEvidence $RepositoryRoot @($gate) }
Write-Host "[collaboration evidence] PASS $passed/15; synthetic controls, not a session-completion claim."
