$ErrorActionPreference = 'Stop'
$taskRoot = (Get-Location).Path
foreach ($taskId in @('C2026-10-24-728','C2026-10-24-729')) {
    $evidenceRoot = Join-Path $taskRoot "scripts/contracts/evidence/$taskId"
    $trace = Join-Path $evidenceRoot 'as-us-001.json'
    if (Test-Path -LiteralPath $trace) { throw 'Fresh structured trace required; preserve prior observed trace.' }
    [IO.File]::Copy((Join-Path $evidenceRoot 'as-us-001.observed.json'), $trace)
    $authority = if ($taskId -eq 'C2026-10-24-728') {
        'selfhost/semantic/diagnostics.slg:firstExpressionOperandDiagnostic'
    } else {
        'selfhost/llvm/text/foundation.slg:interpolationIntegerTypeSymbol'
    }
    & scripts/promote-compiler-defect-shaping-trace.ps1 `
        -DefectId $taskId -AssetKind invariant -AuthorityPath $authority `
        -Reason 'Reuse existing semantic type identity and validation runners. Actual canonical source10/runtime7 and current O2 Native focused pairs passed with original expected output and warnings. This completes the focused implementation unit only; final defect/phase/Stage/platform closure remains pending. No performance or total-cost improvement claim.' `
        -ValidatorEvidence @("scripts/contracts/evidence/$taskId/qualification13317.json", 'scripts/contracts/evidence/C2026-10-24-729/current-source13308/canonical-source10/result.json') `
        -ConsumerEvidence @("scripts/contracts/evidence/$taskId/qualification13317.json")
}
