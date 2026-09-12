param(
    [ValidateSet("Pass", "Fail", "Wait")]
    [string]$Outcome = "Fail"
)

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
Write-Output "probe output before controlled failure E999"
Write-Output "sollang compiler error S015: controlled diagnostic"
Write-Output "[1/1] PASS 1411-borrowed-receiver-error-reuse"
Write-Output "[1/1] PASS 2-error-name-negative-control"
Write-Output "native LLVM error in 80-unicode-code-points"
Write-Output "FAIL 1-short-fixture-id"
Write-Output "FAIL 9999-detached-supervisor-probe"
exit 7
