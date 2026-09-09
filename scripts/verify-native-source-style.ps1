[CmdletBinding()]
param(
    [string]$Compiler = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3.exe"
}
$Compiler = [System.IO.Path]::GetFullPath($Compiler)
if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw "native compiler is missing: $Compiler"
}

$cases = @(
    @{
        Name = "1004-compound-control-condition-warning"
        Expected = @(
            "note N001 in module '' at 5:5: control condition is 57 characters; keep conditions under 45 on the same line as 'if', or put the condition on its own line and then write '-> if {' on the next line"
            "note N001 in module '' at 12:5: control condition is 54 characters; keep conditions under 45 on the same line as 'while', or put the condition on its own line and then write '-> while {' on the next line"
        ) -join "`n"
    },
    @{
        Name = "1022-redundant-control-condition-parentheses-note"
        Expected = "note N002 in module '' at 4:5: whole control conditions do not need parentheses; remove the outer '(' and ')'"
    },
    @{
        Name = "1154-multiline-redundant-control-parentheses-note"
        Expected = "note N002 in module '' at 4:5: whole control conditions do not need parentheses; remove the outer '(' and ')'"
    },
    @{ Name = "1155-multiline-partial-control-parentheses-preserved"; Expected = "" },
    @{ Name = "1081-control-condition-inline-limit-accepted"; Expected = "" },
    @{
        Name = "1082-control-condition-inline-limit-note"
        Expected = "note N001 in module '' at 4:5: control condition is 45 characters; keep conditions under 45 on the same line as 'if', or put the condition on its own line and then write '-> if {' on the next line"
    }
)

$temporaryRoot = Join-Path $repoRoot "artifacts\native-source-style"
[System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
foreach ($case in $cases) {
    $source = Join-Path $repoRoot "examples\regression\$($case.Name).slg"
    $output = Join-Path $temporaryRoot "$($case.Name).ll"
    $errorOutput = Join-Path $temporaryRoot "$($case.Name).stderr.txt"
    try {
        $process = Start-Process `
            -FilePath $Compiler `
            -ArgumentList @("windows", $source) `
            -RedirectStandardOutput $output `
            -RedirectStandardError $errorOutput `
            -PassThru `
            -WindowStyle Hidden
        Wait-VerificationProcess $process "$($case.Name) native source-style analysis"
        if ($process.ExitCode -ne 0) {
            $details = [System.IO.File]::ReadAllText($errorOutput)
            throw "$($case.Name) exited $($process.ExitCode): $details"
        }
        $stderr = [System.IO.File]::ReadAllText($errorOutput).Replace("`r`n", "`n").Trim()
        $expected = [string]$case.Expected
        if (-not $stderr.Equals($expected, [System.StringComparison]::Ordinal)) {
            throw "$($case.Name) stderr mismatch.`nexpected:`n$expected`nactual:`n$stderr"
        }
        Write-Host "[native source style] PASS $($case.Name)"
    } finally {
        if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
        if (Test-Path -LiteralPath $errorOutput) { Remove-Item -LiteralPath $errorOutput -Force }
    }
}

Write-Host "[native source style] PASS N001/N002 positive and negative controls."
