$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$verifier = Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1"
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testDirectory = [System.IO.Path]::GetFullPath((Join-Path $tempRoot ("sollang-llvm-call-closure-" + [guid]::NewGuid().ToString("N"))))
if (-not $testDirectory.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [System.IO.Path]::GetFileName($testDirectory).StartsWith("sollang-llvm-call-closure-", [System.StringComparison]::Ordinal)) {
    throw "unsafe LLVM direct-call closure test directory: $testDirectory"
}
$badPath = Join-Path $testDirectory "bad.ll"
$goodPath = Join-Path $testDirectory "good.ll"
$duplicatePath = Join-Path $testDirectory "duplicate.ll"
$runtimePath = Join-Path $testDirectory "runtime.ll"
$sentinelPath = Join-Path $testDirectory "sentinel.ll"
$nativeGlobalPath = Join-Path $testDirectory "native-global.ll"

try {
    New-Item -ItemType Directory -Path $testDirectory | Out-Null
    $bad = @'
@text = private unnamed_addr constant [25 x i8] c"call @sollang_m9_s9()\00"
declare i32 @sollang_m1_s1()
define i32 @main() {
entry:
  %ok = call i32 @sollang_m1_s1()
  %bad = call i32 @sollang_m2_s2()
  ret i32 0
}
'@
    [System.IO.File]::WriteAllText($badPath, $bad)
    $rejected = $false
    try {
        & $verifier -LlvmPath $badPath
    } catch {
        $rejected = $true
        if (-not $_.Exception.Message.Contains("sollang_m1_s1") -or
            -not $_.Exception.Message.Contains("sollang_m2_s2") -or
            $_.Exception.Message.Contains("sollang_m9_s9")) {
            throw "V004 negative control reported the wrong symbol set: $($_.Exception.Message)"
        }
    }
    if (-not $rejected) {
        throw "V004 negative control accepted an unresolved direct call"
    }

    $runtime = @'
define i32 @main() {
entry:
  call void @sollang_runtime_eprint(ptr null, i64 0, i1 false)
  ret i32 0
}
'@
    [System.IO.File]::WriteAllText($runtimePath, $runtime)
    $runtimeRejected = $false
    try {
        & $verifier -LlvmPath $runtimePath
    } catch {
        $runtimeRejected = $true
        if (-not $_.Exception.Message.Contains("V004") -or
            -not $_.Exception.Message.Contains("sollang_runtime_eprint")) {
            throw "V004 runtime negative control reported the wrong symbol set: $($_.Exception.Message)"
        }
    }
    if (-not $runtimeRejected) {
        throw "V004 runtime negative control accepted an unresolved target-runtime call"
    }

    $sentinel = @'
define i32 @main() {
entry:
  %bad = call i1 @sollang_m-1_s-1(ptr null, i32 0)
  ret i32 0
}
'@
    [System.IO.File]::WriteAllText($sentinelPath, $sentinel)
    $sentinelRejected = $false
    try {
        & $verifier -LlvmPath $sentinelPath
    } catch {
        $sentinelRejected = $true
        if (-not $_.Exception.Message.Contains("V004") -or
            -not $_.Exception.Message.Contains("sollang_m-1_s-1")) {
            throw "V004 sentinel negative control reported the wrong symbol set: $($_.Exception.Message)"
        }
    }
    if (-not $sentinelRejected) {
        throw "V004 sentinel negative control accepted an unresolved compiler symbol"
    }

    $nativeGlobal = @'
@text = private unnamed_addr constant [43 x i8] c"@sollang_native_function_m9_s9 should ignore\00"
define i32 @main() {
entry:
  %target = load ptr, ptr @sollang_native_function_m1_s4, align 8
  ret i32 0
}
'@
    [System.IO.File]::WriteAllText($nativeGlobalPath, $nativeGlobal)
    $nativeGlobalRejected = $false
    try {
        & $verifier -LlvmPath $nativeGlobalPath
    } catch {
        $nativeGlobalRejected = $true
        if (-not $_.Exception.Message.Contains("V007") -or
            -not $_.Exception.Message.Contains("sollang_native_function_m1_s4") -or
            $_.Exception.Message.Contains("sollang_native_function_m9_s9")) {
            throw "V007 negative control reported the wrong symbol set: $($_.Exception.Message)"
        }
    }
    if (-not $nativeGlobalRejected) {
        throw "V007 negative control accepted an unresolved native-function global"
    }

    $duplicate = @'
@text = private unnamed_addr constant [28 x i8] c"declare i32 @close(i32)\00"
declare i32 @close(i32)
declare i32 @close(i32)
define i32 @main() {
entry:
  ret i32 0
}
'@
    [System.IO.File]::WriteAllText($duplicatePath, $duplicate)
    $duplicateRejected = $false
    try {
        & $verifier -LlvmPath $duplicatePath
    } catch {
        $duplicateRejected = $true
        if (-not $_.Exception.Message.Contains("V005") -or
            -not $_.Exception.Message.Contains("close")) {
            throw "V005 negative control reported the wrong symbol set: $($_.Exception.Message)"
        }
    }
    if (-not $duplicateRejected) {
        throw "V005 negative control accepted a duplicate function declaration"
    }

$good = @'
declare i32 @external_fixture(ptr)
@sollang_native_function_m1_s4 = internal global ptr null, align 8
define i32 @sollang_m1_s1() {
entry:
  ret i32 1
}
define i32 @sollang_m2_s2() {
entry:
  ret i32 2
}
define i32 @main() {
entry:
  %one = call i32 @sollang_m1_s1()
  %two = call i32 @sollang_m2_s2()
  %external = call i32 @external_fixture(ptr null)
  %native = load ptr, ptr @sollang_native_function_m1_s4, align 8
  ret i32 0
}
'@
    [System.IO.File]::WriteAllText($goodPath, $good)
    & $verifier -LlvmPath $goodPath
    Write-Host "[LLVM direct-call closure contract] PASS declared-only internal, unresolved runtime/sentinel/native-global, duplicate declaration, string-literal negative, defined-internal, and external-declaration controls."
} finally {
    if (Test-Path -LiteralPath $testDirectory) {
        Remove-Item -LiteralPath $testDirectory -Recurse -Force
    }
}
