$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. scripts/managed-reference-snapshot.ps1
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$o=Join-Path $b 'managed12768'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$dotnet=(Get-Command dotnet -CommandType Application).Source
$project=Join-Path $root 'src/Sollang.Compiler/Sollang.Compiler.csproj'
$globalDll=Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$globalBefore=(Get-FileHash -LiteralPath $globalDll -Algorithm SHA256).Hash
$argv=@('build',$project,'-c','Release','--no-restore','--nologo','-v','minimal','--disable-build-servers','-nodeReuse:false','-p:UseSharedCompilation=false','-warnaserror','--output',(Join-Path $o 'compiler'))
$roots=@('src/Sollang.Compiler','src/Sollang.Compiler.Generators','stdlib','syntax'|ForEach-Object{Join-Path $root $_})
$required=@($dotnet,$PSCommandPath,(Join-Path $root 'scripts/managed-reference-snapshot.ps1'),(Join-Path $root 'scripts/verification-process.ps1'))
foreach($name in @('Directory.Build.props','Directory.Build.targets','global.json','NuGet.Config','nuget.config')){$p=Join-Path $root $name;if(Test-Path -LiteralPath $p -PathType Leaf){$required+=$p}}
$before=Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet)+$argv)
$before|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $o 'inputs-before.json') -Encoding utf8
$r=[ordered]@{schemaVersion=1;status='running';scope='One isolated CSharp C711 bounded dictionary numerator repair build; global managed compiler and retained native products protected';inputFingerprint=$before.fingerprint;buildBudget=1;buildInvocations=1;globalManagedDllSha256Before=$globalBefore;stage2Stage3Executed=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 8)+"`n",[Text.UTF8Encoding]::new($false))}
Save
try{
 $a=Invoke-VerificationProcessCapture -FilePath $dotnet -ArgumentList $argv -WorkingDirectory $root -Description 'C711 bounded dictionary numerator isolated managed compiler' -TimeoutMilliseconds 180000 -ExecutionRecordPath (Join-Path $o 'build.execution.json')
 $r.exitCode=$a.ExitCode
 if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('ISOLATED_MANAGED_BUILD_FAILED '+$a.Stderr)}
 $after=Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet)+$argv)
 $after|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $o 'inputs-after.json') -Encoding utf8
 Assert-InputFingerprintStable -ExpectedFingerprint $before.fingerprint -CurrentFingerprint $after.fingerprint -Phase 'C711 bounded dictionary numerator isolated managed compiler'
 $r.inputsStable=$true;$r.finalInputFingerprint=$after.fingerprint
 $r.globalManagedDllSha256After=(Get-FileHash -LiteralPath $globalDll -Algorithm SHA256).Hash
 if($r.globalManagedDllSha256After -cne $globalBefore){throw 'GLOBAL_MANAGED_INPUT_CHANGED'}
 $r.compilerSha256=(Get-FileHash -LiteralPath (Join-Path $o 'compiler/Sollang.Compiler.dll') -Algorithm SHA256).Hash
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{$r.processesStopped=(Get-Content -LiteralPath (Join-Path $o 'build.execution.json') -Raw|ConvertFrom-Json).processesStopped;Save}
[pscustomobject]$r|Select-Object status,compilerSha256,inputsStable,processesStopped|ConvertTo-Json -Compress
