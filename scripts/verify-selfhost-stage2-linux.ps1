param(
    [string]$Distribution = "Ubuntu",
    [ValidateRange(1, 64)]
    [int]$Jobs = 4,
    [switch]$Rebuild,
    [switch]$ResumeCandidate
)

$ErrorActionPreference = "Stop"
if ($Rebuild -and $ResumeCandidate) {
    throw "-Rebuild and -ResumeCandidate are mutually exclusive"
}

. (Join-Path $PSScriptRoot "selfhost-verification-lock.ps1")
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
. (Join-Path $PSScriptRoot "stage3-seed-provenance.ps1")
. (Join-Path $PSScriptRoot "input-fingerprint-stability.ps1")
$selfHostVerificationLock = Enter-SelfHostVerificationLock
try {

$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot "verify-quic-frame-consumers.ps1") -RepositoryRoot $repoRoot -Jobs 3
& (Join-Path $PSScriptRoot "verify-gzip-stream-api-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-zstd-foundation-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-brotli-foundation-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-body-framing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-response-writing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-request-writing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-client-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-server-contract.ps1") -RepositoryRoot $repoRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$manifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"
$stage1Path = Join-Path $repoRoot "artifacts\incremental-selfhost\selfhost-slg-seed.exe"
$stage1ReceiptPath = Join-Path $repoRoot "artifacts\incremental-selfhost\selfhost-slg-seed.sha256"
$stage2LlvmPath = Join-Path $artifactsDir "selfhost-stage2-linux.ll"
$stage2BitcodePath = Join-Path $artifactsDir "selfhost-stage2-linux.bc"
$stage2ObjectPath = Join-Path $artifactsDir "selfhost-stage2-linux.o"
$stage2Path = Join-Path $artifactsDir "selfhost-stage2-linux"
$stage2FingerprintPath = Join-Path $artifactsDir "selfhost-stage2-linux.inputs.sha256"
$stage2ArtifactReceiptPath = Join-Path $artifactsDir "selfhost-stage2-linux.outputs.sha256"
$publishedStage2LlvmPath = $stage2LlvmPath
$publishedStage2BitcodePath = $stage2BitcodePath
$publishedStage2ObjectPath = $stage2ObjectPath
$publishedStage2Path = $stage2Path
$stage2WasRebuilt = $false
$llvmDir = Join-Path $repoRoot ".tools\llvm-22.1.8"
$llvmAsPath = Join-Path $llvmDir "bin\llvm-as.exe"
$clangPath = Join-Path $llvmDir "bin\clang.exe"
$runtimeManifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
& (Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1") `
    -Manifest @($manifestPath, $runtimeManifestPath) `
    -RepositoryRoot $repoRoot
$compilerRuntimeSources = Get-Content $runtimeManifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_.Trim() }
$compilerSources = Get-Content $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }
$singleSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-single-smoke.slg"
$multiLibrarySource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-library-smoke.slg"
$multiMainSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-main-smoke.slg"
$subjectWhenDirectResultSource = Join-Path $repoRoot "examples\user\670-inclusive-and-half-open-ranges.slg"
$resultPropagationControlSource = Join-Path $repoRoot "examples\regression\1017-quic-friendly-ipv4-endpoints.slg"
$setKeyOnlySource = Join-Path $repoRoot "examples\regression\854-set-key-only.slg"
$setKeyOnlyExpectedPath = Join-Path $repoRoot "examples\regression\expected\854-set-key-only.stdout.txt"
$setKeyOnlyForbiddenPath = Join-Path $repoRoot "examples\regression\expected\854-set-key-only.selfhost.llvm.not-contains.txt"
$stdlibRoot = Join-Path $repoRoot "stdlib"
$directoryCreateSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-directory-create.slg"
$pathNormalizeResultSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-path-normalize-result.slg"
$borrowConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-conflict.slg"
$borrowUnionConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-union-conflict.slg"
$borrowAliasConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-alias-conflict.slg"
$borrowAggregateConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-aggregate-conflict.slg"
$borrowProjectionConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-projection-conflict.slg"
$partialMoveConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-partial-move-conflict.slg"
$branchPartialMoveConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-branch-partial-move-conflict.slg"
$parallelMutableCaptureSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-parallel-mutable-capture.slg"
$parallelNonSendableCaptureSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-parallel-nonsendable-capture.slg"
$referenceTemporarySource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-temporary.slg"
$referenceLivenessSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-liveness.slg"
$referenceOwnerMoveSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-owner-move.slg"
$referenceLoopContinueSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-loop-continue.slg"
$referenceStoredStructSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-stored-struct.slg"
$referenceAggregateEscapeSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-aggregate-escape.slg"
$referenceStoredEnumSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-stored-enum.slg"
$referenceStoredArraySource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-stored-array.slg"
$referenceEnumEscapeSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-enum-escape.slg"
$referenceArrayEscapeSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-array-escape.slg"
$borrowSourceRuntime = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-source.slg"
$expectedStage2Bytes = if (Test-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -AdditionalArtifacts @{ object = $stage2ObjectPath } `
        -ReceiptPath $stage2ArtifactReceiptPath) {
    (Get-Item -LiteralPath $stage2LlvmPath).Length
} else {
    $windowsStage2LlvmPath = Join-Path $artifactsDir "selfhost-stage2.ll"
    if (Test-Path -LiteralPath $windowsStage2LlvmPath) {
        (Get-Item -LiteralPath $windowsStage2LlvmPath).Length
    } else {
        19994874L
    }
}

New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null
& (Join-Path $PSScriptRoot "verify-verification-process-contract.ps1") `
    -IncludeWsl `
    -Distribution $Distribution

function Convert-ToWslPath {
    param([string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    return "/mnt/$drive/$tail"
}

function Invoke-ProcessToFile {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$OutputPath,
        [string]$ErrorPath
    )

    Remove-Item -LiteralPath $OutputPath, $ErrorPath -ErrorAction SilentlyContinue
    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -RedirectStandardOutput $OutputPath `
        -RedirectStandardError $ErrorPath `
        -PassThru `
        -WindowStyle Hidden
    $null = $process.Handle
    return $process
}

function Assert-ProcessSucceeded {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$ErrorPath,
        [string]$Description
    )

    Wait-VerificationProcess $Process $Description
    $Process.Refresh()
    if ($Process.ExitCode -ne 0) {
        $details = if (Test-Path $ErrorPath) { Get-Content $ErrorPath -Raw } else { "" }
        throw "$Description failed with exit code $($Process.ExitCode).`n$details"
    }
}

function Get-NormalizedHash {
    param([string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

function Get-ContentFingerprint {
    param([string[]]$Paths)

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    foreach ($path in $Paths) {
        $relative = [System.IO.Path]::GetRelativePath($repoRoot, $path).Replace("\", "/")
        $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes("$relative`0"))
        $hash.AppendData([System.IO.File]::ReadAllBytes($path))
    }
    return [Convert]::ToHexString($hash.GetHashAndReset())
}

function Get-LinuxStage2InputFingerprint {
    $paths = @($stage1Path, $manifestPath, $runtimeManifestPath)
    $paths += $compilerSources
    $paths += $compilerRuntimeSources
    return Get-ContentFingerprint $paths
}

function Test-Stage2IsCurrent {
    if ($Rebuild -or
        -not (Test-Stage2ArtifactReceipt `
            -LlvmPath $stage2LlvmPath `
            -BitcodePath $stage2BitcodePath `
            -ExecutablePath $stage2Path `
            -AdditionalArtifacts @{ object = $stage2ObjectPath } `
            -ReceiptPath $stage2ArtifactReceiptPath)) {
        return $false
    }

    return (Test-Path -LiteralPath $stage2FingerprintPath) -and
        [System.IO.File]::ReadAllText($stage2FingerprintPath).Trim() -ceq (Get-LinuxStage2InputFingerprint)
}

function Build-And-ExecuteLinuxLlvm {
    param(
        [string]$LlvmPath,
        [string]$Name,
        [string]$Expected
    )

    $bitcodePath = Join-Path $artifactsDir "$Name.bc"
    $objectPath = Join-Path $artifactsDir "$Name.o"
    $executablePath = Join-Path $artifactsDir $Name
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $LlvmPath
    & $llvmAsPath $LlvmPath -o $bitcodePath
    if ($LASTEXITCODE -ne 0) { throw "llvm-as failed for $Name" }
    & $clangPath --target=x86_64-unknown-linux-gnu -c $LlvmPath -O0 -o $objectPath
    if ($LASTEXITCODE -ne 0) { throw "Linux object generation failed for $Name" }
    & wsl.exe -d $Distribution -- gcc (Convert-ToWslPath $objectPath) -o (Convert-ToWslPath $executablePath)
    if ($LASTEXITCODE -ne 0) { throw "Linux link failed for $Name" }
    $actual = (& wsl.exe -d $Distribution -- (Convert-ToWslPath $executablePath) | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
    if ($LASTEXITCODE -ne 0 -or $actual -ne $Expected) {
        throw "Linux execution failed for $Name`: expected '$Expected', actual '$actual'"
    }
}

Write-Host "[linux-stage2 1/6] Verify the receipt-bound SLG feedback seed."
if (-not (Test-Path -LiteralPath $stage1Path) -or (Get-Item -LiteralPath $stage1Path).Length -eq 0) {
    throw "verified Stage3 SLG seed is missing: $stage1Path; complete the Windows Stage3 fixed point first"
}
if (-not (Test-Path -LiteralPath $stage1ReceiptPath)) {
    throw "verified Stage3 SLG seed receipt is missing: $stage1ReceiptPath"
}
$recordedStage1Hash = [System.IO.File]::ReadAllText($stage1ReceiptPath).Trim()
$actualStage1Hash = (Get-FileHash -LiteralPath $stage1Path -Algorithm SHA256).Hash
if ($recordedStage1Hash -cne $actualStage1Hash) {
    throw "Stage3 SLG seed differs from its verification receipt: expected $recordedStage1Hash, actual $actualStage1Hash"
}
Assert-VerifiedStage3SeedProvenance `
    -RepositoryRoot $repoRoot `
    -SeedPath $stage1Path `
    -Target windows | Out-Null
Write-Host "[linux-stage2 1/6] PASS SLG-first seed $actualStage1Hash."

& (Join-Path $PSScriptRoot "verify-native-exact-fixture.ps1") `
    -Compiler $stage1Path `
    -Label "linux-stage1-seed" `
    -Fixture "1217-selfhost-late-indexed-array-type-contract" `
    -Platform linux `
    -Distribution $Distribution `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory (Join-Path $artifactsDir "linux-stage1-seed-exact") `
    -Jobs $Jobs `
    -CompilerHost windows `
    -CompilationMode raw-llvm `
    -AdditionalSource $compilerRuntimeSources
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "[linux-stage2 1/6] PASS late indexed-array semantic seed gate."

$directoryCreateTarget = Join-Path $artifactsDir "stage2-directory-create"
if (Test-Path -LiteralPath $directoryCreateTarget) {
    Remove-Item -LiteralPath $directoryCreateTarget -Recurse -Force
}
$directoryCreateLlvm = Join-Path $artifactsDir "linux-stage2-check-directory-create.ll"
$directoryCreateError = Join-Path $artifactsDir "linux-stage2-check-directory-create.err"
$directoryCreateProcess = Invoke-ProcessToFile `
    $stage1Path `
    (@("linux", $directoryCreateSource) + $compilerRuntimeSources) `
    $directoryCreateLlvm `
    $directoryCreateError
Assert-ProcessSucceeded $directoryCreateProcess $directoryCreateError "Linux stage-1 directory creation emission"
Build-And-ExecuteLinuxLlvm $directoryCreateLlvm "linux-stage2-check-directory-create" "created`nexists"
if (-not (Test-Path -LiteralPath $directoryCreateTarget -PathType Container)) {
    throw "Linux directory creation did not create $directoryCreateTarget"
}
Write-Host "[linux-stage2 1/6] PASS directory creation and existing-directory idempotence."

$pathNormalizeResultLlvm = Join-Path $artifactsDir "linux-stage2-check-path-normalize-result.ll"
$pathNormalizeResultError = Join-Path $artifactsDir "linux-stage2-check-path-normalize-result.err"
$pathNormalizeResultProcess = Invoke-ProcessToFile `
    $stage1Path `
    (@("linux", $pathNormalizeResultSource) + $compilerRuntimeSources) `
    $pathNormalizeResultLlvm `
    $pathNormalizeResultError
Assert-ProcessSucceeded $pathNormalizeResultProcess $pathNormalizeResultError "Linux stage-1 owned Result path normalization emission"
Build-And-ExecuteLinuxLlvm $pathNormalizeResultLlvm "linux-stage2-check-path-normalize-result" "artifacts/native-grammar-build/probe/generated.slg`ntrue"
Write-Host "[linux-stage2 1/6] PASS owned Result nested-return path normalization."

Write-Host "[linux-stage2 2/6] Build or reuse the complete Linux stage-2 compiler."
if (Test-Stage2IsCurrent) {
    Write-Host "[linux-stage2 2/6] REUSE current Linux stage 2."
} else {
    $stage2CandidateLlvmPath = Get-CandidateArtifactPath $stage2LlvmPath
    $stage2CandidateBitcodePath = Get-CandidateArtifactPath $stage2BitcodePath
    $stage2CandidateObjectPath = Get-CandidateArtifactPath $stage2ObjectPath
    $stage2CandidatePath = "$stage2Path.candidate"
    $stage2CandidateFingerprintPath = Get-CandidateArtifactPath $stage2FingerprintPath
    $stage2CandidateArtifactReceiptPath = Get-CandidateArtifactPath $stage2ArtifactReceiptPath
    if ($ResumeCandidate) {
        if (-not (Test-Stage2ArtifactReceipt `
                -LlvmPath $stage2CandidateLlvmPath `
                -BitcodePath $stage2CandidateBitcodePath `
                -ExecutablePath $stage2CandidatePath `
                -AdditionalArtifacts @{ object = $stage2CandidateObjectPath } `
                -ReceiptPath $stage2CandidateArtifactReceiptPath) -or
            -not (Test-Path -LiteralPath $stage2CandidateFingerprintPath) -or
            [System.IO.File]::ReadAllText($stage2CandidateFingerprintPath).Trim() -cne (Get-LinuxStage2InputFingerprint)) {
            throw "Linux Stage2 candidate artifacts do not match their input/output receipts; rebuild without -ResumeCandidate"
        }
        Write-Host "[linux-stage2 2/6] RESUME receipt-bound Linux Stage2 candidate."
    } else {
        Remove-Item -LiteralPath $stage2CandidateLlvmPath, $stage2CandidateBitcodePath, $stage2CandidateObjectPath, $stage2CandidatePath, $stage2CandidateFingerprintPath, $stage2CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
        $sourcePaths = @($compilerSources + ($compilerRuntimeSources | ForEach-Object { (Resolve-Path $_).Path }))
        $sourceLineCount = ($sourcePaths | ForEach-Object { [System.IO.File]::ReadAllLines($_).LongLength } | Measure-Object -Sum).Sum
        $stage2ErrorPath = Join-Path $artifactsDir "selfhost-stage2-linux.err.log"
        $stage2TimeoutMilliseconds = 3600000
        $stage2Started = [DateTimeOffset]::Now
        $lastAnalysisHeartbeat = -1
        $lastEmissionHeartbeat = -1
        $lastReportedBytes = -1L
        Write-Host ("[linux-stage2 2/6] phase 1/2 analyze {0:N0} source files / {1:N0} lines" -f $sourcePaths.Count, $sourceLineCount)
        $stage2Process = Invoke-ProcessToFile `
            -FilePath $stage1Path `
            -ArgumentList (@("linux", "--jobs", $Jobs.ToString()) + $sourcePaths) `
            -OutputPath $stage2CandidateLlvmPath `
            -ErrorPath $stage2ErrorPath
        while (-not $stage2Process.HasExited) {
            Start-Sleep -Seconds 2
            $stage2Process.Refresh()
            if (([DateTimeOffset]::Now - $stage2Started).TotalMilliseconds -gt $stage2TimeoutMilliseconds) {
                Wait-VerificationProcess `
                    -Process $stage2Process `
                    -Description "Linux stage-2 LLVM emission" `
                    -TimeoutMilliseconds $stage2TimeoutMilliseconds `
                    -TimeoutStartedAt $stage2Started
            }
            $elapsed = [int]([DateTimeOffset]::Now - $stage2Started).TotalSeconds
            $cpuSeconds = [int]$stage2Process.TotalProcessorTime.TotalSeconds
            $workingMiB = [int]($stage2Process.WorkingSet64 / 1MB)
            $bytes = if (Test-Path $stage2CandidateLlvmPath) { (Get-Item $stage2CandidateLlvmPath).Length } else { 0L }
            if ($bytes -eq 0L) {
                $heartbeat = [Math]::Floor($elapsed / 60)
                if ($heartbeat -gt $lastAnalysisHeartbeat) {
                    Write-Host ("[linux-stage2 2/6] phase 1/2 analyze active ({0:N0}s elapsed, {1:N0}s CPU, {2:N0} MiB)" -f $elapsed, $cpuSeconds, $workingMiB)
                    $lastAnalysisHeartbeat = $heartbeat
                }
            } else {
                $emissionHeartbeat = [Math]::Floor($elapsed / 60)
                if ($bytes -ne $lastReportedBytes -or $emissionHeartbeat -gt $lastEmissionHeartbeat) {
                    $percent = [Math]::Min(100.0, 100.0 * $bytes / $expectedStage2Bytes)
                    Write-Host ("[linux-stage2 2/6] phase 2/2 LLVM {0:N0} bytes ({1:N1}%); {2:N0}s elapsed, {3:N0}s CPU, {4:N0} MiB" -f $bytes, $percent, $elapsed, $cpuSeconds, $workingMiB)
                    $lastReportedBytes = $bytes
                    $lastEmissionHeartbeat = $emissionHeartbeat
                }
            }
        }
        Assert-ProcessSucceeded $stage2Process $stage2ErrorPath "Linux stage-2 LLVM emission"
        & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $stage2CandidateLlvmPath
        & $llvmAsPath $stage2CandidateLlvmPath -o $stage2CandidateBitcodePath
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $clangPath --target=x86_64-unknown-linux-gnu -c $stage2CandidateLlvmPath -O1 -o $stage2CandidateObjectPath
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & wsl.exe -d $Distribution -- gcc (Convert-ToWslPath $stage2CandidateObjectPath) -pthread -o (Convert-ToWslPath $stage2CandidatePath)
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-Stage2ArtifactReceipt `
            -LlvmPath $stage2CandidateLlvmPath `
            -BitcodePath $stage2CandidateBitcodePath `
            -ExecutablePath $stage2CandidatePath `
            -AdditionalArtifacts @{ object = $stage2CandidateObjectPath } `
            -ReceiptPath $stage2CandidateArtifactReceiptPath
        [System.IO.File]::WriteAllText($stage2CandidateFingerprintPath, (Get-LinuxStage2InputFingerprint))
    }
    $stage2LlvmPath = $stage2CandidateLlvmPath
    $stage2BitcodePath = $stage2CandidateBitcodePath
    $stage2ObjectPath = $stage2CandidateObjectPath
    $stage2Path = $stage2CandidatePath
    $stage2WasRebuilt = $true
}
Write-Host "[linux-stage2 2/6] PASS $((Get-Item $stage2LlvmPath).Length) LLVM bytes."

$lateReferenceAllocas = foreach ($line in [System.IO.File]::ReadLines($stage2LlvmPath)) {
    if ($line -match '^define ') {
        $inEntryBlock = $false
    } elseif ($line -eq 'entry:') {
        $inEntryBlock = $true
    } elseif ($line -match '^[A-Za-z0-9_.]+:$') {
        $inEntryBlock = $false
    } elseif ($line -match '^  %callref\d+_arg\d+ = alloca ' -and -not $inEntryBlock) {
        $line
    }
}
if ($lateReferenceAllocas) {
    throw "Linux stage-2 LLVM contains reference-argument allocas outside function entry blocks:`n$($lateReferenceAllocas -join "`n")"
}
Write-Host "[linux-stage2 2/6] PASS reference-argument allocas are hoisted to function entry."

Write-Host "[linux-stage2 3/6] Compare stage-1 and stage-2 single-file LLVM."
$singleStage1Llvm = Join-Path $artifactsDir "linux-stage2-check-single-stage1.ll"
$singleStage2Llvm = Join-Path $artifactsDir "linux-stage2-check-single-stage2.ll"
$singleStage1Error = Join-Path $artifactsDir "linux-stage2-check-single-stage1.err"
$singleStage2Error = Join-Path $artifactsDir "linux-stage2-check-single-stage2.err"
$singleStage1 = Invoke-ProcessToFile $stage1Path @("linux", "--jobs", "2", $singleSource) $singleStage1Llvm $singleStage1Error
$singleStage2 = Invoke-ProcessToFile "wsl.exe" @("-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux", "--jobs", "2", (Convert-ToWslPath $singleSource)) $singleStage2Llvm $singleStage2Error
Assert-ProcessSucceeded $singleStage1 $singleStage1Error "Linux stage-1 single-file emission"
Assert-ProcessSucceeded $singleStage2 $singleStage2Error "Linux stage-2 single-file emission"
$singleStage1Hash = Get-NormalizedHash $singleStage1Llvm
$singleStage2Hash = Get-NormalizedHash $singleStage2Llvm
if ($singleStage1Hash -ne $singleStage2Hash) { throw "Linux single-file LLVM differs: stage1=$singleStage1Hash stage2=$singleStage2Hash" }
Write-Host "[linux-stage2 3/6] PASS $singleStage2Hash"

$subjectWhenStage1Llvm = Join-Path $artifactsDir "linux-stage2-check-subject-when-direct-result-stage1.ll"
$subjectWhenStage2Llvm = Join-Path $artifactsDir "linux-stage2-check-subject-when-direct-result-stage2.ll"
$subjectWhenStage1Error = Join-Path $artifactsDir "linux-stage2-check-subject-when-direct-result-stage1.err"
$subjectWhenStage2Error = Join-Path $artifactsDir "linux-stage2-check-subject-when-direct-result-stage2.err"
$subjectWhenStage1 = Invoke-ProcessToFile $stage1Path @("linux", $subjectWhenDirectResultSource) $subjectWhenStage1Llvm $subjectWhenStage1Error
$subjectWhenStage2 = Invoke-ProcessToFile "wsl.exe" @("-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux", (Convert-ToWslPath $subjectWhenDirectResultSource)) $subjectWhenStage2Llvm $subjectWhenStage2Error
Assert-ProcessSucceeded $subjectWhenStage1 $subjectWhenStage1Error "Linux stage-1 subject-when direct-result emission"
Assert-ProcessSucceeded $subjectWhenStage2 $subjectWhenStage2Error "Linux stage-2 subject-when direct-result emission"
$subjectWhenStage1Hash = Get-NormalizedHash $subjectWhenStage1Llvm
$subjectWhenStage2Hash = Get-NormalizedHash $subjectWhenStage2Llvm
if ($subjectWhenStage1Hash -ne $subjectWhenStage2Hash) { throw "Linux subject-when direct-result LLVM differs: stage1=$subjectWhenStage1Hash stage2=$subjectWhenStage2Hash" }
Write-Host "[linux-stage2 3/6] PASS subject-when-direct-result $subjectWhenStage2Hash"

Write-Host "[linux-stage2 4/6] Compare stage-1 and stage-2 imported multi-file LLVM."
$multiStage1Llvm = Join-Path $artifactsDir "linux-stage2-check-multi-stage1.ll"
$multiStage2Llvm = Join-Path $artifactsDir "linux-stage2-check-multi-stage2.ll"
$multiStage1Error = Join-Path $artifactsDir "linux-stage2-check-multi-stage1.err"
$multiStage2Error = Join-Path $artifactsDir "linux-stage2-check-multi-stage2.err"
$multiStage1 = Invoke-ProcessToFile $stage1Path @("linux", $multiLibrarySource, $multiMainSource) $multiStage1Llvm $multiStage1Error
$multiStage2 = Invoke-ProcessToFile "wsl.exe" @("-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux", (Convert-ToWslPath $multiLibrarySource), (Convert-ToWslPath $multiMainSource)) $multiStage2Llvm $multiStage2Error
Assert-ProcessSucceeded $multiStage1 $multiStage1Error "Linux stage-1 multi-file emission"
Assert-ProcessSucceeded $multiStage2 $multiStage2Error "Linux stage-2 multi-file emission"
$multiStage1Hash = Get-NormalizedHash $multiStage1Llvm
$multiStage2Hash = Get-NormalizedHash $multiStage2Llvm
if ($multiStage1Hash -ne $multiStage2Hash) { throw "Linux multi-file LLVM differs: stage1=$multiStage1Hash stage2=$multiStage2Hash" }
$codegenStage1Output = Join-Path $artifactsDir "linux-stage2-check-codegen-units-stage1.txt"
$codegenStage2Output = Join-Path $artifactsDir "linux-stage2-check-codegen-units-stage2.txt"
$codegenStage1Error = Join-Path $artifactsDir "linux-stage2-check-codegen-units-stage1.err"
$codegenStage2Error = Join-Path $artifactsDir "linux-stage2-check-codegen-units-stage2.err"
$codegenStage1 = Invoke-ProcessToFile $stage1Path @("llvm-codegen-units") $codegenStage1Output $codegenStage1Error
$codegenStage2 = Invoke-ProcessToFile "wsl.exe" @("-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "llvm-codegen-units") $codegenStage2Output $codegenStage2Error
Assert-ProcessSucceeded $codegenStage1 $codegenStage1Error "Linux stage-1 canonical codegen units"
Assert-ProcessSucceeded $codegenStage2 $codegenStage2Error "Linux stage-2 canonical codegen units"
$codegenStage1Text = ([System.IO.File]::ReadAllText($codegenStage1Output)).Trim()
$codegenStage2Text = ([System.IO.File]::ReadAllText($codegenStage2Output)).Trim()
if ($codegenStage1Text -ne "codegen units = 0,2,6") { throw "Linux stage-1 canonical codegen units differed: $codegenStage1Text" }
if ($codegenStage2Text -ne $codegenStage1Text) { throw "Linux stage-2 canonical codegen units differed: $codegenStage2Text" }
$setStage1Llvm = Join-Path $artifactsDir "linux-stage2-check-set-stage1.ll"
$setStage2Llvm = Join-Path $artifactsDir "linux-stage2-check-set-stage2.ll"
$setStage1Error = Join-Path $artifactsDir "linux-stage2-check-set-stage1.err"
$setStage2Error = Join-Path $artifactsDir "linux-stage2-check-set-stage2.err"
$setStage1 = Invoke-ProcessToFile $stage1Path @("linux", $setKeyOnlySource) $setStage1Llvm $setStage1Error
$setStage2 = Invoke-ProcessToFile "wsl.exe" @("-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux", (Convert-ToWslPath $setKeyOnlySource)) $setStage2Llvm $setStage2Error
Assert-ProcessSucceeded $setStage1 $setStage1Error "Linux stage-1 Set intrinsic emission"
Assert-ProcessSucceeded $setStage2 $setStage2Error "Linux stage-2 Set intrinsic emission"
$setStage1Hash = Get-NormalizedHash $setStage1Llvm
$setStage2Hash = Get-NormalizedHash $setStage2Llvm
if ($setStage1Hash -ne $setStage2Hash) { throw "Linux Set intrinsic LLVM differs: stage1=$setStage1Hash stage2=$setStage2Hash" }
$setStage2Text = [System.IO.File]::ReadAllText($setStage2Llvm)
foreach ($forbiddenPattern in ([System.IO.File]::ReadAllLines($setKeyOnlyForbiddenPath) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    if ($setStage2Text.Contains($forbiddenPattern.Trim(), [System.StringComparison]::Ordinal)) {
        throw "Linux stage-2 Set intrinsic LLVM contains forbidden text '$($forbiddenPattern.Trim())'"
    }
}
Write-Host "[linux-stage2 4/6] PASS $multiStage2Hash"

Write-Host "[linux-stage2 5/6] Assemble, link, and execute both Linux stage-2 products."
Build-And-ExecuteLinuxLlvm $singleStage2Llvm "linux-stage2-check-single" "stage2-single-ok"
Build-And-ExecuteLinuxLlvm $multiStage2Llvm "linux-stage2-check-multi" "stage2-multi-ok"
Build-And-ExecuteLinuxLlvm $subjectWhenStage2Llvm "linux-stage2-check-subject-when-direct-result" "6,3,inclusive"
$setExpected = [System.IO.File]::ReadAllText($setKeyOnlyExpectedPath).Replace("`r`n", "`n").TrimEnd("`n")
Build-And-ExecuteLinuxLlvm $setStage2Llvm "linux-stage2-check-set" $setExpected
$resultPropagationExecutable = Join-Path $artifactsDir "linux-stage2-check-result-propagation-control"
$resultPropagationLlvm = $resultPropagationExecutable + ".ll"
$resultPropagationOutput = Join-Path $artifactsDir "linux-stage2-check-result-propagation-control.stdout.txt"
$resultPropagationError = Join-Path $artifactsDir "linux-stage2-check-result-propagation-control.stderr.txt"
Remove-Item -LiteralPath $resultPropagationExecutable, $resultPropagationLlvm -ErrorAction SilentlyContinue
$resultPropagationProcess = Invoke-ProcessToFile "wsl.exe" @(
    "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path),
    "build", (Convert-ToWslPath $resultPropagationControlSource),
    "-o", (Convert-ToWslPath $resultPropagationExecutable),
    "--target", "linux-x64",
    "--stdlib", (Convert-ToWslPath $stdlibRoot),
    "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
    "-O1", "--keep-temps"
) $resultPropagationOutput $resultPropagationError
Assert-ProcessSucceeded $resultPropagationProcess $resultPropagationError "Linux stage-2 Result propagation control-order native build"
if (-not (Test-Path $resultPropagationLlvm) -or -not (Test-Path $resultPropagationExecutable)) {
    throw "Linux stage-2 Result propagation control-order build did not retain LLVM and executable artifacts"
}
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $resultPropagationLlvm
& $llvmAsPath $resultPropagationLlvm -o ($resultPropagationExecutable + ".bc")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$resultPropagationActual = (& wsl.exe -d $Distribution -- (Convert-ToWslPath $resultPropagationExecutable) | Out-String).TrimEnd("`r", "`n")
if ($LASTEXITCODE -ne 0 -or $resultPropagationActual -ne "quic-endpoint=ok") {
    throw "Linux stage-2 Result propagation control-order execution failed: expected 'quic-endpoint=ok', actual '$resultPropagationActual'"
}
& (Join-Path $PSScriptRoot "verify-native-socket-timeouts.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Platform linux `
    -Distribution $Distribution `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-mutable-parameter-indexing-batch.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Platform linux `
    -Distribution $Distribution `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-interpolation-reference-arguments.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Platform linux `
    -Distribution $Distribution `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-projected-reference-places.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Platform linux `
    -Distribution $Distribution `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-linux-process-child-lifecycle.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Distribution $Distribution `
    -LlvmHome (Join-Path $repoRoot ".tools\llvm-22.1.8") `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-quic-endpoint-ownership-linux.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Distribution $Distribution `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-exact-fixture-batch.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Platform linux `
    -Distribution $Distribution `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "[linux-stage2 5/6] PASS Linux stage-2 products, Set intrinsics, Result propagation, and process Child lifecycle execute."

Write-Host "[linux-stage2 6/6] Enforce production ownership diagnostics E17 through E23."
foreach ($conflict in @(
    @($borrowConflictSource, "single"),
    @($borrowUnionConflictSource, "union"),
    @($borrowAliasConflictSource, "alias"),
    @($borrowAggregateConflictSource, "aggregate"),
    @($borrowProjectionConflictSource, "projection")
)) {
    $stage1DiagnosticOutput = Join-Path $artifactsDir "linux-stage2-check-borrow-$($conflict[1])-stage1.txt"
    $stage1DiagnosticError = Join-Path $artifactsDir "linux-stage2-check-borrow-$($conflict[1])-stage1.err"
    $stage1Diagnostic = Invoke-ProcessToFile $stage1Path @("linux", $conflict[0], $borrowSourceRuntime) $stage1DiagnosticOutput $stage1DiagnosticError
    $stage2DiagnosticOutput = Join-Path $artifactsDir "linux-stage2-check-borrow-$($conflict[1])-stage2.txt"
    $stage2DiagnosticError = Join-Path $artifactsDir "linux-stage2-check-borrow-$($conflict[1])-stage2.err"
    $stage2Diagnostic = Invoke-ProcessToFile "wsl.exe" @(
        "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux",
        (Convert-ToWslPath $conflict[0]), (Convert-ToWslPath $borrowSourceRuntime)
    ) $stage2DiagnosticOutput $stage2DiagnosticError
    foreach ($candidate in @(
        @($stage1Diagnostic, $stage1DiagnosticOutput, "stage1"),
        @($stage2Diagnostic, $stage2DiagnosticOutput, "stage2")
    )) {
        Wait-VerificationProcess $candidate[0] "$($candidate[2]) borrow-conflict diagnostic"
        $candidate[0].Refresh()
        if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[2]) accepted a $($conflict[1])-origin move with a live borrowed Text view" }
        $diagnosticText = [System.IO.File]::ReadAllText($candidate[1])
        if ($diagnosticText -notmatch 'error\[E21\].*origin moved while a borrowed Text view is still live') {
            throw "$($candidate[2]) did not emit ownership diagnostic E21 for $($conflict[1]) origin: '$diagnosticText'"
        }
        if ($diagnosticText -match '^target (datalayout|triple)') {
            throw "$($candidate[2]) began LLVM emission before rejecting $($conflict[1])-origin diagnostic E21"
        }
    }
}
$stage1PartialMoveOutput = Join-Path $artifactsDir "linux-stage2-check-partial-move-stage1.txt"
$stage1PartialMoveError = Join-Path $artifactsDir "linux-stage2-check-partial-move-stage1.err"
$stage1PartialMove = Invoke-ProcessToFile $stage1Path @("linux", $partialMoveConflictSource) $stage1PartialMoveOutput $stage1PartialMoveError
$stage2PartialMoveOutput = Join-Path $artifactsDir "linux-stage2-check-partial-move-stage2.txt"
$stage2PartialMoveError = Join-Path $artifactsDir "linux-stage2-check-partial-move-stage2.err"
$stage2PartialMove = Invoke-ProcessToFile "wsl.exe" @(
    "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux",
    (Convert-ToWslPath $partialMoveConflictSource)
) $stage2PartialMoveOutput $stage2PartialMoveError
foreach ($candidate in @(
    @($stage1PartialMove, $stage1PartialMoveOutput, "stage1"),
    @($stage2PartialMove, $stage2PartialMoveOutput, "stage2")
)) {
    Wait-VerificationProcess $candidate[0] "$($candidate[2]) partial-move diagnostic"
    $candidate[0].Refresh()
    if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[2]) accepted a reachable whole-owner use after a partial move" }
    $diagnosticText = [System.IO.File]::ReadAllText($candidate[1])
    if ($diagnosticText -notmatch 'error\[E17\].*use of a partially moved value') {
        throw "$($candidate[2]) did not emit ownership diagnostic E17: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($candidate[2]) began LLVM emission before rejecting partial-move diagnostic E17"
    }
}
$stage1BranchPartialMoveOutput = Join-Path $artifactsDir "linux-stage2-check-branch-partial-move-stage1.txt"
$stage1BranchPartialMoveError = Join-Path $artifactsDir "linux-stage2-check-branch-partial-move-stage1.err"
$stage1BranchPartialMove = Invoke-ProcessToFile $stage1Path @("linux", $branchPartialMoveConflictSource) $stage1BranchPartialMoveOutput $stage1BranchPartialMoveError
$stage2BranchPartialMoveOutput = Join-Path $artifactsDir "linux-stage2-check-branch-partial-move-stage2.txt"
$stage2BranchPartialMoveError = Join-Path $artifactsDir "linux-stage2-check-branch-partial-move-stage2.err"
$stage2BranchPartialMove = Invoke-ProcessToFile "wsl.exe" @(
    "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux",
    (Convert-ToWslPath $branchPartialMoveConflictSource)
) $stage2BranchPartialMoveOutput $stage2BranchPartialMoveError
foreach ($candidate in @(
    @($stage1BranchPartialMove, $stage1BranchPartialMoveOutput, "stage1"),
    @($stage2BranchPartialMove, $stage2BranchPartialMoveOutput, "stage2")
)) {
    Wait-VerificationProcess $candidate[0] "$($candidate[2]) branch-partial-move diagnostic"
    $candidate[0].Refresh()
    if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[2]) accepted a branch that exits with a partial move" }
    $diagnosticText = [System.IO.File]::ReadAllText($candidate[1])
    if ($diagnosticText -notmatch 'error\[E20\].*partial move exits a branch or loop without reinitialization') {
        throw "$($candidate[2]) did not emit ownership diagnostic E20: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($candidate[2]) began LLVM emission before rejecting branch-partial-move diagnostic E20"
    }
}
$stage1ParallelCaptureOutput = Join-Path $artifactsDir "linux-stage2-check-parallel-mutable-capture-stage1.txt"
$stage1ParallelCaptureError = Join-Path $artifactsDir "linux-stage2-check-parallel-mutable-capture-stage1.err"
$stage1ParallelCapture = Invoke-ProcessToFile $stage1Path @("linux", $parallelMutableCaptureSource) $stage1ParallelCaptureOutput $stage1ParallelCaptureError
$stage2ParallelCaptureOutput = Join-Path $artifactsDir "linux-stage2-check-parallel-mutable-capture-stage2.txt"
$stage2ParallelCaptureError = Join-Path $artifactsDir "linux-stage2-check-parallel-mutable-capture-stage2.err"
$stage2ParallelCapture = Invoke-ProcessToFile "wsl.exe" @(
    "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux",
    (Convert-ToWslPath $parallelMutableCaptureSource)
) $stage2ParallelCaptureOutput $stage2ParallelCaptureError
foreach ($candidate in @(
    @($stage1ParallelCapture, $stage1ParallelCaptureOutput, "stage1"),
    @($stage2ParallelCapture, $stage2ParallelCaptureOutput, "stage2")
)) {
    Wait-VerificationProcess $candidate[0] "$($candidate[2]) mutable parallel-capture diagnostic"
    $candidate[0].Refresh()
    if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[2]) accepted a transitive mutable parallel capture" }
    $diagnosticText = [System.IO.File]::ReadAllText($candidate[1])
    if ($diagnosticText -notmatch 'error\[E18\].*mutable binding captured by a parallel callback') {
        throw "$($candidate[2]) did not emit ownership diagnostic E18: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($candidate[2]) began LLVM emission before rejecting parallel-capture diagnostic E18"
    }
}
$stage1NonSendableCaptureOutput = Join-Path $artifactsDir "linux-stage2-check-parallel-nonsendable-capture-stage1.txt"
$stage1NonSendableCaptureError = Join-Path $artifactsDir "linux-stage2-check-parallel-nonsendable-capture-stage1.err"
$stage1NonSendableCapture = Invoke-ProcessToFile $stage1Path @("linux", $parallelNonSendableCaptureSource) $stage1NonSendableCaptureOutput $stage1NonSendableCaptureError
$stage2NonSendableCaptureOutput = Join-Path $artifactsDir "linux-stage2-check-parallel-nonsendable-capture-stage2.txt"
$stage2NonSendableCaptureError = Join-Path $artifactsDir "linux-stage2-check-parallel-nonsendable-capture-stage2.err"
$stage2NonSendableCapture = Invoke-ProcessToFile "wsl.exe" @(
    "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux",
    (Convert-ToWslPath $parallelNonSendableCaptureSource)
) $stage2NonSendableCaptureOutput $stage2NonSendableCaptureError
foreach ($candidate in @(
    @($stage1NonSendableCapture, $stage1NonSendableCaptureOutput, "stage1"),
    @($stage2NonSendableCapture, $stage2NonSendableCaptureOutput, "stage2")
)) {
    Wait-VerificationProcess $candidate[0] "$($candidate[2]) non-sendable parallel-capture diagnostic"
    $candidate[0].Refresh()
    if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[2]) accepted a transitive non-sendable parallel capture" }
    $diagnosticText = [System.IO.File]::ReadAllText($candidate[1])
    if ($diagnosticText -notmatch 'error\[E19\].*non-sendable binding captured by a parallel callback') {
        throw "$($candidate[2]) did not emit ownership diagnostic E19: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($candidate[2]) began LLVM emission before rejecting parallel-capture diagnostic E19"
    }
}
$stage1ReferenceOutput = Join-Path $artifactsDir "linux-stage2-check-reference-temporary-stage1.txt"
$stage1ReferenceError = Join-Path $artifactsDir "linux-stage2-check-reference-temporary-stage1.err"
$stage1Reference = Invoke-ProcessToFile $stage1Path @("linux", $referenceTemporarySource) $stage1ReferenceOutput $stage1ReferenceError
$stage2ReferenceOutput = Join-Path $artifactsDir "linux-stage2-check-reference-temporary-stage2.txt"
$stage2ReferenceError = Join-Path $artifactsDir "linux-stage2-check-reference-temporary-stage2.err"
$stage2Reference = Invoke-ProcessToFile "wsl.exe" @(
    "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux", (Convert-ToWslPath $referenceTemporarySource)
) $stage2ReferenceOutput $stage2ReferenceError
foreach ($candidate in @(
    @($stage1Reference, $stage1ReferenceOutput, "stage1"),
    @($stage2Reference, $stage2ReferenceOutput, "stage2")
)) {
    Wait-VerificationProcess $candidate[0] "$($candidate[2]) temporary-reference diagnostic"
    $candidate[0].Refresh()
    if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[2]) accepted a temporary readonly-reference argument" }
    $diagnosticText = [System.IO.File]::ReadAllText($candidate[1])
    if ($diagnosticText -notmatch 'error\[E22\].*requires an addressable owner or reference; literals and temporary values cannot be borrowed') {
        throw "$($candidate[2]) did not emit ownership diagnostic E22: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($candidate[2]) began LLVM emission before rejecting readonly-reference diagnostic E22"
    }
}
foreach ($referenceConflict in @(
    @($referenceLivenessSource, "mutation"),
    @($referenceOwnerMoveSource, "move"),
    @($referenceLoopContinueSource, "loop-continue"),
    @($referenceStoredStructSource, "stored-struct"),
    @($referenceStoredEnumSource, "stored-enum"),
    @($referenceStoredArraySource, "stored-array")
)) {
    $stage1ReferenceOutput = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceConflict[1])-stage1.txt"
    $stage1ReferenceError = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceConflict[1])-stage1.err"
    $stage1Reference = Invoke-ProcessToFile $stage1Path @("linux", $referenceConflict[0]) $stage1ReferenceOutput $stage1ReferenceError
    $stage2ReferenceOutput = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceConflict[1])-stage2.txt"
    $stage2ReferenceError = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceConflict[1])-stage2.err"
    $stage2Reference = Invoke-ProcessToFile "wsl.exe" @(
        "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux", (Convert-ToWslPath $referenceConflict[0])
    ) $stage2ReferenceOutput $stage2ReferenceError
    foreach ($candidate in @(
        @($stage1Reference, $stage1ReferenceOutput, "stage1"),
        @($stage2Reference, $stage2ReferenceOutput, "stage2")
    )) {
        Wait-VerificationProcess $candidate[0] "$($candidate[2]) $($referenceConflict[1])-reference diagnostic"
        $candidate[0].Refresh()
        if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[2]) accepted owner $($referenceConflict[1]) with a live readonly reference" }
        $diagnosticText = [System.IO.File]::ReadAllText($candidate[1])
        if ($diagnosticText -notmatch 'error\[E23\].*owner mutation conflicts with a live readonly reference') {
            throw "$($candidate[2]) did not emit ownership diagnostic E23 for owner $($referenceConflict[1]): '$diagnosticText'"
        }
        if ($diagnosticText -match '^target (datalayout|triple)') {
            throw "$($candidate[2]) began LLVM emission before rejecting readonly-reference owner $($referenceConflict[1]) diagnostic E23"
        }
    }
}

foreach ($referenceEscape in @(
    @($referenceAggregateEscapeSource, "aggregate-escape"),
    @($referenceEnumEscapeSource, "enum-escape"),
    @($referenceArrayEscapeSource, "array-escape")
)) {
    $stage1AggregateEscapeOutput = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceEscape[1])-stage1.txt"
    $stage1AggregateEscapeError = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceEscape[1])-stage1.err"
    $stage1AggregateEscape = Invoke-ProcessToFile $stage1Path @("linux", $referenceEscape[0]) $stage1AggregateEscapeOutput $stage1AggregateEscapeError
    $stage2AggregateEscapeOutput = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceEscape[1])-stage2.txt"
    $stage2AggregateEscapeError = Join-Path $artifactsDir "linux-stage2-check-reference-$($referenceEscape[1])-stage2.err"
    $stage2AggregateEscape = Invoke-ProcessToFile "wsl.exe" @(
        "-d", $Distribution, "--", (Convert-ToWslPath $stage2Path), "linux", (Convert-ToWslPath $referenceEscape[0])
    ) $stage2AggregateEscapeOutput $stage2AggregateEscapeError
    foreach ($candidate in @(
        @($stage1AggregateEscape, $stage1AggregateEscapeOutput, $stage1AggregateEscapeError, "stage-1"),
        @($stage2AggregateEscape, $stage2AggregateEscapeOutput, $stage2AggregateEscapeError, "stage-2")
    )) {
        Wait-VerificationProcess $candidate[0] "$($candidate[3]) $($referenceEscape[1])-escape diagnostic"
        $candidate[0].Refresh()
        $diagnosticText = (Get-Content $candidate[1] -Raw) + (Get-Content $candidate[2] -Raw)
        if ($candidate[0].ExitCode -eq 0) { throw "$($candidate[3]) accepted returned $($referenceEscape[1]) containing a callee-owned readonly reference" }
        if ($diagnosticText -notmatch 'error\[E22\]') {
            throw "$($candidate[3]) did not emit ownership diagnostic E22 for $($referenceEscape[1]): '$diagnosticText'"
        }
        if ($diagnosticText -match 'target triple') {
            throw "$($candidate[3]) began LLVM emission before rejecting $($referenceEscape[1]) diagnostic E22"
        }
    }
}
Write-Host "[linux-stage2 6/6] PASS E17-E23 ownership violations block LLVM emission in stage-1 and stage-2."
& (Join-Path $PSScriptRoot "verify-selfhost-unresolved-call-diagnostic.ps1") `
    -Compiler $stage1Path `
    -Label "linux-stage1" `
    -Target linux `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-result-propagation-diagnostics.ps1") `
    -Compiler $stage1Path `
    -Label "linux-stage1" `
    -Target linux `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-private-field-diagnostics.ps1") `
    -Compiler $stage1Path `
    -Label "linux-stage1" `
    -Target linux `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-unresolved-call-diagnostic.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Target linux `
    -Distribution $Distribution `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-result-propagation-diagnostics.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Target linux `
    -Distribution $Distribution `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-private-field-diagnostics.ps1") `
    -Compiler $stage2Path `
    -Label "linux-stage2" `
    -Target linux `
    -Distribution $Distribution `
    -RepositoryRoot $repoRoot
Write-Host "[linux-stage2 6/6] PASS unresolved calls, invalid Result propagation, and private-field access remain blocked before LLVM in stage-1 and stage-2."
if ($stage2WasRebuilt) {
    if (-not (Test-Stage2ArtifactReceipt `
            -LlvmPath $stage2LlvmPath `
            -BitcodePath $stage2BitcodePath `
            -ExecutablePath $stage2Path `
            -AdditionalArtifacts @{ object = $stage2ObjectPath } `
            -ReceiptPath $stage2CandidateArtifactReceiptPath)) {
        throw "Linux Stage2 candidate artifacts differ from their completion receipt"
    }
    Assert-InputFingerprintStable `
        -ExpectedFingerprint ([System.IO.File]::ReadAllText($stage2CandidateFingerprintPath)) `
        -CurrentFingerprint (Get-LinuxStage2InputFingerprint) `
        -Phase "Linux Stage2"
    Move-Item -LiteralPath $stage2LlvmPath -Destination $publishedStage2LlvmPath -Force
    Move-Item -LiteralPath $stage2BitcodePath -Destination $publishedStage2BitcodePath -Force
    Move-Item -LiteralPath $stage2ObjectPath -Destination $publishedStage2ObjectPath -Force
    Move-Item -LiteralPath $stage2Path -Destination $publishedStage2Path -Force
    Write-Stage2ArtifactReceipt `
        -LlvmPath $publishedStage2LlvmPath `
        -BitcodePath $publishedStage2BitcodePath `
        -ExecutablePath $publishedStage2Path `
        -AdditionalArtifacts @{ object = $publishedStage2ObjectPath } `
        -ReceiptPath $stage2ArtifactReceiptPath
    Move-Item -LiteralPath $stage2CandidateFingerprintPath -Destination $stage2FingerprintPath -Force
    Remove-Item -LiteralPath $stage2CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
    Write-Host "[linux-stage2 promotion] PASS input fingerprint and output receipts published last."
}
}
finally {
    Release-SelfHostVerificationLock $selfHostVerificationLock
}
