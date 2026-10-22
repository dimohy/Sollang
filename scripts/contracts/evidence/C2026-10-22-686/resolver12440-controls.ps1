$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. scripts/verification-process.ps1
$b=Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
$o=Join-Path $b 'resolver12440-controls'
[void][IO.Directory]::CreateDirectory($o)
$tool='scripts/verify-focused-selfhost-semantic-preflight.py'
$cases=@(
 @{id='reparse';args=@('--reusable-directory',(Join-Path $env:LOCALAPPDATA 'Sollang/c92-fixed-array-region-abi-direct-20261001-20'));error='ARTIFACT_REPARSE_POINT'},
 @{id='capacity';args=@('--reusable-directory',(Join-Path $b 'v12357/compiler-build01'),'--reusable-directory',(Join-Path $b 'v12405/compiler-build01'),'--reusable-directory',(Join-Path $b 'v12432/compiler-build01'),'--reusable-directory',(Join-Path $b 'input12437-body'));error='ARTIFACT_REUSABLE_COMPILER_LIMIT_EXCEEDED'}
)
$rows=@()
foreach($case in $cases){
 $out=Join-Path $o $case.id
 $a=Invoke-VerificationProcessCapture -FilePath python -ArgumentList (@($tool,'--output',$out)+$case.args) -WorkingDirectory (Get-Location).Path -Description ('explicit compiler resolver '+$case.id) -TimeoutMilliseconds 30000 -ExecutionRecordPath (Join-Path $o ($case.id+'.execution.json'))
 if($a.ExitCode -ne 1 -or -not $a.Stderr.Contains($case.error) -or (Test-Path -LiteralPath $out)){throw ('RESOLVER_CONTROL_FAILED '+$case.id)}
 $rows+=@{id=$case.id;exit=$a.ExitCode;failureId=$case.error;outputCreated=$false;passed=$true}
}
[ordered]@{schemaVersion=1;status='passed';completed=2;total=2;cases=$rows;normalEvidence='input12438-preflight/result.json';scope='Explicit reusable compiler directories preserve reparse rejection and cap3; no silent environment fallback';toolSha256=(Get-FileHash $tool -Algorithm SHA256).Hash}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $o 'result.json') -Encoding utf8
