[CmdletBinding()]
param(
    [string]$Compiler = "",
    [string[]]$Manifest = @(),
    [string]$OutputDirectory = "",
    [ValidateRange(1, 256)]
    [int]$Jobs = 16,
    [ValidateRange(1000, 3600000)]
    [int]$TimeoutMilliseconds = 3600000
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "verification-process.ps1")

if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\incremental-selfhost\selfhost-stage1-host-o0.exe"
}
if ($Manifest.Count -eq 0) {
    $Manifest = @(
        (Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"),
        (Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt")
    )
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "artifacts\profiles\windows-control-allocas"
}

$Compiler = [System.IO.Path]::GetFullPath($Compiler)
$Manifest = @($Manifest | ForEach-Object { [System.IO.Path]::GetFullPath($_) })
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw "compiler is missing: $Compiler"
}
foreach ($manifestPath in $Manifest) {
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "source manifest is missing: $manifestPath"
    }
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$seenSources = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$relativeSources = @($Manifest | ForEach-Object {
    [System.IO.File]::ReadAllLines($_)
} | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_) -and $seenSources.Add($_.Replace('\', '/'))
})
$sourcePaths = @($relativeSources | ForEach-Object {
    $path = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $_))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "manifest source is missing: $path"
    }
    $path
})
$sourceIdentity = [string]::Join("`n", @($relativeSources | ForEach-Object {
    $path = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $_))
    "$($_.Replace('\', '/'))|$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
}))
$sourceFingerprint = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sourceIdentity)))
$compilerFingerprint = (Get-FileHash -LiteralPath $Compiler -Algorithm SHA256).Hash
$stdoutPath = Join-Path $OutputDirectory "control-allocas.stdout.txt"
$stderrPath = Join-Path $OutputDirectory "control-allocas.stderr.txt"
$recordPath = Join-Path $OutputDirectory "control-allocas.measurement.json"
$arguments = @("control-allocas", "--jobs", [string]$Jobs) + $sourcePaths
$startedAt = [DateTimeOffset]::Now
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$status = "passed"
$failure = $null
try {
    Invoke-VerificationProcessToFile `
        -FilePath $Compiler `
        -ArgumentList $arguments `
        -Description "Windows self-host control-allocas profile" `
        -OutputPath $stdoutPath `
        -ErrorPath $stderrPath `
        -TimeoutMilliseconds $TimeoutMilliseconds
} catch {
    $status = "failed"
    $failure = $_.Exception.Message
} finally {
    $stopwatch.Stop()
}

$stdout = if (Test-Path -LiteralPath $stdoutPath) {
    [System.IO.File]::ReadAllText($stdoutPath)
} else { "" }
$endingSourceIdentity = [string]::Join("`n", @($relativeSources | ForEach-Object {
    $path = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $_))
    "$($_.Replace('\', '/'))|$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
}))
$endingSourceFingerprint = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($endingSourceIdentity)))
$record = [ordered]@{
    schemaVersion = 1
    phase = "control-allocas"
    platform = "windows-x64"
    status = $status
    startedAt = $startedAt.ToString("o")
    wallMilliseconds = [long]$stopwatch.ElapsedMilliseconds
    jobs = $Jobs
    timeoutMilliseconds = $TimeoutMilliseconds
    compilerPath = [System.IO.Path]::GetRelativePath($repoRoot, $Compiler).Replace('\', '/')
    compilerSha256 = $compilerFingerprint
    manifestPaths = @($Manifest | ForEach-Object {
        [System.IO.Path]::GetRelativePath($repoRoot, $_).Replace('\', '/')
    })
    sourceCount = $sourcePaths.Count
    sourceFingerprint = $sourceFingerprint
    endingSourceFingerprint = $endingSourceFingerprint
    inputStable = $sourceFingerprint -eq $endingSourceFingerprint
    command = "control-allocas --jobs $Jobs <manifests:$($Manifest.Count), sources:$($relativeSources.Count)>"
    checkedDiagnosticsZero = $stdout.Contains("checked diagnostics = 0", [StringComparison]::Ordinal)
    stdoutPath = [System.IO.Path]::GetRelativePath($repoRoot, $stdoutPath).Replace('\', '/')
    stderrPath = [System.IO.Path]::GetRelativePath($repoRoot, $stderrPath).Replace('\', '/')
    failure = $failure
}
[System.IO.File]::WriteAllText(
    $recordPath,
    (($record | ConvertTo-Json -Depth 4) + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false))
Write-Host "[control-allocas measurement] $status $($stopwatch.ElapsedMilliseconds)ms; evidence $recordPath"
if ($status -ne "passed" -or -not $record.checkedDiagnosticsZero -or -not $record.inputStable) {
    throw "control-allocas measurement did not complete with zero checked diagnostics"
}
