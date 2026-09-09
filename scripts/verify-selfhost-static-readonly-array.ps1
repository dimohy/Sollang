[CmdletBinding()]
param(
    [string]$Compiler = "",
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$Label = "stage2",
    [string]$LlvmHome = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
$Compiler = [System.IO.Path]::GetFullPath($Compiler)
$clang = Join-Path ([System.IO.Path]::GetFullPath($LlvmHome)) "bin\clang.exe"
$fixture = Join-Path $repoRoot "examples\regression\1227-static-readonly-array-storage.slg"
$expectedPath = Join-Path $repoRoot "examples\regression\expected\1227-static-readonly-array-storage.stdout.txt"
$runtimeManifest = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
foreach ($required in @($Compiler, $clang, $fixture, $expectedPath, $runtimeManifest)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "static readonly-array dependency is missing: $required"
    }
}

$artifacts = Join-Path $repoRoot "artifacts\static-readonly-array"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$llvmPath = Join-Path $artifacts "$Label.ll"
$stderrPath = Join-Path $artifacts "$Label.stderr.log"
$executablePath = Join-Path $artifacts "$Label.exe"
$runtimeSources = [System.IO.File]::ReadAllLines($runtimeManifest) |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_ }

$compile = Start-Process `
    -FilePath $Compiler `
    -ArgumentList (@("windows", "--jobs", "4", $fixture) + $runtimeSources) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $llvmPath `
    -RedirectStandardError $stderrPath `
    -WindowStyle Hidden `
    -PassThru
Wait-VerificationProcess $compile "$Label static readonly-array build"
$compileErrors = [System.IO.File]::ReadAllText($stderrPath)
if ($compile.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($compileErrors)) {
    throw "$Label static readonly-array emission failed or produced diagnostics.`n$compileErrors"
}

$llvm = [System.IO.File]::ReadAllText($llvmPath)
$global = [regex]::Match(
    $llvm,
    '(?<symbol>@sollang_static_array_m\d+_s\d+) = private unnamed_addr constant \[8 x i8\] \[i8 3, i8 5, i8 7, i8 11, i8 13, i8 17, i8 19, i8 23\], align 1')
if (-not $global.Success) {
    throw "$Label omitted the exact immutable static table"
}
$staticGlobals = [regex]::Matches($llvm, '@sollang_static_array_m\d+_s\d+ =')
if ($staticGlobals.Count -ne 1) {
    throw "$Label emitted $($staticGlobals.Count) static array globals; computed fixed values, literal fixed values, and growable owners must not be promoted"
}
$symbol = [regex]::Escape($global.Groups['symbol'].Value)
$functionSymbol = [regex]::Escape(
    $global.Groups['symbol'].Value.Replace('@sollang_static_array_', '@sollang_'))
$function = [regex]::Match(
    $llvm,
    "define [^\r\n]+ $functionSymbol\([^\r\n]*\) \{(?<body>.*?)\r?\n\}",
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
$body = if ($function.Success) { $function.Groups['body'].Value } else { "" }
if (-not $function.Success -or
    $body -notmatch "getelementptr \[8 x i8\], ptr $symbol, i64 0, i64 0" -or
    $body -match '@(?:malloc|sollang_alloc)\(') {
    throw "$Label static table function omitted the global reference or retained a call-time allocation"
}

& $clang -Wno-override-module $llvmPath -O1 -o $executablePath -Xlinker /subsystem:console -lshell32 -lws2_32 -lbcrypt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$run = Invoke-VerificationProcessCapture -FilePath $executablePath -Description "$Label static readonly-array executable"
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
if ($run.ExitCode -ne 0 -or $actual -ne $expected) {
    throw "$Label static readonly-array output mismatch.`nExpected:`n$expected`nActual:`n$actual`n$($run.Stderr)"
}

Write-Host "[selfhost static readonly array] PASS ${Label}: immutable global, zero call-time allocation, fixed/owned negative controls, exact execution."
