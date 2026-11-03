param([Parameter(Mandatory)][string]$Compiler,[Parameter(Mandatory)][string]$Output,[Parameter(Mandatory)][string]$Contract)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath('W:/MyWorks/Sollang')
. (Join-Path $repo 'scripts/verification-process.ps1')
. (Join-Path $repo 'scripts/verification-compiler-build.ps1')
$cases=(Get-Content -LiteralPath $Contract -Raw | ConvertFrom-Json).cases
foreach($case in $cases){
    $folder=Join-Path $Output $case.id
    [void](New-Item -ItemType Directory -Path $folder)
    $binary=Join-Path $folder 'probe.exe'
    $built=Invoke-VerificationCompilerBuild -Compiler $Compiler -Source (Join-Path $repo $case.source) -Output $binary -Target 'linux-x64' -WorkingDirectory $repo -Description ('compute-linux-'+$case.id) -TimeoutMilliseconds 180000
    if($built.ExitCode -ne 0 -or $built.Stderr.Trim() -cne $case.stderr){throw "COMPUTE_LINUX_BUILD_FAILED:$($case.id):$($built.Stderr)"}
    $mapped=Invoke-VerificationProcessCapture -FilePath 'C:/Windows/System32/wsl.exe' -ArgumentList @('-d','Ubuntu','--','wslpath','-a',$binary.Replace('\','/')) -WorkingDirectory $repo -Description 'compute-linux-map' -TimeoutMilliseconds 15000 -ExecutionRecordPath (Join-Path $folder 'path.execution.json')
    if($mapped.ExitCode -ne 0){throw 'COMPUTE_LINUX_PATH_FAILED'}
    $ran=Invoke-VerificationProcessCapture -FilePath 'C:/Windows/System32/wsl.exe' -ArgumentList @('-d','Ubuntu','--','/usr/bin/timeout','--kill-after=2s','10s',$mapped.Stdout.Trim()) -WorkingDirectory $repo -Description 'compute-linux-run' -TimeoutMilliseconds 15000 -ExecutionRecordPath (Join-Path $folder 'run.execution.json')
    if($ran.ExitCode -ne 0 -or $ran.Stdout.Replace("`r`n","`n").TrimEnd() -cne $case.stdout -or $ran.Stderr -cne ''){throw "COMPUTE_LINUX_ORACLE_FAILED:$($case.id):$($ran.Stdout):$($ran.Stderr)"}
    Write-Host ('Compute Linux {0}: PASS' -f $case.id)
}
