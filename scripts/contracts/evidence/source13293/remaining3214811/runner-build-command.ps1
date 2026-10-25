$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. "$root/scripts/managed-reference-snapshot.ps1"
$output="$root/artifacts/scratch/resume-20261006-owner-continuation22/runner14810"
if(Test-Path -LiteralPath $output){throw 'EXAMPLETESTS_RUNNER_OUTPUT_EXISTS_NO_RETRY'}
$dotnet=(Get-Command dotnet -CommandType Application).Source
$arguments=@('build',"$root/tests/Sollang.ExampleTests/Sollang.ExampleTests.csproj",'-c','Release','--no-restore','--nologo','-v','minimal','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false','-warnaserror','--output',"$output/bin")
$roots=@('src/Sollang.Compiler','src/Sollang.Compiler.Generators','tests/Sollang.ExampleTests','stdlib','syntax' | ForEach-Object {Join-Path $root $_})
$required=@($dotnet,$PSCommandPath,"$root/global.json","$root/Directory.Build.props","$root/scripts/managed-reference-snapshot.ps1","$root/scripts/verification-process.ps1","$root/scripts/input-fingerprint-stability.ps1")
foreach($name in @('src/Sollang.Compiler','src/Sollang.Compiler.Generators','tests/Sollang.ExampleTests')){$required+=Join-Path $root "$name/obj/project.assets.json"}
$protected=@("$root/artifacts/scratch/resume-20261006-owner-continuation22/managed14487/compiler/Sollang.Compiler.dll","$root/artifacts/scratch/resume-20261006-owner-continuation22/v12432/compiler-build01/compiler.exe","$root/artifacts/scratch/resume-20261006-owner-continuation22/v14562/compiler-build01/compiler.exe","$root/artifacts/scratch/resume-20261006-owner-continuation22/v14775/compiler-build01/compiler.exe","$root/src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll")
$required+=$protected
$before=Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet)+$arguments)
[IO.Directory]::CreateDirectory($output)|Out-Null
$before | ConvertTo-Json -Depth 8 | Set-Content "$output/inputs-before.json"
$result=[ordered]@{schemaVersion=1;status='running';scope='One current ExampleTests runner build for original frozen32 and subsequent full catalog; no regression cases executed';buildBudget=1;buildInvocations=1;stage2Stage3Executed=$false;buildSeconds=180}
$result | ConvertTo-Json | Set-Content "$output/result.json"
try {
 $done=Invoke-VerificationProcessCapture -FilePath $dotnet -ArgumentList $arguments -Description 'Current ExampleTests runner build' -WorkingDirectory $root -TimeoutMilliseconds 180000 -ExecutionRecordPath "$output/build.execution.json"
 $after=Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet)+$arguments)
 $after | ConvertTo-Json -Depth 8 | Set-Content "$output/inputs-after.json"
 Assert-InputFingerprintStable -ExpectedFingerprint $before.fingerprint -CurrentFingerprint $after.fingerprint -Phase 'Current ExampleTests build'
 if($done.ExitCode -ne 0){throw "EXAMPLETESTS_RUNNER_BUILD_EXIT_$($done.ExitCode)"}
 $result.status='passed';$result.exitCode=$done.ExitCode;$result.inputFingerprint=$before.fingerprint;$result.finalInputFingerprint=$after.fingerprint;$result.inputsStable=$true;$result.processesStopped=$true
 $result.runnerSha256=(Get-FileHash "$output/bin/Sollang.ExampleTests.dll").Hash;$result.compilerDllSha256=(Get-FileHash "$output/bin/Sollang.Compiler.dll").Hash
} catch {$result.status='failed';$result.failure=$_.Exception.Message;throw} finally {$result|ConvertTo-Json -Depth 6|Set-Content "$output/result.json"}
$result|ConvertTo-Json -Depth 4
