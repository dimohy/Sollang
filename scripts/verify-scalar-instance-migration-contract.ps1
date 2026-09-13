[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-Contains([string]$Text, [string]$Expected, [string]$Label) {
    if (-not $Text.Contains($Expected, [StringComparison]::Ordinal)) {
        throw "$Label is missing: $Expected"
    }
}

function Assert-Rejected([scriptblock]$Check, [string]$Label) {
    try { & $Check; throw "negative control accepted: $Label" }
    catch {
        if ($_.Exception.Message -eq "negative control accepted: $Label") { throw }
    }
}

function Assert-NoDirectCalls([string]$Sources, [string]$QualifiedMethod) {
    foreach ($line in ($Sources -split "`r?`n")) {
        $call = $line.IndexOf("$QualifiedMethod(", [StringComparison]::Ordinal)
        if ($call -ge 0) {
            $prefix = $line.Substring(0, $call)
            if (-not $prefix.Contains('->', [StringComparison]::Ordinal)) {
                throw "direct global-form call remains: $QualifiedMethod"
            }
        }
    }
}

function Assert-Contract([string]$Bits, [string]$Recovery, [string]$Fixture, [string]$AllSources, [hashtable]$SecondSources) {
    $bitMethods = @('and', 'and64', 'not', 'not64', 'powerOfTwo', 'powerOfTwo64', 'rotateRight', 'rotateRight64', 'shiftRight', 'shiftRight64', 'xor', 'xor64')
    $recoveryMethods = @('initialCongestionWindow', 'lostByPacketThreshold', 'minimumCongestionWindow')
    Assert-Contains $Bits 'impl UInt32 {' 'bits UInt32 instance surface'
    Assert-Contains $Bits 'impl UInt64 {' 'bits UInt64 instance surface'
    Assert-Contains $Recovery 'impl UInt64 {' 'QUIC recovery UInt64 instance surface'
    if ([regex]::Matches($Recovery, '(?m)^impl UInt64 \{').Count -ne 1) {
        throw 'QUIC recovery scalar methods must share exactly one UInt64 impl block'
    }
    foreach ($method in $bitMethods) {
        Assert-Contains $Bits "public ${method}: self" "bits instance method $method"
        Assert-Contains $Fixture "-> bits.${method}" "scalar fixture call $method"
        if ($Bits -match "(?m)^public\s+$method\s+[^:]" ) { throw "bits global wrapper remains: $method" }
        Assert-NoDirectCalls $AllSources "bits.$method"
    }
    foreach ($method in $recoveryMethods) {
        Assert-Contains $Recovery "public ${method}: self" "QUIC recovery instance method $method"
        Assert-Contains $Fixture "-> recovery.${method}" "scalar fixture call $method"
        if ($Recovery -match "(?m)^public\s+$method\s+[^:]" ) { throw "QUIC recovery global wrapper remains: $method" }
        Assert-NoDirectCalls $AllSources "recovery.$method"
    }
    $secondMethods = @(
        @('packet_number', 'restore'), @('packet_number', 'selectLength'), @('packet_number', 'truncate'),
        @('varint', 'encode'), @('version_negotiation', 'isReserved'),
        @('transport_parameters', 'encode'), @('transport_parameters', 'encodeEmpty'), @('transport_parameters', 'encodeInteger'),
        @('tls_handshake', 'encode'), @('tls_handshake', 'encodeExtension'), @('tls_auth', 'encodeCertificateVerify'),
        @('stream_state', 'validatePeerOpened'), @('packet', 'encodeHandshakeHeader'), @('packet', 'encodeInitialHeader'),
        @('handshake_engine', 'encode')
    )
    foreach ($entry in $secondMethods) {
        Assert-Contains $SecondSources[$entry[0]] "public $($entry[1]): self" "second scalar instance method $($entry[0]).$($entry[1])"
    }
    foreach ($module in @('packet_number', 'transport_parameters', 'packet')) {
        $target = $module -eq 'packet' ? 'UInt32' : 'UInt64'
        if ([regex]::Matches($SecondSources[$module], "(?m)^impl $target \{").Count -ne 1) {
            throw "$module scalar methods must share exactly one $target impl block"
        }
    }
    foreach ($evidence in @(
        '-> packetNumber.restore(', '-> packetNumber.selectLength(', '-> packetNumber.truncate(',
        '-> varint.encode', '-> isReserved', '-> transport.encode(', '-> transport.encodeInteger(', '-> parameters.encodeEmpty',
        '-> handshake.encode(', '-> handshake.encodeExtension(', '-> auth.encodeCertificateVerify(',
        '-> streams.validatePeerOpened(', '-> packet.encodeInitialHeader(', '-> encodeHandshakeHeader(', '-> handshakeEngine.encode('
    )) { Assert-Contains $AllSources $evidence "second scalar caller evidence $evidence" }

    $frame = $SecondSources['frame']
    $protection = $SecondSources['protection']
    $initial = $SecondSources['initial_engine']
    Assert-Contains $frame 'impl Value {' 'third slice frame Value instance surface'
    Assert-Contains $frame 'public encodeValue: move self' 'third slice consuming frame encoder'
    Assert-Contains $frame 'value -> encodeValue? => encoded' 'third slice internal frame caller'
    Assert-Contains $protection 'impl PacketKey {' 'third slice PacketKey instance surface'
    Assert-Contains $protection 'public seal: self' 'third slice PacketKey seal method'
    Assert-Contains $protection 'public open: self' 'third slice PacketKey open method'
    Assert-Contains $initial 'impl AcceptedClientInitial {' 'third slice accepted Initial instance surface'
    Assert-Contains $initial 'public encodeServerInitial: self' 'third slice accepted Initial encoder'
    if ($frame -match '(?m)^public encodeValue frame:') { throw 'third slice frame global wrapper remains' }
    if ($initial -match '(?m)^public encodeServerInitial accepted:') { throw 'third slice Initial global wrapper remains' }
    if ($protection -match '(?m)^public seal packetKey:') { throw 'third slice PacketKey seal global wrapper remains' }
    if ($protection -match '(?m)^public open packetKey:') { throw 'third slice PacketKey open global wrapper remains' }
    foreach ($evidence in @(
        '-> frames.encodeValue',
        '-> initial.encodeServerInitial(',
        'protector.packet -> seal(',
        'protector.packet -> open(')) {
        Assert-Contains $AllSources $evidence "third slice caller evidence $evidence"
    }
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$bitsPath = Join-Path $root 'stdlib/std/crypto/bits.slg'
$recoveryPath = Join-Path $root 'stdlib/std/net/quic/loss_recovery.slg'
$fixturePath = Join-Path $root 'scripts/contracts/fixtures/stdlib-scalar-instance-migration.slg'
$bits = [IO.File]::ReadAllText($bitsPath)
$recovery = [IO.File]::ReadAllText($recoveryPath)
$fixture = [IO.File]::ReadAllText($fixturePath)
$secondSources = @{}
foreach ($module in @('packet_number', 'varint', 'version_negotiation', 'transport_parameters', 'tls_handshake', 'tls_auth', 'stream_state', 'packet', 'handshake_engine', 'frame', 'protection', 'initial_engine')) {
    $secondSources[$module] = [IO.File]::ReadAllText((Join-Path $root "stdlib/std/net/quic/$module.slg"))
}
$sourceFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg'
    Get-ChildItem -LiteralPath (Join-Path $root 'examples') -Recurse -File -Filter '*.slg'
)
$allSources = ($sourceFiles | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"

Assert-Contract $bits $recovery $fixture $allSources $secondSources
Assert-Rejected { Assert-Contract ($bits -replace 'public xor: self', 'public xor left') $recovery $fixture $allSources $secondSources } 'global wrapper decoy'
Assert-Rejected { Assert-Contract $bits $recovery ($fixture -replace '-> bits.not64', '-> bits.not') $allSources $secondSources } 'fixture call decoy'
Assert-Rejected { Assert-Contract $bits $recovery $fixture ($allSources + "`nbits.xor(left, right)") $secondSources } 'direct global-form caller decoy'

Write-Host '[instance migration contract] PASS 37/37 (34 methods + 3 mutation controls)'
