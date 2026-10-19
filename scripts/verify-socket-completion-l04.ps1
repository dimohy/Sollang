[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$Distribution = 'Ubuntu',
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/l04'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$fixture = Join-Path $root 'scripts/probes/socket-completion/l02-pending-receive.slg'
$expectedPath = Join-Path $root 'scripts/probes/socket-completion/l02-pending-receive.stdout.txt'
$shimSource = Join-Path $root 'scripts/probes/socket-completion/l04-false-readiness-recv.c'
$schemaPath = Join-Path $root 'scripts/contracts/socket-completion-l04-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = @($PSCommandPath, $schemaPath, $formatVerifier, $closureVerifier, $fixture, $expectedPath, $shimSource,
    (Join-Path $root 'stdlib/std/net/socket.slg'), (Join-Path $root 'stdlib/sys/runtime/socket.slg'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'),
    (Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'), $compilerPath)
$inputHashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "L04 input missing: $path" }
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw "L04 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'l04'; $llvm = Join-Path $output 'l04.ll'; $bitcode = Join-Path $output 'l04.bc'; $shim = Join-Path $output 'l04-recv.so'; $tracePath = Join-Path $output 'forced.trace'; $resultPath = Join-Path $output 'result.json'
foreach ($artifact in @($exe, $llvm, $bitcode, $shim, $tracePath, $resultPath)) { if (Test-Path -LiteralPath $artifact) { throw "L04 output already exists: $artifact" } }
$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
function Get-FunctionBody([string]$Ir, [string]$Name) {
    $escaped = [regex]::Escape($Name)
    $match = [regex]::Match($Ir, "(?m)^define internal [^\r\n]+ @$escaped\([^\r\n]*\) #0 \{(?<body>.*?)\r?\n\}", [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Groups['body'].Value }
    return ''
}
$formatExitCode=$null; $compileExitCode=$null; $compileDiagnosticsClean=$false; $shimCompileExitCode=$null; $shimDiagnosticsClean=$false; $llvmAsExitCode=$null; $closureExitCode=$null; $nativeExitCode=$null
$stdout=@(); $stderr=''; $trace=@(); $orphanProcessIds=@()
$irAssertions=[ordered]@{singleBlockingWaiter=$false;oneShotInterest=$false;wouldBlockRearms=$false;rearmDoesNotPublish=$false;terminalPublishOnce=$false;taskWakeHandoff=$false}
try {
    $format=Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile','-File',$formatVerifier,'-Check','-Source',$fixture) -WorkingDirectory $root -Description 'L04 format' -TimeoutMilliseconds 120000
    $formatExitCode=$format.ExitCode;if($formatExitCode-ne0){Add-Failure 'L04_FORMAT'}
    $compile=Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath,'build',$fixture,'-o',$exe,'--target','linux-x64','-O0','--keep-temps') -WorkingDirectory $root -Description 'L04 compile' -TimeoutMilliseconds 120000
    $compileExitCode=$compile.ExitCode;$compileText=$compile.Stdout+"`n"+$compile.Stderr;$compileDiagnosticsClean=[string]::IsNullOrWhiteSpace($compile.Stderr)-and-not[regex]::IsMatch($compileText,'(?im)^(warning|note|error)\b')
    if($compileExitCode-ne0-or-not(Test-Path $llvm -PathType Leaf)){Add-Failure 'L04_COMPILE'};if(-not$compileDiagnosticsClean){Add-Failure 'L04_COMPILE_DIAGNOSTIC'}
    if($compileExitCode-eq0-and(Test-Path $llvm -PathType Leaf)){
        $assembled=Invoke-VerificationProcessCapture -FilePath (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') -ArgumentList @($llvm,'-o',$bitcode) -WorkingDirectory $root -Description 'L04 llvm-as' -TimeoutMilliseconds 120000
        $llvmAsExitCode=$assembled.ExitCode;if($llvmAsExitCode-ne0){Add-Failure 'L04_LLVM_AS'}
        $closure=Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$llvm) -WorkingDirectory $root -Description 'L04 V004' -TimeoutMilliseconds 120000
        $closureExitCode=$closure.ExitCode;if($closureExitCode-ne0){Add-Failure 'L04_V004'}
        $ir=[IO.File]::ReadAllText($llvm);$waiter=Get-FunctionBody $ir 'sollang_socket_completion_waiter';$submit=Get-FunctionBody $ir 'sollang_platform_socket_completion_submit'
        $irAssertions.singleBlockingWaiter=([regex]::Matches($ir,'(?m)^\s*%[^=]+ = call i32 @epoll_wait\(')).Count-eq1-and$waiter.Contains('i32 1, i32 -1)',[StringComparison]::Ordinal)
        $irAssertions.oneShotInterest=$submit.Contains('or i32 %association_interest, 1073741824',[StringComparison]::Ordinal)-and$submit.Contains('or i32 %rearm_interest, 1073741824',[StringComparison]::Ordinal)
        $irAssertions.wouldBlockRearms=$waiter.Contains('%would_block = icmp eq i32 %completion_error, 11',[StringComparison]::Ordinal)-and$waiter.Contains('br i1 %would_block, label %rearm, label %publish_failure',[StringComparison]::Ordinal)-and$waiter.Contains('call i32 @epoll_ctl(i32 %epoll, i32 3',[StringComparison]::Ordinal)
        $rearm=[regex]::Match($waiter,'(?ms)^rearm:\r?\n(?<body>.*?)^pending_continue:').Groups['body'].Value
        $irAssertions.rearmDoesNotPublish=$rearm.Length-gt0-and$rearm-notmatch 'store atomic i64 2|sollang_io_push_completion'
        $irAssertions.terminalPublishOnce=([regex]::Matches($waiter,'store atomic i64 2, ptr %pending_entry release')).Count-eq1
        $irAssertions.taskWakeHandoff=$waiter.Contains('atomicrmw xchg ptr %task_slot, ptr null acq_rel',[StringComparison]::Ordinal)-and$waiter.Contains('call void @sollang_io_push_completion(ptr %task)',[StringComparison]::Ordinal)
        foreach($entry in $irAssertions.GetEnumerator()){if(-not$entry.Value){Add-Failure ("L04_IR_"+$entry.Key.ToUpperInvariant())}}
        $wsrc=(& wsl.exe -d $Distribution -- wslpath -a ($shimSource.Replace('\','/'))).Trim();$wshim=(& wsl.exe -d $Distribution -- wslpath -a ($shim.Replace('\','/'))).Trim();$wexe=(& wsl.exe -d $Distribution -- wslpath -a ($exe.Replace('\','/'))).Trim();$wtrace=(& wsl.exe -d $Distribution -- wslpath -a ($tracePath.Replace('\','/'))).Trim()
        $shimCompile=Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d',$Distribution,'--','gcc','-shared','-fPIC','-O2','-Wall','-Wextra','-Werror',$wsrc,'-o',$wshim,'-ldl') -WorkingDirectory $root -Description 'L04 shim' -TimeoutMilliseconds 20000
        $shimCompileExitCode=$shimCompile.ExitCode;$shimDiagnosticsClean=[string]::IsNullOrWhiteSpace($shimCompile.Stdout)-and[string]::IsNullOrWhiteSpace($shimCompile.Stderr);if($shimCompileExitCode-ne0-or-not$shimDiagnosticsClean){Add-Failure 'L04_SHIM'}
        if($shimCompileExitCode-eq0){$native=Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d',$Distribution,'--','env',"LD_PRELOAD=$wshim",'SOLLANG_L04_FORCE_EAGAIN=1',"SOLLANG_L04_TRACE=$wtrace",$wexe) -WorkingDirectory $root -Description 'L04 native' -TimeoutMilliseconds 20000;$nativeExitCode=$native.ExitCode;$stdout=[string[]]@($native.Stdout-split'\r?\n'|Where-Object{$_});$stderr=$native.Stderr.Trim();$trace=if(Test-Path $tracePath){[string[]]@(Get-Content $tracePath)}else{[string[]]@()};$expected=[string[]]@(Get-Content $expectedPath);if($nativeExitCode-ne0-or$stderr.Length-ne0-or($stdout-join"`n")-cne($expected-join"`n")-or($trace-join"`n")-cne'forced-recv-call=2'){Add-Failure 'L04_EXACT'}}
        $orphanText=(& wsl.exe -d $Distribution -- sh -lc "pgrep -f -x '$wexe' || true")-join"`n";$orphanProcessIds=@($orphanText-split'\r?\n'|Where-Object{$_-match'^\d+$'}|ForEach-Object{[int]$_});if($orphanProcessIds.Count-ne0){Add-Failure 'L04_ORPHAN_PROCESS'}
    }
}catch{Add-Failure 'L04_RUNNER_EXCEPTION'}
$inputDrift=@();foreach($path in $inputs){$relative=[IO.Path]::GetRelativePath($root,$path).Replace('\','/');if((Get-FileHash $path -Algorithm SHA256).Hash-cne$inputHashes[$relative]){$inputDrift+=$relative}};if($inputDrift.Count-ne0){Add-Failure 'L04_INPUT_DRIFT'}
$record=[ordered]@{schemaVersion=1;caseId='L04';status=if($failures.Count-eq0){'passed'}else{'failed'};compilerSha256=$compilerSha256;inputStable=$inputDrift.Count-eq0;inputDrift=$inputDrift;inputHashes=$inputHashes;formatExitCode=$formatExitCode;compileExitCode=$compileExitCode;compileDiagnosticsClean=$compileDiagnosticsClean;shimCompileExitCode=$shimCompileExitCode;shimDiagnosticsClean=$shimDiagnosticsClean;llvmAsExitCode=$llvmAsExitCode;closureExitCode=$closureExitCode;nativeExitCode=$nativeExitCode;stdout=$stdout;stderr=$stderr;trace=[string[]]@($trace);orphanProcessIds=$orphanProcessIds;irAssertions=$irAssertions;failureIds=@($failures)}
$json=($record|ConvertTo-Json -Depth 12)+"`n";[IO.File]::WriteAllText($resultPath,$json,[Text.UTF8Encoding]::new($false));if(-not($json|Test-Json -SchemaFile $schemaPath)){throw "L04 result schema failure: $resultPath"};if($record.status-cne'passed'){throw "L04 failed: $($record.failureIds -join ', '); result=$resultPath"};Write-Host "[socket completion L04] PASS result=$resultPath"
