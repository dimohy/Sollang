[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DefectId,
    [Parameter(Mandatory)][ValidateSet('baseline', 'candidate', 'measurement')][string]$Phase,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$InputFingerprint,
    [Parameter(Mandatory)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [string]$WorkingDirectory = '',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 3600000,
    [int]$ExpectedExitCode = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'verification-process.ps1')

if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $WorkingDirectory = $repositoryRoot
}
$workingRoot = [System.IO.Path]::GetFullPath($WorkingDirectory)
$evidenceDirectory = Join-Path $repositoryRoot "scripts\contracts\evidence\$DefectId"
[System.IO.Directory]::CreateDirectory($evidenceDirectory) | Out-Null
$outputPath = Join-Path $evidenceDirectory "$Phase.output.txt"
$receiptPath = Join-Path $evidenceDirectory "$Phase.json"

$result = Invoke-VerificationProcessCapture `
    -FilePath $FilePath `
    -ArgumentList $ArgumentList `
    -Description "$DefectId $Phase evidence" `
    -WorkingDirectory $workingRoot `
    -TimeoutMilliseconds $TimeoutMilliseconds

$output = "[stdout]`n$($result.Stdout)[stderr]`n$($result.Stderr)"
[System.IO.File]::WriteAllText($outputPath, $output, [System.Text.UTF8Encoding]::new($false))
$outputSha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
$relativeOutputPath = [System.IO.Path]::GetRelativePath($repositoryRoot, $outputPath).Replace('\', '/')
$relativeReceiptPath = [System.IO.Path]::GetRelativePath($repositoryRoot, $receiptPath).Replace('\', '/')
$command = (@($FilePath) + $ArgumentList) -join ' '
$receipt = [ordered]@{
    schemaVersion = 1
    defectId = $DefectId
    phase = $Phase
    inputFingerprint = $InputFingerprint.ToUpperInvariant()
    command = $command
    exitCode = $result.ExitCode
    expectedExitCode = $ExpectedExitCode
    outputPath = $relativeOutputPath
    outputSha256 = $outputSha256
}
[System.IO.File]::WriteAllText(
    $receiptPath,
    ($receipt | ConvertTo-Json -Depth 4) + "`n",
    [System.Text.UTF8Encoding]::new($false))

if ($result.ExitCode -ne $ExpectedExitCode) {
    throw "$DefectId $Phase exited $($result.ExitCode), expected $ExpectedExitCode; evidence preserved at $relativeReceiptPath"
}
Write-Host "[$DefectId] $Phase evidence PASS $relativeReceiptPath output=$outputSha256"
