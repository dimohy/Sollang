function Close-CompilerArtifactConsumers {
    param([Parameter(Mandatory)][string]$OutputDirectory,
          [Parameter(Mandatory)][string[]]$ConsumerResult,
          [Parameter(Mandatory)][string]$ReplacementBuild, [switch]$LegacyTerminalConsumers)
    $repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $arguments = @((Join-Path $PSScriptRoot 'completed_artifact_plan.py'), '--repo', $repo,
        '--close-consumers', $OutputDirectory, '--replacement-build', $ReplacementBuild)
    foreach ($path in $ConsumerResult) { $arguments += @('--consumer-result', $path) }
    if ($LegacyTerminalConsumers) { $arguments += '--legacy-terminal-consumers' }
    & $python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'ARTIFACT_CONSUMER_CLOSURE_FAILED' }
}

function Initialize-ArtifactOutput {
    param([Parameter(Mandatory)][string]$OutputDirectory, [string[]]$ReusableCompilerDirectories)
    $repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $arguments = @((Join-Path $PSScriptRoot 'completed_artifact_plan.py'), '--repo', $repo, '--validate-output', $OutputDirectory)
    foreach ($directory in $ReusableCompilerDirectories) { $arguments += @('--reusable-directory', $directory) }
    & $python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'ARTIFACT_OUTPUT_PREFLIGHT_FAILED' }
}

function Complete-VerifiedArtifactOutput {
    param([Parameter(Mandatory)][string]$OutputDirectory, [switch]$KeepCompiler, [switch]$TemporaryOnly,
          [switch]$RetentionTerminal, [string[]]$ReusableCompilerDirectories, [switch]$PlanOnly)
    $repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $output = [IO.Path]::GetFullPath($OutputDirectory)
    if (-not (Test-Path -LiteralPath (Join-Path $output 'result.json') -PathType Leaf)) { throw 'ARTIFACT_COMPLETION_RECORD_MISSING' }
    $python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $plan = Join-Path $output 'artifact-cleanup-plan.json'
    $arguments = @((Join-Path $PSScriptRoot 'completed_artifact_plan.py'), '--repo', $repo, '--output-directory', $output, '--plan', $plan)
    if ($KeepCompiler) { $arguments += '--keep-compiler' }
    if ($TemporaryOnly) { $arguments += '--temporary-only' }
    if ($RetentionTerminal) { $arguments += '--retention-terminal' }
    foreach ($directory in $ReusableCompilerDirectories) { $arguments += @('--reusable-directory', $directory) }
    & $python @arguments
    if ($LASTEXITCODE -ne 0) { throw 'ARTIFACT_COMPLETION_PLAN_FAILED' }
    $prepared = Get-Content -LiteralPath $plan -Raw | ConvertFrom-Json
    if (@($prepared.completionRecords).Count -ne 1) { throw 'ARTIFACT_COMPLETION_NOT_VERIFIED' }
    if ($PlanOnly) { return $plan }
    & (Join-Path $PSScriptRoot 'Invoke-CompletedArtifactCleanup.ps1') -Plan $plan -Execute
}
