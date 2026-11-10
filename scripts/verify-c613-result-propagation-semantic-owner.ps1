[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OwnerEvidence = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-C613ExpectedDiagnostic([string]$CurrentRoot, $Negative) {
    $sourceName = [IO.Path]::GetFileName([string]$Negative.source)
    $expectedName = [IO.Path]::ChangeExtension($sourceName, '.stderr.contains.txt')
    if ([IO.Path]::GetExtension($sourceName) -cne '.slg' -or
        [IO.Path]::GetFileName([string]$Negative.expected) -cne $expectedName) {
        throw 'C613 historical diagnostic source/expectation identity differs'
    }
    $expectedPath = ''
    foreach ($entry in @(
        @{ recorded = $Negative.source; name = $sourceName; hash = $Negative.sourceSha256 },
        @{ recorded = $Negative.expected; name = $expectedName; hash = $Negative.expectedSha256 }
    )) {
        $relative = [IO.Path]::Combine('examples', 'regression', 'diagnostics', $entry.name)
        $canonical = [IO.Path]::GetFullPath([IO.Path]::Combine($CurrentRoot, $relative))
        $historical = [IO.Path]::Combine('P:\MyWorks\Sollang', $relative)
        $recorded = [IO.Path]::GetFullPath([string]$entry.recorded)
        if (($recorded -ine $canonical -and $recorded -ine $historical) -or
            [string]$entry.hash -notmatch '^[0-9A-Fa-f]{64}$' -or
            (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash -ine $entry.hash) {
            throw 'C613 historical diagnostic canonical path or pinned bytes differ'
        }
        $expectedPath = $canonical
    }
    return $expectedPath
}
function Resolve-C613OwnedPath([string]$CurrentRoot, [string]$Name) {
    $path = [IO.Path]::GetFullPath([IO.Path]::Combine($CurrentRoot, $Name))
    if (-not $path.StartsWith($CurrentRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'C613 evidence path leaves the repository'
    }
    return $path
}
function Read-C613OwnedRecord([string]$CurrentRoot, [string]$Name) {
    $path = Resolve-C613OwnedPath $CurrentRoot $Name
    return [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
}
function Assert-C613CurrentOriginalControls([string]$CurrentRoot, $Owner, $Paired) {
    $requiredSources = @(
        'selfhost/semantic/interpolation_inference.slg',
        'selfhost/llvm/text/context_prepare.slg',
        'selfhost/ir/typed/function_lowering.slg',
        'selfhost/llvm/codegen_compilation_functions.slg',
        'selfhost/llvm/codegen_ir_specializations.slg'
    )
    $mappedSources = @($Owner.sourceMapping | ForEach-Object { $_.canonical })
    if ($mappedSources.Count -ne 5 -or
        @($mappedSources | Select-Object -Unique).Count -ne 5 -or
        @(Compare-Object $requiredSources $mappedSources).Count -ne 0 -or
        @($Owner.sourceMapping | Where-Object { $_.source -cne $_.canonical }).Count -ne 0) {
        throw 'C613 current semantic source ownership scope differs'
    }
    $originalPath = Resolve-C613OwnedPath $CurrentRoot 'scripts/contracts/evidence/source13293/block24358-c613-current/contract.json'
    $contractPath = Resolve-C613OwnedPath $CurrentRoot $Owner.currentContract
    $managedPath = Resolve-C613OwnedPath $CurrentRoot $Owner.managedFirst
    $original = Read-C613OwnedRecord $CurrentRoot $originalPath
    $contract = Read-C613OwnedRecord $CurrentRoot $contractPath
    $managedProof = Read-C613OwnedRecord $CurrentRoot $managedPath
    $buildPath = Resolve-C613OwnedPath $CurrentRoot $Owner.nativeBuild
    $birth = Read-C613OwnedRecord $CurrentRoot $buildPath
    $compilerPath = Join-Path ([IO.Path]::GetDirectoryName($buildPath)) 'compiler.exe'
    $managedCompiler = [IO.Path]::GetFullPath($managedProof.managedCompiler)
    $managedDll = [IO.Path]::ChangeExtension($managedCompiler, '.dll')
    $compilerHash = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
    $managedHash = (Get-FileHash -LiteralPath $managedCompiler -Algorithm SHA256).Hash
    $managedDllHash = (Get-FileHash -LiteralPath $managedDll -Algorithm SHA256).Hash
    $seedMatches = $false
    if ($null -ne $birth.PSObject.Properties['seedCompilerSha256']) {
        $seedMatches = $birth.seedCompilerSha256 -ceq $managedHash
    } elseif ($birth.phaseMode -ceq 'explicit-separated-emission-and-production-link') {
        $manifest = Join-Path $CurrentRoot 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
        $sourceCount = @([IO.File]::ReadAllLines($manifest, [Text.Encoding]::UTF8) | Where-Object { $_.Trim() }).Count
        $seedMatches = $birth.emission.status -ceq 'passed' -and $birth.emission.mode -ceq 'emit' -and
            $birth.emission.sourceCount -eq $sourceCount -and $birth.link.status -ceq 'passed' -and $birth.link.mode -ceq 'link' -and
            $birth.emission.compilerAssemblySha256 -ceq $managedDllHash -and $birth.link.compilerAssemblySha256 -ceq $managedDllHash -and
            $birth.inputHashesStart.PSObject.Properties[$managedCompiler].Value -ceq $managedHash -and
            $birth.inputHashesStart.PSObject.Properties[$managedDll].Value -ceq $managedDllHash
    }
    if ($birth.status -cne 'passed' -or -not $birth.inputsStable -or -not $birth.processesStopped -or
        $birth.compilerSha256 -cne $compilerHash -or $Owner.compilerSha256 -cne $compilerHash -or
        -not $seedMatches -or
        $Paired.managedCompiler -cne $managedCompiler -or
        $Paired.managedCompilerDllSha256 -cne $managedDllHash -or $managedProof.managedCompilerDllSha256 -cne $managedDllHash -or
        $contract.expectedManagedDllSha256 -cne $managedDllHash -or
        $Paired.inputHashes.PSObject.Properties[$buildPath].Value -cne (Get-FileHash -LiteralPath $buildPath -Algorithm SHA256).Hash -or
        $Paired.inputHashes.PSObject.Properties[$compilerPath].Value -cne $compilerHash -or
        $managedProof.inputHashes.PSObject.Properties[$managedCompiler].Value -cne $managedHash -or
        $managedProof.inputHashes.PSObject.Properties[$managedDll].Value -cne $managedDllHash) {
        throw 'C613 current compiler producer or managed-first identity differs'
    }
    # Reuse the same canonical source-closure admission as the paired runner.
    & python -c 'import sys,json; from pathlib import Path; sys.path.insert(0,sys.argv[1]); from verification_source_proof import current_build_inputs; current_build_inputs(Path(sys.argv[2]),json.loads(Path(sys.argv[3]).read_bytes()))' (Join-Path $CurrentRoot 'scripts') $CurrentRoot $buildPath
    if ($LASTEXITCODE -ne 0) {
        throw 'C613 current compiler source proof is incomplete or changed'
    }
    $originalHash = (Get-FileHash -LiteralPath $originalPath -Algorithm SHA256).Hash
    if ($originalHash -cne $Owner.originalContractSha256 -or
        $contract.previousContractSha256 -cne $originalHash -or
        @($original.cases).Count -ne 12 -or
        ($original.cases | ConvertTo-Json -Depth 100 -Compress) -cne ($contract.cases | ConvertTo-Json -Depth 100 -Compress)) {
        throw 'C613 original twelve-case source and oracle contract differs'
    }
    if ($Paired.inputHashes.PSObject.Properties[$managedPath].Value -cne (Get-FileHash -LiteralPath $managedPath -Algorithm SHA256).Hash) {
        throw 'C613 paired proof does not bind the managed-first execution'
    }
    $priorManagedPath = Resolve-C613OwnedPath $CurrentRoot 'scripts/contracts/evidence/source13293/block24358-c613-current/managed-result.json'
    $priorManaged = Read-C613OwnedRecord $CurrentRoot $priorManagedPath
    $expectedContractHash = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash
    foreach ($role in @(@{ mode = 'managed'; proof = $managedProof }, @{ mode = 'paired'; proof = $Paired })) {
        $proof = $role.proof
        if ($proof.status -cne 'passed' -or $proof.mode -cne $role.mode -or
            -not $proof.inputsStable -or -not $proof.processesStopped -or
            $proof.completed -ne 12 -or $proof.total -ne 12 -or @($proof.cases).Count -ne 12 -or
            $proof.inputHashes.PSObject.Properties[$contractPath].Value -cne $expectedContractHash -or
            @($proof.processes).Count -eq 0 -or
            @($proof.processes | Where-Object { -not $_.shutdownConfirmed }).Count -ne 0 -or
            @($proof.generatedOutputHashes.PSObject.Properties).Count -eq 0) {
            throw 'C613 current twelve-case execution or output inventory is incomplete'
        }
        foreach ($pin in $proof.inputHashes.PSObject.Properties) {
            if (-not (Test-Path -LiteralPath $pin.Name -PathType Leaf) -or
                (Get-FileHash -LiteralPath $pin.Name -Algorithm SHA256).Hash -cne $pin.Value) {
                throw "C613 current execution input changed: $($pin.Name)"
            }
        }
        for ($index = 0; $index -lt 12; $index++) {
            $expectedCase = $contract.cases[$index]
            $observed = $proof.cases[$index]
            $source = Resolve-C613OwnedPath $CurrentRoot $expectedCase.source
            $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
            if ($priorManaged.inputHashes.PSObject.Properties[$source].Value -cne $sourceHash -or
                $proof.inputHashes.PSObject.Properties[$source].Value -cne $sourceHash -or
                $observed.id -cne $expectedCase.id -or $observed.status -cne 'passed' -or -not $observed.passed -or
                $observed.expectedBuildExit -ne $expectedCase.exit -or $observed.buildExit -ne $expectedCase.exit -or
                $observed.buildStderr -cne $expectedCase.stderr -or $observed.wholeCaseBudgetSeconds -ne 180) {
                throw 'C613 exact source identity, diagnostic, or case budget differs'
            }
            $expectedCompiler = if ($role.mode -ceq 'managed') { $managedCompiler } else { $compilerPath }
            $builds = @($proof.processes | Where-Object {
                $_.command.Count -gt 2 -and $_.command[0] -ceq $expectedCompiler -and
                $_.command[1] -ceq 'build' -and [IO.Path]::GetFullPath($_.command[2]) -ieq $source
            })
            if ($builds.Count -ne 1 -or $builds[0].exit -ne $expectedCase.exit) {
                throw 'C613 build process is not bound to its compiler and original source'
            }
            if ($expectedCase.exit -eq 0) {
                if ($observed.runExit -ne 0 -or $observed.runStdout -cne $expectedCase.stdout -or $observed.runStderr -cne '') {
                    throw 'C613 exact positive runtime output differs'
                }
            } elseif ($null -ne $observed.PSObject.Properties['runExit'] -and $null -ne $observed.runExit) {
                throw 'C613 rejected source must not execute'
            }
            if ($expectedCase.id -match '^208[2-5]-') {
                $expectedPath = [IO.Path]::ChangeExtension($source, '.stderr.contains.txt')
                $expectedDiagnostic = [IO.File]::ReadAllText($expectedPath, [Text.Encoding]::UTF8).Replace("`r`n", "`n").TrimEnd("`n")
                if (-not $observed.buildStderr.Contains($expectedDiagnostic, [StringComparison]::Ordinal)) {
                    throw 'C613 original negative diagnostic differs'
                }
                $outputIndex = [array]::IndexOf($builds[0].command, '-o')
                if ($outputIndex -lt 0 -or $outputIndex + 1 -ge $builds[0].command.Count) {
                    throw 'C613 negative output owner is missing'
                }
                $folder = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($builds[0].command[$outputIndex + 1]))
                $executable = [IO.Path]::GetFullPath($builds[0].command[$outputIndex + 1])
                if (@($proof.processes | Where-Object {
                    $_.command.Count -gt 0 -and [IO.Path]::GetFullPath($_.command[0]) -ieq $executable
                }).Count -ne 0) {
                    throw 'C613 rejected source has a runtime process'
                }
                $prefix = $folder.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
                $recorded = @($proof.generatedOutputHashes.PSObject.Properties | Where-Object {
                    $_.Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
                })
                $remaining = @(Get-ChildItem -LiteralPath $folder -Recurse -File | Where-Object {
                    $_.Name -match '\.(ll|bc\d*|obj|o|exe|dll|pdb|lib|a|wasm)$'
                })
                if ($recorded.Count -ne 0 -or $remaining.Count -ne 0) {
                    throw 'C613 original negative source emitted a product'
                }
            }
        }
    }
}
$unit = Get-Content -LiteralPath (Join-Path $root 'artifacts/scratch/c613-result-propagation-semantic-owner-unit-20260929-01.json') -Raw | ConvertFrom-Json
$focused = $unit.steps[3]
$managed = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'))
$semantic = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
$preparation = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/context_prepare.slg'))
$context = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/emitter/context.slg'))
$diagnostics = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/emitter/diagnostics.slg'))
$emitter = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/foundation.slg'))
$interpolation = [IO.File]::ReadAllText((Join-Path $root 'selfhost/ir/interpolation.slg'))
$goal = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/active-goal-progress.json') -Raw | ConvertFrom-Json
$ownerPath = if ($OwnerEvidence) { $OwnerEvidence } else { $goal.currentResultPropagationOwnerEvidence }
$owner = Read-C613OwnedRecord $root $ownerPath
$currentScope = $null -ne $owner.PSObject.Properties['verificationScope']
if ($currentScope -and $owner.verificationScope -cne 'original12-current-input') {
    throw 'C613 current verification scope is unsupported'
}
if (-not $currentScope) {
    $managedFirst = Get-Content -LiteralPath $unit.steps[0].evidence -Raw | ConvertFrom-Json
    $build = Get-Content -LiteralPath $unit.steps[2].evidence -Raw | ConvertFrom-Json
    $positive = Get-Content -LiteralPath $focused.positiveEvidence -Raw | ConvertFrom-Json
}
if ($owner.status -cne 'canonical-single-result-owner-focused-verified') {
    throw 'Current pre-IR Result owner has not completed its focused runtime verification'
}
$currentProof = Get-Content -LiteralPath (Join-Path $root $owner.runtimeProof) -Raw | ConvertFrom-Json
if ($currentProof.status -cne 'passed' -or -not $currentProof.inputsStable -or
    -not $currentProof.processesStopped -or $currentProof.completed -ne $currentProof.total -or
    $currentProof.total -ne 12) {
    throw 'Current Result owner production proof is incomplete'
}
foreach ($inputHash in $currentProof.inputHashes.PSObject.Properties) {
    if (-not (Test-Path -LiteralPath $inputHash.Name -PathType Leaf) -or
        (Get-FileHash -LiteralPath $inputHash.Name -Algorithm SHA256).Hash -cne $inputHash.Value) {
        throw "Current Result owner production input changed: $($inputHash.Name)"
    }
}
foreach ($mapping in $owner.sourceMapping) {
    $canonicalPath = [IO.Path]::GetFullPath((Join-Path $root $mapping.canonical))
    $candidatePath = [IO.Path]::GetFullPath((Join-Path $root $mapping.source))
    $input = $currentProof.inputHashes.PSObject.Properties[$candidatePath]
    if ((Get-FileHash -LiteralPath $canonicalPath -Algorithm SHA256).Hash -cne $mapping.afterSha256 -or
        $null -eq $input -or $input.Value -cne $mapping.afterSha256) {
        throw 'Current Result owner source differs from its production proof'
    }
}

if ($unit.completed -ne 4 -or $unit.total -ne 4 -or
    @($unit.steps | Where-Object status -ne 'complete').Count -ne 0) {
    throw 'C613 historical source-decision declaration is incomplete'
}
if (-not $currentScope -and ($managedFirst.status -cne 'passed' -or -not $managedFirst.inputsStable -or
    $managedFirst.completed -ne 5 -or $managedFirst.total -ne 5 -or
    $build.status -cne 'passed' -or -not $build.inputsStable -or
    $positive.status -cne 'passed' -or -not $positive.inputStable -or
    $positive.completed -ne 2 -or $positive.total -ne 2 -or
    @($positive.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0)) {
    throw 'C613 historical focused evidence is incomplete'
}
if (-not $managed.Contains('private BoundType InferTryExpression(', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public preIrResultPropagationDecisionByNode', [StringComparison]::Ordinal) -or
    $semantic.Contains('public resultPropagationDecisionByNode', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('interpolationLexicalTypeFromIr', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationResultPropagationByNode: preIrResultPropagationDecisions', [StringComparison]::Ordinal) -or
    $preparation.Contains('interpolationInference.resultPropagationDecisionByNode(', [StringComparison]::Ordinal) -or
    -not $context.Contains('public interpolationResultPropagationByNode:', [StringComparison]::Ordinal) -or
    -not $diagnostics.Contains('context.interpolationResultPropagationByNode[interpolationIndex!].status > 0', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('decision.operandTypeId => resultTypeId', [StringComparison]::Ordinal) -or
    -not $interpolation.Contains('(loweredKind! == 3 or loweredKind! == 11)', [StringComparison]::Ordinal) -or
    $diagnostics.Contains('C613_PROBE', [StringComparison]::Ordinal)) {
    throw 'C613 Result propagation semantic ownership, source structure, or positive proof failed'
}

if ($currentScope) {
    Assert-C613CurrentOriginalControls $root $owner $currentProof
    Write-Host '[C613 Result propagation semantic owner] PASS current original12 on both compilers, original negative4 before LLVM, and current single pre-IR owner. Historical user-profile receipts are not relabeled as replayed; whole source/Stage gates remain separate.'
    return
}
foreach ($path in $focused.negativeEvidence) {
    $negative = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent $path
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    $expectedPath = Resolve-C613ExpectedDiagnostic $root $negative
    $expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $null -ne $negative.failureId -or
        $negative.selfhostCompilerSha256 -cne $build.compilerSha256 -or
        $negative.managed.exitCode -ne 1 -or $negative.selfhost.exitCode -ne 1 -or
        -not $negative.managed.noEmittedProducts -or -not $negative.selfhost.noEmittedProducts -or
        $managedStderr -cne $selfhostStderr -or
        -not $managedStderr.Contains($expected, [StringComparison]::Ordinal)) {
        throw "C613 exact Result propagation diagnostic mismatch: $path"
    }
}

Write-Host '[C613 Result propagation semantic owner] PASS historical C613 controls retained; current single pre-IR owner source matches focused production 12/12. Full native CLI and Stage gates remain separate.'
