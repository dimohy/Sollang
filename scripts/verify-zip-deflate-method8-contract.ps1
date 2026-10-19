[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root 'scripts/contracts/zip-deflate-method8.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/zip-deflate-method8.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/zip-deflate-method8-result.schema.json'
$resultVerifierPath = Join-Path $root 'scripts/verify-zip-deflate-method8-result.ps1'
$fixturePath = Join-Path $root 'examples/regression/1756-zip-deflate-method8.slg'
$zipSourcePath = Join-Path $root 'stdlib/std/archive/zip.slg'

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath -ErrorAction Stop)) { throw 'ZIP DEFLATE contract schema rejected the authority' }
$contract = $contractText | ConvertFrom-Json
if (@($contract.semanticNegatives).Count -ne 2 -or @($contract.resultNegativeControls).Count -ne 8) { throw 'ZIP DEFLATE contract denominator drift' }
$fixtureText = [IO.File]::ReadAllText($fixturePath)
if (-not $fixtureText.Contains("[UInt8('t'), 'h', 'e'", [StringComparison]::Ordinal)) {
    throw 'ZIP DEFLATE dynamic payload must retain explicit UInt8 element inference'
}
if (-not $fixtureText.Contains('UInt8(237), 202, 97', [StringComparison]::Ordinal)) {
    throw 'ZIP DEFLATE dynamic stream must retain explicit UInt8 element inference'
}
if (-not $fixtureText.Contains('210, 254, 217, 54; ~', [StringComparison]::Ordinal)) {
    throw 'ZIP DEFLATE padded stream must retain growable array storage'
}
foreach ($requiredCall in @('codec -> writer(writerLimits)? => writer!', 'codec -> deflateDecoder(deflateLimits)? => decoder!')) {
    if (-not $fixtureText.Contains($requiredCall, [StringComparison]::Ordinal)) {
        throw "ZIP DEFLATE fixture must retain natural instance direction: $requiredCall"
    }
}
if (-not $fixtureText.Contains('"zip-deflate-failure=$(error.kind -> kindCode)@$(error.offset)"', [StringComparison]::Ordinal)) {
    throw 'ZIP DEFLATE failure reporting must interpolate only supported scalar values'
}
if (-not $fixtureText.Contains('finalBytes >= 69', [StringComparison]::Ordinal)) {
    throw 'ZIP DEFLATE writer transactionality must accept the exact minimum finalization size'
}
$zipSourceText = [IO.File]::ReadAllText($zipSourcePath)
foreach ($forbiddenInlineState in @('takeDeflate', 'Option<gzip.RawDeflateDecoder>')) {
    if ($zipSourceText.Contains($forbiddenInlineState, [StringComparison]::Ordinal)) {
        throw "ZIP DEFLATE decoder must not retain large inline state: $forbiddenInlineState"
    }
}
$runtimeOwnershipGuards = @(
    'deflate: [gzip.RawDeflateDecoder; ~]',
    'decoder.deflate -> push(raw)',
    'decoder.deflate -> take(0) => active!',
    'active! -> write([byte])',
    'decoder.deflate -> take(0) => raw'
)
foreach ($runtimeOwnershipGuard in $runtimeOwnershipGuards) {
    if (-not $zipSourceText.Contains($runtimeOwnershipGuard, [StringComparison]::Ordinal)) {
        throw "ZIP DEFLATE runtime ownership guard missing: $runtimeOwnershipGuard"
    }
}

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
Write-Host "PASS ZIP DEFLATE contract controls: contract 1/1; mode positives 2/2; schema mutations $($negatives.Count)/$($negatives.Count); semantic guards 5/5; runtime ownership guards $($runtimeOwnershipGuards.Count)/$($runtimeOwnershipGuards.Count)"
