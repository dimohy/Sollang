[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SelfhostCompiler,
    [switch]$NativeSelfhost
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($NativeSelfhost -and
    (-not $PSBoundParameters.ContainsKey('SelfhostCompiler') -or
        [string]::IsNullOrWhiteSpace($SelfhostCompiler))) {
    throw 'NativeSelfhost requires an explicit current SelfhostCompiler path'
}
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$fixture = Join-Path $root 'scripts/probes/borrowed-return-scalars/projection-alias.slg'
$expected = Join-Path $root 'scripts/probes/borrowed-return-scalars/projection-alias.stdout.txt'
$managedSource = Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'
$managedBorrowSource = Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.BorrowOrigins.cs'
$managedCompiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$selfhost = if ([string]::IsNullOrWhiteSpace($SelfhostCompiler)) {
    Join-Path $root 'artifacts/incremental-selfhost/selfhost-slg-seed.exe'
} else {
    [IO.Path]::GetFullPath($SelfhostCompiler)
}
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$stdlib = Join-Path $root 'stdlib'
$llvmAs = Join-Path $llvm 'bin/llvm-as.exe'
$clang = Join-Path $llvm 'bin/clang.exe'
$closure = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$processHelper = Join-Path $root 'scripts/verification-process.ps1'
$inputHelper = Join-Path $root 'scripts/native-exact-fixture-receipt.ps1'
$artifactHelper = Join-Path $root 'scripts/stage2-artifact-receipt.ps1'
$format = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$managedVerifier = Join-Path $root 'scripts/verify-borrowed-return-boundaries.ps1'
$nativeRequired = @($expected, $llvmAs, $clang, $closure, $processHelper,
    $inputHelper, $artifactHelper, $format, $managedVerifier)
$required = @($fixture, $managedSource, $managedBorrowSource, $managedCompiler, $selfhost, $PSCommandPath)
if ($NativeSelfhost) {
    if ([IO.Path]::GetExtension($selfhost) -cne '.exe') {
        throw 'NativeSelfhost requires a Windows selfhost executable'
    }
    if (-not (Test-Path -LiteralPath $stdlib -PathType Container)) {
        throw "missing stdlib source root: $stdlib"
    }
    $required += $nativeRequired
}
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing input: $path" }
}
if ($NativeSelfhost) {
    . $processHelper
    . $inputHelper
    $nativeFingerprintStart = Get-NativeExactWindowsCommonInputFingerprint `
        -RepositoryRoot $root -CompilerPath $selfhost -StdlibRoot $stdlib -LlvmRoot $llvm
}
$output = Join-Path $root ('artifacts/scratch/borrowed-projection-alias-parity-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'
$hashes = [ordered]@{}
foreach ($path in $required) { $hashes[$path] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'managed-selfhost-borrowed-projection-alias-parity'
    completed = 0
    total = $(if ($NativeSelfhost) { 7 } else { 6 })
    inputHashes = $hashes
    checks = @()
    resultPath = $resultPath
}
function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}

try {
    Save-Result
    & $format -Check -Source $fixture
    if ($LASTEXITCODE -ne 0) { throw 'projection alias fixture authoritative format failed' }
    Complete-Check 'fixture-authoritative-format'

    $semantic = [IO.File]::ReadAllText($managedSource).Replace("`r`n", "`n")
    $bindingCalls = [regex]::Matches($semantic, 'TypeCanCarryBorrowedTextOrigin\([^\r\n]+\)[\s\S]{0,240}?TryGetBorrowedSourceCallSiteOrigins\(').Count
    if ($bindingCalls -ne 2) { throw "managed binding/flow borrowed-origin authority count drifted: $bindingCalls" }
    Complete-Check 'managed-binding-and-flow-share-source-origin-authority'

    $borrowAuthority = [IO.File]::ReadAllText($managedBorrowSource).Replace("`r`n", "`n")
    if (-not $borrowAuthority.Contains('if (TryGetConcreteBorrowOrigins(source, bindings, out origins))') -or
        -not $borrowAuthority.Contains('return TryGetBorrowedTextCallOrigins(source, functions, bindings, out origins);')) {
        throw 'managed concrete-place-first borrowed source authority drifted'
    }
    Complete-Check 'managed-concrete-place-first-authority'

    $managedResultText = (& pwsh -NoProfile -File $managedVerifier -CaseId projection-alias 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $managedResultText -notmatch '\(1/1\)') {
        throw "managed projection alias regression failed: $managedResultText"
    }
    $record.managedObservation = $managedResultText
    Complete-Check 'managed-native-exact-and-llvm'

    $selfhostLlvm = Join-Path $output 'selfhost.ll'
    $selfhostText = (& $selfhost windows $fixture 2>&1) -join "`n"
    $selfhostExit = $LASTEXITCODE
    [IO.File]::WriteAllText($selfhostLlvm, $selfhostText + "`n", [Text.UTF8Encoding]::new($false))
    if ($selfhostExit -ne 0 -or $selfhostText -match '(?m)^(warning|; sollang .*error)' -or $selfhostText -notmatch '(?m)^define ') {
        throw "selfhost projection alias emission failed or warned: $selfhostText"
    }
    $record.selfhost = [ordered]@{ compilerSha256=$hashes[$selfhost]; llvmSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $selfhostLlvm).Hash }
    Complete-Check 'selfhost-warning-zero-llvm-emission'

    & $llvmAs $selfhostLlvm -o (Join-Path $output 'selfhost.bc')
    if ($LASTEXITCODE -ne 0) { throw 'selfhost projection alias LLVM assembly failed' }
    & $closure -LlvmPath $selfhostLlvm
    Complete-Check 'selfhost-llvm-assembly-and-direct-call-closure'

    if ($NativeSelfhost) {
        $nativeExe = Join-Path $output 'selfhost-native.exe'
        $nativeLlvm = "$nativeExe.ll"
        $nativeBitcode = "$nativeExe.bc"
        $build = Invoke-VerificationProcessCapture -FilePath $selfhost `
            -ArgumentList @('build', $fixture, '-o', $nativeExe,
                '--target', 'windows-x64', '--llvm', $llvm, '--stdlib', $stdlib,
                '--jobs', '1', '-O1', '--keep-temps') `
            -Description 'C405 selfhost native build' -WorkingDirectory $root -TimeoutMilliseconds 300000
        if ($build.ExitCode -ne 0 -or $build.Stderr.Length -ne 0 -or
            ($build.Stdout + $build.Stderr) -match '(?im)^(?:warning|note)\b' -or
            -not (Test-Path -LiteralPath $nativeExe -PathType Leaf) -or
            -not (Test-Path -LiteralPath $nativeLlvm -PathType Leaf)) {
            throw "selfhost projection alias native build failed or warned: $($build.Stdout) $($build.Stderr)"
        }
        & $closure -LlvmPath $nativeLlvm
        if (-not $?) { throw 'selfhost projection alias native LLVM direct-call closure failed' }
        $assembly = Invoke-VerificationProcessCapture -FilePath $llvmAs `
            -ArgumentList @($nativeLlvm, '-o', $nativeBitcode) `
            -Description 'C405 selfhost native llvm-as' -TimeoutMilliseconds 30000
        if ($assembly.ExitCode -ne 0 -or $assembly.Stderr.Length -ne 0) {
            throw "selfhost projection alias native LLVM assembly failed: $($assembly.Stderr)"
        }
        $run = Invoke-VerificationProcessCapture -FilePath $nativeExe `
            -Description 'C405 selfhost native run' -TimeoutMilliseconds 10000
        $actualBytes = [Text.Encoding]::UTF8.GetBytes($run.Stdout)
        $expectedBytes = [IO.File]::ReadAllBytes($expected)
        if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0 -or
            [Convert]::ToHexString($actualBytes) -cne [Convert]::ToHexString($expectedBytes)) {
            throw 'selfhost projection alias native output differs from exact expected bytes'
        }
        $record.native = [ordered]@{
            compilerSha256 = $hashes[$selfhost]
            expectedSha256 = $hashes[$expected]
            llvmSha256 = (Get-FileHash -LiteralPath $nativeLlvm -Algorithm SHA256).Hash
            executableSha256 = (Get-FileHash -LiteralPath $nativeExe -Algorithm SHA256).Hash
            stdoutSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($actualBytes))
            buildExitCode = $build.ExitCode
            llvmAsExitCode = $assembly.ExitCode
            runExitCode = $run.ExitCode
            inputFingerprint = $nativeFingerprintStart
        }
        Complete-Check 'selfhost-native-exact'
    }

    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -cne $hashes[$path]) { throw "input drift: $path" }
    }
    if ($NativeSelfhost) {
        $nativeFingerprintEnd = Get-NativeExactWindowsCommonInputFingerprint `
            -RepositoryRoot $root -CompilerPath $selfhost -StdlibRoot $stdlib -LlvmRoot $llvm
        if ($nativeFingerprintEnd -cne $nativeFingerprintStart) {
            throw 'selfhost native common inputs changed during verification'
        }
        $record.native.inputStable = $true
    }
    $record.inputsStable = $true
    if ($record.completed -ne $record.total) { throw "denominator mismatch: $($record.completed)/$($record.total)" }
    $record.status = 'passed'
    Save-Result
    Write-Output "PASS $($record.completed)/$($record.total); $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
