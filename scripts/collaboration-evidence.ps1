Set-StrictMode -Version Latest

function Assert-CollaborationEvidence {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][object[]]$Gates
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    function Read-EvidenceFile {
        param([string]$RelativePath, [string]$Sha256)
        if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
            throw 'collaboration evidence requires a repository-relative file'
        }
        $path = [IO.Path]::GetFullPath((Join-Path $root $RelativePath))
        if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'collaboration evidence escapes the repository'
        }
        $item = Get-Item -LiteralPath $path -ErrorAction Stop
        if ($item.PSIsContainer) { throw 'collaboration evidence must be a file' }
        $cursor = $item
        while ($null -ne $cursor -and $cursor.FullName.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'collaboration evidence cannot follow a reparse point'
            }
            $cursor = if ($cursor -is [IO.FileInfo]) { $cursor.Directory } else { $cursor.Parent }
        }
        if ($Sha256 -cnotmatch '^[a-f0-9]{64}$' -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Sha256) {
            throw "collaboration evidence hash mismatch: $RelativePath"
        }
        return $path
    }

    foreach ($gate in $Gates) {
        if ($gate.status -ceq 'pending') { continue }
        if ($gate.status -cne 'complete') { throw 'unsupported collaboration gate status' }
        if ($gate.name -ceq 'codex-runtime-wait-interposition') {
            throw 'runtime wait interception requires an independent dispatcher audit; AS-CR-001 cannot certify it'
        }
        if (-not $gate.PSObject.Properties['evidenceTrace']) {
            throw "complete collaboration gate requires evidenceTrace: $($gate.name)"
        }
        $tracePath = Read-EvidenceFile $gate.evidenceTrace.path $gate.evidenceTrace.sha256
        $trace = Get-Content -LiteralPath $tracePath -Raw | ConvertFrom-Json
        $expectedTarget = switch -CaseSensitive ($gate.name) {
            'agentic-shaping-hook-policy' { 'agentic-shaping' }
            'slogs-llm-wiki-policy' { 'slogs-llm-wiki' }
            default { throw "unknown collaboration gate: $($gate.name)" }
        }
        if ($trace.phase -cne 'final' -or $trace.currentTaskComplete -isnot [bool] -or
            -not $trace.currentTaskComplete -or $expectedTarget -cnotin $trace.requestTargets) {
            throw 'collaboration completion requires a final trace for the requested target; in-progress audits remain pending'
        }
        if ($gate.name -ceq 'agentic-shaping-hook-policy') {
            if (-not $gate.PSObject.Properties['publicationSync']) {
                throw 'complete Agentic Shaping collaboration requires publicationSync evidence'
            }
            $publicationPath = Read-EvidenceFile $gate.publicationSync.path $gate.publicationSync.sha256
            $publication = Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json
            if ($publication.systemTarget -cne 'agentic-shaping' -or
                $publication.ruleId -cne 'AS-PS-001' -or
                $publication.status -cne 'passed' -or
                $publication.exitCode -ne 0 -or
                $publication.total -lt 1 -or
                $publication.passed -ne $publication.total -or
                $publication.forbiddenActions -ne 0 -or
                $publication.synchronizedSurfaces -ne 8 -or
                $publication.git.stagedFiles -ne
                    ($publication.git.approvedInitialFiles + $publication.git.approvedAdditionalFiles) -or
                $publication.git.unexpectedStagedFiles -ne 0 -or
                $publication.git.commitCreated -ne $false -or
                $publication.git.pushPerformed -ne $false) {
                throw 'Agentic Shaping publication evidence is incomplete or outside the approved Git scope'
            }
        }
        foreach ($action in $trace.actions) {
            foreach ($entry in $action.evidence) {
                if ($entry -cnotmatch '^(.+)#sha256=([a-f0-9]{64})$') {
                    throw 'collaboration trace evidence requires path#sha256=hash'
                }
                $artifactPath = Read-EvidenceFile $Matches[1] $Matches[2]
                if ($action.kind -ceq 'behavioral-verification') {
                    $verification = Get-Content -LiteralPath $artifactPath -Raw | ConvertFrom-Json
                    if ($verification.exitCode -isnot [long] -and $verification.exitCode -isnot [int]) {
                        throw 'collaboration behavioral result requires an integer exitCode'
                    }
                    if ($verification.total -isnot [long] -and $verification.total -isnot [int]) {
                        throw 'collaboration behavioral result requires an integer total'
                    }
                    if ($verification.passed -isnot [long] -and $verification.passed -isnot [int]) {
                        throw 'collaboration behavioral result requires an integer passed count'
                    }
                    if ($verification.exitCode -ne 0 -or $verification.total -lt 1 -or
                        $verification.passed -ne $verification.total -or $verification.forbiddenActions -ne 0) {
                        throw 'collaboration behavioral result is not a complete passing evaluation'
                    }
                }
            }
        }
        $evaluator = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\AgenticShaping\evals\verify-collaboration-routing.mjs'))
        $resultText = & node $evaluator --trace $tracePath 2>&1
        if ($LASTEXITCODE -ne 0) { throw "collaboration AS-CR-001 rejected trace: $resultText" }
        $result = ($resultText -join [Environment]::NewLine) | ConvertFrom-Json
        if ($result.allowed -ne $true -or $result.code -cne 'system-evolution-routed') {
            throw 'collaboration trace did not prove the requested system evolution route'
        }
        # The trace proves routing only; subsequent Sollang application needs its own artifact.
        $null = Read-EvidenceFile $gate.sollangApplication.path $gate.sollangApplication.sha256
    }
}
