param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = 'artifacts/scratch/portable-socket-completion-submission/focused'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = [IO.Path]::GetFullPath((Join-Path $root $Compiler))
$output = [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
$contractPath = Join-Path $root 'scripts/contracts/portable-socket-completion-submission.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/portable-socket-completion-submission.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/portable-socket-completion-submission-result.schema.json'
$contractRaw = Get-Content $contractPath -Raw
if (-not ($contractRaw | Test-Json -SchemaFile $contractSchemaPath)) { throw 'submission contract schema validation failed' }
$contract = $contractRaw | ConvertFrom-Json
$fixture = Join-Path $root $contract.fixture
$expectedPath = Join-Path $root $contract.expected
$pendingFixture = Join-Path $root $contract.pendingFixture
$pendingExpectedPath = Join-Path $root $contract.pendingExpected
$inputs = @(
    $PSCommandPath,
    (Join-Path $root 'scripts/format-authoritative-slg.ps1'),
    (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'),
    $contractPath,
    $contractSchemaPath,
    $resultSchemaPath,
    $fixture,
    $expectedPath,
    $pendingFixture,
    $pendingExpectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'),
    (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/Semantics/BoundProgram.cs'),
    (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Async.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/Tooling/WindowsLinker.cs'),
    $compilerPath
)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing focused input: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash $path -Algorithm SHA256).Hash
}
$compilerSha = (Get-FileHash $compilerPath -Algorithm SHA256).Hash
if ($compilerSha -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha" }
$exe = Join-Path $output 'socket-completion-submission.exe'
$llvm = [IO.Path]::ChangeExtension($exe, '.ll')
$bitcode = [IO.Path]::ChangeExtension($exe, '.bc')
$pendingExe = Join-Path $output 'socket-completion-pending-wake.exe'
$pendingLlvm = [IO.Path]::ChangeExtension($pendingExe, '.ll')
$pendingBitcode = [IO.Path]::ChangeExtension($pendingExe, '.bc')
$resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $pendingExe, $pendingLlvm, $pendingBitcode, $resultPath)) {
    if (Test-Path -LiteralPath $artifact) { throw "focused output already exists and will not be reused: $artifact" }
}
New-Item -ItemType Directory -Force -Path $output | Out-Null
$formatExitCode = 0
foreach ($formatSource in @($fixture, $pendingFixture, (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'))) {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @(
        '-NoProfile', '-File', (Join-Path $root 'scripts/format-authoritative-slg.ps1'), '-Check', '-Source', $formatSource
    ) -WorkingDirectory $root -Description "portable socket completion format $formatSource" -TimeoutMilliseconds 120000
    if ($format.ExitCode -ne 0) { throw "authoritative format failed for $formatSource`:`n$($format.Stderr)$($format.Stdout)" }
}
$compile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @(
    $compilerPath, 'build', $fixture, '-o', $exe, '--target', 'windows-x64',
    '--llvm', (Join-Path $root '.tools/llvm-22.1.8'), '-O0', '--keep-temps'
) -WorkingDirectory $root -Description 'portable socket completion compile' -TimeoutMilliseconds 120000
if ($compile.ExitCode -ne 0) { throw "focused compile failed:`n$($compile.Stderr)$($compile.Stdout)" }
$compileDiagnostics = $compile.Stderr + $compile.Stdout
$warningCount = ([regex]::Matches($compileDiagnostics, '(?im)^.*\bwarning\b.*$')).Count
$noteCount = ([regex]::Matches($compileDiagnostics, '(?im)^.*\bnote\b.*$')).Count
if ($warningCount -ne 0 -or $noteCount -ne 0) { throw "focused compile emitted warning/note diagnostics: warnings=$warningCount notes=$noteCount" }
$pendingCompile = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @(
    $compilerPath, 'build', $pendingFixture, '-o', $pendingExe, '--target', 'windows-x64',
    '--llvm', (Join-Path $root '.tools/llvm-22.1.8'), '-O0', '--keep-temps'
) -WorkingDirectory $root -Description 'portable socket pending wake compile' -TimeoutMilliseconds 120000
if ($pendingCompile.ExitCode -ne 0) { throw "pending wake compile failed:`n$($pendingCompile.Stderr)$($pendingCompile.Stdout)" }
$pendingDiagnostics = $pendingCompile.Stderr + $pendingCompile.Stdout
if ($pendingDiagnostics -match '(?im)^.*\b(warning|note)\b.*$') { throw 'pending wake compile emitted warning/note diagnostics' }
$llvmAs = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description 'portable socket completion llvm-as' -TimeoutMilliseconds 120000
if ($llvmAs.ExitCode -ne 0) { throw "llvm-as failed:`n$($llvmAs.Stderr)$($llvmAs.Stdout)" }
$closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'), '-LlvmPath', $llvm) -WorkingDirectory $root -Description 'portable socket completion V004' -TimeoutMilliseconds 120000
if ($closure.ExitCode -ne 0) { throw "V004 failed:`n$($closure.Stderr)$($closure.Stdout)" }
$pendingLlvmAs = Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($pendingLlvm, '-o', $pendingBitcode) -WorkingDirectory $root -Description 'portable socket pending wake llvm-as' -TimeoutMilliseconds 120000
if ($pendingLlvmAs.ExitCode -ne 0) { throw "pending wake llvm-as failed:`n$($pendingLlvmAs.Stderr)$($pendingLlvmAs.Stdout)" }
$pendingClosure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'), '-LlvmPath', $pendingLlvm) -WorkingDirectory $root -Description 'portable socket pending wake V004' -TimeoutMilliseconds 120000
if ($pendingClosure.ExitCode -ne 0) { throw "pending wake V004 failed:`n$($pendingClosure.Stderr)$($pendingClosure.Stdout)" }
$native = Invoke-VerificationProcessCapture -FilePath $exe -ArgumentList @() -WorkingDirectory $root -Description 'portable socket completion native' -TimeoutMilliseconds 120000
if ($native.ExitCode -ne 0) { throw "focused native failed $($native.ExitCode):`n$($native.Stderr)$($native.Stdout)" }
$orphanProcessIds = @(
    Get-CimInstance Win32_Process |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and [IO.Path]::GetFullPath($_.ExecutablePath) -ceq $exe } |
        ForEach-Object { [int]$_.ProcessId }
)
if ($orphanProcessIds.Count -ne 0) { throw "focused native left orphan process ids: $($orphanProcessIds -join ', ')" }
$actual = @($native.Stdout -split '\r?\n' | Where-Object { $_ -ne '' })
$expected = @(Get-Content $expectedPath)
if (($actual -join "`n") -cne ($expected -join "`n")) { throw "stdout mismatch expected=$($expected -join '|') actual=$($actual -join '|')" }

$peerStartInfo = [Diagnostics.ProcessStartInfo]::new()
$peerStartInfo.FileName = $pendingExe
$peerStartInfo.WorkingDirectory = $root
$peerStartInfo.UseShellExecute = $false
$peerStartInfo.CreateNoWindow = $true
$peerStartInfo.RedirectStandardOutput = $true
$peerStartInfo.RedirectStandardError = $true
$peerStartInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
$peerStartInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
$peerProcess = [Diagnostics.Process]::new()
$peerProcess.StartInfo = $peerStartInfo
$peerClient = $null
try {
    if (-not $peerProcess.Start()) { throw 'pending wake fixture could not start' }
    $peerProcessId = $peerProcess.Id
    $stderrTask = $peerProcess.StandardError.ReadToEndAsync()
    $portLineTask = $peerProcess.StandardOutput.ReadLineAsync()
    if (-not $portLineTask.Wait(5000)) { throw 'pending wake fixture did not publish its dynamic peer port' }
    $portLine = $portLineTask.Result
    if ($portLine -notmatch '^peer-port=(\d+)$') { throw "unexpected pending wake protocol line: $portLine" }
    $peerProcess.Refresh()
    $baselineThreadCount = $peerProcess.Threads.Count
    $peerClient = [Net.Sockets.TcpClient]::new()
    $peerClient.Connect('127.0.0.1', [int]$Matches[1])
    $peerConnectedAt = [DateTimeOffset]::UtcNow
    $readyLineTask = $peerProcess.StandardOutput.ReadLineAsync()
    if (-not $readyLineTask.Wait(5000)) { throw 'scheduler ready task did not run while dequeue was pending' }
    $readyLine = $readyLineTask.Result
    $readyObservedAt = [DateTimeOffset]::UtcNow
    if ($readyLine -cne 'ready-task=true') { throw "ready task ordering mismatch: $readyLine" }
    $peerProcess.Refresh()
    $pendingThreadCount = $peerProcess.Threads.Count
    $waiterThreadDelta = $pendingThreadCount - $baselineThreadCount
    if ($waiterThreadDelta -ne 1) { throw "pending submission must add exactly one reactor waiter: baseline=$baselineThreadCount pending=$pendingThreadCount" }
    $peerActivityAt = [DateTimeOffset]::UtcNow
    $peerBytes = [byte[]](100, 101)
    $peerStream = $peerClient.GetStream()
    $peerStream.Write($peerBytes, 0, $peerBytes.Length)
    $peerStream.Flush()
    $peerClient.Close()
    $peerClient = $null
    $remainingOutputTask = $peerProcess.StandardOutput.ReadToEndAsync()
    if (-not $peerProcess.WaitForExit(5000)) { throw 'pending wake fixture did not terminate' }
    $peerProcess.WaitForExit()
    $pendingStderr = $stderrTask.GetAwaiter().GetResult()
    $remainingOutput = $remainingOutputTask.GetAwaiter().GetResult()
    if ($peerProcess.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($pendingStderr)) { throw "pending wake native failed exit=$($peerProcess.ExitCode): $pendingStderr" }
    $pendingProcessExitedAt = [DateTimeOffset]::UtcNow
    $pendingActual = @($readyLine) + @($remainingOutput -split '\r?\n' | Where-Object { $_ -ne '' })
    $pendingExpected = @(Get-Content $pendingExpectedPath)
    if (($pendingActual -join "`n") -cne ($pendingExpected -join "`n")) { throw "pending wake stdout mismatch expected=$($pendingExpected -join '|') actual=$($pendingActual -join '|')" }
    if ($peerActivityAt -lt $readyObservedAt) { throw 'peer activity occurred before pending ready-task observation' }
    $pendingNativeExitCode = $peerProcess.ExitCode
} finally {
    if ($null -ne $peerClient) { $peerClient.Dispose() }
    if (-not $peerProcess.HasExited) { $peerProcess.Kill($true); $peerProcess.WaitForExit() }
    $peerProcess.Dispose()
}
$orphanProcessIds = @(
    Get-CimInstance Win32_Process |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and
            @($exe, $pendingExe) -ccontains [IO.Path]::GetFullPath($_.ExecutablePath)
        } |
        ForEach-Object { [int]$_.ProcessId }
)
if ($orphanProcessIds.Count -ne 0) { throw "focused native left orphan process ids: $($orphanProcessIds -join ', ')" }
$ir = Get-Content $llvm -Raw
$pendingIr = Get-Content $pendingLlvm -Raw
foreach ($needle in @(
    '@sollang_platform_socket_completion_submit',
    '@CreateIoCompletionPort',
    '@SetFileCompletionNotificationModes',
    '@WSARecv',
    '@sollang_platform_socket_completion_cancel',
    '@CancelIoEx',
    '@sollang_platform_socket_completion_dequeue',
    '@GetQueuedCompletionStatusEx',
    '@sollang_socket_completion_dequeue_task_worker',
    '@sollang_task_start'
)) { if (-not $ir.Contains($needle, [StringComparison]::Ordinal)) { throw "LLVM omission: $needle" } }
$waiterBody = [regex]::Match($pendingIr, 'define internal i32 @sollang_socket_completion_waiter\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
$taskWorkerBody = [regex]::Match($pendingIr, 'define internal i1 @sollang_socket_completion_dequeue_task_worker\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $waiterBody.Success -or ([regex]::Matches($waiterBody.Value, '@GetQueuedCompletionStatusEx')).Count -ne 1) { throw 'reactor waiter must own the sole blocking dequeue call site' }
if (([regex]::Matches($pendingIr, 'call i32 @GetQueuedCompletionStatusEx')).Count -ne 1) { throw 'reactor waiter must be the only IOCP completion consumer' }
if (-not $taskWorkerBody.Success -or $taskWorkerBody.Value.Contains('@GetQueuedCompletionStatusEx', [StringComparison]::Ordinal) -or -not $taskWorkerBody.Value.Contains('ret i1 false', [StringComparison]::Ordinal)) { throw 'Task worker must park without blocking or polling IOCP' }
$waiterThreadCallSites = ([regex]::Matches($pendingIr, 'call ptr @CreateThread\([^\r\n]*@sollang_socket_completion_waiter')).Count
if ($waiterThreadCallSites -ne 1) { throw "reactor waiter CreateThread call site count must be one; actual=$waiterThreadCallSites" }
foreach ($symbol in @('sollang_platform_socket_completion_submit','sollang_platform_socket_completion_dequeue')) {
    $match = [regex]::Match($ir, "define internal .*?@$symbol\(.*?\) #0 \{(?<body>.*?)\r?\n\}", [Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { throw "missing LLVM body: $symbol" }
    if ($match.Groups['body'].Value -match '@llvm\.(memcpy|memmove)') { throw "$symbol copies caller payload" }
}
$submit = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_submit\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
$cancel = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_cancel\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
$dequeue = [regex]::Match($ir, 'define internal %sollang\.socket_result @sollang_platform_socket_completion_dequeue\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $submit.Success -or -not $cancel.Success -or -not $dequeue.Success) { throw 'missing submission ownership body' }
if (([regex]::Matches($cancel.Value, '@CancelIoEx')).Count -ne 1) { throw 'cancel must contain one native cancellation call site' }
if (([regex]::Matches($dequeue.Value, '@GetQueuedCompletionStatusEx')).Count -ne 0 -or
    ([regex]::Matches($dequeue.Value, '@sollang_free')).Count -ne 0 -or
    $dequeue.Groups['body'].Value.IndexOf('store ptr null, ptr %entry_buffer_slot', [StringComparison]::Ordinal) -lt 0 -or
    $dequeue.Groups['body'].Value.IndexOf('store atomic i64 0, ptr %pending_record release', [StringComparison]::Ordinal) -lt 0) {
    throw 'dequeue must transfer the retained owner, clear its source, and select one terminal completion without freeing payload storage'
}
$close = [regex]::Match($ir, 'define internal void @sollang_platform_socket_completion_close\(.*?\) #0 \{(?<body>.*?)\r?\n\}', [Text.RegularExpressions.RegexOptions]::Singleline)
$closeBody = $close.Groups['body'].Value
if (-not $close.Success -or
    $closeBody.Contains('@GetQueuedCompletionStatusEx', [StringComparison]::Ordinal) -or
    $closeBody.IndexOf('@CancelIoEx', [StringComparison]::Ordinal) -gt $closeBody.IndexOf('@PostQueuedCompletionStatus', [StringComparison]::Ordinal) -or
    $closeBody.IndexOf('@PostQueuedCompletionStatus', [StringComparison]::Ordinal) -gt $closeBody.IndexOf('@WaitForSingleObject', [StringComparison]::Ordinal) -or
    $closeBody.IndexOf('@WaitForSingleObject', [StringComparison]::Ordinal) -gt $closeBody.IndexOf('sollang_free(ptr %completed_buffer)', [StringComparison]::Ordinal) -or
    $closeBody.IndexOf('sollang_free(ptr %completed_buffer)', [StringComparison]::Ordinal) -gt $closeBody.IndexOf('@closesocket', [StringComparison]::Ordinal)) {
    throw 'close must cancel, let the waiter drain, stop/join it, then free retained buffers and sockets'
}
foreach ($invariant in @(
    '%cancel_is_pending = icmp eq i64 %cancel_active, 1',
    '%completed_is_terminal = icmp eq i64 %completed_active, 2',
    '%waiting_task_clear = icmp eq ptr %waiting_task, null'
)) { if (-not $closeBody.Contains($invariant, [StringComparison]::Ordinal)) { throw "close invariant omission: $invariant" } }
$closeCallSites = [ordered]@{
    cancelIoEx = ([regex]::Matches($closeBody, '@CancelIoEx')).Count
    stopPacket = ([regex]::Matches($closeBody, '@PostQueuedCompletionStatus')).Count
    waiterJoin = ([regex]::Matches($closeBody, '@WaitForSingleObject')).Count
    retainedBufferFree = ([regex]::Matches($closeBody, 'sollang_free\(ptr %completed_buffer\)')).Count
    socketClose = ([regex]::Matches($closeBody, '@closesocket')).Count
    waiterHandleClose = ([regex]::Matches($closeBody, '@CloseHandle\(ptr %waiter\)')).Count
    completionPortClose = ([regex]::Matches($closeBody, '@CloseHandle\(ptr %port\)')).Count
}
foreach ($entry in $closeCallSites.GetEnumerator()) {
    if ($entry.Value -ne 1) { throw "close $($entry.Key) call site count must be exactly one; actual=$($entry.Value)" }
}
if ($closeBody.IndexOf('store ptr null, ptr %completed_buffer_slot', [StringComparison]::Ordinal) -lt 0 -or
    $closeBody.IndexOf('store atomic i64 0, ptr %completed_entry release', [StringComparison]::Ordinal) -lt 0) {
    throw 'close must clear each released retained-buffer record exactly once'
}
$drift = @()
foreach ($path in $inputs) {
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    if ((Get-FileHash $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $drift += $relative }
}
$result = [ordered]@{
    schemaVersion = 1
    status = if ($drift.Count -eq 0) { 'passed' } else { 'failed' }
    completed = if ($drift.Count -eq 0) { 1 } else { 0 }
    total = 1
    compilerSha256 = $compilerSha
    inputStable = $drift.Count -eq 0
    inputDrift = $drift
    compileExitCode = $compile.ExitCode
    formatExitCode = $formatExitCode
    warningCount = $warningCount
    noteCount = $noteCount
    nativeExitCode = $native.ExitCode
    llvmAsExitCode = $llvmAs.ExitCode
    directCallClosureExitCode = $closure.ExitCode
    pendingCompileExitCode = $pendingCompile.ExitCode
    pendingNativeExitCode = $pendingNativeExitCode
    pendingLlvmAsExitCode = $pendingLlvmAs.ExitCode
    pendingDirectCallClosureExitCode = $pendingClosure.ExitCode
    pendingStdout = $pendingActual
    peerConnectedAt = $peerConnectedAt.ToString('O')
    readyObservedAt = $readyObservedAt.ToString('O')
    peerActivityAt = $peerActivityAt.ToString('O')
    pendingProcessExitedAt = $pendingProcessExitedAt.ToString('O')
    baselineThreadCount = $baselineThreadCount
    pendingThreadCount = $pendingThreadCount
    waiterThreadDelta = $waiterThreadDelta
    waiterThreadCallSites = $waiterThreadCallSites
    orphanProcessIds = $orphanProcessIds
    payloadCopyFree = $true
    dequeueOwnerTransferVerified = $true
    waiterJoinedBeforeExit = $true
    closeCallSites = $closeCallSites
    stdout = $actual
    llvmSha256 = (Get-FileHash $llvm -Algorithm SHA256).Hash
    pendingLlvmSha256 = (Get-FileHash $pendingLlvm -Algorithm SHA256).Hash
    inputHashes = $inputHashes
}
$json = ($result | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw 'focused result schema validation failed' }
if ($drift.Count -ne 0) { throw "focused inputs drifted: $($drift -join ', ')" }
Write-Host "[portable socket completion submission] PASS 1/1 result=$resultPath"
