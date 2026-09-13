param(
    [ValidateSet("Pass", "Fail", "PlainFail", "Wait", "ChildPass", "ChildOrphan", "ChildWorker", "CooperativeWait", "CooperativeChild", "NonCooperativeWait")]
    [string]$Outcome = "Fail",
    [string]$EvidencePath = '',
    [string]$ReleasePath = '',
    [int]$ChildMilliseconds = 0,
    [string]$CancellationRequestPath = '',
    [string]$CancellationRunId = '',
    [string]$CancellationAcknowledgementPath = ''
)

function Test-CooperativeCancellation {
    param([switch]$Acknowledge)
    if ($CancellationRequestPath -eq '' -or -not (Test-Path -LiteralPath $CancellationRequestPath -PathType Leaf)) {
        return $false
    }
    $request = Get-Content -LiteralPath $CancellationRequestPath -Raw | ConvertFrom-Json
    if ($request.schemaVersion -ne 1 -or $request.runId -cne $CancellationRunId) {
        throw 'probe cancellation request does not match the active run'
    }
    if ($Acknowledge) {
        $acknowledgement = [ordered]@{
            schemaVersion = 1
            runId = $CancellationRunId
            targetProcessId = $PID
            observedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
        }
        $temporaryPath = "$CancellationAcknowledgementPath.tmp-$PID"
        $acknowledgement | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
        Move-Item -LiteralPath $temporaryPath -Destination $CancellationAcknowledgementPath -Force
    }
    return $true
}

if ($Outcome -eq 'ChildWorker') {
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($ChildMilliseconds)
    while ([DateTimeOffset]::UtcNow -lt $deadline -and -not (Test-Path -LiteralPath $ReleasePath)) {
        if (Test-CooperativeCancellation) { exit 130 }
        Start-Sleep -Milliseconds 100
    }
    exit 0
}

if ($Outcome -eq 'NonCooperativeWait') {
    Start-Sleep -Seconds 20
    exit 0
}

if ($Outcome -eq 'CooperativeChild') {
    if ($EvidencePath -eq '') { throw 'CooperativeChild requires its evidence path' }
    $child = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @(
        '-NoProfile', '-File', ('"' + $PSCommandPath + '"'),
        '-Outcome', 'ChildWorker',
        '-ChildMilliseconds', '30000',
        '-CancellationRequestPath', ('"' + $CancellationRequestPath + '"'),
        '-CancellationRunId', ('"' + $CancellationRunId + '"'),
        '-CancellationAcknowledgementPath', ('"' + $CancellationAcknowledgementPath + '"')
    ) -WindowStyle Hidden -PassThru
    [ordered]@{ processId = $child.Id } | ConvertTo-Json |
        Set-Content -LiteralPath $EvidencePath -Encoding utf8
    while (-not (Test-CooperativeCancellation -Acknowledge)) { Start-Sleep -Milliseconds 50 }
    if (-not $child.WaitForExit(5000)) { throw 'cooperative child did not stop after cancellation' }
    exit 130
}

if ($Outcome -eq 'CooperativeWait') {
    while (-not (Test-CooperativeCancellation -Acknowledge)) { Start-Sleep -Milliseconds 50 }
    exit 130
}
if ($Outcome -in @('ChildPass', 'ChildOrphan')) {
    if ($EvidencePath -eq '') { throw 'Child probe requires its evidence path' }
    $release = "$EvidencePath.release"
    $duration = if ($Outcome -eq 'ChildPass') { 4000 } else { 30000 }
    $child = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @(
        '-NoProfile', '-File', ('"' + $PSCommandPath + '"'),
        '-Outcome', 'ChildWorker', '-ReleasePath', ('"' + $release + '"'),
        '-ChildMilliseconds', $duration.ToString()
    ) -WindowStyle Hidden -PassThru
    [ordered]@{ processId = $child.Id; releasePath = $release } |
        ConvertTo-Json | Set-Content -LiteralPath $EvidencePath -Encoding utf8
    # Span multiple supervisor snapshots so this tests observed descendants,
    # not an unobserved fork-and-exit race outside the audit's declared scope.
    Start-Sleep -Milliseconds 2200
    Write-Output "parent exits before child $($child.Id)"
    exit 0
}

if ($Outcome -eq "Wait") {
    Start-Sleep -Seconds 30
    Write-Output "probe wait completed"
    exit 0
}

Start-Sleep -Milliseconds 1200
if ($Outcome -eq "Pass") {
    Write-Output "probe completed successfully"
    exit 0
}
if ($Outcome -eq "PlainFail") {
    Write-Output "probe stopped without a structured diagnostic identifier"
    exit 9
}
Write-Output "probe output before controlled failure E999"
Write-Output "sollang compiler error S015: controlled diagnostic"
Write-Output "[1/1] PASS 1411-borrowed-receiver-error-reuse"
Write-Output "[1/1] PASS 2-error-name-negative-control"
Write-Output "native LLVM error in 80-unicode-code-points"
Write-Output "FAIL 1-short-fixture-id"
Write-Output "FAIL 9999-detached-supervisor-probe"
exit 7
