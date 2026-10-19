[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$repository = Split-Path -Parent $PSScriptRoot
$root = Join-Path $repository "artifacts/scratch/native-exact-phase-test-$([guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($root)
$passed = [Collections.Generic.List[string]]::new()
function Assert-Rejected([string]$Id, [scriptblock]$Action, [string]$Expected) {
    try { & $Action; throw "TEST_EXPECTED_REJECTION: $Id" }
    catch { if (-not $_.Exception.Message.Contains($Expected, [StringComparison]::Ordinal)) { throw } }
    $passed.Add($Id)
}
function Save-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
}
$llvmContractsRoot = Join-Path $root 'producer-contracts'
[void][IO.Directory]::CreateDirectory($llvmContractsRoot)
$managedLlvm = Join-Path $llvmContractsRoot 'managed.ll'
$selfhostLlvm = Join-Path $llvmContractsRoot 'selfhost.ll'
$managedCounts = Join-Path $llvmContractsRoot 'profile.llvm.regex-counts.txt'
[IO.File]::WriteAllText($managedLlvm, "; managed-marker`n; native-only-marker`n")
[IO.File]::WriteAllText($selfhostLlvm, "; selfhost-marker`n")
[IO.File]::WriteAllText($managedCounts, "1`t(?m)^; managed-marker$`n")
[IO.File]::WriteAllText((Join-Path $llvmContractsRoot 'profile.selfhost.llvm.regex-counts.txt'), "1`t(?m)^; selfhost-marker$`n")
[IO.File]::WriteAllText((Join-Path $llvmContractsRoot 'profile.selfhost.llvm.not-contains.txt'), 'native-only-marker')
$managedProfile = Get-NativeExactLlvmContracts -ExpectedRoot $llvmContractsRoot -Fixture profile -CompilerIsManagedDll $true
$selfhostProfile = Get-NativeExactLlvmContracts -ExpectedRoot $llvmContractsRoot -Fixture profile -CompilerSide selfhost
Assert-NativeExactLlvmContracts -LlvmPath $managedLlvm -Contracts $managedProfile
Assert-NativeExactLlvmContracts -LlvmPath $selfhostLlvm -Contracts $selfhostProfile
$passed.Add('managed-and-selfhost-use-their-own-llvm-contracts')
Assert-Rejected 'managed-rejects-wrong-producer-contract' {
    Assert-NativeExactLlvmContracts -LlvmPath $selfhostLlvm -Contracts $managedProfile
} 'EXACT_LLVM_REGEX_COUNT'
Assert-Rejected 'selfhost-retains-native-forbidden-contract' {
    Assert-NativeExactLlvmContracts -LlvmPath $managedLlvm -Contracts $selfhostProfile
} 'EXACT_LLVM_FORBIDDEN_TEXT'
Assert-Rejected 'managed-dll-cannot-declare-selfhost' {
    Get-NativeExactLlvmContracts -ExpectedRoot $llvmContractsRoot -Fixture profile -CompilerIsManagedDll $true -CompilerSide selfhost
} 'EXACT_LLVM_PRODUCER_IDENTITY_CONFLICT'
Assert-Rejected 'managed-apphost-needs-phase-identity' {
    Get-NativeExactLlvmContracts -ExpectedRoot $llvmContractsRoot -Fixture profile -CompilerSide managed
} 'EXACT_LLVM_MANAGED_APPHOST_REQUIRES_PHASE_IDENTITY'
[IO.File]::WriteAllText($managedCounts, " `n")
Assert-Rejected 'empty-llvm-contract-does-not-disable-check' {
    Assert-NativeExactLlvmContracts -LlvmPath $managedLlvm -Contracts $managedProfile
} 'EXACT_LLVM_EMPTY_REGEX_COUNTS'
[IO.File]::WriteAllText($managedCounts, "1`t(?m)^; managed-marker$`n")
$external = Join-Path $env:LOCALAPPDATA "Sollang/verification/phase-path-test-$([guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($external)
$externalFile = Join-Path $external 'proof.txt'
[IO.File]::WriteAllText($externalFile, 'owned external evidence')
$externalReference = Get-NativeExactPhaseReference $repository $externalFile
if ($externalReference.path -cne [IO.Path]::GetFullPath($externalFile).Replace('\', '/') -or
    (Assert-NativeExactPhaseOutputPath $repository (Join-Path $external 'next')) -cne (Join-Path $external 'next')) {
    throw 'TEST_EXTERNAL_PHASE_PATH_IDENTITY'
}
$passed.Add('owned-external-phase-path')
Assert-Rejected 'external-sibling-rejected' {
    Assert-NativeExactPhaseOutputPath $repository (Join-Path $env:LOCALAPPDATA 'Sollang-other/proof.json')
} 'PHASE_EXECUTION_OUTPUT_BOUNDARY'
Assert-Rejected 'external-parent-escape-rejected' {
    Assert-NativeExactPhaseOutputPath $repository (Join-Path $external '../../../escaped.json')
} 'PHASE_EXECUTION_OUTPUT_BOUNDARY'
Remove-Item -LiteralPath $externalFile
Remove-Item -LiteralPath $external
# Synthetic authority is isolated here; operational commands below are tiny OS
# children, never compiler builds or phase promotion of these regression files.
$fixture = Join-Path $root 'fixture.slg'; [IO.File]::WriteAllText($fixture, 'test source')
$compiler = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$contractPath = Join-Path $root 'contract.json'
$case = [pscustomobject]@{id='positive';fixture=(Get-NativeExactPhaseReference $repository $fixture);decisionIds=@('test');
    expectedStages=[pscustomobject]@{compile=[pscustomobject]@{exitCode=0;stdout='';stderr=''};run=[pscustomobject]@{exitCode=0;stdout="actual`r`n";stderr=''}}}
Save-Json $contractPath @{schemaVersion=1;cases=@($case)}
$context = [pscustomobject]@{Root=$repository;CompilerSide='managed';
    Contract=[pscustomobject]@{phase='test';cases=@($case);evidenceDirectory=[IO.Path]::GetRelativePath($repository,$root)};
    CompilerBinary=@{path=$compiler;sha256=(Get-FileHash $compiler).Hash.ToLowerInvariant()};
    InputHashes=(Get-NativeExactPhaseHashes $repository @($fixture,$contractPath,$PSCommandPath))}
$prefix = Get-NativeExactPhaseOutcomePrefix $context $case
$binary = Join-Path $root 'product.exe'
$compileChild = Join-Path $root 'compile-child.ps1'
[IO.File]::WriteAllText($compileChild, 'param($Destination,$Fixture) Copy-Item -LiteralPath "$env:SystemRoot/System32/cmd.exe" -Destination $Destination')
$pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$start = Get-NativeExactPhaseCommandInputs $context @($compileChild)
$compileRecord = Join-Path $root 'compile.execution.json'
$null = Invoke-VerificationProcessCapture -FilePath $pwsh -ArgumentList @('-NoProfile','-File',$compileChild,$binary,$fixture) -Description 'phase regression compile child' -TimeoutMilliseconds 10000 -ExecutionRecordPath $compileRecord
$null = Write-NativeExactPhaseOutcome $context $case compile $compileRecord $prefix $binary -InputHashesStart $start
$runStart = Get-NativeExactPhaseCommandInputs $context @($binary)
$runRecord = Join-Path $root 'run.execution.json'
$null = Invoke-VerificationProcessCapture -FilePath $binary -ArgumentList @('/d','/c','echo actual') -Description 'phase regression run child' -TimeoutMilliseconds 10000 -ExecutionRecordPath $runRecord
$null = Write-NativeExactPhaseOutcome $context $case run $runRecord $prefix $binary -InputHashesStart $runStart
$run = Get-Content "$prefix.run.json" -Raw | ConvertFrom-Json
if ($run.executableBinary.sha256 -ine (Get-FileHash $binary).Hash -or $run.compilerSide -cne 'managed' -or $run.stage -cne 'run') { throw 'TEST_ACTUAL_LINKAGE_FAILED' }
$passed.Add('normal-positive')

# Same exact process and input contract, with evidence in the owned external root.
[void][IO.Directory]::CreateDirectory($external)
$externalContext = [pscustomobject]@{Root=$repository;CompilerSide='managed';
    Contract=[pscustomobject]@{phase='test';cases=@($case);evidenceDirectory=$external};
    CompilerBinary=$context.CompilerBinary;InputHashes=$context.InputHashes}
$externalLink = Join-Path $external 'linked'
$null = New-Item -ItemType Junction -Path $externalLink -Target $root
Assert-Rejected 'external-reparse-file-rejected' { Get-NativeExactPhaseFile $repository (Join-Path $externalLink 'fixture.slg') } 'PHASE_EXECUTION_REPARSE_POINT'
Assert-Rejected 'external-reparse-output-rejected' { Assert-NativeExactPhaseOutputPath $repository (Join-Path $externalLink 'future.json') } 'PHASE_EXECUTION_OUTPUT_REPARSE_POINT'
if (-not [IO.Path]::GetFullPath($externalLink).StartsWith([IO.Path]::GetFullPath($external) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'TEST_LINK_CLEANUP_BOUNDARY' }
Remove-Item -LiteralPath $externalLink
$externalPrefix = Get-NativeExactPhaseOutcomePrefix $externalContext $case
$externalBinary = Join-Path $external 'product.exe'
$externalCompile = Join-Path $external 'compile.execution.json'
$externalStart = Get-NativeExactPhaseCommandInputs $externalContext @($compileChild)
$null = Invoke-VerificationProcessCapture -FilePath $pwsh -ArgumentList @('-NoProfile','-File',$compileChild,$externalBinary,$fixture) -Description 'external phase compile child' -TimeoutMilliseconds 10000 -ExecutionRecordPath $externalCompile
$null = Write-NativeExactPhaseOutcome $externalContext $case compile $externalCompile $externalPrefix $externalBinary -InputHashesStart $externalStart
$externalRun = Join-Path $external 'run.execution.json'
$externalStart = Get-NativeExactPhaseCommandInputs $externalContext @($externalBinary)
$null = Invoke-VerificationProcessCapture -FilePath $externalBinary -ArgumentList @('/d','/c','echo actual') -Description 'external phase run child' -TimeoutMilliseconds 10000 -ExecutionRecordPath $externalRun
$externalOutcome = Write-NativeExactPhaseOutcome $externalContext $case run $externalRun $externalPrefix $externalBinary -InputHashesStart $externalStart
$externalReadback = Read-NativeExactPhaseReference $repository ([pscustomobject]$externalOutcome)
if ($externalReadback.actualStdout -cne "actual`r`n" -or $externalReadback.executableBinary.sha256 -ine (Get-FileHash $externalBinary).Hash) { throw 'TEST_EXTERNAL_PROCESS_LINKAGE' }
$passed.Add('external-real-process-receipts')
[IO.File]::AppendAllText("$externalPrefix.run.json", ' ')
Assert-Rejected 'external-evidence-drift-rejected' { Read-NativeExactPhaseReference $repository ([pscustomobject]$externalOutcome) } 'PHASE_EXECUTION_REFERENCE_DRIFT'
Remove-Item -LiteralPath $externalBinary

$negative = [pscustomobject]@{id='negative';fixture=$case.fixture;expectedStages=[pscustomobject]@{compile=[pscustomobject]@{exitCode=1;stdout='';stderr="actual rejection`n"}}}
$negativeRecord = Join-Path $root 'negative.execution.json'
$negativeChild = Join-Path $root 'negative-child.ps1'
[IO.File]::WriteAllText($negativeChild, 'param($Fixture) [Console]::Error.Write("actual rejection"+[char]10); exit 1')
$negativeStart = Get-NativeExactPhaseCommandInputs $context @($negativeChild)
$null = Invoke-VerificationProcessCapture -FilePath $pwsh -ArgumentList @('-NoProfile','-File',$negativeChild,$fixture) -Description 'phase regression negative child' -TimeoutMilliseconds 10000 -ExecutionRecordPath $negativeRecord
$null = Write-NativeExactPhaseOutcome $context $negative compile $negativeRecord (Join-Path $root 'negative') -InputHashesStart $negativeStart
$passed.Add('normal-negative')
# Exact side-specific oracles use actual isolated OS children; no compiler/phase proof.
$sideCase = [pscustomobject]@{id='side-positive';fixture=$case.fixture;expectedStages=[pscustomobject]@{
    compile=[pscustomobject]@{compilerSides=[pscustomobject]@{
        managed=[pscustomobject]@{exitCode=0;stdout="managed build`n";stderr=''}
        selfhost=[pscustomobject]@{exitCode=0;stdout="selfhost build`n";stderr=''}}}
    run=$case.expectedStages.run}}
$sideChild=Join-Path $root 'side-compile-child.ps1'
[IO.File]::WriteAllText($sideChild, 'param($Destination,$Fixture,$Side) Copy-Item -LiteralPath "$env:SystemRoot/System32/cmd.exe" -Destination $Destination; [Console]::Write($Side+" build"+[char]10)')
foreach ($side in @('managed','selfhost')) {
    $context.CompilerSide=$side
    $sideBinary=Join-Path $root "$side-product.exe"
    $sideRecord=Join-Path $root "$side.execution.json"
    $sideStart=Get-NativeExactPhaseCommandInputs $context @($sideChild)
    $null=Invoke-VerificationProcessCapture -FilePath $pwsh -ArgumentList @('-NoProfile','-File',$sideChild,$sideBinary,$fixture,$side) -Description 'exact compile side regression child' -TimeoutMilliseconds 10000 -ExecutionRecordPath $sideRecord
    $null=Write-NativeExactPhaseOutcome $context $sideCase compile $sideRecord (Join-Path $root "$side-exact") $sideBinary -InputHashesStart $sideStart
    $other=if($side -ceq 'managed'){'selfhost'}else{'managed'}
    $context.CompilerSide=$other
    Assert-Rejected "wrong-side-$side" { Write-NativeExactPhaseOutcome $context $sideCase compile $sideRecord (Join-Path $root "$side-wrong") $sideBinary -InputHashesStart $sideStart } 'PHASE_EXECUTION_EXACT_OUTCOME_MISMATCH'
    # Safe deletion of this successful test-only generated binary within exact test root.
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($sideBinary)) -cne [IO.Path]::GetFullPath($root)) { throw 'TEST_OUTPUT_BOUNDARY' }
    Remove-Item -LiteralPath $sideBinary
}
$context.CompilerSide='managed'
$passed.Add('distinct-positive-side-oracles')
$fullSchema=Get-Content (Join-Path $PSScriptRoot 'contracts/native-exact-phase-execution.schema.json') -Raw | ConvertFrom-Json -AsHashtable
$stageSchema=@{'$schema'=$fullSchema['$schema'];'$defs'=$fullSchema['$defs']} + $fullSchema.properties.cases.items.properties.expectedStages
if (-not (Test-Json -Json ($sideCase.expectedStages | ConvertTo-Json -Depth 20) -Schema ($stageSchema | ConvertTo-Json -Depth 30))) { throw 'TEST_SIDE_SCHEMA_REJECTED' }
$negativeSides=[pscustomobject]@{compile=[pscustomobject]@{compilerSides=[pscustomobject]@{
    managed=[pscustomobject]@{exitCode=1;stdout='';stderr="managed rejected`n"}
    selfhost=[pscustomobject]@{exitCode=1;stdout='';stderr="selfhost rejected`n"}}}}
if (-not (Test-Json -Json ($negativeSides | ConvertTo-Json -Depth 20) -Schema ($stageSchema | ConvertTo-Json -Depth 30))) { throw 'TEST_NEGATIVE_SIDE_SCHEMA_REJECTED' }
$passed.Add('side-oracle-stage-schema')

$missingSide=$sideCase | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$missingSide.expectedStages.compile.compilerSides.PSObject.Properties.Remove('selfhost')
Assert-Rejected 'missing-side-oracle' { Get-NativeExactPhaseExpectedStage $missingSide compile managed } 'PHASE_EXECUTION_BOTH_SIDE_ORACLES_REQUIRED'
$unequal=$sideCase | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$unequal.expectedStages.compile.compilerSides.selfhost.exitCode=1
Assert-Rejected 'unequal-side-exits' { Get-NativeExactPhaseExpectedStage $unequal compile managed } 'PHASE_EXECUTION_SIDE_EXITS_DIFFER'
$sideRun=$sideCase | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$sideRun.expectedStages.run=$sideRun.expectedStages.compile
Assert-Rejected 'side-run-forbidden' { Get-NativeExactPhaseExpectedStage $sideRun run managed } 'PHASE_EXECUTION_COMPILE_SIDE_ORACLE_ONLY'

$negativeTokens=$null; $negativeErrors=$null
$negativeAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'verify-compiler-parity-negative-fixture.ps1'),[ref]$negativeTokens,[ref]$negativeErrors)
foreach ($name in @('Get-NegativeLiveDescendantIds','Invoke-NegativeBuild')) {
    $function=$negativeAst.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name},$true)
    if ($null -eq $function) { throw "TEST_EXISTING_NEGATIVE_FUNCTION_MISSING: $name" }
    Invoke-Expression $function.Extent.Text
}
$TimeoutMilliseconds=10000
$customRecord=Join-Path $root 'negative-custom.execution.json'
$customOrphans=[Collections.Generic.List[int]]::new()
$custom=Invoke-NegativeBuild -File $pwsh -Arguments @('-NoProfile','-File',$negativeChild,$fixture) -Name test `
    -StdoutPath (Join-Path $root 'negative-custom.stdout') -StderrPath (Join-Path $root 'negative-custom.stderr') `
    -OrphanProcessIds $customOrphans -ExecutionRecordPath $customRecord
if ($custom.ExitCode -ne 1 -or $customOrphans.Count -ne 0) { throw 'TEST_ACTUAL_NEGATIVE_SUPERVISOR_FAILED' }
$null=Write-NativeExactPhaseOutcome $context $negative compile $customRecord (Join-Path $root 'negative-custom') -InputHashesStart $negativeStart
$passed.Add('actual-existing-negative-supervisor')
Assert-Rejected 'negative-products' { Write-NativeExactPhaseOutcome $context $negative compile $negativeRecord (Join-Path $root 'negative-product') $binary -InputHashesStart $negativeStart } 'PHASE_EXECUTION_NEGATIVE_PRODUCT'
Assert-Rejected 'unexpected-exit' { Write-NativeExactPhaseOutcome $context $case compile $negativeRecord (Join-Path $root 'unexpected') -InputHashesStart $negativeStart } 'PHASE_EXECUTION_EXACT_OUTCOME_MISMATCH'
$failedProcess = Get-Content $negativeRecord -Raw | ConvertFrom-Json
$failedProcess.processesStopped=$false
$unconfirmedRecord = Join-Path $root 'unconfirmed.json'; Save-Json $unconfirmedRecord $failedProcess
Assert-Rejected 'orphan-cancel' { Write-NativeExactPhaseOutcome $context $negative compile $unconfirmedRecord (Join-Path $root 'unconfirmed') -InputHashesStart $negativeStart } 'PHASE_EXECUTION_PROCESS_UNCONFIRMED'
$failedProcess.pid=$null; Save-Json $unconfirmedRecord $failedProcess
Assert-Rejected 'missing-process-record' { Write-NativeExactPhaseOutcome $context $negative compile $unconfirmedRecord (Join-Path $root 'synthetic') -InputHashesStart $negativeStart } 'PHASE_EXECUTION_REAL_PROCESS_MISSING'
$timeoutRecord=Join-Path $root 'timeout.execution.json'
try {
    $null=Invoke-VerificationProcessCapture -FilePath $pwsh -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 10') -Description 'phase regression timeout child' -TimeoutMilliseconds 1000 -ExecutionRecordPath $timeoutRecord
    throw 'TEST_TIMEOUT_EXPECTED'
} catch {
    if ($_.Exception.Message -ceq 'TEST_TIMEOUT_EXPECTED') { throw }
    if (-not (Test-Path -LiteralPath $timeoutRecord)) { throw }
}
$timeout=Get-Content $timeoutRecord -Raw | ConvertFrom-Json
if ($timeout.processesStopped -ne $true -or $null -eq $timeout.failure) { throw 'TEST_TIMEOUT_NOT_CONFIRMED' }
Assert-Rejected 'actual-timeout-not-promoted' { Write-NativeExactPhaseOutcome $context $negative compile $timeoutRecord (Join-Path $root 'timeout') -InputHashesStart $negativeStart } 'PHASE_EXECUTION_PROCESS_UNCONFIRMED'
$other = Join-Path $root 'other.exe'; Copy-Item -LiteralPath $binary -Destination $other
Assert-Rejected 'different-executable' { Write-NativeExactPhaseOutcome $context $case run $runRecord $prefix $other -InputHashesStart $runStart } 'PHASE_EXECUTION_DIFFERENT_EXECUTABLE'
[IO.File]::AppendAllText($fixture,'changed')
Assert-Rejected 'contract-drift' { Get-NativeExactPhaseCommandInputs $context } 'PHASE_EXECUTION_INPUT_DRIFT'

$pending = Join-Path $root 'pending.json'; Save-Json $pending @{status='pending';phase='test'}
$pendingContract = Join-Path $root 'pending-contract.json'
Save-Json $pendingContract @{schemaVersion=1;phase='test';reviewedInventory=(Get-NativeExactPhaseReference $repository $pending)}
Assert-Rejected 'pending-review' { Get-NativeExactPhaseContext $repository $pendingContract managed $compiler $PSCommandPath } 'PHASE_EXECUTION_INVENTORY_UNREVIEWED'
$batchTokens=$null;$batchErrors=$null
$batch=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1'),[ref]$batchTokens,[ref]$batchErrors)
$plan=@((($batch.ParamBlock.Parameters|Where-Object {$_.Name.VariablePath.UserPath -ceq 'Fixture'}).DefaultValue).SafeGetValue())
if ($plan.Count -ne 405 -or $batchErrors.Count -ne 0) { throw 'TEST_LEGACY_405_CHANGED' }
$passed.Add('legacy405')
# Authority-gate tests use an isolated mock repository; this cannot authorize
# any operational compiler or close a real structural phase.
$gateRoot = Join-Path $root 'gate'
[void][IO.Directory]::CreateDirectory((Join-Path $gateRoot 'scripts/contracts'))
$testSchema=Get-Content (Join-Path $PSScriptRoot 'contracts/native-exact-phase-execution.schema.json') -Raw | ConvertFrom-Json -AsHashtable
$testSchema.properties.phase.enum=@('test')
$testSchema.properties.compilerBinaries.required=@('managed')
Save-Json (Join-Path $gateRoot 'scripts/contracts/native-exact-phase-execution.schema.json') $testSchema
foreach ($name in @('native-exact-fixture-receipt.ps1','stage2-artifact-receipt.ps1','verify-native-exact-fixture-batch.ps1','verification-process.ps1','contracts/artifact-lifecycle.json')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $gateRoot "scripts/$name")
}
foreach ($name in @('m.cs','s.slg','fixture.slg','m.bin')) { [IO.File]::WriteAllText((Join-Path $gateRoot $name), 'regression-only') }
[void][IO.Directory]::CreateDirectory((Join-Path $gateRoot 'examples/regression/expected'))
foreach ($name in $plan) {
    [IO.File]::WriteAllText((Join-Path $gateRoot "examples/regression/$name.slg"), 'regression-only')
    [IO.File]::WriteAllText((Join-Path $gateRoot "examples/regression/expected/$name.stdout.txt"), 'regression-only')
}
. (Join-Path $gateRoot 'scripts/native-exact-fixture-receipt.ps1')
$scopes=[ordered]@{managed=@('m.cs');selfhost=@('s.slg')}
$decision=[ordered]@{id='test';status='complete';managedSources=@('m.cs');selfhostSources=@('s.slg');
    structure='test';branches='test';logic='test';diagnostics='test'}
$inventory=[ordered]@{status='reviewed';phase='test';sourceScopes=$scopes;requiredDecisionIds=@('test');decisions=@($decision);managedFirstRecord='first.json'}
Save-Json (Join-Path $gateRoot 'scripts/contracts/structural-parity-detail.json') @{phaseProgress=@(@{phase='test';decisionInventory=$inventory})}
Save-Json (Join-Path $gateRoot 'inventory.json') $inventory
$sourceHashes=Get-NativeExactPhaseHashes $gateRoot @('m.cs','s.slg')
Save-Json (Join-Path $gateRoot 'first.json') @{status='passed';phase='test';inputStable=$true;exitCode=0;canceled=$false;failureIds=@();orphanProcessIds=@()}
$comparison=@{status='compared';phase='test';sourceHashes=$sourceHashes;decisions=@($decision);managedFirstRecord=(Get-NativeExactPhaseReference $gateRoot 'first.json')}
Save-Json (Join-Path $gateRoot 'comparison.json') $comparison
$binaryReference=Get-NativeExactPhaseReference $gateRoot 'm.bin'
$build=@{status='passed';phase='test';compilerSide='managed';inputStable=$true;exitCode=0;canceled=$false;failureIds=@();orphanProcessIds=@();
    completed=1;total=1;binary=$binaryReference;sourceHashesStart=@{'m.cs'=$sourceHashes['m.cs']};sourceHashesEnd=@{'m.cs'=$sourceHashes['m.cs']}}
Save-Json (Join-Path $gateRoot 'build.json') $build
$binaryReference.buildRecord='build.json'; $binaryReference.buildRecordSha256=(Get-NativeExactPhaseReference $gateRoot 'build.json').sha256
$gateContract=@{schemaVersion=1;phase='test';wholeFixturePlan=$plan;decisionIds=@('test');evidenceDirectory='evidence';
    batchReports=@{managed='managed-batch.json';selfhost='selfhost-batch.json'};
    reviewedInventory=(Get-NativeExactPhaseReference $gateRoot 'inventory.json');sourceComparisonRecord=(Get-NativeExactPhaseReference $gateRoot 'comparison.json');
    compilerBinaries=@{managed=$binaryReference};cases=@(@{id='case';fixture=(Get-NativeExactPhaseReference $gateRoot "examples/regression/$($plan[0]).slg");decisionIds=@('test');
        expectedStages=@{compile=@{exitCode=0;stdout='';stderr=''};run=@{exitCode=0;stdout='';stderr=''}}})}
$gateContractPath=Join-Path $gateRoot 'contract.json'; Save-Json $gateContractPath $gateContract
$validContext=Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') (Join-Path $gateRoot 'scripts/verify-native-exact-fixture-batch.ps1') $plan
$passed.Add('reviewed-authority-shape')
# Progress fields must not invalidate the immutable reviewed inventory or force
# another whole batch. Semantic changes still require a new review contract.
$authorityPath=Join-Path $gateRoot 'scripts/contracts/structural-parity-detail.json'
$authority=Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$authority | Add-Member -NotePropertyName observedAtUtc -NotePropertyValue 'progress-only-update'
Save-Json $authorityPath $authority
Assert-NativeExactPhaseHashes $gateRoot $validContext.InputHashes
$null=Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') (Join-Path $gateRoot 'scripts/verify-native-exact-fixture-batch.ps1') $plan
$passed.Add('progress-metadata-preserves-immutable-review')
$authority.phaseProgress[0].decisionInventory.decisions[0].logic='unreviewed semantic change'
Save-Json $authorityPath $authority
Assert-Rejected 'semantic-authority-drift-blocked' { Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') $PSCommandPath } 'PHASE_EXECUTION_REVIEW_AUTHORITY_MISMATCH'
$authority.phaseProgress[0].decisionInventory.decisions[0].logic=$inventory.decisions[0].logic
Save-Json $authorityPath $authority
$extraCase=$gateContract.cases[0] | ConvertTo-Json -Depth 15 | ConvertFrom-Json -AsHashtable
$extraCase.id='duplicate-source'
$gateContract.cases+=@($extraCase); Save-Json $gateContractPath $gateContract
Assert-Rejected 'duplicate-source-no-collapse' { Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') $PSCommandPath } 'PHASE_EXECUTION_DUPLICATE_FIXTURE_OR_OUTPUT'
$gateContract.cases=@($gateContract.cases[0])
$gateContract.sourceComparisonRecord='future-compared.json'; Save-Json $gateContractPath $gateContract
$null=Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') (Join-Path $gateRoot 'scripts/verify-native-exact-fixture-batch.ps1') $plan
$passed.Add('managed-first-no-circular-comparison')
Assert-Rejected 'selfhost-requires-real-comparison' { Get-NativeExactPhaseContext $gateRoot $gateContractPath selfhost (Join-Path $gateRoot 'm.bin') $PSCommandPath } 'PHASE_EXECUTION_FILE_BOUNDARY'
$gateContract.sourceComparisonRecord=Get-NativeExactPhaseReference $gateRoot 'comparison.json'
$reordered=@($plan); $reordered[0]=$plan[1]; $reordered[1]=$plan[0]
$gateContract.wholeFixturePlan=$reordered; Save-Json $gateContractPath $gateContract
Assert-Rejected 'narrowed-whole-plan' { Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') $PSCommandPath } 'PHASE_EXECUTION_WHOLE_PLAN_NARROWED'
$gateContract.wholeFixturePlan=$plan
$build.inputStable=$false; Save-Json (Join-Path $gateRoot 'build.json') $build
$gateContract.compilerBinaries.managed.buildRecordSha256=(Get-NativeExactPhaseReference $gateRoot 'build.json').sha256
Save-Json $gateContractPath $gateContract
Assert-Rejected 'missing-build-authority' { Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') $PSCommandPath } 'PHASE_EXECUTION_BUILD_AUTHORITY_MISSING'
$inventory.decisions[0].managedSources=@()
Save-Json (Join-Path $gateRoot 'scripts/contracts/structural-parity-detail.json') @{phaseProgress=@(@{phase='test';decisionInventory=$inventory})}
Save-Json (Join-Path $gateRoot 'inventory.json') $inventory
$gateContract.reviewedInventory=Get-NativeExactPhaseReference $gateRoot 'inventory.json'; Save-Json $gateContractPath $gateContract
Assert-Rejected 'incomplete-decisions' { Get-NativeExactPhaseContext $gateRoot $gateContractPath managed (Join-Path $gateRoot 'm.bin') $PSCommandPath } 'PHASE_EXECUTION_SOURCE_REVIEW_INCOMPLETE'
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
$phaseContext=$context
$batchRecordPath=Join-Path $root 'test-only-batch.json'
Save-Json $batchRecordPath @{state='passed';total=405;completed=405;passed=405;failed=0;missing=0;
    compilerSha256=$context.CompilerBinary.sha256;phaseFixturePlan=$plan;results=@($plan | ForEach-Object { @{Fixture=$_;Success=$true} })}
$phaseContext.Contract | Add-Member -NotePropertyName wholeFixturePlan -NotePropertyValue $plan
$phaseContext.Contract | Add-Member -NotePropertyName batchReports -NotePropertyValue @{managed=[IO.Path]::GetRelativePath($repository,$batchRecordPath)}
$phaseContext.Contract | Add-Member -NotePropertyName decisionIds -NotePropertyValue @('test')
$phaseContext.Contract | Add-Member -NotePropertyName compilerBinaries -NotePropertyValue ([pscustomobject]@{managed=$context.CompilerBinary})
$phaseContext.Contract | Add-Member -NotePropertyName sourceComparisonRecord -NotePropertyValue @{path='test-only';sha256='test-only'}
$phaseContext | Add-Member -NotePropertyName ContractReference -NotePropertyValue (Get-NativeExactPhaseReference $repository $contractPath)
$phaseContext | Add-Member -NotePropertyName RunnerReference -NotePropertyValue (Get-NativeExactPhaseReference $repository $PSCommandPath)
$phaseContext | Add-Member -NotePropertyName SideSourceHashes -NotePropertyValue @{}
[IO.File]::WriteAllText($fixture,'test source')
$unverifiedBatch=Get-Content $batchRecordPath -Raw | ConvertFrom-Json
$unverifiedBatch.state='failed'; Save-Json $batchRecordPath $unverifiedBatch
Assert-Rejected 'failed-batch-no-promotion' { Complete-NativeExactPhaseExecution $phaseContext } 'PHASE_EXECUTION_WHOLE_BATCH_UNVERIFIED'
$unverifiedBatch.state='passed'; Save-Json $batchRecordPath $unverifiedBatch
$closed=Complete-NativeExactPhaseExecution $phaseContext
if (-not $closed -or (Get-Content (Join-Path $root 'managed-phase-execution.json') -Raw | ConvertFrom-Json).consumerState -cne 'pending-structural-phase-validation') {
    throw 'TEST_CONSUMER_PROTECTION_MISSING'
}
$passed.Add('consumer-protection')
Assert-Rejected 'cached-no-execution' { Write-NativeExactPhaseOutcome $context $case run $runRecord $prefix $binary -InputHashesStart $runStart } 'PHASE_EXECUTION_RECORD_ALREADY_EXISTS'
if ((Get-Content (Join-Path $root 'managed-phase-execution.json') -Raw | ConvertFrom-Json).phase -cne 'test') { throw 'TEST_CLI_PHASE_CONFUSION' }
$passed.Add('cli-phase-confusion')
foreach ($name in @('verify-native-exact-fixture-batch.ps1','verify-native-exact-fixture.ps1','verify-compiler-parity-negative-fixture.ps1','native-exact-fixture-receipt.ps1')) {
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name),[ref]$tokens,[ref]$errors)
    if ($errors.Count -gt 0) { throw "TEST_PARSE_FAILED: $name" }
}
$buildPolicyCase=[pscustomobject]@{expectedStages=[pscustomobject]@{
    compile=[pscustomobject]@{exitCode=0;stdout='';stderr='';stdoutPolicy='compiler-build-telemetry-v1'};
    run=[pscustomobject]@{exitCode=0;stdout='';stderr='';stdoutPolicy='compiler-build-telemetry-v1'}}}
$null=Get-NativeExactPhaseExpectedStage $buildPolicyCase compile managed
$passed.Add('declared-successful-build-stdout-policy')
Assert-Rejected 'build-stdout-policy-not-program-output' {
    Get-NativeExactPhaseExpectedStage $buildPolicyCase run managed
} 'PHASE_EXECUTION_BUILD_STDOUT_POLICY_SCOPE'
$buildPolicyCase.expectedStages.compile.exitCode=1
Assert-Rejected 'build-stdout-policy-not-negative-diagnostics' {
    Get-NativeExactPhaseExpectedStage $buildPolicyCase compile managed
} 'PHASE_EXECUTION_BUILD_STDOUT_POLICY_SCOPE'
$buildPolicyCase.expectedStages.compile.exitCode=0
$buildPolicyCase.expectedStages.compile.stdout='must preserve'
Assert-Rejected 'build-stdout-policy-preserves-semantic-stdout' {
    Get-NativeExactPhaseExpectedStage $buildPolicyCase compile managed
} 'PHASE_EXECUTION_BUILD_STDOUT_POLICY_SCOPE'
$buildPolicyCase.expectedStages.compile.stdout=''
$buildPolicyCase.expectedStages.compile.stdoutPolicy='ignore-all'
Assert-Rejected 'build-stdout-unknown-policy-rejected' {
    Get-NativeExactPhaseExpectedStage $buildPolicyCase compile managed
} 'PHASE_EXECUTION_BUILD_STDOUT_POLICY_SCOPE'
$diagnosticControlPath=Join-Path $PSScriptRoot 'contracts/fixtures/compiler-exact-diagnostics.json'
$diagnosticPlan=Get-Content $diagnosticControlPath -Raw | ConvertFrom-Json
$managedDiagnosticSource=Join-Path $repository 'tests/Sollang.ExampleTests/CompilerDiagnosticAssertions.cs'
$managedDiagnosticType=Add-Type -Path $managedDiagnosticSource -PassThru -CompilerOptions '/nullable:enable'
$managedDiagnosticMethod=$managedDiagnosticType.GetMethod('Verify',[Reflection.BindingFlags]'Static,NonPublic')
foreach ($control in $diagnosticPlan.cases) {
    $expectedPath=''
    if ($null -ne $control.expectedExact) {
        $expectedPath=Join-Path $root "diagnostic-$($control.id).stderr.txt"
        [IO.File]::WriteAllText($expectedPath,$control.expectedExact,[Text.UTF8Encoding]::new($false))
    }
    $accepted=$true
    try { Assert-NativeExactCompilerDiagnostics -Stdout $control.stdout -Stderr $control.stderr -ExpectedExactPath $expectedPath }
    catch { $accepted=$false }
    if ($accepted -ne $control.accept) { throw "TEST_DIAGNOSTIC_PS_CONTROL: $($control.id)" }
    $parameters=[object[]]@($control.stdout,$control.stderr,$control.expectedExact,'')
    if ($managedDiagnosticMethod.Invoke($null,$parameters) -ne $control.accept) { throw "TEST_DIAGNOSTIC_MANAGED_CONTROL: $($control.id)" }
    $passed.Add("exact-diagnostic-ps-$($control.id)")
    $passed.Add("exact-diagnostic-managed-$($control.id)")
}
$acceptancePath=Join-Path $PSScriptRoot 'contracts/native-exact-phase-execution-acceptance.json'
$acceptance=Get-Content $acceptancePath -Raw | ConvertFrom-Json
if ($acceptance.status -cne 'frozen-before-implementation' -or
    @($acceptance.cases | Where-Object { 'suite' -cnotin @($_.PSObject.Properties.Name) -and $_.id -cnotin @($passed) }).Count -gt 0) { throw 'TEST_ACCEPTANCE_SCOPE_UNCOVERED' }
$ownedInputs=@($PSCommandPath,$acceptancePath,(Join-Path $PSScriptRoot 'contracts/native-exact-compile-side-oracle-acceptance.json'),$diagnosticControlPath,$managedDiagnosticSource)
foreach ($name in @('native-exact-fixture-receipt.ps1','verify-native-exact-fixture.ps1','verify-native-exact-fixture-batch.ps1','verify-compiler-parity-negative-fixture.ps1',
    'verification-process.ps1','contracts/native-exact-phase-execution.schema.json','contracts/compiler-parity-negative-fixture-result.schema.json')) {
    $ownedInputs+=Join-Path $PSScriptRoot $name
}
$result = @{status='passed';completed=$passed.Count;total=$passed.Count;cases=@($passed);scope='regression-only; actual tiny OS children, no compiler/405 execution';
    inputHashes=(Get-NativeExactPhaseHashes $repository $ownedInputs)}
Save-Json (Join-Path $root 'test-result.json') $result
Write-Host "[native exact phase regression] PASS $($passed.Count)/$($passed.Count); $root/test-result.json"
# Generated test executables have no phase consumers. Retain records/source/logs.
Remove-Item -LiteralPath $binary,$other
