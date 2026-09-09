[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$Label = "selfhost",
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$expected = "capacity requires a growable/bounded array, dictionary or Arena receiver"
$fixtures = @(
    "1487-interpolation-capacity-fixed",
    "1488-interpolation-capacity-slice",
    "1489-interpolation-capacity-text"
)
foreach ($fixture in $fixtures) {
    $source = (Resolve-Path -LiteralPath (Join-Path $RepositoryRoot "examples/regression/diagnostics/$fixture.slg")).Path
    $result = Invoke-VerificationProcessCapture `
        -FilePath $compilerPath `
        -ArgumentList @("windows", $source) `
        -Description "$Label $fixture"
    $text = $result.Stdout + $result.Stderr
    if ($result.ExitCode -ne 1 -or
        [regex]::Matches($text, [regex]::Escape($expected)).Count -ne 1 -or
        $text -match '(?m)^(target (datalayout|triple)|define )') {
        throw "$fixture must fail once with its capacity receiver diagnostic before LLVM under $Label. Exit=$($result.ExitCode)`n$text"
    }
}
Write-Host "[selfhost interpolation capacity] PASS $Label 3/3 unsupported receiver diagnostics before LLVM."
