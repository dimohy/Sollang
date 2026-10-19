[CmdletBinding()]
param(
    [string]$RepositoryRoot = '',
    [switch]$RequireVerified,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path -Parent $PSScriptRoot
}
$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$ledgerPath = Join-Path $RepositoryRoot 'scripts/contracts/compiler-defects.json'
$manifestPath = Join-Path $RepositoryRoot 'scripts/contracts/compiler-defect-evidence-migration.json'
$shaPattern = '^[A-F0-9]{64}$'

function Get-Field {
    param([object]$Value, [string]$Name)
    if ($null -eq $Value -or -not ($Value.PSObject.Properties.Name -contains $Name)) {
        return $null
    }
    return ,$Value.$Name
}

function Test-Sha256 {
    param([object]$Value)
    return $Value -is [string] -and $Value -cmatch $shaPattern
}

function Resolve-RepositoryPath {
    param([string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Evidence path must be nonempty and repository-relative: $RelativePath"
    }
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $RelativePath))
    $prefix = $RepositoryRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Evidence path escapes the repository: $RelativePath"
    }
    $current = $RepositoryRoot
    if (((Get-Item -LiteralPath $current -Force).Attributes -band
        [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Repository root is a reparse point: $RepositoryRoot"
    }
    foreach ($segment in ($RelativePath -split '[\\/]')) {
        if ($segment -eq '') { continue }
        if ($segment -in @('.', '..')) {
            throw "Evidence path contains a traversal segment: $RelativePath"
        }
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { continue }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Evidence path traverses a reparse point: $RelativePath"
        }
    }
    return $resolved
}

function Test-PinnedFile {
    param([string]$RelativePath, [string]$ExpectedSha256, [System.Collections.Generic.List[string]]$Issues, [string]$Prefix)
    if (-not (Test-Sha256 $ExpectedSha256)) {
        $Issues.Add("$Prefix.expectedSha256")
        return $null
    }
    try {
        $path = Resolve-RepositoryPath $RelativePath
    } catch {
        $Issues.Add("$Prefix.path")
        return $null
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $Issues.Add("$Prefix.file")
        return $null
    }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
    } catch {
        $Issues.Add("$Prefix.file")
        return $null
    }
    $actualSha256 = [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes))
    if ($actualSha256 -cne $ExpectedSha256) {
        $Issues.Add("$Prefix.sha256")
        return $null
    }
    try {
        $jsonText = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        if ($jsonText.StartsWith([string][char]0xFEFF, [System.StringComparison]::Ordinal)) {
            $jsonText = $jsonText.Substring(1)
        }
        return ConvertFrom-Json -InputObject $jsonText
    } catch {
        $Issues.Add("$Prefix.json")
        return $null
    }
}

function Test-EmptyArrayField {
    param([object]$Record, [string]$Field, [System.Collections.Generic.List[string]]$Issues, [string]$Prefix)
    $value = Get-Field $Record $Field
    if ($value -isnot [System.Array] -or $value.Count -ne 0) {
        $Issues.Add("$Prefix.$Field")
    }
}

function Test-ReferencedResult {
    param(
        [string]$RelativePath,
        [string]$ExpectedSha256,
        [string]$Phase,
        [object]$PhaseRecord,
        [string]$DefectId,
        [System.Collections.Generic.List[string]]$Issues,
        [string]$Prefix
    )
    $result = Test-PinnedFile $RelativePath $ExpectedSha256 $Issues $Prefix
    if ($null -eq $result) { return }
    Test-ResultState $result $Phase $PhaseRecord $DefectId $Issues $Prefix
}

function Test-ResultState {
    param(
        [object]$Result,
        [string]$Phase,
        [object]$PhaseRecord,
        [string]$DefectId,
        [System.Collections.Generic.List[string]]$Issues,
        [string]$Prefix
    )
    $status = Get-Field $Result 'status'
    $exitCode = Get-Field $Result 'exitCode'
    if ($status -isnot [string]) { $Issues.Add("$Prefix.statusType") }
    if ($exitCode -isnot [long]) { $Issues.Add("$Prefix.exitCodeType") }
    if ($Phase -eq 'candidate') {
        if ($status -cne 'passed') { $Issues.Add("$Prefix.status") }
        if ($null -eq $exitCode -or $exitCode -ne 0) { $Issues.Add("$Prefix.exitCode") }
        Test-EmptyArrayField $Result 'failureIds' $Issues $Prefix
    } else {
        if ($status -cnotin @('failed', 'failed-as-expected')) { $Issues.Add("$Prefix.status") }
        if ($null -eq $exitCode -or $exitCode -eq 0) { $Issues.Add("$Prefix.exitCode") }
    }
    Test-EmptyArrayField $Result 'orphanProcessIds' $Issues $Prefix
    if ($status -cne (Get-Field $PhaseRecord 'status')) { $Issues.Add("$Prefix.phaseStatus") }
    if ($exitCode -ne (Get-Field $PhaseRecord 'exitCode')) { $Issues.Add("$Prefix.phaseExitCode") }
    $resultDefectId = Get-Field $Result 'defectId'
    $recordRunId = Get-Field $PhaseRecord 'runId'
    $resultRunId = Get-Field $Result 'runId'
    if ($null -ne $resultDefectId -and $resultDefectId -cne $DefectId) {
        $Issues.Add("$Prefix.defectId")
    }
    if ($null -ne $resultRunId -and $resultRunId -cne $recordRunId) {
        $Issues.Add("$Prefix.runId")
    }
    if ($resultDefectId -cne $DefectId -and
        ($null -eq $recordRunId -or $resultRunId -cne $recordRunId)) {
        $Issues.Add("$Prefix.identity")
    }
    $resultPhase = Get-Field $Result 'phase'
    if ($null -ne $resultPhase -and $resultPhase -cne $Phase) {
        $Issues.Add("$Prefix.phase")
    }
    $resultFingerprint = Get-Field $Result 'inputFingerprint'
    if ($null -ne $resultFingerprint -and
        $resultFingerprint -cne (Get-Field $PhaseRecord 'inputFingerprint')) {
        $Issues.Add("$Prefix.inputFingerprint")
    }
    $candidateCompilerSha256 = Get-Field $PhaseRecord 'candidateCompilerSha256'
    if ($null -ne $candidateCompilerSha256 -and
        (Get-Field $Result 'candidateCompilerSha256') -cne $candidateCompilerSha256) {
        $Issues.Add("$Prefix.candidateCompilerSha256")
    }
    if ($null -ne $candidateCompilerSha256) {
        $compilerPath = Get-Field $Result 'candidateCompiler'
        try {
            $resolvedCompiler = Resolve-RepositoryPath $compilerPath
            if (-not (Test-Path -LiteralPath $resolvedCompiler -PathType Leaf) -or
                (Get-FileHash -LiteralPath $resolvedCompiler -Algorithm SHA256).Hash -cne
                    $candidateCompilerSha256) {
                $Issues.Add("$Prefix.candidateCompilerFileSha256")
            }
        } catch {
            $Issues.Add("$Prefix.candidateCompilerPath")
        }
    }
    $recordCompleted = Get-Field $PhaseRecord 'completed'
    $recordTotal = Get-Field $PhaseRecord 'total'
    if ($null -ne $recordCompleted -or $null -ne $recordTotal) {
        if ($recordCompleted -isnot [long] -or $recordTotal -isnot [long] -or
            $recordTotal -le 0 -or
            $recordCompleted -ne $recordTotal -or
            (Get-Field $Result 'completed') -isnot [long] -or
            (Get-Field $Result 'total') -isnot [long] -or
            (Get-Field $Result 'completed') -ne $recordCompleted -or
            (Get-Field $Result 'total') -ne $recordTotal) {
            $Issues.Add("$Prefix.completedTotal")
        }
    }
    $recordFailureIds = Get-Field $PhaseRecord 'failureIds'
    if ($null -ne $recordFailureIds -and
        (@($recordFailureIds) -join '|') -cne (@((Get-Field $Result 'failureIds')) -join '|')) {
        $Issues.Add("$Prefix.failureIds")
    }
}

function Test-PhaseRecord {
    param(
        [object]$Record,
        [string]$Id,
        [string]$Phase,
        [string]$LedgerFingerprint,
        [System.Collections.Generic.List[string]]$Issues
    )
    $prefix = $Phase
    if ($null -eq $Record) { return $null }
    if ((Get-Field $Record 'schemaVersion') -isnot [long] -or
        (Get-Field $Record 'schemaVersion') -ne 1) { $Issues.Add("$prefix.schemaVersion") }
    if ((Get-Field $Record 'defectId') -cne $Id) { $Issues.Add("$prefix.defectId") }
    if ((Get-Field $Record 'phase') -cne $Phase) { $Issues.Add("$prefix.phase") }
    $fingerprint = Get-Field $Record 'inputFingerprint'
    if (-not (Test-Sha256 $fingerprint)) { $Issues.Add("$prefix.inputFingerprint") }
    if ($null -ne $LedgerFingerprint -and $fingerprint -cne $LedgerFingerprint) {
        $Issues.Add("$prefix.ledgerInputFingerprint")
    }

    $status = Get-Field $Record 'status'
    $exitCode = Get-Field $Record 'exitCode'
    if ($status -isnot [string]) { $Issues.Add("$prefix.statusType") }
    if ($exitCode -isnot [long]) { $Issues.Add("$prefix.exitCodeType") }
    if ($Phase -eq 'candidate') {
        if ($status -cne 'passed') { $Issues.Add("$prefix.status") }
        if ($null -eq $exitCode -or $exitCode -ne 0) { $Issues.Add("$prefix.exitCode") }
        Test-EmptyArrayField $Record 'failureIds' $Issues $prefix
    } else {
        if ($status -cnotin @('failed', 'failed-as-expected')) { $Issues.Add("$prefix.status") }
        if ($null -eq $exitCode -or $exitCode -eq 0) { $Issues.Add("$prefix.exitCode") }
    }
    Test-EmptyArrayField $Record 'orphanProcessIds' $Issues $prefix
    $expectedExitCode = Get-Field $Record 'expectedExitCode'
    if ($null -ne $expectedExitCode -and $expectedExitCode -ne $exitCode) {
        $Issues.Add("$prefix.expectedExitCode")
    }

    $outputPath = Get-Field $Record 'outputPath'
    if ($null -ne $outputPath) {
        $outputSha256 = Get-Field $Record 'outputSha256'
        if (-not (Test-Sha256 $outputSha256)) {
            $Issues.Add("$prefix.outputSha256")
        } else {
            try {
                $resolvedOutput = Resolve-RepositoryPath $outputPath
                if (-not (Test-Path -LiteralPath $resolvedOutput -PathType Leaf) -or
                    (Get-FileHash -LiteralPath $resolvedOutput -Algorithm SHA256).Hash -cne $outputSha256) {
                    $Issues.Add("$prefix.outputSha256")
                }
            } catch {
                $Issues.Add("$prefix.outputPath")
            }
        }
    } elseif ($null -ne (Get-Field $Record 'outputSha256')) {
        $Issues.Add("$prefix.outputPath")
    }

    $completionRecord = Get-Field $Record 'completionRecord'
    $completionRecords = Get-Field $Record 'completionRecords'
    if ($null -ne $completionRecord -and $null -ne $completionRecords) {
        $Issues.Add("$prefix.completionRecordForm")
    }
    if ($null -ne $completionRecord) {
        Test-ReferencedResult $completionRecord (Get-Field $Record 'completionRecordSha256') `
            $Phase $Record $Id $Issues "$prefix.completionRecord"
    } elseif ($null -ne $completionRecords -and @($completionRecords).Count -gt 0) {
        $index = 0
        foreach ($item in @($completionRecords)) {
            Test-ReferencedResult (Get-Field $item 'path') (Get-Field $item 'sha256') `
                $Phase $Record $Id $Issues "$prefix.completionRecords[$index]"
            $index++
        }
    } else {
        $Issues.Add("$prefix.completionRecord")
    }
    return $fingerprint
}

function Test-FlatTrace {
    param([object]$Trace, [object]$Defect, [System.Collections.Generic.List[string]]$Issues)
    if ($null -eq $Trace) { return }
    if ((Get-Field $Trace 'schemaVersion') -ne 1 -or
        (Get-Field $Trace 'ruleId') -eq 'AS-US-001') {
        $Issues.Add('trace.schemaKind')
    }
    if ((Get-Field $Trace 'defectId') -cne $Defect.id) { $Issues.Add('trace.defectId') }
    foreach ($field in @('signal', 'structure')) {
        if ([string]::IsNullOrWhiteSpace((Get-Field $Trace $field))) {
            $Issues.Add("trace.$field")
        }
    }
    if ((Get-Field $Trace 'baselineReceipt') -cne $Defect.shapingEvidence.baselineReceipt) {
        $Issues.Add('trace.baselineReceipt')
    }
    if ((Get-Field $Trace 'candidateReceipt') -cne $Defect.shapingEvidence.candidateReceipt) {
        $Issues.Add('trace.candidateReceipt')
    }
    $authorityPath = Get-Field $Trace 'authorityPath'
    $authorityPaths = Get-Field $Trace 'authorityPaths'
    $declaredPaths = @($authorityPath) + @($authorityPaths)
    $declaredPaths = @($declaredPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($declaredPaths.Count -eq 0) {
        $Issues.Add('trace.authorityPath')
    }
    foreach ($declaredPath in $declaredPaths) {
        try {
            $resolvedAuthority = Resolve-RepositoryPath $declaredPath
            if (-not (Test-Path -LiteralPath $resolvedAuthority -PathType Leaf)) {
                $Issues.Add('trace.authorityFile')
            }
        } catch {
            $Issues.Add('trace.authorityFile')
        }
    }
}

function Assert-ManifestContract {
    param([object]$Manifest)
    if ($Manifest.schemaVersion -isnot [long] -or $Manifest.schemaVersion -ne 1 -or
        $Manifest.entries -isnot [System.Array] -or $Manifest.entries.Count -ne 17) {
        throw 'Migration manifest must contain exactly 17 version-1 entries'
    }
    $expectedTopLevelFields = @('schemaVersion', 'purpose', 'entries')
    if ($Manifest.purpose -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Manifest.purpose) -or
        @($Manifest.PSObject.Properties.Name | Where-Object { $_ -cnotin $expectedTopLevelFields }).Count -ne 0) {
        throw 'Migration manifest has missing purpose or unknown top-level fields'
    }
    $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in @($Manifest.entries)) {
        if ($entry.id -cnotmatch '^C[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]+$' -or
            -not $ids.Add($entry.id)) {
            throw 'Migration manifest ids must be unique compiler defect ids'
        }
        foreach ($field in @('traceSha256', 'baselineSha256', 'candidateSha256')) {
            if (-not (Test-Sha256 (Get-Field $entry $field))) {
                throw "Migration manifest $($entry.id) has invalid $field"
            }
        }
        $expectedFields = @('id', 'traceSha256', 'baselineSha256', 'candidateSha256')
        if (@($entry.PSObject.Properties.Name | Where-Object { $_ -cnotin $expectedFields }).Count -ne 0) {
            throw "Migration manifest $($entry.id) has an unknown field"
        }
    }
}

function Invoke-SelfTest {
    $id = 'C2026-09-23-999'
    $sha = 'A' * 64
    $artifactPath = 'scripts/verify-compiler-defect-evidence-migration.ps1'
    $artifactSha = (Get-FileHash -LiteralPath (Join-Path $RepositoryRoot $artifactPath) -Algorithm SHA256).Hash
    $valid = [pscustomobject]@{
        schemaVersion = [long]1; defectId = $id; phase = 'candidate'; status = 'passed'
        inputFingerprint = $sha; exitCode = [long]0; failureIds = @(); orphanProcessIds = @()
        runId = 'candidate-test'; candidateCompilerSha256 = $artifactSha
        completed = [long]1; total = [long]1
        completionRecord = 'missing/result.json'; completionRecordSha256 = $sha
    }
    $mutations = @(
        @{ Name = 'missing-input-fingerprint'; Field = 'inputFingerprint'; Value = $null; Expected = 'candidate.inputFingerprint' },
        @{ Name = 'failed-candidate'; Field = 'status'; Value = 'failed'; Expected = 'candidate.status' },
        @{ Name = 'nonzero-candidate'; Field = 'exitCode'; Value = 1; Expected = 'candidate.exitCode' },
        @{ Name = 'string-candidate-exit'; Field = 'exitCode'; Value = '0'; Expected = 'candidate.exitCodeType' },
        @{ Name = 'orphan-process'; Field = 'orphanProcessIds'; Value = @(42); Expected = 'candidate.orphanProcessIds' },
        @{ Name = 'scalar-orphan-field'; Field = 'orphanProcessIds'; Value = ''; Expected = 'candidate.orphanProcessIds' },
        @{ Name = 'missing-result-hash'; Field = 'completionRecordSha256'; Value = $null; Expected = 'candidate.completionRecord.expectedSha256' }
    )
    foreach ($mutation in $mutations) {
        $record = $valid | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        $record.($mutation.Field) = $mutation.Value
        $issues = [System.Collections.Generic.List[string]]::new()
        Test-PhaseRecord $record $id 'candidate' $sha $issues | Out-Null
        if (-not $issues.Contains($mutation.Expected)) {
            throw "Migration negative test $($mutation.Name) was accepted"
        }
    }
    $trace = [pscustomobject]@{
        schemaVersion = 1; defectId = $id; signal = 'observed'; structure = 'applied'
        authorityPath = 'scripts/example.ps1'; baselineReceipt = 'baseline.json'
        candidateReceipt = 'candidate.json'
    }
    $defect = [pscustomobject]@{
        id = $id
        shapingEvidence = [pscustomobject]@{ baselineReceipt = 'baseline.json'; candidateReceipt = 'candidate.json' }
    }
    $trace.candidateReceipt = 'wrong.json'
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-FlatTrace $trace $defect $issues
    if (-not $issues.Contains('trace.candidateReceipt')) {
        throw 'Migration negative test mismatched trace link was accepted'
    }
    if (-not $issues.Contains('trace.authorityFile')) {
        throw 'Migration negative test missing trace authority was accepted'
    }
    $result = [pscustomobject]@{
        defectId = $id; runId = 'candidate-test'; status = 'passed'; exitCode = [long]0
        inputFingerprint = $sha; candidateCompilerSha256 = $artifactSha
        candidateCompiler = $artifactPath
        completed = [long]1; total = [long]1; failureIds = @(); orphanProcessIds = @()
    }
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-ResultState $result 'candidate' $valid $id $issues 'completion'
    if ($issues.Count -ne 0) { throw 'Migration positive identity control was rejected' }
    $resultMutations = @(
        @{ Name = 'wrong-defect'; Field = 'defectId'; Value = 'C2026-09-23-998'; Expected = 'completion.defectId' },
        @{ Name = 'wrong-run'; Field = 'runId'; Value = 'another-run'; Expected = 'completion.runId' },
        @{ Name = 'wrong-input'; Field = 'inputFingerprint'; Value = ('B' * 64); Expected = 'completion.inputFingerprint' },
        @{ Name = 'wrong-compiler'; Field = 'candidateCompilerSha256'; Value = ('B' * 64); Expected = 'completion.candidateCompilerSha256' },
        @{ Name = 'wrong-compiler-file'; Field = 'candidateCompiler'; Value = 'scripts/contracts/compiler-defect-evidence-migration.json'; Expected = 'completion.candidateCompilerFileSha256' },
        @{ Name = 'wrong-count'; Field = 'completed'; Value = 0; Expected = 'completion.completedTotal' },
        @{ Name = 'wrong-status-link'; Field = 'status'; Value = 'failed'; Expected = 'completion.phaseStatus' },
        @{ Name = 'wrong-exit-link'; Field = 'exitCode'; Value = 1; Expected = 'completion.phaseExitCode' },
        @{ Name = 'string-result-exit'; Field = 'exitCode'; Value = '0'; Expected = 'completion.exitCodeType' }
    )
    foreach ($mutation in $resultMutations) {
        $changed = $result | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        $changed.($mutation.Field) = $mutation.Value
        $issues = [System.Collections.Generic.List[string]]::new()
        Test-ResultState $changed 'candidate' $valid $id $issues 'completion'
        if (-not $issues.Contains($mutation.Expected)) {
            throw "Migration result identity mutation $($mutation.Name) was accepted"
        }
    }
    $result.orphanProcessIds = @(42)
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-ResultState $result 'candidate' $valid $id $issues 'completion'
    if (-not $issues.Contains('completion.orphanProcessIds')) {
        throw 'Migration negative test referenced-result orphan was accepted'
    }
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-PinnedFile 'scripts/contracts/compiler-defect-evidence-migration.json' $sha $issues 'pinned' | Out-Null
    if (-not $issues.Contains('pinned.sha256')) {
        throw 'Migration negative test wrong source hash was accepted'
    }
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-PinnedFile '../outside.json' $sha $issues 'escape' | Out-Null
    if (-not $issues.Contains('escape.path')) {
        throw 'Migration negative test path escape was accepted'
    }
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-PinnedFile 'scripts/../scripts/contracts/compiler-defect-evidence-migration.json' `
        $sha $issues 'traversal' | Out-Null
    if (-not $issues.Contains('traversal.path')) {
        throw 'Migration negative test interior path traversal was accepted'
    }
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-PhaseRecord $valid $id 'candidate' ('B' * 64) $issues | Out-Null
    if (-not $issues.Contains('candidate.ledgerInputFingerprint')) {
        throw 'Migration negative test wrong ledger fingerprint was accepted'
    }
    $bothForms = $valid | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $bothForms | Add-Member -NotePropertyName completionRecords -NotePropertyValue @()
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-PhaseRecord $bothForms $id 'candidate' $sha $issues | Out-Null
    if (-not $issues.Contains('candidate.completionRecordForm')) {
        throw 'Migration negative test ambiguous completion references was accepted'
    }
    $orphanOutputHash = $valid | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $orphanOutputHash | Add-Member -NotePropertyName outputSha256 -NotePropertyValue $sha
    $issues = [System.Collections.Generic.List[string]]::new()
    Test-PhaseRecord $orphanOutputHash $id 'candidate' $sha $issues | Out-Null
    if (-not $issues.Contains('candidate.outputPath')) {
        throw 'Migration negative test unlinked output hash was accepted'
    }
    Write-Host '[compiler evidence migration] PASS 25 adversarial controls and 1 positive identity control.'
}

if ($SelfTest) { Invoke-SelfTest }

$ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-ManifestContract $manifest

$defectById = @{}
$flatTraceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($defect in @($ledger.defects)) {
    $defectById[$defect.id] = $defect
    $tracePath = Get-Field (Get-Field $defect 'shapingEvidence') 'tracePath'
    if ([string]::IsNullOrWhiteSpace($tracePath)) { continue }
    $path = Resolve-RepositoryPath $tracePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $trace = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ((Get-Field $trace 'ruleId') -cne 'AS-US-001') {
        [void]$flatTraceIds.Add($defect.id)
    }
}
$manifestIds = @($manifest.entries | ForEach-Object id)
if ($flatTraceIds.Count -ne $manifestIds.Count -or
    @($manifestIds | Where-Object { -not $flatTraceIds.Contains($_) }).Count -ne 0) {
    throw "Migration inventory drift: flat traces=$($flatTraceIds.Count), manifest=$($manifestIds.Count)"
}

$entries = foreach ($entry in @($manifest.entries)) {
    $defect = $defectById[$entry.id]
    $issues = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $defect) {
        $issues.Add('ledger.defectId')
        [pscustomobject]@{ id = $entry.id; verified = $false; missingFields = @($issues) }
        continue
    }
    $evidence = $defect.shapingEvidence
    $trace = Test-PinnedFile $evidence.tracePath $entry.traceSha256 $issues 'trace'
    Test-FlatTrace $trace $defect $issues
    $baseline = Test-PinnedFile $evidence.baselineReceipt $entry.baselineSha256 $issues 'baseline'
    $baselineFingerprint = Test-PhaseRecord $baseline $entry.id 'baseline' `
        (Get-Field $evidence 'inputFingerprint') $issues
    $candidate = Test-PinnedFile $evidence.candidateReceipt $entry.candidateSha256 $issues 'candidate'
    $candidateFingerprint = Test-PhaseRecord $candidate $entry.id 'candidate' `
        (Get-Field $evidence 'inputFingerprint') $issues
    [pscustomobject]@{
        id = $entry.id
        verified = ($issues.Count -eq 0)
        traceKind = 'flat-shaping-claim; not AS-US-001 evaluator proof'
        phases = [pscustomobject]@{
            baseline = [pscustomobject]@{ inputFingerprint = $baselineFingerprint }
            candidate = [pscustomobject]@{ inputFingerprint = $candidateFingerprint }
        }
        missingFields = @($issues | Sort-Object -Unique)
    }
}
$verified = @($entries | Where-Object verified).Count
$result = [ordered]@{
    schemaVersion = 1
    auditOnly = $true
    status = if ($verified -eq $entries.Count) { 'verified' } else { 'unverified' }
    verified = $verified
    total = $entries.Count
    entries = @($entries)
}
$json = $result | ConvertTo-Json -Depth 10
Write-Output $json
if ($RequireVerified -and $verified -ne $entries.Count) {
    throw "Compiler evidence migration remains unverified: $verified/$($entries.Count)"
}
