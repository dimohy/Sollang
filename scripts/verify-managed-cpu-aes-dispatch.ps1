[CmdletBinding()]
param(
    [string]$CompilerAssembly = "",
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$Label = "managed",
    [string]$LlvmHome = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CompilerAssembly)) {
    $CompilerAssembly = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
$CompilerAssembly = [System.IO.Path]::GetFullPath($CompilerAssembly)
$LlvmHome = [System.IO.Path]::GetFullPath($LlvmHome)
$fixture = Join-Path $repoRoot "examples\regression\889-stdlib-aes128-gcm.slg"
$expectedPath = Join-Path $repoRoot "examples\regression\expected\889-stdlib-aes128-gcm.stdout.txt"
foreach ($required in @($CompilerAssembly, $fixture, $expectedPath, (Join-Path $LlvmHome "bin\clang.exe"))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "managed CPU AES dispatch dependency is missing: $required"
    }
}

$artifacts = Join-Path $repoRoot "artifacts\managed-cpu-aes-dispatch"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$executablePath = Join-Path $artifacts "$Label.exe"
$llvmPath = Join-Path $artifacts "$Label.ll"
$temporaryPath = Join-Path $artifacts "$Label.slg-tmp"
$stdoutPath = Join-Path $artifacts "$Label.stdout.log"
$stderrPath = Join-Path $artifacts "$Label.stderr.log"
Remove-Item -LiteralPath $executablePath, $llvmPath, $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $temporaryPath -Recurse -Force -ErrorAction SilentlyContinue

$compile = Start-Process `
    -FilePath "dotnet" `
    -ArgumentList @(
        $CompilerAssembly,
        "build",
        $fixture,
        "-o",
        $executablePath,
        "--llvm",
        $LlvmHome,
        "-O0",
        "--keep-temps") `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -WindowStyle Hidden `
    -PassThru
Wait-VerificationProcess $compile "$Label managed CPU AES build"
$compileErrors = [System.IO.File]::ReadAllText($stderrPath)
if ($compile.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
    $compileOutput = [System.IO.File]::ReadAllText($stdoutPath)
    throw "$Label managed CPU AES build failed or omitted LLVM.`n$compileOutput`n$compileErrors"
}
if (-not [string]::IsNullOrWhiteSpace($compileErrors)) {
    throw "$Label managed CPU AES compiler emitted diagnostics for the valid fixture.`n$compileErrors"
}

$llvm = [System.IO.File]::ReadAllText($llvmPath)
$x86Match = [regex]::Match(
    $llvm,
    'define internal [^\r\n]+@sollang_fn_std_crypto_aes128_Key_encryptBlock_x86\([^\r\n]+\) #1 \{(?<body>.*?)\r?\n\}',
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
$portableMatch = [regex]::Match(
    $llvm,
    'define internal [^\r\n]+@sollang_fn_std_crypto_aes128_Key_encryptBlock_portable\([^\r\n]+\) #0 \{(?<body>.*?)\r?\n\}',
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $x86Match.Success -or -not $portableMatch.Success) {
    throw "$Label managed CPU AES LLVM omitted the exact instance-owned portable or x86 function"
}
$x86Body = $x86Match.Groups['body'].Value
$portableBody = $portableMatch.Groups['body'].Value
$aesRounds = [regex]::Matches($x86Body, '@llvm\.x86\.aesni\.aesenc\(').Count
$lastRounds = [regex]::Matches($x86Body, '@llvm\.x86\.aesni\.aesenclast\(').Count
if ($aesRounds -ne 9 -or $lastRounds -ne 1) {
    throw "$Label managed CPU AES x86 kernel has $aesRounds aesenc and $lastRounds aesenclast calls; expected 9 and 1"
}
if ($x86Body -match 'sollang_cpu_features_once|alloca\s+\[176|memcpy[^\r\n]*176') {
    throw "$Label managed CPU AES x86 hot function probes features or copies the 176-byte schedule"
}
if ($portableBody -match 'llvm\.x86\.aesni') {
    throw "$Label managed CPU AES portable function contains optional x86 instructions"
}
if ($llvm -notmatch 'target-features"="\+aes,\+sse2"' `
    -or $llvm -notmatch 'define internal i64 @sollang_cpu_features_once\(\)' `
    -or $llvm -notmatch 'cpuid' `
    -or $llvm -notmatch '@sollang_aes128_selected = internal global ptr @sollang_fn_std_crypto_aes128_Key_encryptBlock_resolve' `
    -or $llvm -notmatch '%output = call ptr @sollang_alloc\(i64 16\)') {
    throw "$Label managed CPU AES LLVM omitted the target feature, once resolver, exact instance identity, or platform allocator contract"
}

$run = Invoke-VerificationProcessCapture `
    -FilePath $executablePath `
    -Description "$Label managed CPU AES executable"
if ($run.ExitCode -ne 0) {
    throw "$Label managed CPU AES executable exited with $($run.ExitCode).`n$($run.Stderr)"
}
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
if ($actual -ne $expected) {
    throw "$Label managed CPU AES output mismatch.`nExpected:`n$expected`nActual:`n$actual"
}

Write-Host "[managed CPU AES dispatch] PASS ${Label}: exact Key instance identity, portable isolation, once dispatch, 9+1 AES rounds, platform allocation, and fixture 889 output."
