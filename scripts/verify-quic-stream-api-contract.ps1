param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$contractPath = Join-Path $RepositoryRoot "scripts\contracts\quic-stream-api.json"
$schemaPath = Join-Path $RepositoryRoot "scripts\contracts\quic-stream-api.schema.json"
$nativeExactBatchPath = Join-Path $RepositoryRoot "scripts\verify-native-exact-fixture-batch.ps1"
$frameConsumerVerifierPath = Join-Path $RepositoryRoot "scripts\verify-quic-frame-consumers.ps1"
$stage2VerifierPath = Join-Path $RepositoryRoot "scripts\verify-selfhost-stage2.ps1"
$stage3VerifierPath = Join-Path $RepositoryRoot "scripts\verify-selfhost-stage3.ps1"
$linuxStage2VerifierPath = Join-Path $RepositoryRoot "scripts\verify-selfhost-stage2-linux.ps1"
$linuxStage3VerifierPath = Join-Path $RepositoryRoot "scripts\verify-selfhost-stage3-linux.ps1"
$browserStage2VerifierPath = Join-Path $RepositoryRoot "scripts\build-stage2-browser.ps1"
$windowsQuicVerifierPath = Join-Path $RepositoryRoot "scripts\verify-native-quic-endpoint-ownership.ps1"
$linuxQuicVerifierPath = Join-Path $RepositoryRoot "scripts\verify-native-quic-endpoint-ownership-linux.ps1"
$fieldVisibilityVerifierPath = Join-Path $RepositoryRoot "scripts\verify-struct-field-visibility-contract.ps1"
$quicPath = Join-Path $RepositoryRoot "stdlib\std\net\quic.slg"
$framePath = Join-Path $RepositoryRoot "stdlib\std\net\quic\frame.slg"
$transportPath = Join-Path $RepositoryRoot "stdlib\std\net\quic\transport_parameters.slg"
$streamStatePath = Join-Path $RepositoryRoot "stdlib\std\net\quic\stream_state.slg"
$reassemblyPath = Join-Path $RepositoryRoot "stdlib\std\net\quic\reassembly.slg"
$multiStreamFixturePath = Join-Path $RepositoryRoot "examples\regression\1206-quic-bidirectional-multi-stream-routing.slg"
$multiStreamExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1206-quic-bidirectional-multi-stream-routing.stdout.txt"
$optionsFixturePath = Join-Path $RepositoryRoot "examples\regression\1209-quic-connection-options-queue-limits.slg"
$optionsExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1209-quic-connection-options-queue-limits.stdout.txt"
$unidirectionalFixturePath = Join-Path $RepositoryRoot "examples\regression\1291-quic-unidirectional-stream-registry.slg"
$unidirectionalExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1291-quic-unidirectional-stream-registry.stdout.txt"
$unidirectionalOwnerFixturePath = Join-Path $RepositoryRoot "examples\regression\1297-quic-unidirectional-stream-owners.slg"
$unidirectionalOwnerExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1297-quic-unidirectional-stream-owners.stdout.txt"
$unidirectionalOwnerLlvmContainsPath = Join-Path $RepositoryRoot "examples\regression\expected\1297-quic-unidirectional-stream-owners.llvm.contains.txt"
$unidirectionalOwnerLlvmNotContainsPath = Join-Path $RepositoryRoot "examples\regression\expected\1297-quic-unidirectional-stream-owners.llvm.not-contains.txt"
$sendStreamReceiveRejectedPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\quic-send-stream-receive-rejected.slg"
$sendStreamReceiveRejectedExpectedPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\quic-send-stream-receive-rejected.stderr.contains.txt"
$receiveStreamSendRejectedPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\quic-receive-stream-send-rejected.slg"
$receiveStreamSendRejectedExpectedPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\quic-receive-stream-send-rejected.stderr.contains.txt"
$reassemblyFixturePath = Join-Path $RepositoryRoot "examples\regression\1300-quic-bounded-stream-reassembly.slg"
$reassemblyExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1300-quic-bounded-stream-reassembly.stdout.txt"
$finalSizeFixturePath = Join-Path $RepositoryRoot "examples\regression\1301-quic-reassembly-final-size-rejected.slg"
$finalSizeExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1301-quic-reassembly-final-size-rejected.stdout.txt"
$directionalFixturePath = Join-Path $RepositoryRoot "examples\regression\1210-quic-directional-control-frames.slg"
$directionalExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1210-quic-directional-control-frames.stdout.txt"
$directionalOwnerFixturePath = Join-Path $RepositoryRoot "examples\regression\1211-quic-directional-owner-transitions.slg"
$directionalOwnerExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1211-quic-directional-owner-transitions.stdout.txt"
$opaqueBoundaryFixturePath = Join-Path $RepositoryRoot "examples\regression\1391-opaque-struct-instance-boundary.slg"
$opaqueBoundarySourcesPath = Join-Path $RepositoryRoot "examples\regression\expected\1391-opaque-struct-instance-boundary.sources.txt"
$opaqueBoundaryExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1391-opaque-struct-instance-boundary.stdout.txt"
$opaqueAstFixturePath = Join-Path $RepositoryRoot "examples\regression\1392-selfhost-opaque-struct-ast.slg"
$opaqueAstSourcesPath = Join-Path $RepositoryRoot "examples\regression\expected\1392-selfhost-opaque-struct-ast.sources.txt"
$opaqueAstExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1392-selfhost-opaque-struct-ast.stdout.txt"
$opaqueDiagnosticsFixturePath = Join-Path $RepositoryRoot "examples\regression\1393-selfhost-opaque-struct-diagnostics.slg"
$opaqueDiagnosticsSourcesPath = Join-Path $RepositoryRoot "examples\regression\expected\1393-selfhost-opaque-struct-diagnostics.sources.txt"
$opaqueDiagnosticsExpectedPath = Join-Path $RepositoryRoot "examples\regression\expected\1393-selfhost-opaque-struct-diagnostics.stdout.txt"
$opaqueConstructionPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-construction.slg"
$opaqueConstructionSourcesPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-construction.sources.txt"
$opaqueConstructionExpectedPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-construction.stderr.contains.txt"
$opaqueFieldReadPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-field-read.slg"
$opaqueFieldReadSourcesPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-field-read.sources.txt"
$opaqueFieldReadExpectedPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-field-read.stderr.contains.txt"
$opaqueFieldWritePath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-field-write.slg"
$opaqueFieldWriteSourcesPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-field-write.sources.txt"
$opaqueFieldWriteExpectedPath = Join-Path $RepositoryRoot "examples\regression\diagnostics\opaque-struct-field-write.stderr.contains.txt"
$readmePath = Join-Path $RepositoryRoot "README.md"

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "QUIC stream API contract is missing: $contractPath"
}
if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
    throw "QUIC stream API schema is missing: $schemaPath"
}
foreach ($verifierPath in @(
    $nativeExactBatchPath,
    $frameConsumerVerifierPath,
    $stage2VerifierPath,
    $stage3VerifierPath,
    $linuxStage2VerifierPath,
    $linuxStage3VerifierPath,
    $browserStage2VerifierPath,
    $windowsQuicVerifierPath,
    $linuxQuicVerifierPath,
    $fieldVisibilityVerifierPath
)) {
    if (-not (Test-Path -LiteralPath $verifierPath -PathType Leaf)) {
        throw "QUIC stream verification gate is missing: $verifierPath"
    }
}
if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    throw "README is missing: $readmePath"
}
foreach ($sourcePath in @(
    $quicPath,
    $framePath,
    $transportPath,
    $streamStatePath,
    $reassemblyPath,
    $multiStreamFixturePath,
    $multiStreamExpectedPath,
    $optionsFixturePath,
    $optionsExpectedPath,
    $unidirectionalFixturePath,
    $unidirectionalExpectedPath,
    $unidirectionalOwnerFixturePath,
    $unidirectionalOwnerExpectedPath,
    $unidirectionalOwnerLlvmContainsPath,
    $unidirectionalOwnerLlvmNotContainsPath,
    $sendStreamReceiveRejectedPath,
    $sendStreamReceiveRejectedExpectedPath,
    $receiveStreamSendRejectedPath,
    $receiveStreamSendRejectedExpectedPath,
    $reassemblyFixturePath,
    $reassemblyExpectedPath,
    $finalSizeFixturePath,
    $finalSizeExpectedPath,
    $directionalFixturePath,
    $directionalExpectedPath,
    $directionalOwnerFixturePath,
    $directionalOwnerExpectedPath,
    $opaqueBoundaryFixturePath,
    $opaqueBoundarySourcesPath,
    $opaqueBoundaryExpectedPath,
    $opaqueAstFixturePath,
    $opaqueAstSourcesPath,
    $opaqueAstExpectedPath,
    $opaqueDiagnosticsFixturePath,
    $opaqueDiagnosticsSourcesPath,
    $opaqueDiagnosticsExpectedPath,
    $opaqueConstructionPath,
    $opaqueConstructionSourcesPath,
    $opaqueConstructionExpectedPath,
    $opaqueFieldReadPath,
    $opaqueFieldReadSourcesPath,
    $opaqueFieldReadExpectedPath,
    $opaqueFieldWritePath,
    $opaqueFieldWriteSourcesPath,
    $opaqueFieldWriteExpectedPath
)) {
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "QUIC stream implementation evidence is missing: $sourcePath"
    }
}

$readmeText = [System.IO.File]::ReadAllText($readmePath)
foreach ($requiredExample in @(
    'quic.bind(local)? => endpoint!',
    'endpoint! -> listen(identity)? => listener!',
    'endpoint! -> listenWith(identity, connectionOptions)? => listener!'
)) {
    if (-not $readmeText.Contains($requiredExample, [System.StringComparison]::Ordinal)) {
        throw "README does not retain the current QUIC endpoint example: $requiredExample"
    }
}
foreach ($obsoleteExample in @(
    'identity -> bind(',
    'no stateful `quic.bind(...)` module function'
)) {
    if ($readmeText.Contains($obsoleteExample, [System.StringComparison]::Ordinal)) {
        throw "README retains an obsolete QUIC bind description: $obsoleteExample"
    }
}

$raw = [System.IO.File]::ReadAllText($contractPath)
if (-not ($raw | Test-Json -SchemaFile $schemaPath)) {
    throw "QUIC stream API contract does not satisfy its schema"
}

$contract = $raw | ConvertFrom-Json -Depth 20
$frameConsumerFixtures = @($contract.frameExhaustiveConsumerFixtures)
if ($frameConsumerFixtures.Count -eq 0) {
    throw "QUIC frame exhaustive-consumer fixture contract is empty"
}
foreach ($fixture in $frameConsumerFixtures) {
    $fixturePath = Join-Path $RepositoryRoot "examples\regression\$fixture.slg"
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
        throw "QUIC frame exhaustive-consumer fixture is missing: $fixturePath"
    }
}
$frameConsumerVerifierText = [System.IO.File]::ReadAllText($frameConsumerVerifierPath)
if (-not $frameConsumerVerifierText.Contains('frameExhaustiveConsumerFixtures', [System.StringComparison]::Ordinal)) {
    throw "QUIC frame consumer verifier does not read the contract fixture authority"
}
foreach ($gate in @(
    [ordered]@{ Name = "Windows Stage2"; Path = $stage2VerifierPath },
    [ordered]@{ Name = "Windows Stage3"; Path = $stage3VerifierPath },
    [ordered]@{ Name = "Linux Stage2"; Path = $linuxStage2VerifierPath },
    [ordered]@{ Name = "Linux Stage3"; Path = $linuxStage3VerifierPath }
)) {
    $gateText = [System.IO.File]::ReadAllText($gate.Path)
    if (-not $gateText.Contains('verify-quic-frame-consumers.ps1', [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not run the QUIC frame exhaustive-consumer preflight"
    }
}
$ids = @($contract.invariants | ForEach-Object { $_.id })
if (($ids | Select-Object -Unique).Count -ne $ids.Count) {
    throw "QUIC stream invariant ids must be unique"
}

$fixtureIds = @($contract.verificationMatrix | ForEach-Object { $_.id })
if (($fixtureIds | Select-Object -Unique).Count -ne $fixtureIds.Count) {
    throw "QUIC stream verification fixture ids must be unique"
}
$covered = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($fixture in $contract.verificationMatrix) {
    foreach ($invariantId in $fixture.proves) {
        if ($invariantId -cnotin $ids) {
            throw "QUIC stream fixture $($fixture.id) references unknown invariant $invariantId"
        }
        [void]$covered.Add($invariantId)
    }
}
foreach ($invariantId in $ids) {
    if (-not $covered.Contains($invariantId)) {
        throw "QUIC stream invariant has no verification fixture: $invariantId"
    }
}

$qs2 = @($contract.implementationSlices | Where-Object { $_.id -ceq "QS2" })
if ($qs2.Count -ne 1) {
    throw "QUIC stream contract must declare exactly one QS2 slice"
}
if ('examples/regression/1206-quic-bidirectional-multi-stream-routing.slg' -cnotin @($qs2[0].files)) {
    throw "QS2 must retain the live multi-stream routing fixture"
}
if ('examples/regression/1209-quic-connection-options-queue-limits.slg' -cnotin @($qs2[0].files)) {
    throw "QS2 must retain the independent queue-limit fixture"
}
$qs6 = @($contract.implementationSlices | Where-Object { $_.id -ceq "QS6" })
if ($qs6.Count -ne 1 -or $qs6[0].status -cne "partial") {
    throw "QS6 must retain the partially verified unidirectional transport and registry foundation"
}
if ('examples/regression/1291-quic-unidirectional-stream-registry.slg' -cnotin @($qs6[0].files)) {
    throw "QS6 must retain the unidirectional stream registry fixture"
}
$qs3 = @($contract.implementationSlices | Where-Object { $_.id -ceq "QS3" })
if ($qs3.Count -ne 1 -or $qs3[0].status -cne "implemented") {
    throw "QS3 must remain implemented after directional owner platform closure"
}
if ('examples/regression/1210-quic-directional-control-frames.slg' -cnotin @($qs3[0].files)) {
    throw "QS3 must retain the directional control-frame boundary fixture"
}
if ('examples/regression/1211-quic-directional-owner-transitions.slg' -cnotin @($qs3[0].files)) {
    throw "QS3 must retain the live directional owner fixture"
}

$quicText = [System.IO.File]::ReadAllText($quicPath)
$frameText = [System.IO.File]::ReadAllText($framePath)
$transportText = [System.IO.File]::ReadAllText($transportPath)
$streamStateText = [System.IO.File]::ReadAllText($streamStatePath)
$reassemblyText = [System.IO.File]::ReadAllText($reassemblyPath)
foreach ($requiredImplementation in @(
    'public struct ReceiveWindowSizes',
    'public struct ConnectionOptions',
    'pendingInboundBidirectionalStreams: Int',
    'pendingInboundUnidirectionalStreams: Int',
    'pendingApplicationFrames: Int',
    'pendingApplicationBytes: UInt64',
    'public listenWith: mut self, identity: move Identity, options: ConnectionOptions',
    'public connectWith: mut self, peer: net.Endpoint, peerCertificate: move [UInt8; ~], options: ConnectionOptions',
    'public validate: self -> Result<ConnectionOptions, QuicError>',
    'pendingStreamFrames: reassembly.Queue',
    'pendingResetStreams: [frames.ResetStream; ~]',
    'pendingStopSending: [frames.StopSending; ~]',
    'pendingDatagrams: [frames.Datagram; ~]',
    'pendingMaxStreamData: [frames.MaxStreamData; ~]',
    'pumpApplicationPacket endpoint: mut Endpoint, connection: mut Connection',
    'peerReset: Bool',
    'peerStoppedSend: Bool',
    'localReadStopped: Bool',
    'public abortSend: mut self',
    'public requestStop: mut self'
    'public struct SendStream'
    'public struct ReceiveStream'
    'public openUni: mut self, endpoint: mut Endpoint -> Result<SendStream, QuicError>'
    'public acceptUni: mut self, endpoint: mut Endpoint -> Result<ReceiveStream, QuicError>'
    'sendDirectionImpl endpoint: mut Endpoint'
    'receiveDirectionImpl endpoint: mut Endpoint'
    'pendingStreamFrames: reassembly.Queue'
)) {
    if (-not $quicText.Contains($requiredImplementation, [System.StringComparison]::Ordinal)) {
        throw "QUIC Connection no longer retains its bounded application demultiplexer: $requiredImplementation"
    }
}
foreach ($requiredReassembly in @(
    'public struct Queue',
    'public account: self, streamId: UInt64, flow: streamState.ReceiveFlow',
    'public takeContiguous: mut self, streamId: UInt64, consumed: UInt64, maxBytes: UIntSize',
    'newlyReceived: nextFlow!.highestReceived - previousHighest',
    'skipped != 0 or delivered != available',
    'self.byteLength - UInt64(value!.data -> len) => self.byteLength'
)) {
    if (-not $reassemblyText.Contains($requiredReassembly, [System.StringComparison]::Ordinal)) {
        throw "QUIC bounded reassembly is incomplete: $requiredReassembly"
    }
}
foreach ($requiredUnidirectionalTransport in @(
    'unidirectionalStream: UInt64',
    'maxInboundUnidirectionalStreams: UInt64',
    'localInitiatedUnidirectionalStreamSendMaximum: UInt64',
    'peerInitiatedUnidirectionalStreamReceiveMaximum: UInt64',
    'initialMaxStreamDataUni: UInt64',
    'initialMaxStreamsUni: UInt64',
    'transport.initialMaxStreamDataUni()',
    'transport.initialMaxStreamsUni()',
    'maximum -> transport.streamCount'
)) {
    if (-not $quicText.Contains($requiredUnidirectionalTransport, [System.StringComparison]::Ordinal)) {
        throw "QUIC unidirectional transport foundation is incomplete: $requiredUnidirectionalTransport"
    }
}
foreach ($requiredUnidirectionalRegistry in @(
    'public onPeerUnidirectionalLimit: mut self',
    'public openUnidirectional: mut self',
    'public discoverPeerUnidirectional: mut self',
    'public observeInboundUnidirectional: mut self',
    'public nextPeerUnidirectional: mut self'
)) {
    if (-not $streamStateText.Contains($requiredUnidirectionalRegistry, [System.StringComparison]::Ordinal)) {
        throw "QUIC unidirectional stream registry is incomplete: $requiredUnidirectionalRegistry"
    }
}
foreach ($requiredFinalSizeGuard in @(
    'fin and end < self.highestReceived -> if {',
    'Result<ReceiveFlow, errors.Error>.Err(transportError(errors.finalSizeError())) -> return'
)) {
    if (-not $streamStateText.Contains($requiredFinalSizeGuard, [System.StringComparison]::Ordinal)) {
        throw "QUIC receive flow no longer rejects a final size below received data: $requiredFinalSizeGuard"
    }
}
foreach ($requiredDirectionalCodec in @(
    'public struct ResetStream',
    'applicationErrorCode: UInt64',
    'finalSize: UInt64',
    'public struct StopSending',
    'ResetStream(ResetStream)',
    'StopSending(StopSending)',
    'encodeResetStream value: ResetStream',
    'encodeStopSending value: StopSending',
    'decodeResetStream bytes:',
    'decodeStopSending bytes:'
)) {
    if (-not $frameText.Contains($requiredDirectionalCodec, [System.StringComparison]::Ordinal)) {
        throw "QUIC directional control-frame codec is incomplete: $requiredDirectionalCodec"
    }
}
foreach ($requiredDirectionalQueue in @(
    'queueResetStream(connection, value)?',
    'queueStopSending(connection, value)?'
)) {
    if (-not $quicText.Contains($requiredDirectionalQueue, [System.StringComparison]::Ordinal)) {
        throw "QUIC pump no longer retains bounded directional control state: $requiredDirectionalQueue"
    }
}
foreach ($requiredOptionApplication in @(
    'options.receiveWindows.connection',
    'options.receiveWindows.locallyInitiatedBidirectionalStream',
    'options.receiveWindows.remotelyInitiatedBidirectionalStream',
    'options.maxInboundBidirectionalStreams',
    'checkedOptions.pendingApplicationFrames',
    'checkedOptions.pendingApplicationBytes'
)) {
    if (-not $quicText.Contains($requiredOptionApplication, [System.StringComparison]::Ordinal)) {
        throw "QUIC ConnectionOptions no longer drive the live connection state: $requiredOptionApplication"
    }
}
$listenWithIndex = $quicText.IndexOf('public listenWith: mut self', [System.StringComparison]::Ordinal)
$listenValidationIndex = $quicText.IndexOf('validatedConnectionOptions(options)? => checkedOptions', $listenWithIndex, [System.StringComparison]::Ordinal)
$listenMutationIndex = $quicText.IndexOf('true => self.listening', $listenWithIndex, [System.StringComparison]::Ordinal)
if ($listenWithIndex -lt 0 -or $listenValidationIndex -le $listenWithIndex -or $listenMutationIndex -le $listenValidationIndex) {
    throw "QUIC listenWith must validate options before listener state mutation"
}
$connectImplIndex = $quicText.IndexOf('connectVersionImpl endpoint:', [System.StringComparison]::Ordinal)
$connectValidationIndex = $quicText.IndexOf('validatedConnectionOptions(options)? => checkedOptions', $connectImplIndex, [System.StringComparison]::Ordinal)
$connectRandomIndex = $quicText.IndexOf('endpoint -> uniqueConnectionId()', $connectImplIndex, [System.StringComparison]::Ordinal)
$connectSendIndex = $quicText.IndexOf('sendPacket(endpoint.socket, peer, packet)?', $connectImplIndex, [System.StringComparison]::Ordinal)
if ($connectImplIndex -lt 0 -or
    $connectValidationIndex -le $connectImplIndex -or
    $connectRandomIndex -le $connectValidationIndex -or
    $connectSendIndex -le $connectRandomIndex) {
    throw "QUIC connectWith must validate options before randomness and network effects"
}
if (-not $streamStateText.Contains('public observeInboundBidirectional: mut self, streamId: UInt64', [System.StringComparison]::Ordinal)) {
    throw "QUIC StreamRegistry no longer validates inbound bidirectional identities"
}
foreach ($requiredCapacityContract in @(
    'kind: errors.Kind.QueueLimitExceeded',
    'code: UInt64(self.pendingPeerBidirectionalLimit)'
)) {
    if (-not $streamStateText.Contains($requiredCapacityContract, [System.StringComparison]::Ordinal)) {
        throw "QUIC StreamRegistry no longer reports exact local identity capacity: $requiredCapacityContract"
    }
}
$queueStreamBody = [regex]::Match(
    $quicText,
    '(?ms)^queueStreamFrame\b.*?(?=^[A-Za-z_][A-Za-z0-9_]*\s[^\r\n]*\{)'
)
if (-not $queueStreamBody.Success) {
    throw "QUIC queueStreamFrame body could not be located"
}
$queueStreamSteps = @(
    'ensurePendingApplicationCapacity(connection, length)?',
    'connection.streams -> observeInboundBidirectional(value.id)',
    'connection.streams -> observeInboundUnidirectional(value.id)',
    'connection.pendingStreamFrames -> push(value)'
)
$previousStep = -1
foreach ($step in $queueStreamSteps) {
    $stepIndex = $queueStreamBody.Value.IndexOf($step, [System.StringComparison]::Ordinal)
    if ($stepIndex -le $previousStep) {
        throw "QUIC STREAM admission is no longer fail-before-mutation at step: $step"
    }
    $previousStep = $stepIndex
}
$receiveDirectionBody = [regex]::Match(
    $quicText,
    '(?ms)^receiveDirectionImpl\b.*?(?=^[A-Za-z_][A-Za-z0-9_]*\s[^\r\n]*\{)'
)
if (-not $receiveDirectionBody.Success) {
    throw "QUIC receiveDirectionImpl body could not be located"
}
$receiveReassemblySteps = @(
    'connection.pendingStreamFrames -> account(streamId, state.receiveFlow)',
    'connection.flow -> onReceive(accounted.newlyReceived)',
    'accounted.flow => state.receiveFlow',
    'connection.pendingStreamFrames -> takeContiguous('
)
$previousStep = -1
foreach ($step in $receiveReassemblySteps) {
    $stepIndex = $receiveDirectionBody.Value.IndexOf($step, [System.StringComparison]::Ordinal)
    if ($stepIndex -le $previousStep) {
        throw "QUIC receive reassembly no longer validates flow before ordered delivery at step: $step"
    }
    $previousStep = $stepIndex
}
foreach ($requiredApplicationCapacityContract in @(
    'kind: errors.Kind.QueueLimitExceeded',
    'pendingApplicationCapacityError(UInt64(connection.pendingApplicationFrameLimit))',
    'pendingApplicationCapacityError(connection.pendingApplicationByteLimit)'
)) {
    if (-not $quicText.Contains($requiredApplicationCapacityContract, [System.StringComparison]::Ordinal)) {
        throw "QUIC application queues no longer report their exact local capacity: $requiredApplicationCapacityContract"
    }
}
$pumpBody = [regex]::Match(
    $quicText,
    '(?ms)^pumpApplicationPacket\b.*?(?=^[A-Za-z_][A-Za-z0-9_]*\s[^\r\n]*\{)'
)
if (-not $pumpBody.Success) {
    throw "QUIC pumpApplicationPacket body could not be located"
}
if ($pumpBody.Value.Contains('observeInboundBidirectional', [System.StringComparison]::Ordinal)) {
    throw "QUIC pumpApplicationPacket must not mutate stream identity before queue admission"
}
$acceptBiBody = [regex]::Match(
    $quicText,
    '(?ms)^acceptBiImpl\b.*?(?=^[A-Za-z_][A-Za-z0-9_]*\s[^\r\n]*\{)'
)
if (-not $acceptBiBody.Success) {
    throw "QUIC acceptBiImpl body could not be located"
}
if ($acceptBiBody.Value.Contains('streamId: 0', [System.StringComparison]::Ordinal)) {
    throw "QUIC acceptBiImpl must not manufacture stream zero"
}

foreach ($gate in @(
    [ordered]@{ Name = "Windows QUIC"; Path = $windowsQuicVerifierPath },
    [ordered]@{ Name = "Linux QUIC"; Path = $linuxQuicVerifierPath }
)) {
    $gateText = [System.IO.File]::ReadAllText($gate.Path)
    foreach ($fixtureName in @(
        '1206-quic-bidirectional-multi-stream-routing',
        '1209-quic-connection-options-queue-limits',
        '1297-quic-unidirectional-stream-owners'
    )) {
        if (-not $gateText.Contains($fixtureName, [System.StringComparison]::Ordinal)) {
            throw "$($gate.Name) does not retain required QUIC fixture $fixtureName"
        }
    }
}

$surfaces = @{}
foreach ($surface in $contract.publicSurface) {
    $key = "$($surface.owner).$($surface.member)"
    if ($surfaces.ContainsKey($key)) {
        throw "duplicate QUIC stream public surface: $key"
    }
    $surfaces[$key] = $surface
}

foreach ($required in @(
    "StreamCount.value",
    "Endpoint.listenWith",
    "Endpoint.connectWith",
    "ConnectionOptions.validate",
    "Connection.openBi",
    "Connection.acceptBi",
    "Connection.openUni",
    "Connection.acceptUni",
    "Connection.close",
    "BiStream.send",
    "BiStream.receive",
    "BiStream.finish",
    "BiStream.abortSend",
    "BiStream.requestStop",
    "BiStream.id",
    "SendStream.send",
    "SendStream.finish",
    "SendStream.abortSend",
    "SendStream.id",
    "SendStream.isWriteFinished",
    "ReceiveStream.receive",
    "ReceiveStream.requestStop",
    "ReceiveStream.id",
    "ReceiveStream.isReadFinished"
)) {
    if (-not $surfaces.ContainsKey($required)) {
        throw "required QUIC stream public surface is missing: $required"
    }
}

if ($surfaces["Connection.close"].receiver -cne "move self") {
    throw "Connection.close must consume its affine owner"
}
if ($surfaces["BiStream.finish"].receiver -cne "mut self") {
    throw "BiStream.finish must half-close the write direction without consuming the stream"
}
if ($surfaces["StreamCount.value"].receiver -cne "self") {
    throw "StreamCount.value must remain a direct immutable scalar receiver"
}
foreach ($requiredStreamCount in @(
    'public struct StreamCount',
    '    raw: UInt64',
    'public streamCount value: UInt64 -> Result<StreamCount, errors.Error>',
    'impl StreamCount',
    'public value: self -> UInt64 => self.raw'
)) {
    if (-not $transportText.Contains($requiredStreamCount, [System.StringComparison]::Ordinal)) {
        throw "QUIC StreamCount domain boundary is incomplete: $requiredStreamCount"
    }
}

$fieldVisibilityMatrix = @($contract.verificationMatrix | Where-Object { $_.id -ceq 'QSF020' })
if ($fieldVisibilityMatrix.Count -ne 1) {
    throw 'QSF020 must define exactly one private StreamCount field verification contract'
}
$fieldVisibilityContract = $fieldVisibilityMatrix[0]
if ($fieldVisibilityContract.kind -cne 'negative' -or
    'QUIC-STREAM-015' -cnotin @($fieldVisibilityContract.proves)) {
    throw 'QSF020 must remain a negative representation-hiding contract for QUIC-STREAM-015'
}
foreach ($target in @('managed', 'windows-stage2', 'windows-stage3', 'linux-stage2', 'linux-stage3', 'browser')) {
    if ($target -cnotin @($fieldVisibilityContract.targets)) {
        throw "QSF020 does not retain required target: $target"
    }
}
foreach ($requiredEvidence in @(
    'external representation operations fail before LLVM',
    'one UInt64 aggregate with no heap wrapper'
)) {
    if (-not $fieldVisibilityContract.expected.Contains($requiredEvidence, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "QSF020 does not retain required evidence: $requiredEvidence"
    }
}

$fieldVisibilityVerifierText = [System.IO.File]::ReadAllText($fieldVisibilityVerifierPath)
foreach ($fixtureName in @(
    '1391-opaque-struct-instance-boundary',
    '1392-selfhost-opaque-struct-ast',
    '1393-selfhost-opaque-struct-diagnostics',
    'opaque-struct-construction',
    'opaque-struct-field-read',
    'opaque-struct-field-write'
)) {
    if (-not $fieldVisibilityVerifierText.Contains($fixtureName, [System.StringComparison]::Ordinal)) {
        throw "struct field visibility verifier does not retain fixture: $fixtureName"
    }
}
foreach ($zeroCostEvidence in @(
    'sollang_fn_sample_opaque_value_token',
    'sollang_fn_sample_opaque_value_Token_value',
    'insertvalue',
    'extractvalue'
)) {
    if (-not $fieldVisibilityVerifierText.Contains($zeroCostEvidence, [System.StringComparison]::Ordinal)) {
        throw "struct field visibility verifier does not retain isolated zero-cost evidence: $zeroCostEvidence"
    }
}

$fieldVisibilityGaps = @($contract.knownGaps | Where-Object { $_.id -ceq 'QG1' })
if ($fieldVisibilityGaps.Count -ne 1) {
    throw 'QG1 must remain singular until every field visibility target promotion passes'
}
foreach ($promotionTarget in @('Windows/Linux Stage2 and Stage3', 'browser checked compilation')) {
    if (-not $fieldVisibilityGaps[0].required.Contains($promotionTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "QG1 does not retain outstanding promotion target: $promotionTarget"
    }
}
foreach ($forbiddenStreamCount in @(
    'public validateStreamCount',
    'transport.validateStreamCount'
)) {
    if ($transportText.Contains($forbiddenStreamCount, [System.StringComparison]::Ordinal) -or
        $quicText.Contains($forbiddenStreamCount, [System.StringComparison]::Ordinal) -or
        $frameText.Contains($forbiddenStreamCount, [System.StringComparison]::Ordinal) -or
        $streamStateText.Contains($forbiddenStreamCount, [System.StringComparison]::Ordinal)) {
        throw "obsolete raw stream-count validation path remains: $forbiddenStreamCount"
    }
}

$sendStreamImpl = [regex]::Match($quicText, '(?ms)^impl SendStream \{.*?^\}')
$receiveStreamImpl = [regex]::Match($quicText, '(?ms)^impl ReceiveStream \{.*?^\}')
if (-not $sendStreamImpl.Success -or -not $receiveStreamImpl.Success) {
    throw "typed unidirectional stream implementation blocks are missing"
}
foreach ($forbidden in @('public receive:', 'public requestStop:', 'canRead', 'canWrite')) {
    if ($sendStreamImpl.Value.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "SendStream exposes forbidden receive capability: $forbidden"
    }
}
foreach ($forbidden in @('public send:', 'public finish:', 'public abortSend:', 'canRead', 'canWrite')) {
    if ($receiveStreamImpl.Value.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "ReceiveStream exposes forbidden send capability: $forbidden"
    }
}

$boundaryFixture = '"945-quic-flow-control-frames"'
$directionalFixture = '"1210-quic-directional-control-frames"'
$directionalOwnerFixture = '"1211-quic-directional-owner-transitions"'
$unidirectionalRegistryFixture = '"1291-quic-unidirectional-stream-registry"'
$unidirectionalOwnerFixture = '"1297-quic-unidirectional-stream-owners"'
$reassemblyFixture = '"1300-quic-bounded-stream-reassembly"'
$finalSizeFixture = '"1301-quic-reassembly-final-size-rejected"'
$nativeExactBatchText = [System.IO.File]::ReadAllText($nativeExactBatchPath)
foreach ($gate in @(
    [ordered]@{ Name = "native exact batch"; Path = $nativeExactBatchPath },
    [ordered]@{ Name = "Windows Stage2"; Path = $stage2VerifierPath },
    [ordered]@{ Name = "Windows Stage3"; Path = $stage3VerifierPath },
    [ordered]@{ Name = "Linux Stage2"; Path = $linuxStage2VerifierPath },
    [ordered]@{ Name = "Linux Stage3"; Path = $linuxStage3VerifierPath }
)) {
    $gateText = [System.IO.File]::ReadAllText($gate.Path)
    $invokesNativeBatch = $gateText.Contains("verify-native-exact-fixture-batch.ps1", [System.StringComparison]::Ordinal)
    if (-not $invokesNativeBatch -and $gate.Name -cne "native exact batch") {
        throw "$($gate.Name) does not invoke the bounded native exact batch"
    }
    if ($invokesNativeBatch) {
        $gateText += $nativeExactBatchText
    }
    if (-not $gateText.Contains($boundaryFixture, [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not retain fixture 945 as native exact execution evidence"
    }
    if (-not $gateText.Contains($directionalFixture, [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not retain fixture 1210 as directional native exact evidence"
    }
    if (-not $gateText.Contains($directionalOwnerFixture, [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not retain fixture 1211 as directional owner native exact evidence"
    }
    if (-not $gateText.Contains($unidirectionalRegistryFixture, [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not retain fixture 1291 as unidirectional registry native exact evidence"
    }
    if (-not $gateText.Contains($unidirectionalOwnerFixture, [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not retain fixture 1297 as typed unidirectional owner native exact evidence"
    }
    if (-not $gateText.Contains($reassemblyFixture, [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not retain fixture 1300 as bounded reassembly native exact evidence"
    }
    if (-not $gateText.Contains($finalSizeFixture, [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not retain fixture 1301 as final-size rejection native exact evidence"
    }
    foreach ($opaqueFixture in @(
        '1391-opaque-struct-instance-boundary',
        '1392-selfhost-opaque-struct-ast'
    )) {
        if (-not $gateText.Contains($opaqueFixture, [System.StringComparison]::Ordinal)) {
            throw "$($gate.Name) does not retain opaque representation fixture $opaqueFixture"
        }
    }
    if ($gate.Name -cne "native exact batch" -and
        -not $gateText.Contains('verify-selfhost-private-field-diagnostics.ps1', [System.StringComparison]::Ordinal)) {
        throw "$($gate.Name) does not invoke the direct private-field diagnostic manifests"
    }
}
if ($nativeExactBatchText.Contains('"1393-selfhost-opaque-struct-diagnostics"', [System.StringComparison]::Ordinal)) {
    throw "native exact batch must use direct promotion diagnostics instead of the managed 1393 meta-regression"
}

$browserStage2Text = [System.IO.File]::ReadAllText($browserStage2VerifierPath)
foreach ($browserOpaqueEvidence in @(
    '1391-opaque-struct-instance-boundary',
    'opaque-struct-construction',
    'opaque-struct-field-read',
    'opaque-struct-field-write'
)) {
    if (-not $browserStage2Text.Contains($browserOpaqueEvidence, [System.StringComparison]::Ordinal)) {
        throw "browser Stage2 does not retain opaque representation evidence: $browserOpaqueEvidence"
    }
}

$uniSlices = @($contract.implementationSlices | Where-Object { $_.id -ceq "QS4" })
if ($uniSlices.Count -ne 1 -or $uniSlices[0].status -cne "implemented") {
    throw "typed unidirectional stream owners must remain implemented and covered by live gates"
}

$reassemblySlices = @($contract.implementationSlices | Where-Object { $_.id -ceq "QS7" })
if ($reassemblySlices.Count -ne 1 -or $reassemblySlices[0].status -cne "implemented") {
    throw "bounded stream reassembly must remain implemented and covered by live gates"
}
if ('examples/regression/1300-quic-bounded-stream-reassembly.slg' -cnotin @($reassemblySlices[0].files)) {
    throw "QS7 must retain the bounded stream reassembly fixture"
}
if ('examples/regression/1301-quic-reassembly-final-size-rejected.slg' -cnotin @($reassemblySlices[0].files)) {
    throw "QS7 must retain the contradictory final-size fixture"
}
if (@($contract.knownGaps | Where-Object { $_.id -ceq 'QG5' }).Count -ne 0) {
    throw "QG5 must not remain open after bounded reassembly implementation"
}

$sliceOrder = @{}
for ($index = 0; $index -lt $contract.implementationSlices.Count; $index++) {
    $slice = $contract.implementationSlices[$index]
    if ($sliceOrder.ContainsKey($slice.id)) {
        throw "duplicate QUIC stream implementation slice: $($slice.id)"
    }
    $sliceOrder[$slice.id] = $index
}
foreach ($slice in $contract.implementationSlices) {
    foreach ($dependency in $slice.dependsOn) {
        if (-not $sliceOrder.ContainsKey($dependency)) {
            throw "QUIC stream slice $($slice.id) references unknown dependency $dependency"
        }
        if ($sliceOrder[$dependency] -ge $sliceOrder[$slice.id]) {
            throw "QUIC stream slice $($slice.id) dependency $dependency must precede it"
        }
    }
}

Write-Host ("[QUIC stream API contract] PASS {0} authorities, {1} surfaces, {2} invariants, {3} verification fixtures, {4} slices, {5} known gaps, {6} exhaustive frame consumers." -f `
    $contract.authorities.Count,
    $contract.publicSurface.Count,
    $contract.invariants.Count,
    $contract.verificationMatrix.Count,
    $contract.implementationSlices.Count,
    $contract.knownGaps.Count,
    $frameConsumerFixtures.Count)
