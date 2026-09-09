[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'managed-reference-snapshot.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$audit=Join-Path (Split-Path $PSScriptRoot -Parent) ('artifacts/scratch/managed-reference-guard/contract-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $audit
$pwsh=(Get-Process -Id $PID).Path
$fake=@'
param([string]$Mode,[string]$Inputs)
switch($Mode){
 'source' { Add-Content "$Inputs/source.slg" 'changed' }
 'compiler' { Add-Content "$Inputs/Compiler.dll" 'changed' }
 'expected' { Add-Content "$Inputs/expected.txt" 'changed' }
 'runner' { Add-Content "$Inputs/fake-runner.ps1" '# changed' }
 'addition' { Set-Content "$Inputs/new-fixture.slg" 'new' }
 'deletion' { Remove-Item -LiteralPath "$Inputs/source.slg" }
 'nonzero' { Write-Output 'All 1 example tests passed.'; exit 1 }
 'truncated' { Write-Output '[1/1] PASS fake'; exit 0 }
 'timeout' {
   $child=Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 30') -WindowStyle Hidden -PassThru
   Set-Content (Join-Path (Split-Path $Inputs) 'child-pid.txt') $child.Id
   Write-Output '[1/1] START fake'
   Start-Sleep -Seconds 20
   exit 0
 }
}
Write-Output '[1/1] PASS fake'
Write-Output 'All 1 example tests passed.'
exit 0
'@
$results=@()
foreach($mode in @('stable','source','compiler','expected','runner','addition','deletion','nonzero','truncated','timeout')){
    $caseRoot=Join-Path $audit $mode
    $inputs=Join-Path $caseRoot 'inputs'
    $output=Join-Path $caseRoot 'output'
    $null=New-Item -ItemType Directory $inputs -Force
    foreach($name in @('source.slg','Compiler.dll','expected.txt')){Set-Content (Join-Path $inputs $name) 'original'}
    $fakePath=Join-Path $inputs 'fake-runner.ps1'
    Set-Content $fakePath $fake
    $command=@($pwsh,'-NoProfile','-File',$fakePath,'-Mode',$mode,'-Inputs',$inputs)
    $failure=$null
    try {
        $null=Invoke-ManagedReferenceGuard -OutputDirectory $output -GetSnapshot {
            Get-ManagedReferenceSnapshot -DirectoryRoots @($inputs) -RequiredFiles @($pwsh) -Command $command
        } -Run {
            param($logs)
            $limit=if($mode -eq 'timeout'){1500}else{10000}
            Invoke-ManagedReferenceProcess -FilePath $pwsh -ArgumentList $command[1..($command.Length-1)] -WorkingDirectory $caseRoot -OutputDirectory $logs -TimeoutMilliseconds $limit
        }
    } catch { $failure=$_.Exception.Message }
    $success=Test-Path "$output/success.json"
    $expected=if($mode -eq 'stable'){$null}elseif($mode -eq 'nonzero'){'runner exited 1'}elseif($mode -eq 'truncated'){'no terminal success summary'}elseif($mode -eq 'timeout'){'configured verification limit'}else{'inputs changed during verification'}
    $pass=if($mode -eq 'stable'){$null -eq $failure -and $success}else{(-not $success) -and $null -ne $failure -and $failure.Contains($expected)}
    if($mode -eq 'timeout'){
        $pidRecord=Get-Content "$output/process.json" -Raw | ConvertFrom-Json
        $pass=$pass -and (Get-Content "$output/stdout.log" -Raw).Contains('START fake') -and $null -eq (Get-Process -Id $pidRecord.processId -ErrorAction SilentlyContinue)
        $childId=[int](Get-Content "$caseRoot/child-pid.txt")
        $pass=$pass -and $null -eq (Get-Process -Id $childId -ErrorAction SilentlyContinue)
    }
    $results+=[pscustomobject]@{case=$mode;passed=$pass;successReceipt=$success;error=$failure}
}
$stableOutput=Join-Path $audit 'stable/output'
$called=$false
$rejected=$false
try {
    $null=Invoke-ManagedReferenceGuard -OutputDirectory $stableOutput -GetSnapshot {throw 'must not snapshot'} -Run {$called=$true}
} catch { $rejected=$_.Exception.Message.Contains('must be empty') }
$results+=[pscustomobject]@{case='stale-output-reuse';passed=($rejected -and -not $called);successReceipt=$false;error=$null}
$results | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $audit 'results.json')
$results | Format-Table case,passed,successReceipt,error
Write-Output "Evidence: $audit"
if(@($results | Where-Object {-not $_.passed}).Count){throw 'Managed reference guard contract failed'}
