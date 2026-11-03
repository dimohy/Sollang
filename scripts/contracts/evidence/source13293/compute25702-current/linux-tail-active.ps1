param([Parameter(Mandatory)][string]$Output)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath('W:/MyWorks/Sollang')
. (Join-Path $repo 'scripts/verification-process.ps1')
$cfg=(Get-Content -LiteralPath (Join-Path $repo 'scripts/contracts/verification-compiler-build.json') -Raw | ConvertFrom-Json).nativeLinux
$prior=Join-Path $repo 'artifacts/scratch/resume-20261006-owner-continuation22/compute25685-linux-native/active/probe.exe'
$emission=Get-Content -LiteralPath "$prior.compiler-emit-checked.execution.json" -Raw | ConvertFrom-Json
$spent=([datetimeoffset]$emission.finishedAtUtc-[datetimeoffset]$emission.startedAtUtc).TotalSeconds
$seconds=[math]::Floor(180-$spent-3)
if($seconds -le 0 -or $seconds -ge 180){throw 'COMPUTE_LINK_BUDGET_INVALID'}
function Invoke-Step([string]$Id,[string[]]$Arguments,[int]$Timeout=15000){
    $value=Invoke-VerificationProcessCapture -FilePath 'C:/Windows/System32/wsl.exe' -ArgumentList (@('-d','Ubuntu','--')+$Arguments) -WorkingDirectory $repo -Description ('compute-active-'+$Id) -TimeoutMilliseconds $Timeout -ExecutionRecordPath (Join-Path $Output ($Id+'.execution.json'))
    if($value.ExitCode -ne 0 -or $value.Stderr -cne ''){throw "COMPUTE_ACTIVE_STEP_FAILED:${Id}:$($value.Stderr)"}
    return $value.Stdout.Trim()
}
$version=Invoke-Step 'clang-version' @($cfg.clangPath,'--version')
if(-not $version.Contains("clang version $($cfg.clangVersion)")){throw 'COMPUTE_CLANG_VERSION'}
$hash=Invoke-Step 'clang-before' @('/usr/bin/sha256sum',$cfg.clangBinaryPath)
if($hash.Split(' ')[0].ToUpperInvariant() -cne $cfg.clangSha256){throw 'COMPUTE_CLANG_HASH'}
$source=Invoke-Step 'source-path' @('wslpath','-a',"$prior.ll".Replace('\','/'))
$binary=Invoke-Step 'binary-path' @('wslpath','-a',(Join-Path $Output 'active/probe.exe').Replace('\','/'))
[void](Invoke-Step 'link' @($cfg.timeoutPath,'--kill-after=2s',"$($seconds)s",$cfg.clangPath,"--target=$($cfg.targetTriple)",'-O0',$source,'-pthread','-o',$binary) ([int]($seconds*1000)))
$hash=Invoke-Step 'clang-after' @('/usr/bin/sha256sum',$cfg.clangBinaryPath)
if($hash.Split(' ')[0].ToUpperInvariant() -cne $cfg.clangSha256){throw 'COMPUTE_CLANG_CHANGED'}
$actual=Invoke-Step 'active-run' @($cfg.timeoutPath,'--kill-after=2s','10s',$binary)
if($actual -cne 'pool-active=true, results=24'){throw 'COMPUTE_ACTIVE_ORACLE'}
Write-Host 'Compute active existing checked LLVM: PASS'
