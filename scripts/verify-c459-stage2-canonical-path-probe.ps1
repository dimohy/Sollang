[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$CandidateCompiler = 'artifacts/example-tests/selfhost-stage1-verification.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$candidatePath = [IO.Path]::GetFullPath((Join-Path $root $CandidateCompiler))
$resultPath = Join-Path $output 'result.json'
$failureIds = [Collections.Generic.List[string]]::new()
$completed = 0
$total = 5

function Save-Result([string]$Status, [int]$ExitCode) {
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-22-459'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        candidateCompiler = [IO.Path]::GetRelativePath($root, $candidatePath).Replace('\', '/')
        candidateCompilerSha256 = if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash
        } else { $null }
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    $fixture = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-path-normalize-result.slg'
    $pathSource = Join-Path $root 'stdlib/sys/path.slg'
    $runtimeManifest = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
    $llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
    $llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
    $clang = Join-Path $llvmRoot 'bin/clang.exe'
    foreach ($path in @($candidatePath, $fixture, $pathSource, $runtimeManifest, $llvmAs, $clang)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "C459 required input is missing: $path" }
    }

    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $pathSource
    if ($LASTEXITCODE -ne 0) { throw 'C459 authoritative format failed' }
    $completed++

    $fixtureText = [IO.File]::ReadAllText($fixture)
    $pathText = [IO.File]::ReadAllText($pathSource)
    if (-not $fixtureText.Contains('currentInfo.canonical -> byteCount => canonicalLength', [StringComparison]::Ordinal) -or
        $fixtureText.Contains('currentInfo.canonical -> pathText -> resolveAbsolutePath', [StringComparison]::Ordinal)) {
        throw 'C459 fixture still feeds a trusted runtime canonical path into the public confinement validator'
    }
    if (-not $pathText.Contains('normalizeResolvedCanonical: move self', [StringComparison]::Ordinal) -or
        $pathText.Contains('public normalizeResolvedCanonical', [StringComparison]::Ordinal) -or
        -not $pathText.Contains('pathError("unsupported path namespace")', [StringComparison]::Ordinal)) {
        throw 'C459 trusted/private and untrusted/public path normalization boundary changed'
    }
    $completed++

    $runtimeSources = @(Get-Content -LiteralPath $runtimeManifest |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
    $llvm = Join-Path $output 'canonical-path-probe.ll'
    $emissionError = Join-Path $output 'canonical-path-probe.err'
    Invoke-VerificationProcessToFile -FilePath $candidatePath `
        -ArgumentList (@('windows', $fixture) + $runtimeSources) `
        -Description 'C459 current Stage1 canonical path probe emission' `
        -OutputPath $llvm -ErrorPath $emissionError -TimeoutMilliseconds 600000
    if ((Get-Item -LiteralPath $emissionError).Length -ne 0) {
        throw "C459 emission wrote stderr: $([IO.File]::ReadAllText($emissionError))"
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $llvm
    if ($LASTEXITCODE -ne 0) { throw 'C459 direct-call closure failed' }
    $bitcode = Join-Path $output 'canonical-path-probe.bc'
    & $llvmAs $llvm -o $bitcode
    if ($LASTEXITCODE -ne 0) { throw 'C459 llvm-as failed' }
    $executable = Join-Path $output 'canonical-path-probe.exe'
    & $clang -Wno-override-module $llvm -o $executable -lshell32 -lbcrypt -lws2_32 -Xlinker /subsystem:console
    if ($LASTEXITCODE -ne 0) { throw 'C459 native link failed' }
    $completed++

    $stdout = Join-Path $output 'canonical-path-probe.stdout.txt'
    $stderr = Join-Path $output 'canonical-path-probe.stderr.txt'
    Invoke-VerificationProcessToFile -FilePath $executable -ArgumentList @() `
        -Description 'C459 canonical path probe execution' -OutputPath $stdout -ErrorPath $stderr `
        -TimeoutMilliseconds 30000
    if ((Get-Item -LiteralPath $stderr).Length -ne 0) {
        throw "C459 native execution wrote stderr: $([IO.File]::ReadAllText($stderr))"
    }
    $actual = [IO.File]::ReadAllText($stdout).Replace("`r`n", "`n").TrimEnd("`n")
    if ($actual -cne "artifacts\native-grammar-build\probe\generated.slg`ntrue") {
        throw "C459 canonical path probe output mismatch: '$actual'"
    }
    $completed++

    Save-Result -Status 'passed' -ExitCode 0
    Write-Host "[C459 Stage2 canonical path probe] PASS $completed/$total result=$resultPath"
} catch {
    $failureIds.Add('C459_STAGE2_CANONICAL_PATH_PROBE')
    Save-Result -Status 'failed' -ExitCode 1
    throw
}
