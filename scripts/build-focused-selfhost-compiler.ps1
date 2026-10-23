[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SeedCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('O0', 'O1', 'O2')][string]$Optimization = 'O1',
    [ValidateRange(1, 64)][int]$Jobs = 24,
    [string]$CacheSeedDirectory = '',
    [string]$FormatCompiler = '',
    [string[]]$ReusableCompilerDirectories = @(),
    [string[]]$ManagedProofRecord = @(),
    [string[]]$SlgEmissionProofRecord = @(),
    [string]$StdlibSourceProofRecord = '',
    [string]$AwaitRuntimeContract = 'scripts/contracts/full-stdlib-nested-await-owner-emission.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'ArtifactLifecycle.ps1')
. (Join-Path $PSScriptRoot 'focused-selfhost-input-contract.ps1')
$seed = (Resolve-Path -LiteralPath $SeedCompiler).Path
$managedSeed = [IO.Path]::GetFileName($seed) -ceq 'Sollang.Compiler.exe'
$effectiveJobs = $Jobs
if ($managedSeed -and [string]::IsNullOrWhiteSpace($FormatCompiler)) {
    throw 'Focused managed seed requires an explicit native FormatCompiler.'
}
$formatter = if ([string]::IsNullOrWhiteSpace($FormatCompiler)) {
    $seed
} else {
    (Resolve-Path -LiteralPath $FormatCompiler).Path
}
$protectedCompilerDirectories = @($ReusableCompilerDirectories) + @(
    [IO.Path]::GetFullPath($OutputDirectory)
)
# Source-owned managed tools are pinned inputs, not lifecycle-owned products.
# Native formatter products are discovered from $inputs by the shared resolver.
if (-not $managedSeed) { $protectedCompilerDirectories += [IO.Path]::GetDirectoryName($seed) }
if (-not [string]::IsNullOrWhiteSpace($CacheSeedDirectory)) {
    $protectedCompilerDirectories += [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($CacheSeedDirectory))
}
$protectedCompilerDirectories = @($protectedCompilerDirectories |
    ForEach-Object { [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($_)) } |
    Sort-Object -Unique)
if ($protectedCompilerDirectories.Count -gt 3) { throw 'FOCUSED_SELFHOST_REUSABLE_COMPILER_LIMIT' }
$managedDependencies = @()
$semanticPreflight = Join-Path $PSScriptRoot 'verify-focused-selfhost-semantic-preflight.py'
$semanticPreflightInputs = @()
$semanticPythonLauncher = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$semanticPythonProbe = @(& $semanticPythonLauncher -c 'import sys; print(sys.executable)')
if ($LASTEXITCODE -ne 0 -or $semanticPythonProbe.Count -ne 1 -or
    -not (Test-Path -LiteralPath $semanticPythonProbe[0] -PathType Leaf)) {
    throw 'FOCUSED_SELFHOST_PYTHON_PROBE_FAILED: expected one actual Python interpreter path'
}
$semanticPython = (Resolve-Path -LiteralPath $semanticPythonProbe[0]).Path
$stdlibSourceValidator = Join-Path $PSScriptRoot 'verification_stdlib_source_preflight.py'
if ([string]::IsNullOrWhiteSpace($StdlibSourceProofRecord)) {
    throw 'FOCUSED_SELFHOST_STDLIB_SOURCE_PROOF_REQUIRED'
}
$stdlibSourceProof = (Resolve-Path -LiteralPath $StdlibSourceProofRecord).Path
& $semanticPython $stdlibSourceValidator --repo $root --proof $stdlibSourceProof
if ($LASTEXITCODE -ne 0) { throw 'FOCUSED_SELFHOST_STDLIB_SOURCE_PREFLIGHT_FAILED' }
$ManagedProofRecord = @($ManagedProofRecord) + @($stdlibSourceProof)
if ($managedSeed) {
    $managedDirectory = [IO.Path]::GetDirectoryName($seed)
    $managedDependencies = @('Sollang.Compiler.dll', 'Sollang.Compiler.deps.json', 'Sollang.Compiler.runtimeconfig.json') |
        ForEach-Object { Join-Path $managedDirectory $_ }
    $semanticPreflightInputs = @($semanticPreflight, $semanticPython,
        (Join-Path $PSScriptRoot 'verification_fingerprints.py'),
        (Join-Path $PSScriptRoot 'contracts/fixtures/focused-selfhost-semantic-preflight-harness.cs')) +
        @('positive', 'deferred-text', 'rebound-owner' | ForEach-Object {
            Join-Path $PSScriptRoot "contracts/fixtures/semantic-preflight-$_.slg"
        })
}
$manifest = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$stdlib = Join-Path $root 'stdlib'
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clang = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$closure = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$parallelClosure = Join-Path $PSScriptRoot 'verify-selfhost-parallel-callback-llvm.ps1'
$sourceClosure = Join-Path $PSScriptRoot 'verify-source-manifest-closure.ps1'
$sources = @([IO.File]::ReadAllLines($manifest) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $root $_.Trim() })
$stdlibSources = @([IO.Directory]::GetFiles($stdlib, '*.slg', [IO.SearchOption]::AllDirectories))
[Array]::Sort($stdlibSources, [StringComparer]::Ordinal)
$cacheSeedPaths = @()
if (-not [string]::IsNullOrWhiteSpace($CacheSeedDirectory)) {
    $cacheSeed = (Resolve-Path -LiteralPath $CacheSeedDirectory).Path
    $cacheSeedPaths = @([IO.Directory]::GetFiles($cacheSeed, 'compiler.*', [IO.SearchOption]::TopDirectoryOnly))
    [Array]::Sort($cacheSeedPaths, [StringComparer]::Ordinal)
    $suffixes = @($cacheSeedPaths | ForEach-Object { [IO.Path]::GetExtension($_) })
    if ($cacheSeedPaths.Count -ne 4 -or
        @($suffixes | Where-Object { $_ -notin @('.cgu', '.product', '.semantic', '.sources') }).Count -ne 0 -or
        @($suffixes | Select-Object -Unique).Count -ne 4) {
        throw 'Focused self-host cache seed must contain exactly the compiler cgu, product, semantic, and sources receipts.'
    }
}
if ($sources.Count -eq 0 -or $stdlibSources.Count -eq 0) {
    throw 'Focused self-host build requires nonempty compiler and stdlib source closures.'
}
$managedProofPaths = @()
$slgEmissionProofPaths = @()
$managedProofInputHashes = [ordered]@{}
$reusableSemanticPreflight = ''
foreach ($proofPath in (@($ManagedProofRecord) + @($SlgEmissionProofRecord))) {
    $resolvedProof = (Resolve-Path -LiteralPath $proofPath).Path
    $proof = Get-Content -LiteralPath $resolvedProof -Raw | ConvertFrom-Json
    if ($proof.status -cne 'passed' -or $proof.inputsStable -ne $true -or
        $proof.processesStopped -ne $true -or $proof.total -le 0 -or $proof.completed -ne $proof.total) {
        throw "FOCUSED_SELFHOST_MANAGED_PROOF_INCOMPLETE: $resolvedProof"
    }
    $isSlgEmissionProof = $proofPath -in $SlgEmissionProofRecord
    if ($isSlgEmissionProof) {
        if ($null -eq $proof.PSObject.Properties['mode'] -or $proof.mode -cne 'managed' -or
            $null -eq $proof.PSObject.Properties['semanticPreflight'] -or
            $proof.semanticPreflight.status -cne 'passed-current-source' -or
            $proof.semanticPreflight.codegenInvoked -ne $false -or
            $null -eq $proof.PSObject.Properties['cases'] -or
            @($proof.cases).Count -ne $proof.total) {
            throw "FOCUSED_SELFHOST_SLG_EMISSION_PROOF_INCOMPLETE: $resolvedProof"
        }
        foreach ($case in @($proof.cases)) {
            if ($null -ne $case.PSObject.Properties['id'] -and $case.id -ceq 'full-stdlib-nested-await-owner') {
                $awaitOwnerGuard = Join-Path $root 'scripts/verify-late-await-function-order-contract.py'
                $awaitOwnerContractPath = if ([IO.Path]::IsPathRooted($AwaitRuntimeContract)) {
                    (Resolve-Path -LiteralPath $AwaitRuntimeContract).Path
                } else { (Resolve-Path -LiteralPath (Join-Path $root $AwaitRuntimeContract)).Path }
                & $semanticPythonProbe[0] $awaitOwnerGuard --proof $resolvedProof --contract $awaitOwnerContractPath --check-only
                if ($LASTEXITCODE -ne 0) { throw 'FOCUSED_SELFHOST_AWAIT_OWNER_RUNTIME_INPUT_CONTRACT_FAILED' }
                $managedProofInputHashes[$awaitOwnerGuard] = (Get-FileHash -LiteralPath $awaitOwnerGuard -Algorithm SHA256).Hash
                $managedProofInputHashes[$awaitOwnerContractPath] = (Get-FileHash -LiteralPath $awaitOwnerContractPath -Algorithm SHA256).Hash
                $awaitOwnerContract = Get-Content -LiteralPath $awaitOwnerContractPath -Raw | ConvertFrom-Json
                $awaitOwnerProgram = [IO.Path]::GetFullPath((Join-Path $root $awaitOwnerContract.observedSourceOrder[-1]))
                $managedProofInputHashes[$awaitOwnerProgram] = (Get-FileHash -LiteralPath $awaitOwnerProgram -Algorithm SHA256).Hash
            }
            if ($null -eq $case.PSObject.Properties['emittedLlvmSha256'] -or
                $case.emittedLlvmSha256 -notmatch '^[0-9a-fA-F]{64}$' -or
                $case.assemblyExit -ne 0 -or $case.nativeLinkExit -ne 0 -or
                $case.nativeRunExit -ne 0 -or $case.passed -ne $true) {
                throw "FOCUSED_SELFHOST_SLG_EMISSION_PROOF_NOT_EXECUTED: $resolvedProof"
            }
        }
    }
    if ($null -eq $proof.PSObject.Properties['inputHashes'] -or
        @($proof.inputHashes.PSObject.Properties).Count -eq 0) {
        throw "FOCUSED_SELFHOST_MANAGED_PROOF_INPUTS_MISSING: $resolvedProof"
    }
    if ($isSlgEmissionProof -and $null -eq $proof.inputHashes.PSObject.Properties[$manifest]) {
        throw "FOCUSED_SELFHOST_SLG_EMISSION_PROOF_CANONICAL_INPUTS_MISSING: $resolvedProof"
    }
    foreach ($entry in $proof.inputHashes.PSObject.Properties) {
        $proofInput = [IO.Path]::GetFullPath($entry.Name)
        if ([string]$entry.Value -notmatch '^[0-9a-fA-F]{64}$' -or
            -not (Test-Path -LiteralPath $proofInput -PathType Leaf) -or
            (Get-FileHash -LiteralPath $proofInput -Algorithm SHA256).Hash -ine [string]$entry.Value) {
            throw "FOCUSED_SELFHOST_MANAGED_PROOF_INPUT_DRIFT: $proofInput"
        }
        if ($managedProofInputHashes.Contains($proofInput) -and
            $managedProofInputHashes[$proofInput] -ine [string]$entry.Value) {
            throw "FOCUSED_SELFHOST_MANAGED_PROOF_INPUT_CONFLICT: $proofInput"
        }
        $managedProofInputHashes[$proofInput] = [string]$entry.Value
    }
    if ($isSlgEmissionProof) { $slgEmissionProofPaths += $resolvedProof }
    else { $managedProofPaths += $resolvedProof }
    if ($managedSeed -and $null -ne $proof.PSObject.Properties['scope'] -and
        $proof.scope -ceq 'focused-selfhost') {
        $reusableSemanticPreflight = Get-FocusedSelfhostReusableSemanticPreflight `
            -RecordPath $resolvedProof -Manifest $manifest -Sources $sources `
            -StdlibSources $stdlibSources -ManagedDll (Join-Path $managedDirectory 'Sollang.Compiler.dll')
    }
}
$astKindValidator = Join-Path $PSScriptRoot 'verify-ast-expression-kind-contract.py'
$astKindInputs = @($astKindValidator, $semanticPython,
    (Join-Path $PSScriptRoot 'ast_expression_kind_contract.py'),
    (Join-Path $PSScriptRoot 'contracts/ast-expression-kinds.json'))
$inputs = @($seed, $formatter, $manifest, $llvmAs, $clang, $closure, $parallelClosure, $sourceClosure, $stdlibSourceValidator,
    (Join-Path $PSScriptRoot 'build-focused-selfhost-compiler.ps1'),
    (Join-Path $PSScriptRoot 'focused-selfhost-input-contract.ps1'),
    (Join-Path $PSScriptRoot 'ArtifactLifecycle.ps1'),
    (Join-Path $PSScriptRoot 'completed_artifact_plan.py'),
    (Join-Path $PSScriptRoot 'Invoke-CompletedArtifactCleanup.ps1'),
    (Join-Path $PSScriptRoot 'contracts/artifact-lifecycle.json')) + $astKindInputs + $managedDependencies + $semanticPreflightInputs + $sources + $stdlibSources + $cacheSeedPaths + $managedProofPaths + $slgEmissionProofPaths + @($managedProofInputHashes.Keys)
$inputs = @($inputs | Select-Object -Unique)
$protectedCompilerDirectories = @(Get-FocusedSelfhostProtectedCompilerDirectories -Directories $protectedCompilerDirectories `
    -InputPaths $inputs -ExternalOutputRoot (Join-Path $env:LOCALAPPDATA 'Sollang') -MaximumReusableCompilers 3)
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Focused self-host build input missing: $path"
    }
}

& $semanticPython $astKindValidator
if ($LASTEXITCODE -ne 0) { throw 'FOCUSED_SELFHOST_AST_KIND_PREFLIGHT_FAILED' }

& $sourceClosure -Manifest @($manifest) -SourcePath $stdlibSources -RepositoryRoot $root
if (-not $?) {
    throw 'Focused self-host source closure preflight failed.'
}

# Reject source notes and missing build inputs before the costly partitioned build.
& $formatter format --check @sources
if ($LASTEXITCODE -ne 0) { throw 'Focused self-host compiler source format preflight failed.' }

$inputHashesStart = Get-FocusedSelfhostInputHashes -Paths $inputs
$fingerprint = Get-FocusedSelfhostInputFingerprint -Hashes $inputHashesStart -Optimization $Optimization -Jobs $effectiveJobs -ManagedSeed $managedSeed
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) {
    throw "Focused self-host build requires a fresh output directory: $output"
}
Initialize-ArtifactOutput -OutputDirectory $OutputDirectory -ReusableCompilerDirectories $protectedCompilerDirectories
[IO.Directory]::CreateDirectory($output) | Out-Null
if ($cacheSeedPaths.Count -gt 0) {
    $targetCache = Join-Path $output '.sollang-cache'
    if (Test-Path -LiteralPath $targetCache) {
        throw "Focused self-host cache destination already exists: $targetCache"
    }
    [IO.Directory]::CreateDirectory($targetCache) | Out-Null
    foreach ($path in $cacheSeedPaths) {
        $copy = Join-Path $targetCache ([IO.Path]::GetFileName($path))
        Copy-Item -LiteralPath $path -Destination $copy -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -cne
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash) {
            throw "Focused self-host cache copy mismatch: $copy"
        }
    }
}
$exe = Join-Path $output 'compiler.exe'
$bc = "$exe.bc"
$steps = [ordered]@{ semanticPreflight = $null; build = $null; llvmAs = $null; v004 = $null; parallelCallbacks = $null }
$failure = $null
$failureId = $null
try {
    Write-Host "[focused selfhost] preflight compiler=$($sources.Count) stdlib=$($stdlibSources.Count) cache=$($cacheSeedPaths.Count) optimization=$Optimization jobs=$effectiveJobs managed=$managedSeed fingerprint=$fingerprint"
    if ($managedSeed) {
        if ($reusableSemanticPreflight) {
            $steps.semanticPreflight = 0
            $semanticRecord = Get-Content -LiteralPath $reusableSemanticPreflight -Raw | ConvertFrom-Json
            [IO.File]::WriteAllText((Join-Path $output 'semantic-preflight.stdout.txt'),
                "Reused verified semantic preflight: $reusableSemanticPreflight`n", [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $output 'semantic-preflight.stderr.txt'), '')
        } else {
        $semanticPreflightArguments = @($semanticPreflight, '--compiler', $seed,
            '--manifest', $manifest, '--output', (Join-Path $output 'semantic-preflight'),
            '--expected-managed-dll-sha256', (Get-FileHash -LiteralPath (Join-Path $managedDirectory 'Sollang.Compiler.dll') -Algorithm SHA256).Hash)
        foreach ($reusableDirectory in $protectedCompilerDirectories) {
            $semanticPreflightArguments += @('--reusable-directory', $reusableDirectory)
        }
        & $semanticPython @semanticPreflightArguments > (Join-Path $output 'semantic-preflight.stdout.txt') 2> (Join-Path $output 'semantic-preflight.stderr.txt')
        $steps.semanticPreflight = $LASTEXITCODE
        if ($steps.semanticPreflight -ne 0) {
            $failureId = 'FOCUSED_SELFHOST_SEMANTIC_PREFLIGHT_FAILED'
            throw 'Focused self-host semantic preflight failed before LLVM generation.'
        }
        $semanticRecord = Get-Content -LiteralPath (Join-Path $output 'semantic-preflight/result.json') -Raw | ConvertFrom-Json
        }
        if ($semanticRecord.status -cne 'passed' -or -not $semanticRecord.inputsStable -or
            $semanticRecord.codegenInvoked -ne $false -or $semanticRecord.completed -ne $semanticRecord.total -or
            @($semanticRecord.failureIds).Count -ne 0 -or (Get-Item (Join-Path $output 'semantic-preflight.stderr.txt')).Length -ne 0) {
            $failureId = 'FOCUSED_SELFHOST_SEMANTIC_PREFLIGHT_INVALID_RECORD'
            throw 'Focused self-host semantic preflight result cannot authorize LLVM generation.'
        }
        & $seed build @sources -o $exe --target windows-x64 --llvm $llvmRoot --jobs $effectiveJobs "-$Optimization" --keep-temps > (Join-Path $output 'build.stdout.txt') 2> (Join-Path $output 'build.stderr.txt')
    } else {
        & $seed build @sources -o $exe --target windows-x64 --llvm $llvmRoot --stdlib $stdlib --jobs $Jobs "-$Optimization" --keep-temps > (Join-Path $output 'build.stdout.txt') 2> (Join-Path $output 'build.stderr.txt')
    }
    $steps.build = $LASTEXITCODE
    $buildText = [IO.File]::ReadAllText((Join-Path $output 'build.stdout.txt')) +
        [IO.File]::ReadAllText((Join-Path $output 'build.stderr.txt'))
    if ($steps.build -ne 0) {
        $failureId = 'FOCUSED_SELFHOST_BUILD_EXIT_NONZERO'
        $firstDiagnostic = @($buildText -split "`r?`n" |
            Where-Object { $_ -match '^(?:sollang:|warning S\d+|note N\d+)' } |
            Select-Object -First 1)
        $detail = if ($firstDiagnostic.Count -gt 0) { $firstDiagnostic[0] } else { 'no structured diagnostic was emitted' }
        throw "Focused self-host compiler build failed (exit $($steps.build)): $detail"
    }
    $llCandidates = @(@([IO.Path]::ChangeExtension($exe, '.ll'), "$exe.ll") |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($llCandidates.Count -ne 1) {
        throw "Focused self-host build must produce exactly one LLVM text artifact; found $($llCandidates.Count)."
    }
    $ll = $llCandidates[0]
    if ((Get-Item (Join-Path $output 'build.stderr.txt')).Length -ne 0 -or
        $buildText -match '(?m)^(?:warning S\d+|note N\d+)\b' -or
        -not (Test-Path -LiteralPath $ll -PathType Leaf) -or
        -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw 'Focused self-host partitioned build failed, wrote diagnostics, or omitted compiler artifacts.'
    }
    Write-Host '[focused selfhost] native compiler and LLVM built.'
    & $llvmAs $ll -o $bc > (Join-Path $output 'llvm-as.stdout.txt') 2> (Join-Path $output 'llvm-as.stderr.txt')
    $steps.llvmAs = $LASTEXITCODE
    if ($steps.llvmAs -ne 0 -or (Get-Item (Join-Path $output 'llvm-as.stderr.txt')).Length -ne 0) {
        throw 'Focused self-host LLVM assembly failed.'
    }
    & pwsh -NoProfile -File $closure -LlvmPath $ll > (Join-Path $output 'v004.stdout.txt') 2> (Join-Path $output 'v004.stderr.txt')
    $steps.v004 = $LASTEXITCODE
    if ($steps.v004 -ne 0 -or (Get-Item (Join-Path $output 'v004.stderr.txt')).Length -ne 0) {
        throw 'Focused self-host direct-call closure failed.'
    }
    & pwsh -NoProfile -File $parallelClosure -LlvmPath $ll -RequireNominalTransfer > (Join-Path $output 'parallel-callbacks.stdout.txt') 2> (Join-Path $output 'parallel-callbacks.stderr.txt')
    $steps.parallelCallbacks = $LASTEXITCODE
    if ($steps.parallelCallbacks -ne 0 -or (Get-Item (Join-Path $output 'parallel-callbacks.stderr.txt')).Length -ne 0) {
        throw 'FOCUSED_SELFHOST_NOMINAL_PARALLEL_CALLBACK_REQUIRED'
    }
} catch {
    $failure = $_.Exception.Message
    if ($null -eq $failureId) { $failureId = 'FOCUSED_SELFHOST_VERIFICATION_FAILURE' }
}
$inputHashesEnd = Get-FocusedSelfhostInputHashes -Paths $inputs -AllowMissing
$finalFingerprint = Get-FocusedSelfhostInputFingerprint -Hashes $inputHashesEnd -Optimization $Optimization -Jobs $effectiveJobs -ManagedSeed $managedSeed
if ($finalFingerprint -cne $fingerprint) {
    $failure = 'Focused self-host build input drifted during execution.'
    $failureId = 'FOCUSED_SELFHOST_INPUT_DRIFT'
}
$record = [ordered]@{
    schemaVersion = 1
    status = if ($null -eq $failure) { 'passed' } else { 'failed' }
    compilerSourceCount = $sources.Count
    stdlibSourceCount = $stdlibSources.Count
    cacheSeedCount = $cacheSeedPaths.Count
    seedCompilerSha256 = (Get-FileHash -LiteralPath $seed -Algorithm SHA256).Hash
    compilerSha256 = if ($null -eq $failure) { (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash } else { $null }
    optimization = $Optimization
    jobs = $effectiveJobs
    managedSeed = $managedSeed
    managedProofRecords = $managedProofPaths
    slgEmissionProofRecords = $slgEmissionProofPaths
    stdlibSourceProofRecord = $stdlibSourceProof
    inputFingerprint = $fingerprint
    finalInputFingerprint = $finalFingerprint
    inputHashesStart = $inputHashesStart
    inputHashesEnd = $inputHashesEnd
    generatedArtifactHashes = @(
        foreach ($generatedPath in @($exe, $bc, [IO.Path]::ChangeExtension($exe, '.ll'), "$exe.ll")) {
            if (Test-Path -LiteralPath $generatedPath -PathType Leaf) {
                [ordered]@{
                    path = [IO.Path]::GetFullPath($generatedPath)
                    sha256 = (Get-FileHash -LiteralPath $generatedPath -Algorithm SHA256).Hash
                    bytes = (Get-Item -LiteralPath $generatedPath).Length
                }
            }
        }
    )
    inputsStable = $fingerprint -ceq $finalFingerprint
    steps = $steps
    semanticPreflightEvidenceMode = $(if ($reusableSemanticPreflight) { 'reused' } else { 'executed' })
    semanticPreflightEvidencePath = $(if ($reusableSemanticPreflight) { $reusableSemanticPreflight } else { Join-Path $output 'semantic-preflight/result.json' })
    failureId = $failureId
    failure = $failure
    pendingConsumerProtection = [ordered]@{
        purpose = 'Focused paired verification has not finished'
        outputDirectory = $output
        reusableCompilerDirectories = $protectedCompilerDirectories
        buildCompletionDoesNotClosePendingTests = $true
    }
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
if ($null -ne $failure) { throw "$failure result=$result" }
Complete-VerifiedArtifactOutput -OutputDirectory $output -KeepCompiler -TemporaryOnly -ReusableCompilerDirectories $protectedCompilerDirectories
Write-Host "[focused selfhost] PASS compiler SHA-256 $($record.compilerSha256); result=$result"
