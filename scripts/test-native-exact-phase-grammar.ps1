[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$SelfhostCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root=Split-Path -Parent $PSScriptRoot
$output=Assert-NativeExactPhaseOutputPath $root $OutputDirectory
if (Test-Path -LiteralPath $output) { throw 'GRAMMAR_TEST_FRESH_OUTPUT_REQUIRED' }
[void][IO.Directory]::CreateDirectory($output)
$utf8=[Text.UTF8Encoding]::new($false)
$lexer=Join-Path $output 'predicate.lexer'
[IO.File]::WriteAllText($lexer,"token End = end`n",$utf8)
$fixtures=@(
    @{id='lookahead-missing-close';production='lookahead(Missing';reason="expected ')'"},
    @{id='lookahead-closed';production='lookahead(Missing)';reason="unknown token 'Missing'"},
    @{id='keyword-missing-close';production='Identifier("main"';reason="expected ')'"},
    @{id='keyword-closed';production='Identifier("main")';reason="unknown token 'Identifier'"}
)
$cases=@()
foreach ($fixture in $fixtures) {
    $path=Join-Path $output "$($fixture.id).grammar"
    [IO.File]::WriteAllText($path,"parser X`nstart Root`nrule Root = $($fixture.production)`n",$utf8)
    $cases += [pscustomobject]@{id=$fixture.id;fixture=(Get-NativeExactPhaseReference $root $path);
        decisionIds=@('parsing.grammar-predicate-diagnostic-selection-order');
        grammarCommand=[pscustomobject]@{lexer=(Get-NativeExactPhaseReference $root $lexer);grammar=(Get-NativeExactPhaseReference $root $path)};
        expectedStages=[pscustomobject]@{grammar=[pscustomobject]@{compilerSides=[pscustomobject]@{
            managed=[pscustomobject]@{exitCode=1;stdout='';stderr="sollang: grammar line 3: $($fixture.reason)`r`n"};
            selfhost=[pscustomobject]@{exitCode=1;stdout='';stderr="sollang: grammar line 3: $($fixture.reason)`r`n"}}}}}
}
$contract=Join-Path $output 'focused-cases.json'
[IO.File]::WriteAllText($contract,(@{cases=$cases;scope='actual grammar focused commands; not phase closure'} | ConvertTo-Json -Depth 12),$utf8)
$scope=@(Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
$scope+=Join-Path $PSScriptRoot 'verification-process.ps1'
$scope+=Join-Path $PSScriptRoot 'contracts/native-exact-phase-execution.schema.json'
$scope+=Join-Path $PSScriptRoot 'contracts/native-exact-phase-execution-acceptance.json'
$scope+=@($PSCommandPath,$contract,$lexer)+@($cases.fixture.path)
$passed=[Collections.Generic.List[string]]::new()
$proofs=[Collections.Generic.List[object]]::new()
foreach ($side in @('managed','selfhost')) {
    $compiler=Get-NativeExactPhaseFile $root $(if ($side -eq 'managed') {$ManagedCompiler} else {$SelfhostCompiler})
    $context=[pscustomobject]@{Root=$root;CompilerSide=$side;
        Contract=[pscustomobject]@{phase='parsing';cases=$cases;evidenceDirectory=[IO.Path]::GetRelativePath($root,$output)};
        CompilerBinary=(Get-NativeExactPhaseReference $root $compiler);
        CompilerRuntimeHashes=(Get-NativeExactPhaseCompilerRuntimeHashes $compiler);
        InputHashes=(Get-NativeExactPhaseHashes $root ($scope+@($compiler)))}
    foreach ($case in $cases) {
        $proof=Invoke-NativeExactPhaseGrammarCase $context $case
        $proofs.Add($proof)
        $passed.Add("$side-$($case.id)")
    }
}
$case=$cases[0]
$prefix=Get-NativeExactPhaseOutcomePrefix $context $case
$processPath="$prefix.grammar.execution.json"
$start=(Get-Content -LiteralPath "$prefix.grammar.json" -Raw | ConvertFrom-Json -AsHashtable).inputHashesStart
function Reject([string]$Id,[scriptblock]$Action,[string]$Reason) {
    try { & $Action; throw "EXPECTED_REJECTION_MISSING: $Id" }
    catch { if (-not $_.Exception.Message.Contains($Reason,[StringComparison]::Ordinal)) { throw } }
    $passed.Add($Id)
}
Reject 'wrong-command-output' { Write-NativeExactPhaseOutcome $context $case grammar $processPath "$prefix.wrong" -InputHashesStart $start } 'PHASE_EXECUTION_GRAMMAR_COMMAND_MISMATCH'
$bad=$case | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$bad.expectedStages.grammar.compilerSides.managed.exitCode=0
$bad.expectedStages.grammar.compilerSides.selfhost.exitCode=0
Reject 'positive-command-not-supported' { Assert-NativeExactPhaseGrammarCase $root $bad selfhost } 'PHASE_EXECUTION_GRAMMAR_CASE_INVALID'
$bad=$case | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$bad.grammarCommand.lexer.sha256='0'*64
Reject 'grammar-input-drift' { Assert-NativeExactPhaseGrammarCase $root $bad selfhost } 'PHASE_EXECUTION_GRAMMAR_INPUT_DRIFT'
$bad=$case | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$bad.fixture=$cases[1].fixture
Reject 'grammar-fixture-substitution' { Assert-NativeExactPhaseGrammarCase $root $bad selfhost } 'PHASE_EXECUTION_GRAMMAR_CASE_INVALID'
# Isolated adverse copy, never included among the eight actual outcomes.
$adverseProcess=Get-Content -LiteralPath $processPath -Raw | ConvertFrom-Json
$adverseProcess.command[-1]="$prefix.adverse.generated.slg"
$adverseRecord="$prefix.adverse.synthetic-process.json"
[IO.File]::WriteAllText($adverseRecord,($adverseProcess | ConvertTo-Json -Depth 12),$utf8)
[IO.File]::WriteAllText("$prefix.adverse.generated.slg",'# Adverse test fixture, deliberately preserved.',$utf8)
Reject 'negative-generated-product' { Write-NativeExactPhaseOutcome $context $case grammar $adverseRecord "$prefix.adverse" -InputHashesStart $start } 'PHASE_EXECUTION_NEGATIVE_PRODUCT'
$acceptance=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'contracts/native-exact-phase-execution-acceptance.json') -Raw | ConvertFrom-Json
if (@($acceptance.cases | Where-Object { 'suite' -cin @($_.PSObject.Properties.Name) -and $_.suite -eq 'grammar' }).Count -ne 2) {
    throw 'GRAMMAR_ACCEPTANCE_SCOPE_CHANGED'
}
$result=@{status='passed';completed=$passed.Count;total=$passed.Count;cases=@($passed);outcomes=@($proofs);
    scope='Actual current compiler grammar commands8 plus rejection controls5; no405/phase/Stage completion';
    acceptanceCases=@('grammar-negative-command','grammar-command-substitution');claimsPhaseComplete=$false;claimsGoalComplete=$false;
    inputHashes=(Get-NativeExactPhaseHashes $root $scope);processesStopped=$true}
[IO.File]::WriteAllText((Join-Path $output 'result.json'),($result | ConvertTo-Json -Depth 15),$utf8)
Write-Host "[phase grammar focused] PASS $($passed.Count)/$($passed.Count); $output/result.json"
