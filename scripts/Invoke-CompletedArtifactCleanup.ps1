[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$Plan, [switch]$Execute)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
& $python (Join-Path $PSScriptRoot 'completed_artifact_plan.py') --validate-plan $Plan
if ($LASTEXITCODE -ne 0) { throw 'ARTIFACT_PLAN_VALIDATION_FAILED' }
$record = Get-Content -LiteralPath $Plan -Raw | ConvertFrom-Json
$root = [IO.Path]::GetFullPath($record.root).TrimEnd([char[]]'\/')
function Assert-CurrentCleanupBoundary([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'ARTIFACT_TARGET_OUTSIDE_ROOT' }
    $cursor = $full
    while ($cursor) {
        if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'ARTIFACT_REPARSE_POINT' }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $full
}
function Write-DirectoryProtectionRecord([string]$Path, [string]$Output) {
    @{schemaVersion=1; status='protected'; failureId='ARTIFACT_DIRECTORY_NOT_EMPTY_OR_CHANGED';
        path=$Path; output=$Output; removedDirectories=$removedDirectories; reclaimedBytes=$reclaimedBytes;
        finishedAt=(Get-Date -Format o)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ($Plan+'.execution.json') -Encoding utf8
}
function Get-IndependentArtifactConsumer([string]$Output) {
    $processes = @(Get-CimInstance Win32_Process)
    $byId = @{}
    foreach ($process in $processes) { $byId[[long]$process.ProcessId] = $process }
    $supervisors = [Collections.Generic.HashSet[long]]::new()
    $cursor = [long]$PID
    while ($byId.ContainsKey($cursor) -and $supervisors.Add($cursor)) {
        $cursor = [long]$byId[$cursor].ParentProcessId
    }
    return @($processes | Where-Object {
        -not $supervisors.Contains([long]$_.ProcessId) -and $_.CommandLine -and
        $_.CommandLine.Replace('/','\').IndexOf($Output,[StringComparison]::OrdinalIgnoreCase) -ge 0
    })
}
function Assert-CurrentConsumerClosure($Owner) {
    if ($Owner.disposition -cne 'consumer-retired') { return }
    if (-not $Owner.consumerClosure -or
        (Get-FileHash -LiteralPath $Owner.consumerClosure.path -Algorithm SHA256).Hash -ine $Owner.consumerClosure.sha256) {
        throw 'ARTIFACT_CONSUMER_CLOSURE_CHANGED'
    }
    & $python (Join-Path $PSScriptRoot 'completed_artifact_plan.py') --repo $record.repoRoot --validate-consumer-closure $Owner.output
    if ($LASTEXITCODE -ne 0) { throw 'ARTIFACT_CONSUMER_CLOSURE_INVALID' }
}
$drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root))
$freeBytesBefore = $drive.AvailableFreeSpace
$pending = @()
$reclaimedBytes = [long]0
$removedDirectories = 0
$directoryTargets = @()
if ($record.PSObject.Properties['directoryTargets']) { $directoryTargets = @($record.directoryTargets) }
foreach ($target in $record.targets) {
    $path = [IO.Path]::GetFullPath($target.path)
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $pending += $target
}
if ($Execute) {
    $lastOutput = $null
    foreach ($target in $pending) {
        if ((Test-Path -LiteralPath (Join-Path $target.output 'consumer-retirement-protection.json')) -or
            (Test-Path -LiteralPath (Join-Path $target.output 'consumer-retirement-protection.json.pending'))) {
            throw 'ARTIFACT_UNVERIFIED_CONSUMER_PROTECTED'
        }
        if ($target.output -cne $lastOutput) {
            $owner = @($record.completionRecords | Where-Object { $_.output -ceq $target.output })
            if ($owner.Count -ne 1 -or (Get-FileHash -LiteralPath $owner[0].path -Algorithm SHA256).Hash -ine $owner[0].sha256) { throw 'ARTIFACT_COMPLETION_RECORD_CHANGED' }
            if (@(Get-IndependentArtifactConsumer $target.output).Count) { throw 'ARTIFACT_OUTPUT_ACTIVE' }
            Assert-CurrentConsumerClosure $owner[0]
            $lastOutput = $target.output
        }
        $path = Assert-CurrentCleanupBoundary $target.path
        # Recheck immediately before deletion; the complete plan was already validated atomically.
        $file = Get-Item -LiteralPath $path -Force
        if ($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $file.Length -ne $target.bytes -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $target.sha256) {
            throw 'ARTIFACT_TARGET_CHANGED'
        }
        if ($PSCmdlet.ShouldProcess($path, 'Remove owned generated output')) {
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            $reclaimedBytes += $target.bytes
        }
    }
    $lastOutput = $null
    foreach ($target in $directoryTargets) {
        if ((Test-Path -LiteralPath (Join-Path $target.output 'consumer-retirement-protection.json')) -or
            (Test-Path -LiteralPath (Join-Path $target.output 'consumer-retirement-protection.json.pending'))) {
            throw 'ARTIFACT_UNVERIFIED_CONSUMER_PROTECTED'
        }
        $path = Assert-CurrentCleanupBoundary $target.path
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if ($target.output -cne $lastOutput) {
            $owner = @($record.completionRecords | Where-Object { $_.output -ceq $target.output })
            if ($owner.Count -ne 1 -or (Get-FileHash -LiteralPath $owner[0].path -Algorithm SHA256).Hash -ine $owner[0].sha256) { throw 'ARTIFACT_COMPLETION_RECORD_CHANGED' }
            if (@(Get-IndependentArtifactConsumer $target.output).Count) { throw 'ARTIFACT_OUTPUT_ACTIVE' }
            Assert-CurrentConsumerClosure $owner[0]
            $lastOutput = $target.output
        }
        $directory = Get-Item -LiteralPath $path -Force
        if (-not $directory.PSIsContainer -or ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'ARTIFACT_DIRECTORY_CHANGED' }
        if (@(Get-ChildItem -LiteralPath $path -Force).Count) {
            Write-DirectoryProtectionRecord $path $target.output
            throw 'ARTIFACT_DIRECTORY_NOT_EMPTY'
        }
        if ($PSCmdlet.ShouldProcess($path, 'Remove owned empty private output directory')) {
            try { [IO.Directory]::Delete($path, $false) }
            catch {
                Write-DirectoryProtectionRecord $path $target.output
                throw
            }
            $removedDirectories++
        }
    }
    if (-not $WhatIfPreference -and @($directoryTargets | Where-Object { Test-Path -LiteralPath $_.path }).Count) { throw 'ARTIFACT_DIRECTORY_CLEANUP_INCOMPLETE' }
    if (-not $WhatIfPreference -and @($pending | Where-Object { Test-Path -LiteralPath $_.path }).Count) { throw 'ARTIFACT_CLEANUP_INCOMPLETE' }
}
$result = @{schemaVersion=1; status=if($Execute -and -not $WhatIfPreference){'completed'}else{'validated'};
    plannedDirectories=$directoryTargets.Count; removedDirectories=$removedDirectories; plannedFiles=$record.files; pendingFiles=$pending.Count; logicalBytes=$record.logicalBytes; reclaimedBytes=$reclaimedBytes; freeBytesBefore=$freeBytesBefore; freeBytesAfter=$drive.AvailableFreeSpace;
    completionDispositions=@($record.completionRecords | Select-Object output,disposition,recordStatus); finishedAt=(Get-Date -Format o)}
if ($Execute -and -not $WhatIfPreference) { $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath ($Plan+'.execution.json') -Encoding utf8 }
$result | ConvertTo-Json -Depth 5
