[CmdletBinding()]
param(
    [string]$Compiler,
    [string]$LlvmHome
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3.exe"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
$Compiler = [System.IO.Path]::GetFullPath($Compiler)
$LlvmHome = [System.IO.Path]::GetFullPath($LlvmHome)
$llvmAs = Join-Path $LlvmHome "bin\llvm-as.exe"
$clang = Join-Path $LlvmHome "bin\clang.exe"
foreach ($required in @($Compiler, $llvmAs, $clang)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "native binary-codec dependency is missing: $required"
    }
}

$artifacts = Join-Path $repoRoot "artifacts\native-binary-codecs"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null

function Invoke-CompilerToFile {
    param(
        [string[]]$Arguments,
        [string]$OutputPath,
        [string]$ErrorPath
    )

    $process = Start-Process `
        -FilePath $Compiler `
        -ArgumentList $Arguments `
        -WorkingDirectory $repoRoot `
        -RedirectStandardOutput $OutputPath `
        -RedirectStandardError $ErrorPath `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $process "native binary compiler emission"
    if ($process.ExitCode -ne 0) {
        $stdoutDetails = if (Test-Path -LiteralPath $OutputPath) {
            [System.IO.File]::ReadAllText($OutputPath)
        } else { "" }
        $stderrDetails = if (Test-Path -LiteralPath $ErrorPath) {
            [System.IO.File]::ReadAllText($ErrorPath)
        } else { "" }
        throw "native compiler exited with $($process.ExitCode).`nstdout:`n$stdoutDetails`nstderr:`n$stderrDetails"
    }
    $diagnostics = if (Test-Path -LiteralPath $ErrorPath) {
        [System.IO.File]::ReadAllText($ErrorPath)
    } else { "" }
    if (-not [string]::IsNullOrWhiteSpace($diagnostics)) {
        throw "native compiler emitted diagnostics for a passing binary-codec fixture.`n$diagnostics"
    }
}

function Assert-NormalizedOutput {
    param(
        [string]$Executable,
        [string]$ExpectedPath,
        [string]$Label
    )

    $run = Invoke-VerificationProcessCapture `
        -FilePath $Executable `
        -Description "$Label executable"
    $actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
    if ($run.ExitCode -ne 0) {
        throw "$Label exited with $($run.ExitCode).`n$($run.Stderr)"
    }
    $expected = [System.IO.File]::ReadAllText($ExpectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    if ($actual -ne $expected) {
        throw "$Label output mismatch.`nExpected:`n$expected`nActual:`n$actual"
    }
}

$cases = @(
    [ordered]@{
        Name = "binary"
        Sources = @(
            (Join-Path $repoRoot "examples\regression\1085-binary-reader-writer-instances.slg"),
            (Join-Path $repoRoot "stdlib\std\encoding\binary.slg"),
            (Join-Path $repoRoot "stdlib\std\encoding\binary\error.slg")
        )
        Expected = Join-Path $repoRoot "examples\regression\expected\1085-binary-reader-writer-instances.stdout.txt"
        RequireAllocationFreeStart = $false
    },
    [ordered]@{
        Name = "crc32"
        Sources = @(
            (Join-Path $repoRoot "examples\regression\1086-crc32-policy-hasher-instances.slg"),
            (Join-Path $repoRoot "stdlib\std\hash\crc32.slg")
        )
        Expected = Join-Path $repoRoot "examples\regression\expected\1086-crc32-policy-hasher-instances.stdout.txt"
        RequireAllocationFreeStart = $false
    },
    [ordered]@{
        Name = "crc32-fixed"
        Sources = @(
            (Join-Path $repoRoot "examples\regression\1087-crc32-fixed-input-instance-o0.slg"),
            (Join-Path $repoRoot "stdlib\std\hash\crc32.slg")
        )
        Expected = Join-Path $repoRoot "examples\regression\expected\1087-crc32-fixed-input-instance-o0.stdout.txt"
        RequireAllocationFreeStart = $true
    },
    [ordered]@{
        Name = "uint32-interpolation"
        Sources = @(
            (Join-Path $repoRoot "examples\regression\1089-unsigned32-interpolation-contexts.slg")
        )
        Expected = Join-Path $repoRoot "examples\regression\expected\1089-unsigned32-interpolation-contexts.stdout.txt"
        RequireAllocationFreeStart = $false
    },
    [ordered]@{
        Name = "gzip-crc32-parity"
        Sources = @(
            (Join-Path $repoRoot "examples\regression\1090-gzip-public-crc32-parity.slg"),
            (Join-Path $repoRoot "stdlib\std\compress\gzip.slg"),
            (Join-Path $repoRoot "stdlib\std\compress\gzip\error.slg"),
            (Join-Path $repoRoot "stdlib\std\compress\gzip\decoder_phase.slg"),
            (Join-Path $repoRoot "stdlib\std\hash\crc32.slg")
        )
        Expected = Join-Path $repoRoot "examples\regression\expected\1090-gzip-public-crc32-parity.stdout.txt"
        RequireAllocationFreeStart = $false
    },
    [ordered]@{
        Name = "interpolation-chained-enum-method"
        Sources = @(
            (Join-Path $repoRoot "examples\regression\1092-interpolation-chained-enum-method.slg")
        )
        Expected = Join-Path $repoRoot "examples\regression\expected\1092-interpolation-chained-enum-method.stdout.txt"
        RequireAllocationFreeStart = $false
    }
)

$caseIndex = 0
foreach ($case in $cases) {
    $caseIndex++
    Write-Host "[native binary $caseIndex/$($cases.Count)] Emit and verify $($case.Name)."
    $llvmPath = Join-Path $artifacts "$($case.Name).ll"
    $errorPath = Join-Path $artifacts "$($case.Name).err"
    Invoke-CompilerToFile (@("windows") + $case.Sources) $llvmPath $errorPath
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $llvmPath
    & $llvmAs $llvmPath -o (Join-Path $artifacts "$($case.Name).bc")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($case.RequireAllocationFreeStart) {
        $llvmLines = [System.IO.File]::ReadAllLines($llvmPath)
        $startLine = -1
        for ($lineIndex = 0; $lineIndex -lt $llvmLines.Count; $lineIndex++) {
            if ($llvmLines[$lineIndex] -match '^define (?:dso_local )?i32 @(?:sollang_start|main)\(') {
                $startLine = $lineIndex
                break
            }
        }
        if ($startLine -lt 0) {
            throw "$($case.Name) has no executable entry definition"
        }
        $startEnd = $startLine + 1
        while ($startEnd -lt $llvmLines.Count -and $llvmLines[$startEnd] -ne "}") {
            $startEnd++
        }
        if ($startEnd -ge $llvmLines.Count) {
            throw "$($case.Name) executable entry definition is unterminated"
        }
        $startBody = [string]::Join("`n", $llvmLines[$startLine..$startEnd])
        $functionBodies = @{}
        for ($functionLine = 0; $functionLine -lt $llvmLines.Count; $functionLine++) {
            if ($llvmLines[$functionLine] -notmatch '^define [^@]*@([^\(]+)\(') { continue }
            $functionName = $Matches[1]
            $functionEnd = $functionLine + 1
            while ($functionEnd -lt $llvmLines.Count -and $llvmLines[$functionEnd] -ne "}") {
                $functionEnd++
            }
            if ($functionEnd -ge $llvmLines.Count) {
                throw "$($case.Name) function '$functionName' is unterminated"
            }
            $functionBodies[$functionName] = [string]::Join("`n", $llvmLines[$functionLine..$functionEnd])
            $functionLine = $functionEnd
        }
        $entryName = if ($llvmLines[$startLine] -match '@([^\(]+)\(') { $Matches[1] } else { throw "$($case.Name) executable entry name is malformed" }
        $pendingFunctions = [System.Collections.Generic.Stack[string]]::new()
        $pendingFunctions.Push($entryName)
        $visitedFunctions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        while ($pendingFunctions.Count -gt 0) {
            $reachableName = $pendingFunctions.Pop()
            if (-not $visitedFunctions.Add($reachableName)) { continue }
            $reachableBody = $functionBodies[$reachableName]
            if ($reachableBody -match 'call (?:ptr|void) @(?:sollang_alloc|sollang_free|malloc|free)') {
                throw "$($case.Name) reachable instance path allocates or frees heap memory at O0 in '$reachableName'"
            }
            if ($reachableBody -match 'call [^\r\n]*%[A-Za-z0-9_.]+\(') {
                throw "$($case.Name) reachable instance path uses indirect dispatch at O0 in '$reachableName'"
            }
            foreach ($callMatch in [regex]::Matches($reachableBody, 'call [^\r\n]*@(sollang_(?:m\d+_s\d+|fn_[A-Za-z0-9_.]+))\(')) {
                $calledName = $callMatch.Groups[1].Value
                if ($functionBodies.ContainsKey($calledName) -and -not $visitedFunctions.Contains($calledName)) {
                    $pendingFunctions.Push($calledName)
                }
            }
        }
        $startLines = $llvmLines[$startLine..$startEnd]
        $firstLoopLabel = -1
        $fixedPayloadAllocas = @()
        for ($bodyLineIndex = 0; $bodyLineIndex -lt $startLines.Count; $bodyLineIndex++) {
            if ($firstLoopLabel -lt 0 -and $startLines[$bodyLineIndex] -match '^while\d+_header:$') {
                $firstLoopLabel = $bodyLineIndex
            }
            if ($startLines[$bodyLineIndex] -match '_data = alloca \[\d+ x i8\]') {
                $fixedPayloadAllocas += $bodyLineIndex
            }
        }
        if ($firstLoopLabel -lt 0 -or $fixedPayloadAllocas.Count -eq 0) {
            throw "$($case.Name) does not exercise fixed storage inside a loop"
        }
        if ($fixedPayloadAllocas | Where-Object { $_ -gt $firstLoopLabel }) {
            throw "$($case.Name) fixed payload alloca was not hoisted before the loop"
        }
    }

    foreach ($optimization in @("O0", "O2")) {
        $executable = Join-Path $artifacts "$($case.Name)-$optimization.exe"
        & $clang $llvmPath "-$optimization" -Werror -Wno-override-module -o $executable
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Assert-NormalizedOutput $executable $case.Expected "$($case.Name) $optimization"
    }
}

Write-Host "[native binary] PASS binary, CRC32, GZIP checksum parity, UInt32 interpolation, and chained enum-method interpolation at O0/O2; fixed-input Hasher path is heap-allocation-free, direct-dispatch, and function-entry-hoisted at O0."
