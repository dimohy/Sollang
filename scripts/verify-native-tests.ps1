param(
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64"
)

$ErrorActionPreference = "Stop"
$started = [Diagnostics.Stopwatch]::StartNew()
$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Get-ChildItem -LiteralPath (Join-Path $repoRoot "src/Sollang.Compiler/bin/Release") `
    -Recurse -Filter "Sollang.Compiler.dll" | Sort-Object LastWriteTimeUtc -Descending | `
    Select-Object -First 1 -ExpandProperty FullName
$successProject = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/success"
$failureSource = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/failure.slg"
$invalidSource = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/invalid-signature.slg"
$llvm = Join-Path $repoRoot ".tools/llvm-22.1.8"

function Invoke-Case {
    param(
        [int]$Index,
        [string]$Name,
        [string[]]$Arguments,
        [int]$ExpectedExit,
        [string]$ExpectedText
    )

    $percent = [int]($Index * 100 / 4)
    Write-Host "[$Index/4] $percent% $Name (elapsed $([math]::Round($started.Elapsed.TotalSeconds, 1))s)"
    $output = & dotnet $compiler @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne $ExpectedExit) {
        throw "$Name exited $exitCode instead of $ExpectedExit`n$output"
    }
    if (-not $output.Contains($ExpectedText, [StringComparison]::Ordinal)) {
        throw "$Name did not contain '$ExpectedText'`n$output"
    }
}

if (-not $compiler -or -not (Test-Path -LiteralPath $compiler)) {
    throw "Release compiler not found: $compiler"
}

Invoke-Case 1 "project discovery" @("test", "--project", $successProject, "--target", $Target, "--llvm", $llvm, "-O1") 0 "3 passed; 0 failed"
Invoke-Case 2 "name filtering" @("test", "--project", $successProject, "--target", $Target, "--filter", "addition", "--llvm", $llvm, "-O1") 0 "1 passed; 0 failed"
Invoke-Case 3 "native failure status" @("test", $failureSource, "--target", $Target, "--llvm", $llvm, "-O1") 1 "0 passed; 1 failed"
Invoke-Case 4 "signature validation" @("test", $invalidSource, "--target", $Target, "--llvm", $llvm, "-O1") 1 "must be a non-generic, zero-input, non-intrinsic function returning Bool"

Write-Host "[4/4] 100% native test framework verified for $Target (elapsed $([math]::Round($started.Elapsed.TotalSeconds, 1))s)"
