[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root 'scripts/contracts/zip-deflate-method8.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/zip-deflate-method8.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/zip-deflate-method8-result.schema.json'
$resultVerifierPath = Join-Path $root 'scripts/verify-zip-deflate-method8-result.ps1'

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath -ErrorAction Stop)) { throw 'ZIP DEFLATE contract schema rejected the authority' }
$contract = $contractText | ConvertFrom-Json
if (@($contract.semanticNegatives).Count -ne 2 -or @($contract.resultNegativeControls).Count -ne 8) { throw 'ZIP DEFLATE contract denominator drift' }

function Empty-Check([string]$Optimization) { [ordered]@{optimization=$Optimization;status='not-run';stdoutSha256=$null;stdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;artifactSha256=$null;warningCount=$null;noteCount=$null} }
function New-Record([string]$Mode,[string]$Status) {
    $hashes=[ordered]@{};foreach($key in @('compiler','verifier','contract','contractSchema','resultSchema','resultVerifier','contractVerifier','fixture')){$hashes[$key]='A'*64}
    [ordered]@{
        schemaVersion=1;capabilityId='zip-deflate-method8';mode=$Mode;status=$Status;planned=6;completed=0
        compiler=[ordered]@{path='compiler.dll';sha256Start='A'*64;sha256End='A'*64};inputs=[ordered]@{start=$hashes;end=$hashes}
        windows=[ordered]@{status='not-run';planned=2;completed=0;checks=@((Empty-Check 'O0'),(Empty-Check 'O2'))}
        linux=[ordered]@{status='not-run';planned=2;completed=0;checks=@((Empty-Check 'O0'),(Empty-Check 'O2'))}
        browser=[ordered]@{status='not-run';completed=0;artifactProduced=$false;wasmMagicValid=$false;exactOutput=$false;stdoutSha256=$null;stdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;artifactSha256=$null;warningCount=$null;noteCount=$null}
        python=[ordered]@{status='not-run';completed=0;stdoutSha256=$null;stdoutBytes=$null};semanticNegatives=[ordered]@{planned=2;completed=0;failureIds=@()}
        processAudit=[ordered]@{rootProcessIds=@();descendantProcessIds=@();orphanProcessIds=@();invocations=@()};failureIds=@();startedUtc='2026-09-13T00:00:00Z';finishedUtc='2026-09-13T00:00:01Z'
    }
}
function Clone($Value) { (($Value | ConvertTo-Json -Depth 12) | ConvertFrom-Json -AsHashtable -Depth 12) }
function Accepts($Value) { (($Value | ConvertTo-Json -Depth 12) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) }

$inputPositive=New-Record 'input-validation' 'validated-inputs'
$semanticPositive=New-Record 'semantic-preflight' 'validated-semantic-negatives';$semanticPositive.semanticNegatives.completed=2
foreach($positive in @($inputPositive,$semanticPositive)){if(-not(Accepts $positive)){throw 'ZIP DEFLATE result schema rejected a positive mode control'}}

$negatives=[Collections.Generic.List[object]]::new()
$item=Clone $inputPositive;$item.mode='full';$negatives.Add([pscustomobject]@{id='mode-status';record=$item})
$item=Clone $semanticPositive;$item.semanticNegatives.completed=1;$negatives.Add([pscustomobject]@{id='semantic-denominator';record=$item})
$item=Clone $inputPositive;$item.status='failed';$negatives.Add([pscustomobject]@{id='failed-empty-failure';record=$item})
$item=Clone $inputPositive;[void]$item.Remove('mode');$negatives.Add([pscustomobject]@{id='missing-mode';record=$item})
$item=Clone $inputPositive;$item['browser']['processed']=$true;$negatives.Add([pscustomobject]@{id='unexpected-browser-property';record=$item})
foreach($negative in $negatives){if(Accepts $negative.record){throw "ZIP DEFLATE result schema accepted forged control $($negative.id)"}}

$verifierText=[IO.File]::ReadAllText($resultVerifierPath)
foreach($guard in @('compiler provenance drift','input hash drift','current input identity mismatch','semantic preflight invocation topology mismatch','semantic preflight evidence mismatch')){if(-not$verifierText.Contains($guard,[StringComparison]::Ordinal)){throw "ZIP DEFLATE semantic verifier guard missing: $guard"}}
Write-Host "PASS ZIP DEFLATE contract controls: contract 1/1; mode positives 2/2; schema mutations $($negatives.Count)/$($negatives.Count); semantic guards 5/5"
