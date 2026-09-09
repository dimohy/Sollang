param(
    [string]$Distribution = "Ubuntu",
    [ValidateRange(1, 64)]
    [int]$Jobs = 4,
    [switch]$RebuildStage2
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "selfhost-verification-lock.ps1")
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
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
$runtimeManifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
$slgSeedPath = Join-Path $repoRoot "artifacts\incremental-selfhost\selfhost-slg-seed.exe"
$stage2LlvmPath = Join-Path $artifactsDir "selfhost-stage2-linux.ll"
$stage2BitcodePath = Join-Path $artifactsDir "selfhost-stage2-linux.bc"
$stage2ObjectPath = Join-Path $artifactsDir "selfhost-stage2-linux.o"
$stage2Path = Join-Path $artifactsDir "selfhost-stage2-linux"
$stage2FingerprintPath = Join-Path $artifactsDir "selfhost-stage2-linux.inputs.sha256"
$stage2ArtifactReceiptPath = Join-Path $artifactsDir "selfhost-stage2-linux.outputs.sha256"
$stage3LlvmPath = Join-Path $artifactsDir "selfhost-stage3-linux.ll"
$stage3BitcodePath = Join-Path $artifactsDir "selfhost-stage3-linux.bc"
$stage3ObjectPath = Join-Path $artifactsDir "selfhost-stage3-linux.o"
$stage3Path = Join-Path $artifactsDir "selfhost-stage3-linux"
$stage3FingerprintPath = Join-Path $artifactsDir "selfhost-stage3-linux.inputs.sha256"
$stage3ArtifactReceiptPath = Join-Path $artifactsDir "selfhost-stage3-linux.outputs.sha256"
$stage3ErrorPath = Join-Path $artifactsDir "selfhost-stage3-linux.err.log"
$stdlibRoot = Join-Path $repoRoot "stdlib"
$resultPropagationControlSource = Join-Path $repoRoot "examples\regression\1017-quic-friendly-ipv4-endpoints.slg"
$setKeyOnlySource = Join-Path $repoRoot "examples\regression\854-set-key-only.slg"
$setKeyOnlyExpectedPath = Join-Path $repoRoot "examples\regression\expected\854-set-key-only.stdout.txt"
$setKeyOnlyForbiddenPath = Join-Path $repoRoot "examples\regression\expected\854-set-key-only.selfhost.llvm.not-contains.txt"
$socketNoDelaySource = Join-Path $repoRoot "examples\regression\1141-socket-no-delay-instance.slg"
$socketNoDelayExpectedPath = Join-Path $repoRoot "examples\regression\expected\1141-socket-no-delay-instance.stdout.txt"
$socketNoDelayContainsPath = Join-Path $repoRoot "examples\regression\expected\1141-socket-no-delay-instance.linux-x64.llvm.contains.txt"
$socketNoDelayRegexCountsPath = Join-Path $repoRoot "examples\regression\expected\1141-socket-no-delay-instance.llvm.regex-counts.txt"
$llvmAsPath = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\llvm-as.exe"
$clangPath = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\clang.exe"
& (Join-Path $PSScriptRoot "verify-verification-process-contract.ps1") `
    -IncludeWsl `
    -Distribution $Distribution

function Convert-ToWslPath {
    param([string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Get-NormalizedHash {
    param([string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
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
    return Get-ContentFingerprint (@($slgSeedPath, $manifestPath, $runtimeManifestPath) + $sourcePaths)
}

function Get-LinuxStage3InputFingerprint {
    $stage2ExecutableHash = (Get-FileHash -LiteralPath $stage2Path -Algorithm SHA256).Hash
    $sourceFingerprint = Get-ContentFingerprint $sourcePaths
    $text = "linux`0$stage2ExecutableHash`0$sourceFingerprint"
    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::UTF8.GetBytes($text)))
}

if ($RebuildStage2) {
    Write-Host "[linux-stage3 1/3] Rebuild and verify Linux stage 2."
    & (Join-Path $PSScriptRoot "verify-selfhost-stage2-linux.ps1") -Distribution $Distribution -Jobs $Jobs -Rebuild
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[linux-stage3 1/3] Reuse the existing Linux stage 2."
}

$sourcePaths = Get-Content $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }
$sourcePaths += Get-Content $runtimeManifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }

if (-not (Test-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -AdditionalArtifacts @{ object = $stage2ObjectPath } `
        -ReceiptPath $stage2ArtifactReceiptPath)) {
    throw "Linux stage 2 is missing, empty, or differs from its output receipt; rerun with -RebuildStage2"
}
if (-not (Test-Path -LiteralPath $stage2FingerprintPath) -or
    [System.IO.File]::ReadAllText($stage2FingerprintPath).Trim() -cne (Get-LinuxStage2InputFingerprint)) {
    throw "Linux stage 2 input fingerprint differs; rerun with -RebuildStage2"
}
Write-Host "[linux-stage3 1/3] PASS current Linux stage 2."

Write-Host "[linux-stage3 2/3] Generate Linux stage 3 from the stage-2 compiler."
$publishedStage3LlvmPath = $stage3LlvmPath
$publishedStage3BitcodePath = $stage3BitcodePath
$publishedStage3ObjectPath = $stage3ObjectPath
$publishedStage3Path = $stage3Path
$stage3CandidateLlvmPath = Get-CandidateArtifactPath $stage3LlvmPath
$stage3CandidateBitcodePath = Get-CandidateArtifactPath $stage3BitcodePath
$stage3CandidateObjectPath = Get-CandidateArtifactPath $stage3ObjectPath
$stage3CandidatePath = "$stage3Path.candidate"
$stage3CandidateFingerprintPath = Get-CandidateArtifactPath $stage3FingerprintPath
$stage3CandidateArtifactReceiptPath = Get-CandidateArtifactPath $stage3ArtifactReceiptPath
Remove-Item -LiteralPath $stage3CandidateLlvmPath, $stage3CandidateBitcodePath, $stage3CandidateObjectPath, $stage3CandidatePath, $stage3ErrorPath, $stage3CandidateFingerprintPath, $stage3CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
$stage3Arguments = @(
    "-d", $Distribution, "--",
    (Convert-ToWslPath $stage2Path), "linux", "--jobs", $Jobs.ToString()
)
$stage3Arguments += $sourcePaths | ForEach-Object { Convert-ToWslPath $_ }
$process = Start-Process `
    -FilePath "wsl.exe" `
    -ArgumentList $stage3Arguments `
    -RedirectStandardOutput $stage3CandidateLlvmPath `
    -RedirectStandardError $stage3ErrorPath `
    -PassThru `
    -WindowStyle Hidden
$stage3TimeoutMilliseconds = 3600000
$stage3StartedAt = [DateTimeOffset]::Now
$expectedStage3Bytes = (Get-Item -LiteralPath $stage2LlvmPath).Length
while (-not $process.WaitForExit(30000)) {
    $elapsed = [DateTimeOffset]::Now - $stage3StartedAt
    $outputBytes = if (Test-Path -LiteralPath $stage3CandidateLlvmPath) { (Get-Item -LiteralPath $stage3CandidateLlvmPath).Length } else { 0 }
    $errorBytes = if (Test-Path -LiteralPath $stage3ErrorPath) { (Get-Item -LiteralPath $stage3ErrorPath).Length } else { 0 }
    $tree = Get-VerificationProcessTreeSnapshot -RootProcessId $process.Id
    if ($outputBytes -eq 0) {
        Write-Host ("[linux-stage3 2/3] phase 1/2 analyze active ({0:N0}s elapsed; host-visible tree CPU {1:N0}s, memory {2:N0} MiB, processes {3:N0}; errors {4:N0} bytes)." -f `
            $elapsed.TotalSeconds, $tree.CpuSeconds, $tree.WorkingMiB, $tree.ProcessCount, $errorBytes)
    } else {
        $percent = if ($expectedStage3Bytes -gt 0) { [Math]::Min(100.0, 100.0 * $outputBytes / $expectedStage3Bytes) } else { 0.0 }
        Write-Host ("[linux-stage3 2/3] phase 2/2 LLVM {0:N0}/{1:N0} bytes ({2:N1}%); {3:N0}s elapsed; host-visible tree CPU {4:N0}s, memory {5:N0} MiB, processes {6:N0}; errors {7:N0} bytes." -f `
            $outputBytes, $expectedStage3Bytes, $percent, $elapsed.TotalSeconds, $tree.CpuSeconds, $tree.WorkingMiB, $tree.ProcessCount, $errorBytes)
    }
    if ($elapsed.TotalMilliseconds -gt $stage3TimeoutMilliseconds) {
        Wait-VerificationProcess `
            -Process $process `
            -Description "Linux stage-3 LLVM emission" `
            -TimeoutMilliseconds $stage3TimeoutMilliseconds `
            -TimeoutStartedAt $stage3StartedAt
    }
}
$process.Refresh()
if ($process.ExitCode -ne 0) {
    $details = if (Test-Path $stage3ErrorPath) { Get-Content $stage3ErrorPath -Raw } else { "" }
    throw "Linux stage-3 LLVM emission failed with exit code $($process.ExitCode).`n$details"
}
Write-Host "[linux-stage3 2/3] PASS $((Get-Item $stage3CandidateLlvmPath).Length) LLVM bytes."

Write-Host "[linux-stage3 3/3] Verify LLVM structure, compare the fixed point, and link the native compiler."
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $stage3CandidateLlvmPath
& $llvmAsPath $stage3CandidateLlvmPath -o $stage3CandidateBitcodePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$stage2Hash = Get-NormalizedHash $stage2LlvmPath
$stage3Hash = Get-NormalizedHash $stage3CandidateLlvmPath
if ($stage2Hash -ne $stage3Hash) {
    throw "Linux compiler fixed point differs: stage2=$stage2Hash stage3=$stage3Hash. Do not promote either artifact. Review the LLVM semantic diff, regenerate Linux Stage2 from the verified SLG seed, and rerun Linux Stage3."
}
& $clangPath --target=x86_64-unknown-linux-gnu -c $stage3CandidateLlvmPath -O1 -o $stage3CandidateObjectPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& wsl.exe -d $Distribution -- gcc (Convert-ToWslPath $stage3CandidateObjectPath) -pthread -o (Convert-ToWslPath $stage3CandidatePath)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& wsl.exe -d $Distribution -- test -x (Convert-ToWslPath $stage3CandidatePath)
if ($LASTEXITCODE -ne 0) { throw "Linux stage-3 compiler is not executable" }
Write-Stage2ArtifactReceipt `
    -LlvmPath $stage3CandidateLlvmPath `
    -BitcodePath $stage3CandidateBitcodePath `
    -ExecutablePath $stage3CandidatePath `
    -AdditionalArtifacts @{ object = $stage3CandidateObjectPath } `
    -ReceiptPath $stage3CandidateArtifactReceiptPath
[System.IO.File]::WriteAllText($stage3CandidateFingerprintPath, (Get-LinuxStage3InputFingerprint))
$stage3LlvmPath = $stage3CandidateLlvmPath
$stage3BitcodePath = $stage3CandidateBitcodePath
$stage3ObjectPath = $stage3CandidateObjectPath
$stage3Path = $stage3CandidatePath
$resultPropagationExecutable = Join-Path $artifactsDir "linux-stage3-check-result-propagation-control"
& wsl.exe -d $Distribution -- (Convert-ToWslPath $stage3Path) `
    build (Convert-ToWslPath $resultPropagationControlSource) `
    -o (Convert-ToWslPath $resultPropagationExecutable) `
    --target linux-x64 `
    --stdlib (Convert-ToWslPath $stdlibRoot) `
    --jobs $Jobs `
    -O1 --keep-temps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath ($resultPropagationExecutable + ".ll")
& $llvmAsPath ($resultPropagationExecutable + ".ll") -o ($resultPropagationExecutable + ".bc")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$resultPropagationActual = (& wsl.exe -d $Distribution -- (Convert-ToWslPath $resultPropagationExecutable) | Out-String).TrimEnd("`r", "`n")
if ($LASTEXITCODE -ne 0 -or $resultPropagationActual -ne "quic-endpoint=ok") {
    throw "Linux stage-3 Result propagation control-order execution failed: expected 'quic-endpoint=ok', actual '$resultPropagationActual'"
}
$setExecutable = Join-Path $artifactsDir "linux-stage3-check-set"
& wsl.exe -d $Distribution -- (Convert-ToWslPath $stage3Path) `
    build (Convert-ToWslPath $setKeyOnlySource) `
    -o (Convert-ToWslPath $setExecutable) `
    --target linux-x64 `
    --stdlib (Convert-ToWslPath $stdlibRoot) `
    --jobs $Jobs `
    -O1 --keep-temps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$setLlvm = $setExecutable + ".ll"
$missingSetArtifact = -not (Test-Path -LiteralPath $setExecutable -PathType Leaf)
if (-not $missingSetArtifact) {
    $missingSetArtifact = -not (Test-Path -LiteralPath $setLlvm -PathType Leaf)
}
if (-not $missingSetArtifact) {
    $missingSetArtifact = (Get-Item -LiteralPath $setLlvm).Length -eq 0
}
if ($missingSetArtifact) {
    throw "Linux stage-3 Set intrinsic build did not retain executable and LLVM artifacts"
}
$setLlvmText = [System.IO.File]::ReadAllText($setLlvm)
foreach ($forbiddenPattern in ([System.IO.File]::ReadAllLines($setKeyOnlyForbiddenPath) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    if ($setLlvmText.Contains($forbiddenPattern.Trim(), [System.StringComparison]::Ordinal)) {
        throw "Linux stage-3 Set intrinsic LLVM contains forbidden text '$($forbiddenPattern.Trim())'"
    }
}
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $setLlvm
& $llvmAsPath $setLlvm -o ($setExecutable + ".bc")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$setActual = (& wsl.exe -d $Distribution -- (Convert-ToWslPath $setExecutable) | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
$setExpected = [System.IO.File]::ReadAllText($setKeyOnlyExpectedPath).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0 -or $setActual -ne $setExpected) {
    throw "Linux stage-3 Set intrinsic execution differed.`nExpected:`n$setExpected`nActual:`n$setActual"
}
$socketNoDelayExpected = [System.IO.File]::ReadAllText($socketNoDelayExpectedPath).Replace("`r`n", "`n").TrimEnd("`n")
$socketNoDelayOutputs = [System.Collections.Generic.List[string]]::new()
foreach ($generation in @(
    [ordered]@{ Name = "linux-stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "linux-stage3"; Compiler = $stage3Path }
)) {
    $socketNoDelayExecutable = Join-Path $artifactsDir "$($generation.Name)-check-socket-no-delay"
    $socketNoDelayLlvm = $socketNoDelayExecutable + ".ll"
    $socketNoDelayBitcode = $socketNoDelayExecutable + ".bc"
    Remove-Item -LiteralPath $socketNoDelayExecutable, $socketNoDelayLlvm, $socketNoDelayBitcode -ErrorAction SilentlyContinue
    $socketNoDelayBuild = Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList @(
            "-d", $Distribution, "--", (Convert-ToWslPath $generation.Compiler),
            "build", (Convert-ToWslPath $socketNoDelaySource),
            "-o", (Convert-ToWslPath $socketNoDelayExecutable),
            "--target", "linux-x64",
            "--stdlib", (Convert-ToWslPath $stdlibRoot),
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "-O1", "--keep-temps") `
        -Description "$($generation.Name) socket no-delay build"
    if ($socketNoDelayBuild.ExitCode -ne 0) {
        throw "$($generation.Name) socket no-delay build failed.`n$($socketNoDelayBuild.Stdout)$($socketNoDelayBuild.Stderr)"
    }
    if (-not (Test-Path -LiteralPath $socketNoDelayExecutable -PathType Leaf) -or
        -not (Test-Path -LiteralPath $socketNoDelayLlvm -PathType Leaf) -or
        (Get-Item -LiteralPath $socketNoDelayLlvm).Length -eq 0) {
        throw "$($generation.Name) socket no-delay build did not retain executable and LLVM artifacts"
    }
    $socketNoDelayLlvmText = [System.IO.File]::ReadAllText($socketNoDelayLlvm)
    foreach ($requiredText in ([System.IO.File]::ReadAllLines($socketNoDelayContainsPath) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        if (-not $socketNoDelayLlvmText.Contains($requiredText.Trim(), [System.StringComparison]::Ordinal)) {
            throw "$($generation.Name) socket no-delay LLVM is missing '$($requiredText.Trim())'"
        }
    }
    foreach ($countContract in ([System.IO.File]::ReadAllLines($socketNoDelayRegexCountsPath) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $fields = $countContract.Split("`t", 2)
        if ($fields.Length -ne 2) {
            throw "invalid socket no-delay regex-count contract '$countContract'"
        }
        $expectedCount = [int]$fields[0]
        $actualCount = ([regex]::Matches($socketNoDelayLlvmText, $fields[1])).Count
        if ($actualCount -ne $expectedCount) {
            throw "$($generation.Name) socket no-delay LLVM regex '$($fields[1])' matched $actualCount times instead of $expectedCount"
        }
    }
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $socketNoDelayLlvm
    & $llvmAsPath $socketNoDelayLlvm -o $socketNoDelayBitcode
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $socketNoDelayRun = Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList @("-d", $Distribution, "--", (Convert-ToWslPath $socketNoDelayExecutable)) `
        -Description "$($generation.Name) socket no-delay executable"
    $socketNoDelayActual = $socketNoDelayRun.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
    if ($socketNoDelayRun.ExitCode -ne 0 -or $socketNoDelayActual -ne $socketNoDelayExpected) {
        throw "$($generation.Name) socket no-delay execution differed.`nExpected:`n$socketNoDelayExpected`nActual:`n$socketNoDelayActual`n$($socketNoDelayRun.Stderr)"
    }
    $socketNoDelayOutputs.Add($socketNoDelayActual)
}
if ($socketNoDelayOutputs[0] -cne $socketNoDelayOutputs[1]) {
    throw "Linux stage-2 and stage-3 socket no-delay results differ"
}
foreach ($generation in @(
    [ordered]@{ Name = "linux-stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "linux-stage3"; Compiler = $stage3Path }
)) {
    & (Join-Path $PSScriptRoot "verify-native-socket-timeouts.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform linux `
        -Distribution $Distribution `
        -LlvmRoot (Join-Path $repoRoot ".tools\llvm-22.1.8") `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-native-mutable-parameter-indexing-batch.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform linux `
        -Distribution $Distribution `
        -LlvmRoot (Join-Path $repoRoot ".tools\llvm-22.1.8") `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-native-interpolation-reference-arguments.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform linux `
        -Distribution $Distribution `
        -LlvmRoot (Join-Path $repoRoot ".tools\llvm-22.1.8") `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-native-projected-reference-places.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform linux `
        -Distribution $Distribution `
        -LlvmRoot (Join-Path $repoRoot ".tools\llvm-22.1.8") `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& (Join-Path $PSScriptRoot "verify-linux-process-child-lifecycle.ps1") `
    -Compiler $stage3Path `
    -Label "linux-stage3" `
    -Distribution $Distribution `
    -LlvmHome (Join-Path $repoRoot ".tools\llvm-22.1.8") `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-quic-endpoint-ownership-linux.ps1") `
    -Compiler $stage3Path `
    -Label "linux-stage3" `
    -Distribution $Distribution `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-exact-fixture-batch.ps1") `
    -Compiler $stage3Path `
    -Label "linux-stage3" `
    -Platform linux `
    -Distribution $Distribution `
    -LlvmRoot (Join-Path $repoRoot ".tools\llvm-22.1.8") `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($diagnosticCompiler in @(
    [ordered]@{ Name = "linux-stage2"; Path = $stage2Path },
    [ordered]@{ Name = "linux-stage3"; Path = $stage3Path }
)) {
    & (Join-Path $PSScriptRoot "verify-selfhost-unresolved-call-diagnostic.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -Target linux `
        -Distribution $Distribution `
        -RepositoryRoot $repoRoot
    & (Join-Path $PSScriptRoot "verify-selfhost-result-propagation-diagnostics.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -Target linux `
        -Distribution $Distribution `
        -RepositoryRoot $repoRoot
    & (Join-Path $PSScriptRoot "verify-selfhost-private-field-diagnostics.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -Target linux `
        -Distribution $Distribution `
        -RepositoryRoot $repoRoot
}
if (-not (Test-Stage2ArtifactReceipt `
        -LlvmPath $stage3LlvmPath `
        -BitcodePath $stage3BitcodePath `
        -ExecutablePath $stage3Path `
        -AdditionalArtifacts @{ object = $stage3ObjectPath } `
        -ReceiptPath $stage3CandidateArtifactReceiptPath)) {
    throw "Linux Stage3 candidate artifacts differ from their completion receipt"
}
Assert-InputFingerprintStable `
    -ExpectedFingerprint ([System.IO.File]::ReadAllText($stage3CandidateFingerprintPath)) `
    -CurrentFingerprint (Get-LinuxStage3InputFingerprint) `
    -Phase "Linux Stage3"
Move-Item -LiteralPath $stage3LlvmPath -Destination $publishedStage3LlvmPath -Force
Move-Item -LiteralPath $stage3BitcodePath -Destination $publishedStage3BitcodePath -Force
Move-Item -LiteralPath $stage3ObjectPath -Destination $publishedStage3ObjectPath -Force
Move-Item -LiteralPath $stage3Path -Destination $publishedStage3Path -Force
Write-Stage2ArtifactReceipt `
    -LlvmPath $publishedStage3LlvmPath `
    -BitcodePath $publishedStage3BitcodePath `
    -ExecutablePath $publishedStage3Path `
    -AdditionalArtifacts @{ object = $publishedStage3ObjectPath } `
    -ReceiptPath $stage3ArtifactReceiptPath
Move-Item -LiteralPath $stage3CandidateFingerprintPath -Destination $stage3FingerprintPath -Force
Remove-Item -LiteralPath $stage3CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
& (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
    -Platform linux `
    -Stage3Path $publishedStage3Path `
    -RepositoryRoot $repoRoot
Write-Host "[linux-stage3 3/3] PASS fixed point $stage3Hash, Set intrinsics, socket no-delay, Result propagation, and process Child lifecycle."
}
finally {
    Release-SelfHostVerificationLock $selfHostVerificationLock
}
