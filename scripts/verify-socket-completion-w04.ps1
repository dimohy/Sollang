[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/w04'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'verification-compiler-build.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/w04-partial-send.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/w04-partial-send.stdout.txt'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-w04-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @((Join-Path $PSScriptRoot 'verification-compiler-build.ps1'), (Join-Path $PSScriptRoot 'contracts/verification-compiler-build.json'), (Join-Path $PSScriptRoot 'verification-process.ps1'), $PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.cs'), (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "W04 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "W04 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'w04.exe'; $llvm = $exe + '.ll'; $bitcode = Join-Path $output 'w04.bc'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "W04 output already exists: $artifact" } }

$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
$formatExitCode=$null; $compileExitCode=$null; $compileDiagnosticsClean=$false; $nativeExitCode=$null; $llvmAsExitCode=$null; $closureExitCode=$null
$stdout=@(); $peerBytes=@(); $orphanProcessIds=@()
$irAssertions=[ordered]@{sendCallCount=0;rangeOffsetApplied=$false;rangeLengthApplied=$false;payloadCopyFree=$false;dequeueOwnerTransferVerified=$false}
try {
    $format=Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile','-File',$formatVerifier, '-Compiler', $compilerPath,'-Check','-Source',$fixture) -WorkingDirectory $root -Description 'W04 format' -TimeoutMilliseconds 120000
    $formatExitCode=$format.ExitCode; if($formatExitCode -ne 0){Add-Failure 'W04_FORMAT'}
    $compile=Invoke-VerificationCompilerBuild -Compiler $compilerPath -Source $fixture -Output $exe -Target 'windows-x64' -WorkingDirectory $root -Description 'W04 compile' -TimeoutMilliseconds 120000
    $compileExitCode=$compile.ExitCode; $compileText=$compile.Stdout+"`n"+$compile.Stderr
    $compileDiagnosticsClean=[string]::IsNullOrWhiteSpace($compile.Stderr) -and -not [regex]::IsMatch($compileText,'(?im)^(warning|note|error)\b')
    if($compileExitCode -ne 0 -or -not(Test-Path $llvm -PathType Leaf)){Add-Failure 'W04_COMPILE'}; if(-not $compileDiagnosticsClean){Add-Failure 'W04_COMPILE_DIAGNOSTIC'}
    if($compileExitCode -eq 0 -and (Test-Path $llvm -PathType Leaf)){
        $assembled=Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm,'-o',$bitcode) -WorkingDirectory $root -Description 'W04 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode=$assembled.ExitCode; if($llvmAsExitCode -ne 0){Add-Failure 'W04_LLVM_AS'}
        $closure=Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$llvm) -WorkingDirectory $root -Description 'W04 V004' -TimeoutMilliseconds 120000
        $closureExitCode=$closure.ExitCode; if($closureExitCode -ne 0){Add-Failure 'W04_V004'}
        $ir=[IO.File]::ReadAllText($llvm)
        $submit=[regex]::Match($ir,'define internal %sollang\.socket_result @sollang_platform_socket_completion_submit\(.*?\) #0 \{(?<body>.*?)\r?\n\}',[Text.RegularExpressions.RegexOptions]::Singleline)
        $dequeue=[regex]::Match($ir,'define internal %sollang\.socket_result @sollang_platform_socket_completion_dequeue\(.*?\) #0 \{(?<body>.*?)\r?\n\}',[Text.RegularExpressions.RegexOptions]::Singleline)
        if($submit.Success){$body=$submit.Groups['body'].Value;$irAssertions.sendCallCount=([regex]::Matches($body,'call i32 @WSASend')).Count;$irAssertions.rangeOffsetApplied=$body.Contains('getelementptr i8, ptr %buffer, i64 %range_offset',[StringComparison]::Ordinal);$irAssertions.rangeLengthApplied=$body.Contains('trunc i64 %range_length to i32',[StringComparison]::Ordinal)}
        $irAssertions.payloadCopyFree=$submit.Success -and $dequeue.Success -and $submit.Groups['body'].Value -notmatch '@llvm\.(memcpy|memmove)' -and $dequeue.Groups['body'].Value -notmatch '@llvm\.(memcpy|memmove)'
        if($dequeue.Success){$body=$dequeue.Groups['body'].Value;$irAssertions.dequeueOwnerTransferVerified=$body.Contains('store ptr null, ptr %entry_buffer_slot',[StringComparison]::Ordinal) -and $body.Contains('store atomic i64 0, ptr %pending_record release',[StringComparison]::Ordinal)}
        if($irAssertions.sendCallCount -ne 1){Add-Failure 'W04_IR_SEND'};if(-not $irAssertions.rangeOffsetApplied){Add-Failure 'W04_IR_OFFSET'};if(-not $irAssertions.rangeLengthApplied){Add-Failure 'W04_IR_LENGTH'};if(-not $irAssertions.payloadCopyFree){Add-Failure 'W04_IR_PAYLOAD_COPY'};if(-not $irAssertions.dequeueOwnerTransferVerified){Add-Failure 'W04_IR_OWNER_TRANSFER'}
        $process=[Diagnostics.Process]::new();$process.StartInfo=[Diagnostics.ProcessStartInfo]@{FileName=$exe;WorkingDirectory=$root;UseShellExecute=$false;CreateNoWindow=$true;RedirectStandardOutput=$true;RedirectStandardError=$true};$peer=$null
        try {
            if(-not $process.Start()){throw 'W04 native process could not start'};$stderrTask=$process.StandardError.ReadToEndAsync();$portTask=$process.StandardOutput.ReadLineAsync();if(-not $portTask.Wait(5000)){throw 'W04 did not publish peer port'};$portLine=$portTask.Result;if($portLine -notmatch '^peer-port=(\d+)$'){throw "W04 unexpected peer port line: $portLine"}
            $peer=[Net.Sockets.Socket]::new([Net.Sockets.AddressFamily]::InterNetwork,[Net.Sockets.SocketType]::Stream,[Net.Sockets.ProtocolType]::Tcp);$peer.ReceiveTimeout=5000;$peer.Connect([Net.IPAddress]::Loopback,[int]$Matches[1]);$buffer=[byte[]]::new(8);$count=0
            while($true){$received=$peer.Receive($buffer,$count,$buffer.Length-$count,[Net.Sockets.SocketFlags]::None);if($received -eq 0){break};$count+=$received;if($count -eq $buffer.Length){break}}
            if(-not $process.WaitForExit(5000)){throw 'W04 native process did not terminate'};$process.WaitForExit();$nativeExitCode=$process.ExitCode;$stderr=$stderrTask.GetAwaiter().GetResult();$stdout=@($process.StandardOutput.ReadToEnd() -split '\r?\n'|Where-Object{$_});$peerBytes=@($buffer[0..([Math]::Max(0,$count-1))]);$expected=@(Get-Content $expectedPath)
            if($nativeExitCode -ne 0 -or -not[string]::IsNullOrWhiteSpace($stderr) -or ($stdout -join "`n") -cne ($expected -join "`n") -or $count -ne 3 -or ($peerBytes -join ',') -cne '10,20,30'){Add-Failure 'W04_NATIVE_EXACT'}
        } finally {if($null-ne$peer){$peer.Dispose()};if(-not$process.HasExited){$process.Kill($true);$process.WaitForExit()};$process.Dispose()}
    }
} catch {Add-Failure 'W04_RUNNER_EXCEPTION'}
$orphanProcessIds=@(Get-CimInstance Win32_Process|Where-Object{-not[string]::IsNullOrWhiteSpace($_.ExecutablePath)-and[IO.Path]::GetFullPath($_.ExecutablePath)-ceq$exe}|ForEach-Object{[int]$_.ProcessId});if($orphanProcessIds.Count-ne0){Add-Failure 'W04_ORPHAN_PROCESS'}
$inputDrift=@();foreach($path in $inputs){$relative=[IO.Path]::GetRelativePath($root,$path).Replace('\','/');if((Get-FileHash $path -Algorithm SHA256).Hash-cne$inputHashes[$relative]){$inputDrift+=$relative}};if($inputDrift.Count-ne0){Add-Failure 'W04_INPUT_DRIFT'}
$record=[ordered]@{schemaVersion=1;caseId='W04';status=if($failures.Count-eq0){'passed'}else{'failed'};compilerSha256=$compilerSha256;inputStable=$inputDrift.Count-eq0;inputDrift=$inputDrift;inputHashes=$inputHashes;formatExitCode=$formatExitCode;compileExitCode=$compileExitCode;compileDiagnosticsClean=$compileDiagnosticsClean;nativeExitCode=$nativeExitCode;llvmAsExitCode=$llvmAsExitCode;closureExitCode=$closureExitCode;stdout=$stdout;peerBytes=$peerBytes;orphanProcessIds=$orphanProcessIds;irAssertions=$irAssertions;failureIds=@($failures)}
$json=($record|ConvertTo-Json -Depth 10)+"`n";[IO.File]::WriteAllText($resultPath,$json,[Text.UTF8Encoding]::new($false));if(-not($json|Test-Json -SchemaFile $schemaPath)){throw "W04 result schema failure: $resultPath"};if($record.status-cne'passed'){throw "W04 failed: $($record.failureIds -join ', '); result=$resultPath"};Write-Host "[socket completion W04] PASS result=$resultPath"
