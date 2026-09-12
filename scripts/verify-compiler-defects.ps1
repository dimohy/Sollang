[CmdletBinding()]
param(
    [string]$RepositoryRoot = "",
    [switch]$RequireZeroKnownDefects
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $RepositoryRoot "scripts\contracts\compiler-defects.json"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json

if ($contract.schemaVersion -ne 2) {
    throw "compiler defect ledger schemaVersion must be 2"
}
if ($contract.completionPolicy.maximumKnownOpenDefects -ne 0) {
    throw "compiler completion policy must require zero known open defects"
}
$requiredEvidence = @($contract.completionPolicy.requiredEvidence)
foreach ($name in @(
    "focused-fixture",
    "managed-selfhost-differential",
    "stage2-stage3-fixed-point",
    "warning-zero",
    "agentic-shaping-baseline-candidate-trace")) {
    if ($requiredEvidence -notcontains $name) {
        throw "compiler completion policy is missing required evidence '$name'"
    }
}

$agenticShapingEvidenceRequiredFromSequence =
    [int]$contract.completionPolicy.agenticShapingEvidenceRequiredFromSequence
if ($agenticShapingEvidenceRequiredFromSequence -lt 1) {
    throw "compiler completion policy must name a positive Agentic Shaping evidence sequence"
}

function Get-DefectSequence {
    param([Parameter(Mandatory)][string]$Id)

    $match = [regex]::Match($Id, '-(?<sequence>[0-9]+)$')
    if (-not $match.Success) {
        throw "compiler defect id '$Id' must end with a numeric sequence"
    }
    [int]$match.Groups['sequence'].Value
}

function Resolve-ShapingEvidencePath {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Description
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "$Description must be repository-relative"
    }
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $RelativePath))
    $repositoryPrefix = $RepositoryRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description escapes the repository: $RelativePath"
    }
    $resolved
}

function Assert-ClosurePromotion {
    param([Parameter(Mandatory)][psobject]$Promotion)

    if ($Promotion.schemaVersion -ne 1 -or
        $Promotion.promotionId -cne 'compiler-stabilization-v0.5-2026-09-11' -or
        $Promotion.branch -cne 'v0.5') {
        throw 'compiler closure promotion identity is invalid'
    }
    if ($Promotion.prePromotionLedgerSha256 -notmatch '^[A-F0-9]{64}$' -or
        $Promotion.promotedCandidateIdsSha256 -notmatch '^[A-F0-9]{64}$' -or
        $Promotion.promotedCandidateCount -ne 262 -or
        $Promotion.expectedClosedCount -gt @($contract.defects).Count -or
        $Promotion.expectedKnownOpenCount -ne 0) {
        throw 'compiler closure promotion pre/post counts or fingerprints are invalid'
    }

    $requiredRuns = @(
        'Stage2',
        'Stage3',
        'Stage2Linux',
        'Stage3Linux',
        'Incremental',
        'BrowserStage2'
    )
    $runs = @($Promotion.runs)
    if ($runs.Count -ne $requiredRuns.Count -or
        @($runs.verification | Sort-Object -Unique).Count -ne $requiredRuns.Count) {
        throw 'compiler closure promotion must preserve six distinct base/delta runs'
    }
    foreach ($verification in $requiredRuns) {
        if ($runs.verification -cnotcontains $verification) {
            throw "compiler closure promotion is missing $verification"
        }
    }

    foreach ($run in $runs) {
        if ([string]::IsNullOrWhiteSpace($run.runId) -or
            $run.status -cne 'passed' -or
            $run.exitCode -ne 0 -or
            @($run.failureIds).Count -ne 0 -or
            @($run.orphanProcessIds).Count -ne 0 -or
            $run.resultSha256 -notmatch '^[A-F0-9]{64}$' -or
            $run.logSha256 -notmatch '^[A-F0-9]{64}$' -or
            [string]::IsNullOrWhiteSpace($run.summary)) {
            throw "compiler closure promotion run '$($run.runId)' is not a clean terminal success"
        }

        $resultPath = Resolve-ShapingEvidencePath -RelativePath $run.resultPath `
            -Description "$($run.runId) result"
        if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
            $actualResultSha256 = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash
            $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            if ($actualResultSha256 -cne $run.resultSha256 -or
                $result.runId -cne $run.runId -or
                $result.verification -cne $run.verification -or
                $result.status -cne 'passed' -or
                $result.exitCode -ne 0 -or
                @($result.failureIds).Count -ne 0 -or
                @($result.orphanProcessIds).Count -ne 0) {
                throw "compiler closure promotion run '$($run.runId)' differs from its source result"
            }
        }

        $logPath = Resolve-ShapingEvidencePath -RelativePath $run.logPath `
            -Description "$($run.runId) log"
        if (Test-Path -LiteralPath $logPath -PathType Leaf) {
            $actualLogSha256 = (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash
            if ($actualLogSha256 -cne $run.logSha256) {
                throw "compiler closure promotion run '$($run.runId)' differs from its source log"
            }
        }
    }

    $baseRevision = (& git -C $RepositoryRoot rev-parse "$($Promotion.baseStageRevision)^{commit}" 2>$null).Trim()
    $verifiedHeadRevision = (& git -C $RepositoryRoot rev-parse "$($Promotion.verifiedHeadRevision)^{commit}" 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or
        $baseRevision -notmatch '^[a-f0-9]{40}$' -or
        $verifiedHeadRevision -cne $Promotion.verifiedHeadRevision) {
        throw 'compiler closure promotion revisions are unavailable'
    }
    & git -C $RepositoryRoot merge-base --is-ancestor $baseRevision $verifiedHeadRevision
    if ($LASTEXITCODE -ne 0) {
        throw 'compiler closure promotion base is not an ancestor of its verified head'
    }
    & git -C $RepositoryRoot merge-base --is-ancestor $verifiedHeadRevision HEAD
    if ($LASTEXITCODE -ne 0) {
        throw 'compiler closure promotion verified head is not an ancestor of HEAD'
    }
    foreach ($delta in @($Promotion.deltaCommits)) {
        $deltaRevision = (& git -C $RepositoryRoot rev-parse "$($delta.revision)^{commit}" 2>$null).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($delta.defectId)) {
            throw "compiler closure promotion delta '$($delta.defectId)' is unavailable"
        }
        & git -C $RepositoryRoot merge-base --is-ancestor $deltaRevision $verifiedHeadRevision
        if ($LASTEXITCODE -ne 0) {
            throw "compiler closure promotion delta '$($delta.defectId)' is outside the verified head"
        }
    }

    Write-Host "[compiler closure promotion] PASS $($Promotion.promotedCandidateCount) candidates, $($runs.Count) base/delta runs, and clean terminal results."
}

function Assert-ShapingReceipt {
    param(
        [Parameter(Mandatory)][string]$DefectId,
        [Parameter(Mandatory)][string]$Phase,
        [Parameter(Mandatory)][string]$ExpectedInputFingerprint,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $receiptPath = Resolve-ShapingEvidencePath -RelativePath $RelativePath `
        -Description "$DefectId $Phase receipt"
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
        throw "compiler defect '$DefectId' $Phase receipt is missing: $receiptPath"
    }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ($receipt.schemaVersion -ne 1 -or $receipt.defectId -cne $DefectId -or
        $receipt.phase -cne $Phase -or
        $receipt.inputFingerprint -cne $ExpectedInputFingerprint -or
        [string]::IsNullOrWhiteSpace($receipt.command) -or
        $receipt.outputSha256 -notmatch '^[A-Fa-f0-9]{64}$' -or
        [string]::IsNullOrWhiteSpace($receipt.outputPath)) {
        throw "compiler defect '$DefectId' has an invalid $Phase shaping receipt"
    }
    if ($Phase -in @('candidate', 'measurement') -and $receipt.exitCode -ne 0) {
        throw "compiler defect '$DefectId' $Phase shaping command did not pass"
    }
    if (-not ($receipt.PSObject.Properties.Name -contains 'expectedExitCode') -or
        $receipt.exitCode -ne $receipt.expectedExitCode) {
        throw "compiler defect '$DefectId' $Phase shaping command exit does not match its expected exit"
    }
    $outputPath = Resolve-ShapingEvidencePath -RelativePath $receipt.outputPath `
        -Description "$DefectId $Phase output"
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "compiler defect '$DefectId' $Phase output is missing: $outputPath"
    }
    $actualOutputSha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
    if ($actualOutputSha256 -cne $receipt.outputSha256.ToUpperInvariant()) {
        throw "compiler defect '$DefectId' $Phase output hash does not match its receipt"
    }
}

function Assert-ShapingEvidence {
    param(
        [Parameter(Mandatory)][psobject]$Defect,
        [Parameter(Mandatory)][int]$Sequence
    )

    if ($Sequence -lt $agenticShapingEvidenceRequiredFromSequence) {
        return
    }
    if (-not ($Defect.PSObject.Properties.Name -contains 'shapingEvidence')) {
        throw "compiler defect '$($Defect.id)' must preserve Agentic Shaping evidence before repair"
    }

    $evidence = $Defect.shapingEvidence
    foreach ($field in @('inputFingerprint', 'baselineReceipt', 'tracePath')) {
        if ([string]::IsNullOrWhiteSpace($evidence.$field)) {
            throw "compiler defect '$($Defect.id)' shapingEvidence is missing $field"
        }
    }
    if ($evidence.inputFingerprint -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "compiler defect '$($Defect.id)' shapingEvidence inputFingerprint must be SHA-256"
    }

    Assert-ShapingReceipt -DefectId $Defect.id -Phase 'baseline' `
        -ExpectedInputFingerprint $evidence.inputFingerprint `
        -RelativePath $evidence.baselineReceipt

    $tracePath = Resolve-ShapingEvidencePath -RelativePath $evidence.tracePath `
        -Description "$($Defect.id) AS-US-001 trace"
    if (-not (Test-Path -LiteralPath $tracePath -PathType Leaf)) {
        throw "compiler defect '$($Defect.id)' AS-US-001 trace is missing: $tracePath"
    }
    $trace = Get-Content -LiteralPath $tracePath -Raw | ConvertFrom-Json
    if ($trace.ruleId -cne 'AS-US-001' -or
        $trace.signal.id -cne $Defect.id -or
        $trace.orchestratorEvidence.inputFingerprint -cne $evidence.inputFingerprint) {
        throw "compiler defect '$($Defect.id)' AS-US-001 trace identity does not match the ledger"
    }

    $agenticShapingEvaluator = [System.IO.Path]::GetFullPath(
        (Join-Path $RepositoryRoot '..\AgenticShaping\evals\unstructured-to-structured.mjs'))
    if (-not (Test-Path -LiteralPath $agenticShapingEvaluator -PathType Leaf)) {
        throw "Agentic Shaping AS-US-001 evaluator is unavailable: $agenticShapingEvaluator"
    }
    $evaluation = & node $agenticShapingEvaluator --trace $tracePath 2>&1

    # Ledger state tracks defect closure, while the trace tracks whether a
    # durable partial repair has already been structured and applied. An open
    # defect may therefore require candidate evidence without being promoted.
    $structuredClaim = $trace.decision.claimLevel -in @('structured-and-applied', 'measured-improvement')
    $requiresCandidateEvidence = $Defect.state -in @('candidate-fixed', 'closed') -or $structuredClaim
    if ($requiresCandidateEvidence) {
        foreach ($field in @('candidateReceipt')) {
            if ([string]::IsNullOrWhiteSpace($evidence.$field)) {
                throw "compiler defect '$($Defect.id)' shapingEvidence is missing $field"
            }
        }
        Assert-ShapingReceipt -DefectId $Defect.id -Phase 'candidate' `
            -ExpectedInputFingerprint $evidence.inputFingerprint `
            -RelativePath $evidence.candidateReceipt

        if ($trace.decision.claimLevel -eq 'measured-improvement') {
            if ([string]::IsNullOrWhiteSpace($evidence.measurementReceipt)) {
                throw "compiler defect '$($Defect.id)' measured improvement is missing measurementReceipt"
            }
            Assert-ShapingReceipt -DefectId $Defect.id -Phase 'measurement' `
                -ExpectedInputFingerprint $evidence.inputFingerprint `
                -RelativePath $evidence.measurementReceipt
        }

        if ($trace.decision.asset.inputFingerprint -cne $evidence.inputFingerprint) {
            throw "compiler defect '$($Defect.id)' AS-US-001 trace identity does not match the ledger"
        }
        if (-not $structuredClaim -or $LASTEXITCODE -ne 0 -or
            $evaluation -notmatch 'AS-US-001-STRUCTURED-(AND-APPLIED|IMPROVEMENT)') {
            throw "compiler defect '$($Defect.id)' AS-US-001 trace was rejected: $evaluation"
        }
    } elseif ($LASTEXITCODE -ne 0 -or $evaluation -notmatch 'AS-US-001-SIGNAL-OBSERVED') {
        throw "compiler defect '$($Defect.id)' open AS-US-001 trace was rejected: $evaluation"
    }
}

$missingBaselineRejected = $false
try {
    Assert-ShapingEvidence -Sequence $agenticShapingEvidenceRequiredFromSequence -Defect ([pscustomobject]@{
        id = "C-contract-$agenticShapingEvidenceRequiredFromSequence"
        state = 'open'
    })
} catch {
    if ($_.Exception.Message -like '*must preserve Agentic Shaping evidence before repair*') {
        $missingBaselineRejected = $true
    } else {
        throw
    }
}
if (-not $missingBaselineRejected) {
    throw "Agentic Shaping compiler-defect baseline negative control was accepted"
}

$pathEscapeRejected = $false
try {
    Resolve-ShapingEvidencePath -RelativePath '..\outside.json' -Description 'negative control' | Out-Null
} catch {
    if ($_.Exception.Message -like '*escapes the repository*') {
        $pathEscapeRejected = $true
    } else {
        throw
    }
}
if (-not $pathEscapeRejected) {
    throw "Agentic Shaping compiler-defect path-escape negative control was accepted"
}
Write-Host "[compiler defects] Agentic Shaping signal/baseline/candidate gate starts at sequence $agenticShapingEvidenceRequiredFromSequence; missing-baseline and path-escape controls PASS."

$allowedClassifications = @("latent-defect", "introduced-regression", "environment", "verifier")
$allowedStates = @("open", "candidate-fixed", "closed")
$missingShapingEvidence = @($contract.defects | Where-Object {
    (Get-DefectSequence -Id $_.id) -ge $agenticShapingEvidenceRequiredFromSequence -and
        -not ($_.PSObject.Properties.Name -contains 'shapingEvidence')
})
if ($missingShapingEvidence.Count -gt 0) {
    $missingIds = $missingShapingEvidence | ForEach-Object id
    throw "compiler defects must preserve Agentic Shaping evidence before repair; missing $($missingShapingEvidence.Count): $($missingIds -join ', ')"
}
$ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($defect in @($contract.defects)) {
    if ([string]::IsNullOrWhiteSpace($defect.id) -or -not $ids.Add($defect.id)) {
        throw "compiler defect ids must be non-empty and unique"
    }
    if ($allowedClassifications -notcontains $defect.classification) {
        throw "compiler defect '$($defect.id)' has invalid classification '$($defect.classification)'"
    }
    if ($allowedStates -notcontains $defect.state) {
        throw "compiler defect '$($defect.id)' has invalid state '$($defect.state)'"
    }
    $defectSequence = Get-DefectSequence -Id $defect.id
    Assert-ShapingEvidence -Defect $defect -Sequence $defectSequence
    foreach ($field in @("owner", "rootCause", "focusedFixture", "closureGate")) {
        if ([string]::IsNullOrWhiteSpace($defect.$field)) {
            throw "compiler defect '$($defect.id)' is missing $field"
        }
    }
    if ($defect.state -eq "closed") {
        if (-not ($defect.PSObject.Properties.Name -contains "closedEvidence") -or
            @($defect.closedEvidence).Count -eq 0) {
            throw "closed compiler defect '$($defect.id)' has no closedEvidence"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($contract.closurePromotion)) {
    throw 'compiler defect ledger is missing closurePromotion'
}
$closurePromotionPath = Resolve-ShapingEvidencePath -RelativePath $contract.closurePromotion `
    -Description 'compiler closure promotion'
if (-not (Test-Path -LiteralPath $closurePromotionPath -PathType Leaf)) {
    throw "compiler closure promotion is missing: $closurePromotionPath"
}
$closurePromotion = Get-Content -LiteralPath $closurePromotionPath -Raw | ConvertFrom-Json
Assert-ClosurePromotion -Promotion $closurePromotion

$knownOpen = @($contract.defects | Where-Object state -ne "closed")
$byClass = $knownOpen | Group-Object classification | Sort-Object Name
foreach ($group in $byClass) {
    Write-Host "[compiler defects] $($group.Name): $($group.Count) open or candidate-fixed"
}
Write-Host "[compiler defects] known-open=$($knownOpen.Count), total-recorded=$(@($contract.defects).Count)."

if ($RequireZeroKnownDefects -and $knownOpen.Count -ne 0) {
    $details = $knownOpen | ForEach-Object { "$($_.id)=$($_.state)" }
    throw "release requires zero known compiler defects; unresolved: $($details -join ', ')"
}

Write-Host "[compiler defects] PASS ledger structure and zero-defect completion policy."
