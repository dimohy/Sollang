[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Field([object]$Value, [string]$Name) {
    if ($null -eq $Value -or $null -eq $Value.PSObject.Properties[$Name]) { return $null }
    return $Value.PSObject.Properties[$Name].Value
}

function Test-RequiredText([object]$Value) {
    return $Value -is [string] -and -not [string]::IsNullOrWhiteSpace($Value)
}

function Test-Sha256([object]$Value) {
    return $Value -is [string] -and $Value -cmatch '^[A-Fa-f0-9]{64}$'
}

function Get-Sequence([string]$Id) {
    $match = [regex]::Match($Id, '-(?<sequence>[0-9]+)$')
    if (-not $match.Success) { throw "AUDIT_DEFECT_ID_INVALID: $Id" }
    return [int]$match.Groups['sequence'].Value
}

function Add-Issue([Collections.Generic.List[object]]$Issues, [string]$Id,
        [string]$Category, [string]$Code, [string]$Path) {
    $Issues.Add([pscustomobject][ordered]@{
        id = $Id
        category = $Category
        code = $Code
        path = $Path
    })
}

function Test-ReceiptFields([object]$Receipt, [string]$Id, [string]$Phase,
        [string]$Fingerprint) {
    [string[]]$missing = @()
    foreach ($field in @('schemaVersion', 'defectId', 'phase', 'inputFingerprint',
            'command', 'exitCode', 'expectedExitCode', 'outputPath', 'outputSha256')) {
        if ($null -eq (Get-Field $Receipt $field)) { $missing += $field }
    }
    if ($missing.Count -gt 0) { return "REQUIRED_FIELDS_MISSING:$($missing -join ',')" }
    if ((Get-Field $Receipt 'schemaVersion') -ne 1 -or
        (Get-Field $Receipt 'defectId') -cne $Id -or
        (Get-Field $Receipt 'phase') -cne $Phase -or
        (Get-Field $Receipt 'inputFingerprint') -cne $Fingerprint -or
        -not (Test-RequiredText (Get-Field $Receipt 'command')) -or
        -not (Test-RequiredText (Get-Field $Receipt 'outputPath')) -or
        -not (Test-Sha256 (Get-Field $Receipt 'outputSha256')) -or
        (Get-Field $Receipt 'exitCode') -ne (Get-Field $Receipt 'expectedExitCode') -or
        ($Phase -eq 'candidate' -and (Get-Field $Receipt 'exitCode') -ne 0)) {
        return 'REQUIRED_FIELDS_INVALID'
    }
    return $null
}

function Test-TraceIdentity([object]$Trace, [string]$Id, [string]$Fingerprint) {
    if ((Get-Field $Trace 'ruleId') -cne 'AS-US-001' -or
        (Get-Field (Get-Field $Trace 'signal') 'id') -cne $Id -or
        (Get-Field (Get-Field $Trace 'orchestratorEvidence') 'inputFingerprint') -cne $Fingerprint) {
        return 'TRACE_IDENTITY_INVALID'
    }
    $decision = Get-Field $Trace 'decision'
    if ((Get-Field $decision 'claimLevel') -cnotin @('structured-and-applied', 'measured-improvement') -or
        (Get-Field (Get-Field $decision 'asset') 'inputFingerprint') -cne $Fingerprint) {
        return 'TRACE_CANDIDATE_SHAPE_INVALID'
    }
    return $null
}

function Get-InputFingerprint([System.Collections.IDictionary]$Hashes) {
    $lines = @($Hashes.GetEnumerator() | Sort-Object Key | ForEach-Object {
        "$($_.Key)|$($_.Value)"
    })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

function Test-InputHashesStable([System.Collections.IDictionary]$Start,
        [System.Collections.IDictionary]$End) {
    if ($Start.Count -ne $End.Count) { return $false }
    foreach ($entry in $Start.GetEnumerator()) {
        if (-not $End.Contains($entry.Key) -or $End[$entry.Key] -cne $entry.Value) {
            return $false
        }
    }
    return $true
}

if ($SelfTest) {
    $fingerprint = 'A' * 64
    $receipt = [pscustomobject]@{
        schemaVersion = 1; defectId = 'C-test-208'; phase = 'candidate'
        inputFingerprint = $fingerprint; command = 'test'; exitCode = 0
        expectedExitCode = 0; outputPath = 'test.txt'; outputSha256 = ('B' * 64)
    }
    if ($null -ne (Test-ReceiptFields $receipt 'C-test-208' 'candidate' $fingerprint)) {
        throw 'AUDIT_SELFTEST_VALID_RECEIPT_REJECTED'
    }
    if ((Test-ReceiptFields $receipt 'C-test-208' 'candidate' ('C' * 64)) -cne
        'REQUIRED_FIELDS_INVALID') {
        throw 'AUDIT_SELFTEST_FINGERPRINT_MISMATCH_ACCEPTED'
    }
    $receipt.PSObject.Properties.Remove('expectedExitCode')
    if ((Test-ReceiptFields $receipt 'C-test-208' 'candidate' $fingerprint) -cne
        'REQUIRED_FIELDS_MISSING:expectedExitCode') {
        throw 'AUDIT_SELFTEST_MISSING_CANDIDATE_FIELD_ACCEPTED'
    }
    $trace = [pscustomobject]@{
        ruleId = 'AS-US-001'
        signal = [pscustomobject]@{ id = 'C-test-208' }
        orchestratorEvidence = [pscustomobject]@{ inputFingerprint = $fingerprint }
        decision = [pscustomobject]@{
            claimLevel = 'structured-and-applied'
            asset = [pscustomobject]@{ inputFingerprint = $fingerprint }
        }
    }
    if ($null -ne (Test-TraceIdentity $trace 'C-test-208' $fingerprint)) {
        throw 'AUDIT_SELFTEST_VALID_TRACE_REJECTED'
    }
    $trace.decision.asset.inputFingerprint = 'D' * 64
    if ((Test-TraceIdentity $trace 'C-test-208' $fingerprint) -cne
        'TRACE_CANDIDATE_SHAPE_INVALID') {
        throw 'AUDIT_SELFTEST_TRACE_ASSET_MISMATCH_ACCEPTED'
    }
    $trace.decision.asset.inputFingerprint = $fingerprint
    $trace.ruleId = 'AS-US-002'
    if ((Test-TraceIdentity $trace 'C-test-208' $fingerprint) -cne 'TRACE_IDENTITY_INVALID') {
        throw 'AUDIT_SELFTEST_LEGACY_TRACE_ACCEPTED'
    }
    $start = [ordered]@{ 'contract.json' = ('A' * 64); 'baseline.json' = ('B' * 64) }
    $end = [ordered]@{ 'contract.json' = ('A' * 64); 'baseline.json' = ('C' * 64) }
    if ((Test-InputHashesStable $start $end) -or
        (Get-InputFingerprint $start) -ceq (Get-InputFingerprint $end)) {
        throw 'AUDIT_SELFTEST_INPUT_DRIFT_ACCEPTED'
    }
    Write-Host '[compiler evidence audit] SelfTest PASS: valid and invalid receipt/trace controls.'
    return
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
function Resolve-RepositoryFile([object]$RelativePath, [string]$Description) {
    if (-not (Test-RequiredText $RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
        throw "AUDIT_PATH_INVALID: $Description"
    }
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    if (-not $resolved.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "AUDIT_PATH_ESCAPE: $Description"
    }
    return $resolved
}

$scriptPath = [IO.Path]::GetFullPath($PSCommandPath)
$ledgerPath = Join-Path $root 'scripts/contracts/compiler-defects.json'
$evaluatorPath = [IO.Path]::GetFullPath((Join-Path $root '..\AgenticShaping\evals\unstructured-to-structured.mjs'))
foreach ($inputPath in @($scriptPath, $ledgerPath, $evaluatorPath)) {
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw "AUDIT_REQUIRED_INPUT_MISSING: $inputPath"
    }
}
$nodeCommand = Get-Command node -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $nodeCommand) { throw 'AUDIT_NODE_UNAVAILABLE' }
$ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
if ($ledger.schemaVersion -ne 2 -or
    [int]$ledger.completionPolicy.agenticShapingEvidenceRequiredFromSequence -lt 1 -or
    $null -eq $ledger.defects) {
    throw 'AUDIT_LEDGER_CONTRACT_INVALID'
}
$selected = @($ledger.defects | Where-Object {
    $_.state -in @('candidate-fixed', 'closed') -and
    (Get-Sequence $_.id) -ge [int]$ledger.completionPolicy.agenticShapingEvidenceRequiredFromSequence
} | Sort-Object id)
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$scratchPrefix = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch')).TrimEnd(
    [IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $outputPath.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $outputPath)) {
    throw "AUDIT_OUTPUT_MUST_BE_FRESH_SCRATCH_DIRECTORY: $outputPath"
}
$outputParent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
    throw "AUDIT_OUTPUT_PARENT_MISSING: $outputParent"
}
$inputHashes = [ordered]@{}
foreach ($inputPath in @($scriptPath, $ledgerPath, $evaluatorPath, $nodeCommand.Source)) {
    $inputHashes[$inputPath] = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
}
if ($ValidateInputsOnly) {
    Write-Host "[compiler evidence audit] ValidateInputsOnly PASS: $($selected.Count) candidate-fixed/closed entries, fresh scratch output."
    return
}

$issues = [Collections.Generic.List[object]]::new()
foreach ($defect in $selected) {
    $id = [string]$defect.id
    $evidence = Get-Field $defect 'shapingEvidence'
    $fingerprint = Get-Field $evidence 'inputFingerprint'
    if (-not (Test-Sha256 $fingerprint)) {
        Add-Issue $issues $id 'ledgerFingerprintInvalid' 'LEDGER_FINGERPRINT_INVALID' $ledgerPath
        continue
    }
    foreach ($phase in @('baseline', 'candidate')) {
        $field = if ($phase -eq 'baseline') { 'baselineReceipt' } else { 'candidateReceipt' }
        $category = if ($phase -eq 'baseline') { 'baselineReceiptInvalid' } else { 'candidateMandatoryInvalid' }
        $relative = Get-Field $evidence $field
        if (-not (Test-RequiredText $relative)) {
            Add-Issue $issues $id $category 'RECEIPT_PATH_MISSING' $field
            continue
        }
        try { $path = Resolve-RepositoryFile $relative "$id $phase" }
        catch {
            Add-Issue $issues $id $category 'RECEIPT_PATH_INVALID' ([string]$relative)
            continue
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-Issue $issues $id $category 'RECEIPT_FILE_MISSING' ([string]$relative)
            continue
        }
        $inputHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        try { $receipt = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
        catch {
            Add-Issue $issues $id $category 'RECEIPT_JSON_INVALID' ([string]$relative)
            continue
        }
        $receiptFingerprint = Get-Field $receipt 'inputFingerprint'
        if ($phase -eq 'baseline' -and $receiptFingerprint -cne $fingerprint) {
            Add-Issue $issues $id 'baselineFingerprintMismatch' 'BASELINE_LEDGER_FINGERPRINT_MISMATCH' ([string]$relative)
        }
        $fieldError = Test-ReceiptFields $receipt $id $phase $fingerprint
        if ($null -ne $fieldError) {
            Add-Issue $issues $id $category $fieldError ([string]$relative)
        }
        $claimedOutput = Get-Field $receipt 'outputPath'
        $claimedSha = Get-Field $receipt 'outputSha256'
        if ((Test-RequiredText $claimedOutput) -and (Test-Sha256 $claimedSha)) {
            try { $actualOutput = Resolve-RepositoryFile $claimedOutput "$id $phase output" }
            catch {
                Add-Issue $issues $id 'receiptOutputInvalid' 'OUTPUT_PATH_INVALID' ([string]$claimedOutput)
                continue
            }
            if (-not (Test-Path -LiteralPath $actualOutput -PathType Leaf)) {
                Add-Issue $issues $id 'receiptOutputInvalid' 'OUTPUT_FILE_MISSING' ([string]$claimedOutput)
                continue
            }
            $actualSha = (Get-FileHash -LiteralPath $actualOutput -Algorithm SHA256).Hash
            $inputHashes[$actualOutput] = $actualSha
            if ($actualSha -cne $claimedSha.ToUpperInvariant()) {
                Add-Issue $issues $id 'receiptOutputInvalid' 'OUTPUT_SHA_MISMATCH' ([string]$claimedOutput)
            }
        }
    }
    $traceRelative = Get-Field $evidence 'tracePath'
    if (-not (Test-RequiredText $traceRelative)) {
        Add-Issue $issues $id 'traceShapeInvalid' 'TRACE_PATH_MISSING' 'tracePath'
        continue
    }
    try { $tracePath = Resolve-RepositoryFile $traceRelative "$id trace" }
    catch {
        Add-Issue $issues $id 'traceShapeInvalid' 'TRACE_PATH_INVALID' ([string]$traceRelative)
        continue
    }
    if (-not (Test-Path -LiteralPath $tracePath -PathType Leaf)) {
        Add-Issue $issues $id 'traceShapeInvalid' 'TRACE_FILE_MISSING' ([string]$traceRelative)
        continue
    }
    $inputHashes[$tracePath] = (Get-FileHash -LiteralPath $tracePath -Algorithm SHA256).Hash
    try { $trace = Get-Content -LiteralPath $tracePath -Raw | ConvertFrom-Json }
    catch {
        Add-Issue $issues $id 'traceShapeInvalid' 'TRACE_JSON_INVALID' ([string]$traceRelative)
        continue
    }
    $traceError = Test-TraceIdentity $trace $id $fingerprint
    if ($null -ne $traceError) {
        Add-Issue $issues $id 'traceShapeInvalid' $traceError ([string]$traceRelative)
        continue
    }
    $evaluation = & $nodeCommand.Source $evaluatorPath --trace $tracePath 2>&1
    if ($LASTEXITCODE -ne 0 -or
        ($evaluation -join "`n") -notmatch 'AS-US-001-STRUCTURED-(AND-APPLIED|IMPROVEMENT)') {
        Add-Issue $issues $id 'traceShapeInvalid' 'TRACE_EVALUATOR_REJECTED' ([string]$traceRelative)
    }
}

$inputFingerprintStart = Get-InputFingerprint $inputHashes
$endHashes = [ordered]@{}
foreach ($entry in $inputHashes.GetEnumerator()) {
    $endHashes[$entry.Key] = if (Test-Path -LiteralPath $entry.Key -PathType Leaf) {
        (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash
    } else {
        'MISSING'
    }
}
$inputFingerprintEnd = Get-InputFingerprint $endHashes
$inputsStable = Test-InputHashesStable $inputHashes $endHashes
$categories = @('baselineFingerprintMismatch', 'baselineReceiptInvalid',
    'traceShapeInvalid', 'candidateMandatoryInvalid', 'receiptOutputInvalid',
    'ledgerFingerprintInvalid')
$counts = [ordered]@{}
$idsByCategory = [ordered]@{}
foreach ($category in $categories) {
    $matching = @($issues | Where-Object category -eq $category)
    $ids = @($matching | ForEach-Object id | Sort-Object -Unique)
    $counts[$category] = $ids.Count
    $idsByCategory[$category] = $ids
}
$result = [ordered]@{
    schemaVersion = 1
    status = if ($inputsStable) { 'completed' } else { 'input-changed' }
    inputFingerprintStart = $inputFingerprintStart
    inputFingerprintEnd = $inputFingerprintEnd
    inputsStable = $inputsStable
    selectedCount = $selected.Count
    issueCount = $issues.Count
    affectedDefectCount = @($issues | ForEach-Object id | Sort-Object -Unique).Count
    countsByCategory = $counts
    idsByCategory = $idsByCategory
    issues = @($issues | Sort-Object id, category, code)
    inputFiles = @($inputHashes.GetEnumerator() | Sort-Object Key | ForEach-Object {
        [ordered]@{ path = $_.Key; sha256 = $_.Value }
    })
}
$null = New-Item -ItemType Directory -Path $outputPath -ErrorAction Stop
$resultPath = Join-Path $outputPath 'result.json'
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 12),
    [Text.UTF8Encoding]::new($false))
Write-Host "[compiler evidence audit] completed $($selected.Count)/$($selected.Count); affected=$($result.affectedDefectCount); issues=$($issues.Count); result=$resultPath"
foreach ($category in $categories) {
    Write-Host "[compiler evidence audit] ${category}=$($counts[$category])"
}
if (-not $inputsStable) {
    throw "AUDIT_INPUT_CHANGED_DURING_RUN: result=$resultPath"
}
