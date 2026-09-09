[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$verifier = Join-Path $PSScriptRoot 'verify-native-exact-batch-terminal-report.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("sollang-native-batch-terminal-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
try {
    $stage2Compiler = Join-Path $scratch 'stage2.exe'
    $stage3Compiler = Join-Path $scratch 'stage3.exe'
    [IO.File]::WriteAllBytes($stage2Compiler, [byte[]](1, 2, 3))
    [IO.File]::WriteAllBytes($stage3Compiler, [byte[]](4, 5, 6))
    $stage2Hash = (Get-FileHash $stage2Compiler -Algorithm SHA256).Hash
    $stage3Hash = (Get-FileHash $stage3Compiler -Algorithm SHA256).Hash

    function Write-ProbeReport([string]$Path, [string]$Label, [string]$Hash, [bool]$Success = $true) {
        $report = [ordered]@{
            schemaVersion = 1; label = $Label; platform = 'windows'; state = 'passed'
            compilerSha256 = $Hash; commonInputFingerprint = 'probe'
            completed = 2; passed = if ($Success) { 2 } else { 1 }
            failed = if ($Success) { 0 } else { 1 }; missing = 0; total = 2
            results = @(
                [ordered]@{ Fixture = 'a'; Success = $true; Error = '' },
                [ordered]@{ Fixture = 'b'; Success = $Success; Error = if ($Success) { '' } else { 'probe failure' } }
            )
        }
        [IO.File]::WriteAllText($Path, ($report | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
    }

    $stage2Report = Join-Path $scratch 'stage2.json'
    $stage3Report = Join-Path $scratch 'stage3.json'
    Write-ProbeReport $stage2Report 'stage2' $stage2Hash
    Write-ProbeReport $stage3Report 'stage3' $stage3Hash
    & $verifier -Stage2Report $stage2Report -Stage3Report $stage3Report -Stage2Compiler $stage2Compiler -Stage3Compiler $stage3Compiler -ExpectedTotal 2

    Write-ProbeReport $stage3Report 'stage3' $stage3Hash $false
    $rejected = $false
    try {
        & $verifier -Stage2Report $stage2Report -Stage3Report $stage3Report -Stage2Compiler $stage2Compiler -Stage3Compiler $stage3Compiler -ExpectedTotal 2
    } catch {
        $rejected = $_.Exception.Message -like '*totals are incomplete or inconsistent*'
    }
    if (-not $rejected) { throw 'failed terminal report was not rejected' }
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '[native exact terminal report contract] PASS valid pair and failed-result negative control.'
