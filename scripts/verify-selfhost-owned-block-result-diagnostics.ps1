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
$tests = [ordered]@{
    "block-owned-result-unbound" = "collect"
    "parallel-owned-result-must-bind" = "parallel"
    "try-parallel-owned-result-must-bind" = "tryParallel"
}

foreach ($test in $tests.GetEnumerator()) {
    $name = $test.Key
    $target = $test.Value
    $sourcePath = Join-Path $RepositoryRoot "examples/regression/diagnostics/$name.slg"
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
        Wait-VerificationProcess $process "$name owned-result diagnostic"
        $text = [System.IO.File]::ReadAllText($stdoutPath) + [System.IO.File]::ReadAllText($stderrPath)
        $expected = "error[E27]: owned result of block function '$target' must be bound with '=> name'"
        if ($process.ExitCode -eq 0 -or
            -not $text.Contains($expected) -or
            [regex]::Matches($text, 'error\[E27\]').Count -ne 1 -or
            $text -match '(?m)^target (datalayout|triple)') {
            throw "$name did not fail before LLVM with actionable E27 under $compilerPath"
        }
        Write-Host "[selfhost E27] PASS $name."
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
    }
}
