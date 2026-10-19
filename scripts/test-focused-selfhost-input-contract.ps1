[CmdletBinding()]
param([string]$Output = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'focused-selfhost-input-contract.ps1')
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryBase ('sollang-input-contract-' + [Guid]::NewGuid().ToString('N'))
$cases = [Collections.Generic.List[string]]::new()
try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    $productRoot = Join-Path $testRoot 'products'
    $seed = Join-Path $productRoot 'seed'
    $formatter = Join-Path $productRoot 'proof-formatter'
    $candidate = Join-Path $productRoot 'candidate'
    foreach ($directory in @($seed, $formatter, $candidate)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        [IO.File]::WriteAllText((Join-Path $directory 'compiler.exe'), 'fixture')
    }
    $proofFormatter = Join-Path $formatter 'compiler.exe'
    $protected = @(Get-FocusedSelfhostProtectedCompilerDirectories -Directories @($seed, $candidate) `
        -InputPaths @($proofFormatter) -ExternalOutputRoot $productRoot -MaximumReusableCompilers 3)
    if ($protected.Count -ne 3 -or $formatter -notin $protected) { throw 'PROOF_COMPILER_NOT_PROTECTED' }
    $cases.Add('transitive-proof-compiler-protected')

    $outside = Join-Path $testRoot 'outside/compiler.exe'
    $protected = @(Get-FocusedSelfhostProtectedCompilerDirectories -Directories @($seed, $candidate) `
        -InputPaths @($outside) -ExternalOutputRoot $productRoot -MaximumReusableCompilers 3)
    if ($protected.Count -ne 2) { throw 'OUTSIDE_PRODUCT_ROOT_PROTECTED' }
    $cases.Add('outside-product-root-excluded')

    $managedFormatter = Join-Path $testRoot 'source/bin/Sollang.Compiler.exe'
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($managedFormatter)) | Out-Null
    [IO.File]::WriteAllText($managedFormatter, 'managed fixture')
    $protected = @(Get-FocusedSelfhostProtectedCompilerDirectories -Directories @($seed, $candidate) `
        -InputPaths @($managedFormatter, $proofFormatter) -ExternalOutputRoot $productRoot -MaximumReusableCompilers 3)
    if ($protected.Count -ne 3 -or $formatter -notin $protected -or
        [IO.Path]::GetDirectoryName($managedFormatter) -in $protected) { throw 'MANAGED_TOOL_PRODUCT_BOUNDARY_INVALID' }
    $managedPins = Get-FocusedSelfhostInputHashes -Paths @($managedFormatter)
    if ($managedPins[$managedFormatter] -cne (Get-FileHash -LiteralPath $managedFormatter -Algorithm SHA256).Hash) {
        throw 'MANAGED_TOOL_INPUT_NOT_PINNED'
    }
    $cases.Add('managed-tool-pinned-without-artifact-ownership')

    $rejected = $false
    try {
        Get-FocusedSelfhostProtectedCompilerDirectories -Directories @($seed, $candidate, (Join-Path $productRoot 'fourth')) `
            -InputPaths @($proofFormatter) -ExternalOutputRoot $productRoot -MaximumReusableCompilers 3 | Out-Null
    } catch {
        if ($_.Exception.Message -notlike 'FOCUSED_SELFHOST_REUSABLE_COMPILER_LIMIT:*') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'FOUR_REQUIRED_COMPILERS_NOT_REJECTED' }
    $cases.Add('four-required-products-rejected-before-cleanup')

    $start = Get-FocusedSelfhostInputHashes -Paths @($proofFormatter)
    $before = Get-FocusedSelfhostInputFingerprint -Hashes $start -Optimization O1 -Jobs 0 -ManagedSeed $true
    Remove-Item -LiteralPath $proofFormatter
    $rejected = $false
    try { Get-FocusedSelfhostInputHashes -Paths @($proofFormatter) | Out-Null } catch {
        if ($_.Exception.Message -notlike 'FOCUSED_SELFHOST_INPUT_MISSING:*') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'MISSING_PREFLIGHT_INPUT_NOT_REJECTED' }
    $cases.Add('missing-preflight-input-rejected')

    $end = Get-FocusedSelfhostInputHashes -Paths @($proofFormatter) -AllowMissing
    $after = Get-FocusedSelfhostInputFingerprint -Hashes $end -Optimization O1 -Jobs 0 -ManagedSeed $true
    if ($end[$proofFormatter] -cne 'MISSING' -or $before -ceq $after) { throw 'MISSING_FINAL_INPUT_NOT_RECORDED' }
    $cases.Add('missing-final-input-recorded-as-drift')
    $source = Join-Path $testRoot 'source.slg'
    $stdlibSource = Join-Path $testRoot 'stdlib.slg'
    $manifest = Join-Path $testRoot 'sources.txt'
    foreach ($path in @($source, $stdlibSource, $manifest)) { [IO.File]::WriteAllText($path, 'fixture') }
    $proofPath = Join-Path $testRoot 'semantic-proof.json'
    $proof = [ordered]@{
        status = 'passed'; inputsStable = $true; processesStopped = $true
        scope = 'focused-selfhost'; completed = 4; total = 4; codegenInvoked = $false
        codegenPathGuard = 'passed'; productionApiPath = 'CompilerApp.LoadProgram -> SemanticCompiler.Compile(null)'
        failureIds = @(); formatPreflight = @{ status = 'passed'; exit = 0; sourceCount = 1 }
        managedDllSha256 = (Get-FileHash -LiteralPath $managedFormatter -Algorithm SHA256).Hash
        inputHashes = Get-FocusedSelfhostInputHashes -Paths @($source, $stdlibSource, $manifest, $managedFormatter)
        cases = @(
            @{ id = 'positive'; exit = 0; passed = $true },
            @{ id = 'deferred-text'; exit = 1; passed = $true },
            @{ id = 'rebound-owner'; exit = 1; passed = $true },
            @{ id = 'focused-selfhost'; exit = 0; passed = $true; sourceCount = 1 })
    }
    $baselineProof = $proof | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($proofPath, $baselineProof)
    $reused = Get-FocusedSelfhostReusableSemanticPreflight -RecordPath $proofPath -Manifest $manifest `
        -Sources @($source) -StdlibSources @($stdlibSource) -ManagedDll $managedFormatter
    if ($reused -cne $proofPath) { throw 'VALID_SEMANTIC_PREFLIGHT_NOT_REUSED' }
    $cases.Add('stable-full-semantic-preflight-reused')
    foreach ($variant in @('failed-format', 'running', 'controls-only', 'codegen', 'missing-source', 'drift', 'wrong-negative-exit')) {
        $changed = $baselineProof | ConvertFrom-Json -AsHashtable
        switch ($variant) {
            'failed-format' { $changed.status = 'failed'; $changed.failureIds = @('SEMANTIC_PREFLIGHT_COMPILER_SOURCE_FORMAT_FAILED') }
            'running' { $changed.status = 'running'; $changed.processesStopped = $false }
            'controls-only' { $changed.total = 3; $changed.completed = 3 }
            'codegen' { $changed.codegenInvoked = $true }
            'missing-source' { $changed.inputHashes.Remove($source) }
            'drift' { $changed.inputHashes[$source] = '0' * 64 }
            'wrong-negative-exit' { $changed.cases[1].exit = 0 }
        }
        [IO.File]::WriteAllText($proofPath, ($changed | ConvertTo-Json -Depth 6))
        $rejected = $false
        try {
            Get-FocusedSelfhostReusableSemanticPreflight -RecordPath $proofPath -Manifest $manifest `
                -Sources @($source) -StdlibSources @($stdlibSource) -ManagedDll $managedFormatter | Out-Null
        } catch {
            if ($_.Exception.Message -notlike 'FOCUSED_SELFHOST_SEMANTIC_REUSE_*') { throw }
            $rejected = $true
        }
        if (-not $rejected) { throw "INVALID_SEMANTIC_PREFLIGHT_REUSED: $variant" }
        $cases.Add("semantic-preflight-$variant-rejected")
    }
    $record = [ordered]@{ schemaVersion = 1; status = 'passed'; completed = $cases.Count; total = 14; cases = @($cases) }
    $json = $record | ConvertTo-Json -Depth 3
    if ($Output) { [IO.File]::WriteAllText([IO.Path]::GetFullPath($Output), $json + "`n", [Text.UTF8Encoding]::new($false)) }
    $json
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ([IO.Path]::GetDirectoryName($resolved) -cne [IO.Path]::TrimEndingDirectorySeparator($temporaryBase) -or
        [IO.Path]::GetFileName($resolved) -notlike 'sollang-input-contract-*') { throw 'TEST_CLEANUP_PATH_INVALID' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse }
}
