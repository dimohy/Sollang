[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CompilerLinkBridgeProof,
    [Parameter(Mandatory)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath($OutputDirectory)
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts')) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($artifactRoot, [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $output)) { throw 'AES_PREFLIGHT_TEST_FRESH_ARTIFACT_OUTPUT_REQUIRED' }
[IO.Directory]::CreateDirectory($output) | Out-Null
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$runner = Join-Path $PSScriptRoot 'verify-cpu-aes-dispatch.py'
$bridgeProof = [IO.Path]::GetFullPath($CompilerLinkBridgeProof)
$normal = Invoke-VerificationProcessCapture -FilePath $python -ArgumentList @($runner, '--bridge-proof', $bridgeProof, '--validate-bridge-only') `
    -Description 'AES verified bridge preflight' -TimeoutMilliseconds 30000 -ExecutionRecordPath (Join-Path $output 'normal.execution.json')
if ($normal.ExitCode -ne 0) { throw $normal.Stderr }
$normalRecord = $normal.Stdout | ConvertFrom-Json
if ($normalRecord.status -ne 'passed' -or $normalRecord.codegenInvoked -ne $false) { throw 'AES_PREFLIGHT_TEST_NORMAL_CONTRACT_INVALID' }
$fake = Join-Path $output 'unproven-bridge.json'
@{status='passed'; completed=1; total=1; inputsStable=$true; processesStopped=$true; inputHashes=@{};
    bridgeProduct='must-not-run.dll'; bridgeSha256=('0'*64)} | ConvertTo-Json | Set-Content -LiteralPath $fake -Encoding utf8
$inputs = @($normalRecord.inputPaths) + @($PSCommandPath, $fake,
    (Join-Path $PSScriptRoot 'verification-process.ps1'),
    (Join-Path $PSScriptRoot 'verify-selfhost-stage2.ps1'),
    (Join-Path $PSScriptRoot 'verify-selfhost-stage3.ps1'),
    (Join-Path $PSScriptRoot 'invoke-detached-selfhost-verification.ps1'),
    (Join-Path $PSScriptRoot 'run-cpu-aes-dispatch-benchmark.ps1'))
$pins = @{}
foreach ($path in $inputs) { $pins[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$cases = @()
foreach ($script in @('verify-selfhost-stage2.ps1','verify-selfhost-stage3.ps1','run-cpu-aes-dispatch-benchmark.ps1')) {
    $path = Join-Path $PSScriptRoot $script
    $cases += @{id=$script+'.missing'; file=$pwsh; arguments=@('-NoProfile','-File',$path); expected='CPU_AES_LINK_BRIDGE_PROOF_REQUIRED'}
    $cases += @{id=$script+'.unproven'; file=$pwsh; arguments=@('-NoProfile','-File',$path,'-CompilerLinkBridgeProof',$fake); expected='CPU_AES_LINK_BRIDGE_SOURCE_PROOF_MISSING'}
}
$forbiddenOutput = Join-Path $output 'must-not-create'
$cases += @{id='direct-missing'; file=$python; arguments=@($runner,'--output',$forbiddenOutput); expected='CPU_AES_LINK_BRIDGE_PROOF_REQUIRED'}
$cases += @{id='native-wrapper-missing'; file=$pwsh; arguments=@('-NoProfile','-File',(Join-Path $PSScriptRoot 'verify-selfhost-cpu-aes-dispatch.ps1'),'-Compiler','must-not-execute.exe','-ArtifactDirectory',$forbiddenOutput); expected='CPU_AES_LINK_BRIDGE_PROOF_REQUIRED'}
$supervisor = Join-Path $PSScriptRoot 'invoke-detached-selfhost-verification.ps1'
foreach ($stage in @('Stage2','Stage3')) {
    $prefix = @('-NoProfile','-File',$supervisor,'-Verification',$stage,'-ValidateInputsOnly')
    $cases += @{id=$stage+'.supervisor-missing'; file=$pwsh; arguments=$prefix; expected='CPU_AES_LINK_BRIDGE_PROOF_REQUIRED'}
    $cases += @{id=$stage+'.supervisor-unproven'; file=$pwsh; arguments=$prefix+@('-CompilerLinkBridgeProof',$fake); expected='CPU_AES_LINK_BRIDGE_SOURCE_PROOF_MISSING'}
    $cases += @{id=$stage+'.supervisor-normal'; file=$pwsh; arguments=$prefix+@('-CompilerLinkBridgeProof',$bridgeProof); validateOnly=$true}
}
$cases += @{id='supervisor-unrelated-scope'; file=$pwsh; arguments=@('-NoProfile','-File',$supervisor,'-Verification','Probe','-CompilerLinkBridgeProof',$bridgeProof); expected='CompilerLinkBridgeProof is valid only for Windows Stage2 or Stage3'}
$record = [ordered]@{schemaVersion=1; status='running'; completed=1; total=16; inputHashes=$pins;
    cases=@(@{id='normal'; status='passed'; passed=$true; codegenInvoked=$false});
    inputsStable=$false; processesStopped=$false; failure=$null; claimsGoalComplete=$false}
try {
    foreach ($case in $cases) {
        $observed = Invoke-VerificationProcessCapture -FilePath $case.file -ArgumentList $case.arguments `
            -Description ('AES preflight '+$case.id) -TimeoutMilliseconds 30000 -ExecutionRecordPath (Join-Path $output ($case.id+'.execution.json'))
        if ($case.ContainsKey('validateOnly')) {
            if ($observed.ExitCode -ne 0) { throw ('AES_SUPERVISOR_PREFLIGHT_FAILED: '+$observed.Stderr) }
            $validated = $observed.Stdout | ConvertFrom-Json
            if (-not $validated.validated -or $validated.codegenInvoked -ne $false -or $validated.supervisorStarted -ne $false -or
                $validated.linkArguments[0] -cne '-CompilerLinkBridgeProof' -or $validated.linkArguments[1].Trim('"') -cne $bridgeProof) {
                throw 'AES_SUPERVISOR_PREFLIGHT_OR_FORWARDING_INVALID'
            }
        } elseif ($observed.ExitCode -eq 0 -or -not ($observed.Stdout + $observed.Stderr).Contains($case.expected)) {
            throw ('AES_PREFLIGHT_DID_NOT_REJECT: '+$case.id+' '+$observed.Stderr)
        }
        if (Test-Path -LiteralPath $forbiddenOutput) { throw 'AES_PREFLIGHT_STARTED_ARTIFACT_GENERATION' }
        $record.cases += @{id=$case.id; status='passed'; passed=$true; observedExit=$observed.ExitCode;
            validationOnly=$case.ContainsKey('validateOnly')}
        $record.completed++
    }
    foreach ($name in @('verify-selfhost-stage2.ps1','verify-selfhost-stage3.ps1')) {
        $text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $name))
        if ($text.IndexOf('--validate-bridge-only') -ge $text.IndexOf('$selfHostVerificationLock = Enter-SelfHostVerificationLock') -or
            -not $text.Contains('$aesVerificationInputs = @($bridgePreflight.inputPaths)') -or
            -not $text.Contains('$stageCompilationInputs.FingerprintPaths + $aesVerificationInputs')) {
            throw 'AES_STAGE_PREFLIGHT_OR_FINGERPRINT_DISCONNECTED'
        }
    }
    $record.status = 'passed'
} catch { $record.status='failed'; $record.failure=$_.Exception.Message; throw }
finally {
    $record.inputsStable = @($pins.Keys | Where-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash -cne $pins[$_] }).Count -eq 0
    $record.processesStopped = @(Get-ChildItem -LiteralPath $output -Filter '*.execution.json' | Where-Object {
        -not (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json).processesStopped }).Count -eq 0
    $record.finishedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    $record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
}
@{status=$record.status; completed=$record.completed; total=$record.total; inputsStable=$record.inputsStable;
    processesStopped=$record.processesStopped} | ConvertTo-Json
