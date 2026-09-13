[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-SlgFunctionBody([string]$Source, [string]$Signature) {
    $start = $Source.IndexOf($Signature, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "SLG function signature is missing: $Signature" }
    $open = $Source.IndexOf('{', $start)
    if ($open -lt 0) { throw "SLG function body is missing: $Signature" }
    $depth = 0
    for ($index = $open; $index -lt $Source.Length; $index++) {
        switch ($Source[$index]) {
            '{' { $depth++ }
            '}' {
                $depth--
                if ($depth -eq 0) { return $Source.Substring($open + 1, $index - $open - 1) }
            }
        }
    }
    throw "SLG function body is unterminated: $Signature"
}

function Assert-Contains([string]$Text, [string]$Expected, [string]$Label) {
    if (-not $Text.Contains($Expected, [StringComparison]::Ordinal)) {
        throw "$Label is missing: $Expected"
    }
}

function Assert-NegotiationContract([string]$Source, [string]$Fixture) {
    $body = Get-SlgFunctionBody $Source 'public validateClient: self -> Result<Unit, errors.Error>'
    Assert-Contains $body 'includesChosen!' 'version-negotiation function body'
    Assert-Contains $body 'Result<Unit, errors.Error>.Err(error(errors.versionNegotiationError())) -> return' 'version-negotiation function body'
    Assert-Contains $body 'Result<Unit, errors.Error>.Ok' 'version-negotiation function body'
    if ($Source.Contains('validateClient: self -> Result<Bool', [StringComparison]::Ordinal)) {
        throw 'version-negotiation validation must expose success as Unit'
    }
    $fixtureBody = Get-SlgFunctionBody $Fixture 'verify: -> Result<Verified, errors.Error>'
    foreach ($expected in @(
        'decoded -> validateClient?',
        'chosen: keys.version2()',
        'available: [keys.version1(); ~]',
        'Err(error) => error.kind -> when',
        'Transport { error.code == errors.versionNegotiationError() }'
    )) { Assert-Contains $fixtureBody $expected 'fixture 915 validateClient boundary' }
}

function Assert-HandshakeCandidateContract([string]$Source) {
    $body = Get-SlgFunctionBody $Source 'handshakeCandidate bytes: move [UInt8; ~] -> Result<Option<[UInt8; ~]>, QuicError>'
    foreach ($expected in @(
        'packets.longHeaderKind(bytes) -> when',
        'Err(error) { Result<Option<[UInt8; ~]>, QuicError>.Err(protocolFailure(error)) }',
        'kind == 0 or kind == 2 -> if',
        'Result<Option<[UInt8; ~]>, QuicError>.Ok(Option<[UInt8; ~]>.Some(bytes))',
        'Result<Option<[UInt8; ~]>, QuicError>.Ok(Option<[UInt8; ~]>.None)'
    )) { Assert-Contains $body $expected 'coalesced handshake candidate function body' }
    $caller = Get-SlgFunctionBody $Source 'handshakePacket endpoint: mut Endpoint, connectionId: [UInt8] -> Result<[UInt8; ~], QuicError> uses Network'
    foreach ($expected in @('remaining -> handshakeCandidate? -> when', 'None { false }', 'Some(packet)')) {
        Assert-Contains $caller $expected 'coalesced handshake caller body'
    }
}

function Assert-ReassemblyContract([string]$Source, [string]$Fixture) {
    $body = Get-SlgFunctionBody $Source 'public takeContiguous: mut self, streamId: UInt64, consumed: UInt64, maxBytes: UIntSize -> Option<frames.Stream>'
    Assert-Contains $body 'Option<frames.Stream>.Some(value!)' 'reassembly function body'
    Assert-Contains $body 'Option<frames.Stream>.None' 'reassembly function body'
    if ($Source.Contains('TakeError', [StringComparison]::Ordinal)) { throw 'reassembly absence must not use TakeError' }
    $fixtureBody = Get-SlgFunctionBody $Fixture 'run: -> Result<Bool, errors.Error>'
    Assert-Contains $fixtureBody 'queue! -> takeContiguous(0, 0, 3) -> when' 'fixture 1300 absence boundary'
    Assert-Contains $fixtureBody 'None { true }' 'fixture 1300 absence boundary'
}

function Assert-ApplicationFrameContract([string]$Source) {
    $helper = Get-SlgFunctionBody $Source 'unsupportedApplicationFrame frameType: UInt64 -> Result<Unit, QuicError>'
    Assert-Contains $helper 'Result<Unit, QuicError>.Err(QuicError' 'unsupported application-frame helper'
    Assert-Contains $helper 'kind: errors.Kind.Internal' 'unsupported application-frame helper'
    Assert-Contains $helper 'code: frameType' 'unsupported application-frame helper'
    if ($helper.Contains('Result<Unit, QuicError>.Ok', [StringComparison]::Ordinal)) {
        throw 'unsupported QUIC application-frame policy must never silently succeed'
    }
    $pump = Get-SlgFunctionBody $Source 'pumpApplicationPacket endpoint: mut Endpoint, connection: mut Connection -> Result<Unit, QuicError> uses Network, Clock'
    foreach ($expected in @(
        'NewConnectionId(value) { unsupportedApplicationFrame(24)? }',
        'RetireConnectionId(sequence) { unsupportedApplicationFrame(25)? }',
        'DataBlocked(limit) { continue }',
        'StreamDataBlocked(blocked) { continue }',
        'StreamsBlocked(blocked) { continue }'
    )) { Assert-Contains $pump $expected 'QUIC application-frame pump body' }
}

function Assert-Rejects([scriptblock]$Check, [string]$Label) {
    try { & $Check; throw "negative control accepted: $Label" }
    catch {
        if ($_.Exception.Message -eq "negative control accepted: $Label") { throw }
    }
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$quic = [IO.File]::ReadAllText((Join-Path $root 'stdlib/std/net/quic.slg'))
$negotiation = [IO.File]::ReadAllText((Join-Path $root 'stdlib/std/net/quic/version_negotiation.slg'))
$reassembly = [IO.File]::ReadAllText((Join-Path $root 'stdlib/std/net/quic/reassembly.slg'))
$negotiationFixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/915-quic-version-negotiation.slg'))
$reassemblyFixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/1300-quic-bounded-stream-reassembly.slg'))

Assert-NegotiationContract $negotiation $negotiationFixture
Assert-HandshakeCandidateContract $quic
Assert-ReassemblyContract $reassembly $reassemblyFixture
Assert-ApplicationFrameContract $quic

$negotiationDecoy = $negotiation.Replace(
    'Result<Unit, errors.Error>.Err(error(errors.versionNegotiationError())) -> return',
    'Result<Unit, errors.Error>.Ok -> return') + "`n# Result<Unit, errors.Error>.Err(error(errors.versionNegotiationError())) -> return"
Assert-Rejects { Assert-NegotiationContract $negotiationDecoy $negotiationFixture } 'validateClient body decoy'

$handshakeDecoy = $quic.Replace('kind == 0 or kind == 2 -> if', 'kind == 2 -> if') + "`n# kind == 0 or kind == 2 -> if"
Assert-Rejects { Assert-HandshakeCandidateContract $handshakeDecoy } 'handshakeCandidate body decoy'

$reassemblyDecoy = $reassembly.Replace('Option<frames.Stream>.None', 'Option<frames.Stream>.Some(value!)') + "`n# Option<frames.Stream>.None"
Assert-Rejects { Assert-ReassemblyContract $reassemblyDecoy $reassemblyFixture } 'takeContiguous body decoy'

$emptyArmFiles = @(
    'stdlib/std/net/quic.slg',
    'stdlib/std/net/quic/version_negotiation.slg',
    'stdlib/std/net/quic/reassembly.slg',
    'stdlib/std/net/quic/tls_client_state.slg',
    'stdlib/std/net/http/client.slg',
    'stdlib/std/net/http/server.slg',
    'stdlib/std/archive/zip.slg'
)
foreach ($relative in $emptyArmFiles) {
    $text = [IO.File]::ReadAllText((Join-Path $root $relative))
    $count = [regex]::Matches($text, '(?s)\b(?:Ok|Err)\s*(?:\([^{}]*\))?\s*\{\s*\}').Count
    if ($count -ne 0) { throw "$relative retains $count empty Result arm(s)" }
}

Write-Host '[QUIC natural Result contract] PASS 18/18 scoped boundaries, policies, negative controls, and empty-arm surfaces.'
