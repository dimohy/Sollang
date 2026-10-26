# C527 baseline authority is explicit. A replay never claims recovery of the old file.
. (Join-Path $PSScriptRoot 'verification-artifact-identity.ps1')

function Assert-C527Baseline([bool]$Condition, [string]$FailureId) {
    if (-not $Condition) { throw $FailureId }
}
function Convert-C527Pins([string]$Root, [object]$Pins) {
    $map = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $Pins.PSObject.Properties) {
        $path = Resolve-CompilerEvidencePath -RepositoryRoot $Root -LiteralPath $entry.Name
        Assert-C527Baseline (-not $map.ContainsKey($path) -and $entry.Value -cmatch '^[A-Fa-f0-9]{64}$') 'C527_REPLAY_PIN_INVALID'
        $map.Add($path, $entry.Value.ToUpperInvariant())
    }
    return ,$map
}
function Get-C527HistoricalBaselineText {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot,
          [Parameter(Mandatory)][object]$OriginalEvidence,
          [AllowNull()][object]$Authority)
    $repo = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $mode = if ($null -eq $Authority) { 'observed-file' } else { $Authority.mode }
    if ($mode -ceq 'observed-file') {
        $path = Resolve-CompilerEvidencePath -RepositoryRoot $repo -LiteralPath $OriginalEvidence.baselineLlvm
        Assert-C527Baseline (Test-Path -LiteralPath $path -PathType Leaf) 'C527_ORIGINAL_BASELINE_MISSING'
        return [IO.File]::ReadAllText($path)
    }
    Assert-C527Baseline ($mode -ceq 'git-source-replay') 'C527_BASELINE_AUTHORITY_INVALID'
    foreach ($field in @('qualification', 'qualificationSha256', 'archiveRoot')) {
        Assert-C527Baseline ([bool]$Authority.PSObject.Properties[$field]) 'C527_REPLAY_REFERENCE_INVALID'
    }
    $archive = [IO.Path]::GetFullPath($Authority.archiveRoot, $repo).TrimEnd('\', '/')
    $prefix = $archive + [IO.Path]::DirectorySeparatorChar
    Assert-C527Baseline ($archive.StartsWith($repo + '\', [StringComparison]::OrdinalIgnoreCase)) 'C527_REPLAY_SCOPE_INVALID'
    $qualification = [IO.Path]::GetFullPath($Authority.qualification, $repo)
    Assert-C527Baseline ($qualification.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $qualification -PathType Leaf)) 'C527_REPLAY_QUALIFICATION_MISSING'
    Assert-C527Baseline ((Get-FileHash -LiteralPath $qualification -Algorithm SHA256).Hash -ceq $Authority.qualificationSha256) 'C527_REPLAY_QUALIFICATION_CHANGED'
    $q = Get-Content -LiteralPath $qualification -Raw | ConvertFrom-Json
    foreach ($field in @('schemaVersion','status','historicalCommit','originalBaselineRecovered','originalMissingBaseline',
            'originalFixture','originalFixtureSha256','isolatedOriginalFixture','fixtureCopy','baselineLlvm','baselineLlvmSha256',
            'baselineExe','originalReplayLlvm','requiredPredicate','expectedBadStdout','producer','historicalSourceFiles',
            'historicalSourceRoot','originalWorkspaceRoot','historicalStdlibSourceCount','producerBuildRecord','fixtureBuildRecord',
            'runtimeRecord','runtimeStdout','runtimeStderr','managedControlRecord','nativeControlRecord','originalControls',
            'currentSourceHashes','files')) {
        Assert-C527Baseline ([bool]$q.PSObject.Properties[$field]) 'C527_REPLAY_QUALIFICATION_INVALID'
    }
    $predicate = 'sitofp i32 4294967296 to double'
    $badOutput = 'value=0' + [char]10
    Assert-C527Baseline ($q.schemaVersion -eq 1 -and $q.status -ceq 'verified-git-source-replay' -and
        $q.historicalCommit -cmatch '^[a-f0-9]{40}$' -and $q.originalBaselineRecovered -eq $false -and
        $q.originalMissingBaseline -ceq $OriginalEvidence.baselineLlvm -and $q.requiredPredicate -ceq $predicate -and
        $q.expectedBadStdout -ceq $badOutput -and $q.originalFixture -ceq 'examples/regression/1872-interpolation-large-integer-to-float.slg' -and
        $q.originalFixtureSha256 -ceq '2EEBBFA63EE8005249B08D561F3C20CDA8564AE0A50046DDD5AE4F0413B6D3B9') 'C527_REPLAY_IDENTITY_INVALID'
    foreach ($file in $q.files.PSObject.Properties) {
        $path = [IO.Path]::GetFullPath($file.Name, $repo)
        Assert-C527Baseline ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
            $file.Value -cmatch '^[A-F0-9]{64}$' -and (Test-Path -LiteralPath $path -PathType Leaf)) 'C527_REPLAY_FILE_SCOPE_INVALID'
        Assert-C527Baseline ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ceq $file.Value) 'C527_REPLAY_FILE_CHANGED'
    }
    function Read-C527Core([string]$Path) {
        Assert-C527Baseline ([bool]$q.files.PSObject.Properties[$Path]) 'C527_REPLAY_UNPINNED_REFERENCE'
        Get-Content -LiteralPath ([IO.Path]::GetFullPath($Path, $repo)) -Raw | ConvertFrom-Json
    }
    $build = Read-C527Core $q.producerBuildRecord
    $compile = Read-C527Core $q.fixtureBuildRecord
    $runtime = Read-C527Core $q.runtimeRecord
    # Only their successful build stages are reused; failed aggregate receipts remain failed.
    Assert-C527Baseline ($build.compilerBuildExit -eq 0 -and $build.inputsStable -eq $true -and $build.processesStopped -eq $true -and
        $compile.fixtureBuildExit -eq 0 -and $compile.inputsStable -eq $true -and $compile.processesStopped -eq $true -and
        $runtime.status -ceq 'passed' -and $runtime.completed -eq 3 -and $runtime.total -eq 3 -and
        $runtime.inputsStable -eq $true -and $runtime.processesStopped -eq $true -and $runtime.fixtureRunExit -eq 0 -and
        $runtime.fixtureStdout -ceq $badOutput -and $runtime.actualLlvm -ceq $q.originalReplayLlvm -and
        $runtime.actualLlvmSha256 -ceq $q.baselineLlvmSha256 -and
        $build.historicalCommit -ceq $q.historicalCommit -and $compile.historicalCommit -ceq $q.historicalCommit -and
        $runtime.historicalCommit -ceq $q.historicalCommit) 'C527_REPLAY_STAGE_INVALID'
    $compilePins = Convert-C527Pins $repo $compile.inputHashes
    $runtimePins = Convert-C527Pins $repo $runtime.inputHashes
    $generatedPins = Convert-C527Pins $repo $build.generatedCompilerPins
    $oldFixtureRecord = Resolve-CompilerEvidencePath -RepositoryRoot $repo -LiteralPath $runtime.reusedSuccessfulFixtureBuildProof
    $oldProducerRecord = Resolve-CompilerEvidencePath -RepositoryRoot $repo -LiteralPath $compile.reusedCompilerBuildProof
    Assert-C527Baseline ($runtimePins.ContainsKey($oldFixtureRecord) -and
        $runtimePins[$oldFixtureRecord] -ceq $q.files.PSObject.Properties[$q.fixtureBuildRecord].Value -and
        $compilePins.ContainsKey($oldProducerRecord) -and
        $compilePins[$oldProducerRecord] -ceq $q.files.PSObject.Properties[$q.producerBuildRecord].Value) 'C527_REPLAY_STAGE_LINEAGE_CHANGED'
    Assert-C527Baseline (@($q.producer.PSObject.Properties).Count -eq 4) 'C527_REPLAY_PRODUCER_INVALID'
    foreach ($entry in $q.producer.PSObject.Properties) {
        $producer = $entry.Value
        Assert-C527Baseline ([bool]$q.files.PSObject.Properties[$producer.path] -and
            $q.files.PSObject.Properties[$producer.path].Value -ceq $producer.sha256 -and
            $generatedPins.ContainsKey($producer.originalPath) -and $generatedPins[$producer.originalPath] -ceq $producer.sha256 -and
            $compilePins.ContainsKey($producer.originalPath) -and $compilePins[$producer.originalPath] -ceq $producer.sha256) 'C527_REPLAY_PRODUCER_INVALID'
    }
    $producerExe = $q.producer.PSObject.Properties['Sollang.Compiler.exe'].Value.originalPath
    $dotnetBuild = @($build.processes | Where-Object {
        $_.command.Count -gt 1 -and [IO.Path]::GetFileName($_.command[0]).Equals('dotnet.exe', [StringComparison]::OrdinalIgnoreCase) -and $_.command[1] -ceq 'build'
    })
    Assert-C527Baseline ($dotnetBuild.Count -eq 1 -and $dotnetBuild[0].exit -eq 0 -and
        $dotnetBuild[0].command -ccontains ('/p:SourceRevisionId=' + $q.historicalCommit) -and
        @($compile.processes).Count -eq 1 -and $compile.processes[0].exit -eq 0 -and
        $compile.processes[0].command[0] -ceq $producerExe -and $compile.processes[0].command -ccontains $q.isolatedOriginalFixture -and
        @($runtime.processes).Count -eq 1 -and $runtime.processes[0].exit -eq 0) 'C527_REPLAY_COMMAND_INVALID'
    $llvmPin = Resolve-CompilerEvidencePath -RepositoryRoot $repo -LiteralPath $q.originalReplayLlvm
    Assert-C527Baseline ($runtimePins.ContainsKey($llvmPin) -and $runtimePins[$llvmPin] -ceq $q.baselineLlvmSha256 -and
        $q.files.PSObject.Properties[$q.baselineLlvm].Value -ceq $q.baselineLlvmSha256 -and
        [IO.Path]::ChangeExtension($runtime.processes[0].command[0], '.ll') -ceq $q.originalReplayLlvm) 'C527_REPLAY_BASELINE_PIN_INVALID'
    Assert-C527Baseline (@($q.historicalSourceFiles).Count -eq 260 -and
        @($q.historicalSourceFiles | Where-Object { $_.gitPath.StartsWith('stdlib/', [StringComparison]::Ordinal) }).Count -eq 143 -and
        $q.historicalStdlibSourceCount -eq 143) 'C527_REPLAY_SOURCE_INCOMPLETE'
    foreach ($source in $q.historicalSourceFiles) {
        $original = [IO.Path]::GetFullPath($source.gitPath, $q.historicalSourceRoot)
        Assert-C527Baseline ($compilePins.ContainsKey($original) -and $compilePins[$original] -ceq $source.sha256 -and
            $q.files.PSObject.Properties[$source.path].Value -ceq $source.sha256) 'C527_REPLAY_SOURCE_CHANGED'
    }
    Assert-C527Baseline ((Get-FileHash -LiteralPath (Join-Path $repo $q.originalFixture) -Algorithm SHA256).Hash -ceq $q.originalFixtureSha256 -and
        $q.files.PSObject.Properties[$q.fixtureCopy].Value -ceq $q.originalFixtureSha256 -and
        $compilePins.ContainsKey($q.isolatedOriginalFixture) -and $compilePins[$q.isolatedOriginalFixture] -ceq $q.originalFixtureSha256) 'C527_REPLAY_FIXTURE_CHANGED'
    $expectedIds = @('1872-interpolation-large-integer-to-float','1871-interpolation-separated-float-literal',
        '1870-interpolation-size-signed-float-conversion','1801-numeric-conversion-matrix','1873-interpolation-large-signed-float-literals')
    Assert-C527Baseline ((@($q.originalControls.fixture) -join '|') -ceq ($expectedIds -join '|')) 'C527_REPLAY_ORACLE_SET_INVALID'
    $managed = Read-C527Core $q.managedControlRecord
    $native = Read-C527Core $q.nativeControlRecord
    foreach ($entry in @(@{ proof=$managed; mode='managed' }, @{ proof=$native; mode='paired' })) {
        $proof = $entry.proof
        Assert-C527Baseline ($proof.status -ceq 'passed' -and $proof.mode -ceq $entry.mode -and $proof.completed -eq 5 -and $proof.total -eq 5 -and
            $proof.inputsStable -eq $true -and $proof.processesStopped -eq $true -and
            (@($proof.cases.id) -join '|') -ceq ($expectedIds -join '|')) 'C527_REPLAY_CURRENT_CONTROLS_INCOMPLETE'
        $pins = Convert-C527Pins $repo $proof.inputHashes
        foreach ($oracle in $q.originalControls) {
            $pair = Read-C527Core $oracle.originalPairArchive
            $oldRuns = @($pair.runs | Where-Object fixture -ceq $oracle.fixture)
            $source = [IO.Path]::GetFullPath($oracle.source, $repo)
            $recordedSource = [IO.Path]::GetFullPath($oracle.source, $q.originalWorkspaceRoot)
            $expected = [IO.File]::ReadAllText((Join-Path $repo $oracle.oracle)).Trim()
            $case = @($proof.cases | Where-Object id -ceq $oracle.fixture)
            Assert-C527Baseline ($pair.status -ceq 'passed' -and $pair.inputStable -eq $true -and $pair.completed -eq $pair.total -and
                $oldRuns.Count -eq 2 -and @($oldRuns | Where-Object { $_.sourceSha256 -cne $oracle.sourceSha256 -or $_.stdoutSha256 -cne $oracle.oracleSha256 }).Count -eq 0 -and
                $q.files.PSObject.Properties[$oracle.oracle].Value -ceq $oracle.oracleSha256 -and
                (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ceq $oracle.sourceSha256 -and
                $pins.ContainsKey($recordedSource) -and $pins[$recordedSource] -ceq $oracle.sourceSha256 -and
                $case.Count -eq 1 -and $case[0].passed -eq $true -and $case[0].status -ceq 'passed' -and
                $case[0].buildExit -eq 0 -and $case[0].runExit -eq 0 -and $case[0].runStdout -ceq $expected -and
                $case[0].buildStderr -ceq '' -and $case[0].runStderr -ceq '') 'C527_REPLAY_ORIGINAL_ORACLE_CHANGED'
        }
    }
    foreach ($source in $q.currentSourceHashes.PSObject.Properties) {
        Assert-C527Baseline ((Get-FileHash -LiteralPath (Join-Path $repo $source.Name) -Algorithm SHA256).Hash -ceq $source.Value) 'C527_REPLAY_CURRENT_SOURCE_CHANGED'
    }
    $stdout = [IO.File]::ReadAllText((Join-Path $repo $q.runtimeStdout)).Replace(([string][char]13 + [char]10), [string][char]10)
    Assert-C527Baseline ($stdout -ceq $badOutput -and (Get-Item -LiteralPath (Join-Path $repo $q.runtimeStderr)).Length -eq 0) 'C527_REPLAY_BAD_RUNTIME_NOT_OBSERVED'
    $text = [IO.File]::ReadAllText((Join-Path $repo $q.baselineLlvm))
    Assert-C527Baseline ($text.Contains($predicate, [StringComparison]::Ordinal)) 'C527_REPLAY_BAD_LLVM_NOT_OBSERVED'
    return $text
}
