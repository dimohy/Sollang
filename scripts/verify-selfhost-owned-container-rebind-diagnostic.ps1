[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$sourcePath = Join-Path $RepositoryRoot "examples/regression/diagnostics/mutable-owned-container-rebind.slg"
$stdoutPath = [System.IO.Path]::GetTempFileName()
$stderrPath = [System.IO.Path]::GetTempFileName()
try {
    $process = Start-Process `
        -FilePath $compilerPath `
        -ArgumentList @("windows", (Resolve-Path -LiteralPath $sourcePath).Path) `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $process "owned container rebind diagnostic"
    $text = [System.IO.File]::ReadAllText($stdoutPath) + [System.IO.File]::ReadAllText($stderrPath)
    $expected = "error[E28]: owned container binding 'values!' cannot be rebound"
    if ($process.ExitCode -eq 0 -or
        -not $text.Contains($expected) -or
        [regex]::Matches($text, 'error\[E28\]').Count -ne 1 -or
        $text -match '(?m)^target (datalayout|triple)') {
        throw "owned container rebind did not fail before LLVM with actionable E28 under $compilerPath"
    }
    Write-Host "[selfhost E28] PASS owned mutable container rebind is rejected."
} finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
}
