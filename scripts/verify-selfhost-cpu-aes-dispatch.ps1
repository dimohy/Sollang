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
$runtimeManifest = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
$fixture = Join-Path $repoRoot "examples\regression\889-stdlib-aes128-gcm.slg"
$expectedPath = Join-Path $repoRoot "examples\regression\expected\889-stdlib-aes128-gcm.stdout.txt"
$focusedSources = @(
    "stdlib\std\net\quic\packet.slg",
    "stdlib\std\net\quic\protection.slg",
    "stdlib\std\net\quic\keys.slg",
    "stdlib\std\net\quic\packet_number.slg",
    "stdlib\std\net\quic\varint.slg",
    "stdlib\std\net\quic\error.slg",
    "stdlib\std\crypto\aes128_gcm.slg",
    "stdlib\std\crypto\aes128_gcm_result.slg",
    "stdlib\std\crypto\aes128.slg",
    "stdlib\std\crypto\bits.slg",
    "stdlib\std\crypto\hkdf_sha256.slg",
    "stdlib\std\crypto\tls13_hkdf.slg",
    "stdlib\std\crypto\hmac_sha256.slg",
    "stdlib\std\crypto\sha256.slg"
) | ForEach-Object { Join-Path $repoRoot $_ }
foreach ($required in @($Compiler, $clang, $runtimeManifest, $fixture, $expectedPath) + $focusedSources) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "CPU AES dispatch dependency is missing: $required"
    }
}

$artifacts = Join-Path $repoRoot "artifacts\cpu-aes-dispatch"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$llvmPath = Join-Path $artifacts "$Label.ll"
$executablePath = Join-Path $artifacts "$Label.exe"
$stderrPath = Join-Path $artifacts "$Label.stderr.log"
Remove-Item -LiteralPath $llvmPath, $executablePath, $stderrPath -ErrorAction SilentlyContinue

$runtimeSources = [System.IO.File]::ReadAllLines($runtimeManifest) |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_ }
$arguments = @(
    "windows",
    "--jobs",
    "4",
    $fixture
) + $focusedSources + $runtimeSources
$compile = Start-Process `
    -FilePath $Compiler `
    -ArgumentList $arguments `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $llvmPath `
    -RedirectStandardError $stderrPath `
    -WindowStyle Hidden `
    -PassThru
Wait-VerificationProcess $compile "$Label CPU AES focused build"
$compileErrors = [System.IO.File]::ReadAllText($stderrPath)
if ($compile.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
    throw "$Label CPU AES emission failed or omitted LLVM.`n$compileErrors"
}
if (-not [string]::IsNullOrWhiteSpace($compileErrors)) {
    throw "$Label CPU AES compiler emitted diagnostics for the valid focused fixture.`n$compileErrors"
}

$llvm = [System.IO.File]::ReadAllText($llvmPath)
$x86Match = [regex]::Match(
    $llvm,
    'define internal [^\r\n]+@sollang_m\d+_s\d+_x86\([^\r\n]+\) #[0-9]+ \{(?<body>.*?)\r?\n\}',
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
$portableMatch = [regex]::Match(
    $llvm,
    'define [^\r\n]+@sollang_m\d+_s\d+_portable\([^\r\n]+\) \{(?<body>.*?)\r?\n\}',
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $x86Match.Success -or -not $portableMatch.Success) {
    throw "$Label CPU AES LLVM omitted the portable or x86 implementation"
}
$x86Body = $x86Match.Groups['body'].Value
$portableBody = $portableMatch.Groups['body'].Value
$aesRounds = [regex]::Matches($x86Body, '@llvm\.x86\.aesni\.aesenc\(').Count
$lastRounds = [regex]::Matches($x86Body, '@llvm\.x86\.aesni\.aesenclast\(').Count
if ($aesRounds -ne 9 -or $lastRounds -ne 1) {
    throw "$Label CPU AES x86 kernel has $aesRounds aesenc and $lastRounds aesenclast calls; expected 9 and 1"
}
if ($x86Body -match 'sollang_cpu_features_once|alloca\s+\[176|memcpy[^\r\n]*176') {
    throw "$Label CPU AES x86 hot function probes features or copies the 176-byte schedule"
}
if ($portableBody -match 'llvm\.x86\.aesni') {
    throw "$Label CPU AES portable function contains optional x86 instructions"
}
$hasReadonlyReceiverLoad = $llvm -match '%call\d+_arg0_reference_value = load %sollang\.struct\.' -or
    ($llvm -match 'getelementptr inbounds %sollang\.struct\.[^\r\n]+ptr %arg, i32 0, i32 0' -and
    $llvm -match 'load %sollang\.struct\.[^\r\n]+ptr %v\d+_address')
if ($llvm -notmatch 'target-features"="\+aes,\+sse2"' -or
    $llvm -notmatch 'define internal i64 @sollang_cpu_features_once\(\)' -or
    $llvm -notmatch 'cpuid' -or
    $llvm -notmatch '@sollang_aes128_selected = internal global ptr @sollang_m\d+_s\d+_resolve' -or
    -not $hasReadonlyReceiverLoad) {
    throw "$Label CPU AES LLVM omitted the exact target feature, process snapshot, once-resolved dispatch, or readonly receiver load contract"
}

& $clang -Wno-override-module $llvmPath -O1 -o $executablePath -Xlinker /subsystem:console -lshell32 -lws2_32 -lbcrypt
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "$Label CPU AES LLVM failed to link"
}

$run = Invoke-VerificationProcessCapture `
    -FilePath $executablePath `
    -Description "$Label CPU AES executable"
if ($run.ExitCode -ne 0) {
    throw "$Label CPU AES executable exited with $($run.ExitCode).`n$($run.Stderr)"
}
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
if ($actual -ne $expected) {
    throw "$Label CPU AES output mismatch.`nExpected:`n$expected`nActual:`n$actual"
}

Write-Host "[selfhost CPU AES dispatch] PASS ${Label}: portable isolation, once dispatch, 9+1 AES rounds, zero hot schedule copy, and fixture 889 output."
