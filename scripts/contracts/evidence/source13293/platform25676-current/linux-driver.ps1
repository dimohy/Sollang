param([Parameter(Mandatory)][string]$Compiler,[Parameter(Mandatory)][string]$Output,[Parameter(Mandatory)][ValidateSet("buffer","socket")][string]$Case)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath('W:/MyWorks/Sollang')
. (Join-Path $repo 'scripts/verification-process.ps1')
. (Join-Path $repo 'scripts/verification-compiler-build.ps1')
$source=if($Case -eq 'buffer'){Join-Path $repo 'scripts/probes/file-completion-publication/buffer-controls.slg'}else{Join-Path $repo 'scripts/probes/portable-memory-io/socket-completion-task-cancel-before-start.slg'}
$expected=if($Case -eq 'buffer'){"write=2,2`nread=2,65,66,false`neof=0,true`nempty=0,false`nrange=2`ncancel-range=2`ncancel-task=true`ncancel-open=true`n"}else{"cancelled-before-start`n"}
$binary=Join-Path $Output 'probe.exe' 
$built=Invoke-VerificationCompilerBuild -Compiler $Compiler -Source $source -Output $binary -Target 'linux-x64' -WorkingDirectory $repo -Description 'shared-file-buffer-linux-build' -TimeoutMilliseconds 180000
if($built.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($built.Stderr)){throw 'IO_LINUX_BUILD_FAILED'}
$mapped=Invoke-VerificationProcessCapture -FilePath 'C:/Windows/System32/wsl.exe' -ArgumentList @('-d','Ubuntu','--','wslpath','-a',$binary.Replace('\','/')) -WorkingDirectory $repo -Description 'io-linux-map' -TimeoutMilliseconds 15000 -ExecutionRecordPath (Join-Path $Output 'path.execution.json')
if($mapped.ExitCode -ne 0){throw 'IO_LINUX_PATH_FAILED'}
$cache=Join-Path $Output '.sollang-cache'
[void](New-Item -ItemType Directory -Force -Path $cache)
$data=Join-Path $cache 'file-buffer-owned.bin'
if(Test-Path -LiteralPath $data){throw 'IO_LINUX_OUTPUT_NOT_FRESH'}
$mappedData=Invoke-VerificationProcessCapture -FilePath 'C:/Windows/System32/wsl.exe' -ArgumentList @('-d','Ubuntu','--','wslpath','-a',$data.Replace('\','/')) -WorkingDirectory $repo -Description 'io-linux-data-map' -TimeoutMilliseconds 15000 -ExecutionRecordPath (Join-Path $Output 'data-path.execution.json')
if($mappedData.ExitCode -ne 0){throw 'IO_LINUX_DATA_PATH_FAILED'}
$ran=Invoke-VerificationProcessCapture -FilePath 'C:/Windows/System32/wsl.exe' -ArgumentList @('-d','Ubuntu','--','/usr/bin/timeout','--kill-after=2s','10s',$mapped.Stdout.Trim(),$mappedData.Stdout.Trim()) -WorkingDirectory $repo -Description 'io-linux-run' -TimeoutMilliseconds 15000 -ExecutionRecordPath (Join-Path $Output 'run.execution.json')
if($ran.ExitCode -ne 0 -or $ran.Stdout.Replace("`r`n","`n") -cne $expected -or $ran.Stderr -cne ''){throw "IO_LINUX_ORACLE_FAILED:$($ran.Stdout):$($ran.Stderr)"}
if($Case -eq 'buffer' -and (-not (Test-Path -LiteralPath $data -PathType Leaf) -or (Get-Item -LiteralPath $data).Length -ne 0)){throw 'IO_LINUX_OWNED_OUTPUT_MISMATCH'}
Write-Host ('Platform async IO Linux {0}: PASS' -f $Case)
