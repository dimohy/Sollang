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
Write-Output "[1/1] PASS 1411-borrowed-receiver-error-reuse"
Write-Output "FAIL 9999-detached-supervisor-probe"
exit 7
