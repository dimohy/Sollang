[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Compiler,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$Label,
    [string]$LlvmHome = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
$Compiler = [System.IO.Path]::GetFullPath($Compiler)
$LlvmHome = [System.IO.Path]::GetFullPath($LlvmHome)
$llvmAs = Join-Path $LlvmHome "bin\llvm-as.exe"
$clang = Join-Path $LlvmHome "bin\clang.exe"
$source = Join-Path $repoRoot "examples\regression\854-set-key-only.slg"
$expectedPath = Join-Path $repoRoot "examples\regression\expected\854-set-key-only.stdout.txt"
$forbiddenPath = Join-Path $repoRoot "examples\regression\expected\854-set-key-only.selfhost.llvm.not-contains.txt"
foreach ($required in @($Compiler, $llvmAs, $clang, $source, $expectedPath, $forbiddenPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "native Set intrinsic dependency is missing: $required"
    }
}

$artifacts = Join-Path $repoRoot "artifacts\native-set-intrinsics"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$llvmPath = Join-Path $artifacts "$Label.ll"
$bitcodePath = Join-Path $artifacts "$Label.bc"
$executablePath = Join-Path $artifacts "$Label.exe"
$errorPath = Join-Path $artifacts "$Label.err"
Remove-Item -LiteralPath $llvmPath, $bitcodePath, $executablePath, $errorPath -ErrorAction SilentlyContinue

$compile = Start-Process `
    -FilePath $Compiler `
    -ArgumentList @("windows", $source) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $llvmPath `
    -RedirectStandardError $errorPath `
    -WindowStyle Hidden `
    -PassThru
Wait-VerificationProcess $compile "$Label Set intrinsic compiler emission"
if ($compile.ExitCode -ne 0) {
    $details = if (Test-Path -LiteralPath $errorPath) {
        [System.IO.File]::ReadAllText($errorPath)
    } else { "" }
    throw "$Label compiler failed Set intrinsic emission with exit code $($compile.ExitCode).`n$details"
}
$missingLlvm = -not (Test-Path -LiteralPath $llvmPath -PathType Leaf)
if (-not $missingLlvm) {
    $missingLlvm = (Get-Item -LiteralPath $llvmPath).Length -eq 0
}
if ($missingLlvm) {
    throw "$Label compiler produced no Set intrinsic LLVM artifact"
}
$diagnostics = [System.IO.File]::ReadAllText($errorPath)
if (-not [string]::IsNullOrWhiteSpace($diagnostics)) {
    throw "$Label compiler emitted diagnostics for the valid Set fixture.`n$diagnostics"
}
$llvm = [System.IO.File]::ReadAllText($llvmPath)
$forbiddenPatterns = [System.IO.File]::ReadAllLines($forbiddenPath) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
foreach ($pattern in $forbiddenPatterns) {
    if ($llvm.Contains($pattern.Trim(), [System.StringComparison]::Ordinal)) {
        throw "$Label compiler emitted forbidden Set intrinsic text '$($pattern.Trim())'"
    }
}

& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $llvmPath
if (-not $?) { throw "$Label LLVM direct-call closure verification failed" }
& $llvmAs $llvmPath -o $bitcodePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clang -Wno-override-module $llvmPath -O1 -o $executablePath -lws2_32 -lshell32 -lbcrypt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$run = Invoke-VerificationProcessCapture `
    -FilePath $executablePath `
    -Description "$Label Set intrinsic executable"
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
if ($run.ExitCode -ne 0) {
    throw "$Label Set intrinsic executable exited with $($run.ExitCode).`n$($run.Stderr)"
}
$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
if ($actual -ne $expected) {
    throw "$Label Set intrinsic output mismatch.`nExpected:`n$expected`nActual:`n$actual"
}

Write-Host "[native Set intrinsics] PASS $Label emitted no unresolved sentinel, assembled, linked, and matched fixture 854."
