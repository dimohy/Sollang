param(
    [Parameter(Mandatory)]
    [string]$CompletionRecordPath
)

$ErrorActionPreference = "Stop"

function Read-SharedText {
    param([Parameter(Mandatory)][string]$Path)
    $stream = [IO.FileStream]::new(
        $Path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
    try {
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true, 4096, $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    finally {
        $stream.Dispose()
    }
}

$completionRecordPath = [IO.Path]::GetFullPath($CompletionRecordPath)
$launchRecordPath = "$completionRecordPath.launch.json"
if (-not (Test-Path -LiteralPath $launchRecordPath -PathType Leaf)) {
    throw "launch record is missing: $launchRecordPath"
}

$launch = Get-Content -LiteralPath $launchRecordPath -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $launch.logPath -PathType Leaf)) {
    throw "durable log is missing: $($launch.logPath)"
}

$logText = Read-SharedText -Path $launch.logPath
$verificationName = $launch.verification.ToString().ToLowerInvariant()
$stageName = switch ($verificationName) {
    "stage2linux" { "linux-stage2" }
    "stage3linux" { "linux-stage3" }
    "browserstage2" { "browser" }
    "c341focused" { "c341" }
    "c341finalselfhost" { "c341" }
    "c394finalcandidate" { "c394" }
    default { $verificationName }
}
$total = switch ($verificationName) {
    "stage2" { 7 }
    "stage3" { 3 }
    "stage2linux" { 6 }
    "stage3linux" { 3 }
    "browserstage2" { 4 }
    "c341focused" { 20 }
    "c341finalselfhost" { 23 }
    "c394finalcandidate" { 4 }
    "binarychecksum" { 27 }
    "gzipselfhost" { 23 }
    "additionalmoveownership" { 6 }
    "generictypecontexts" { 98 }
    "selfhostdeferredtextstorage" { 48 }
    "selfhostc424nestedwholeowner" { 1 }
    "linuxownershipstorage" { 2 }
    default { 1 }
}
$binaryChecksumCompleted = 0
$gzipSelfhostCompleted = 0
$genericTypeContextsCompleted = 0
$focusedRouteCompleted = 0
if ($verificationName -eq 'c341finalselfhost') {
    $ordinals = [regex]::Matches($logText, '(?im)^\[c341 (?<ordinal>\d+)/20\]') | ForEach-Object { [int]$_.Groups['ordinal'].Value }
    $focusedRouteCompleted = if (@($ordinals).Count) { [int](($ordinals | Measure-Object -Maximum).Maximum) } else { 0 }
    if ($logText -match '(?im)^\[C341 final selfhost\] PASS selfhost 20/20 production 3/3 ') { $focusedRouteCompleted = 23 }
    $current = $focusedRouteCompleted
} elseif ($verificationName -eq 'c394finalcandidate') {
    if ($logText -match '(?im)^Contextual integer literals: metadata helpers PASS 17/17 .* lexical bounds PASS 62/62') { $focusedRouteCompleted += 2 }
    $focusedRouteCompleted += [regex]::Matches($logText, '(?im)^\[native exact batch \d+/2\] PASS ').Count
    if ($logText -match '(?im)^\[C394 final candidate\] PASS contextual 17/17; lexical 62/62; expression 2/2; diagnostic 1/1;') { $focusedRouteCompleted = 4 }
    $focusedRouteCompleted = [math]::Min(4, $focusedRouteCompleted)
    $current = $focusedRouteCompleted
} elseif ($verificationName -eq "selfhostdeferredtextstorage") {
    $match = [regex]::Match($logText, '(?im)^Selfhost deferred storage production guard PASS (?<completed>\d+)/31:')
    if ($match.Success) { $focusedRouteCompleted = [math]::Min(31, [int]$match.Groups['completed'].Value) }
    $current = $focusedRouteCompleted
} elseif ($verificationName -eq "selfhostc424nestedwholeowner") {
    $match = [regex]::Match($logText, '(?im)^\[C424 selfhost nested whole owner\] PASS (?<completed>\d+)/1 ')
    if ($match.Success) { $focusedRouteCompleted = [math]::Min(1, [int]$match.Groups['completed'].Value) }
    $current = $focusedRouteCompleted
} elseif ($verificationName -eq "linuxownershipstorage") {
    $match = [regex]::Match($logText, '(?im)^\[Linux ownership/storage focused\] passed (?<completed>\d+)/2;')
    if ($match.Success) { $focusedRouteCompleted = [math]::Min(2, [int]$match.Groups['completed'].Value) }
    $current = $focusedRouteCompleted
} elseif ($verificationName -eq "generictypecontexts") {
    if ($logText -match '(?im)^Generic type contexts: .* PASS 21/21\.') { $genericTypeContextsCompleted += 21 }
    foreach ($summary in @(
        @{ Pattern = '(?im)^Type delimiters: .* PASS (?<completed>\d+)/41;'; Maximum = 41 },
        @{ Pattern = '(?im)^Declaration/layout consumers: .* (?<completed>\d+)/2;'; Maximum = 2 },
        @{ Pattern = '(?im)^Declaration recursion/diagnostics: .* PASS (?<completed>\d+)/4;'; Maximum = 4 },
        @{ Pattern = '(?im)^Managed focused source execution PASS (?<completed>\d+)/9;'; Maximum = 9 },
        @{ Pattern = '(?im)^Extracted shared array classifier .* PASS (?<completed>\d+)/11;'; Maximum = 11 },
        @{ Pattern = '(?im)^C396 candidate Windows: .* PASS (?<completed>\d+)/10;'; Maximum = 10 }
    )) {
        $match = [regex]::Match($logText, $summary.Pattern)
        if ($match.Success) {
            $genericTypeContextsCompleted += [math]::Min($summary.Maximum, [int]$match.Groups['completed'].Value)
        }
    }
    $genericTypeContextsCompleted = [math]::Min(98, $genericTypeContextsCompleted)
    $current = $genericTypeContextsCompleted
} elseif ($verificationName -eq "gzipselfhost") {
    $progressOrdinals = [regex]::Matches($logText, '(?im)^\[GZIP selfhost focused (?<ordinal>\d+)/23\] PASS') |
        ForEach-Object { [int]$_.Groups["ordinal"].Value }
    $gzipSelfhostCompleted = if (@($progressOrdinals).Count -gt 0) {
        [int](($progressOrdinals | Measure-Object -Maximum).Maximum)
    } else { 0 }
    if ($logText -match '(?im)^\[GZIP selfhost focused\] PASS 23/23 ') { $gzipSelfhostCompleted = 23 }
    $current = $gzipSelfhostCompleted
} elseif ($verificationName -eq "additionalmoveownership") {
    $match = [regex]::Match($logText, '(?im)^\[C92 additional move ownership\] PASS (?<completed>\d+)/6 ')
    if ($match.Success) { $focusedRouteCompleted = [math]::Min(6, [int]$match.Groups['completed'].Value) }
    $current = $focusedRouteCompleted
} elseif ($verificationName -eq "binarychecksum") {
    $positiveOrdinals = [regex]::Matches($logText, '(?im)^\[binary/checksum positive (?<ordinal>\d+)/24\] PASS') |
        ForEach-Object { [int]$_.Groups["ordinal"].Value }
    $negativeOrdinals = [regex]::Matches($logText, '(?im)^\[binary/checksum negative (?<ordinal>\d+)/3\] PASS') |
        ForEach-Object { [int]$_.Groups["ordinal"].Value }
    $positiveCompleted = if (@($positiveOrdinals).Count -gt 0) {
        [int](($positiveOrdinals | Measure-Object -Maximum).Maximum)
    } else { 0 }
    $negativeCompleted = if (@($negativeOrdinals).Count -gt 0) {
        [int](($negativeOrdinals | Measure-Object -Maximum).Maximum)
    } else { 0 }
    $binaryChecksumCompleted = [math]::Min(27, $positiveCompleted + $negativeCompleted)
    $current = $binaryChecksumCompleted
} else {
    $ordinals = [regex]::Matches($logText, "(?im)^\[$stageName (?<ordinal>\d+)/$total\]") |
        ForEach-Object { [int]$_.Groups["ordinal"].Value }
    $current = if (@($ordinals).Count -gt 0) { [int](($ordinals | Measure-Object -Maximum).Maximum) } else { 0 }
}
$result = if (Test-Path -LiteralPath $completionRecordPath -PathType Leaf) {
    Get-Content -LiteralPath $completionRecordPath -Raw | ConvertFrom-Json
} else {
    $null
}
$supervisorRunning = $null -ne (Get-Process -Id ([int]$launch.supervisorPid) -ErrorAction SilentlyContinue)
$status = if ($null -ne $result) {
    $result.status
} elseif ($supervisorRunning) {
    "running"
} else {
    "interrupted-without-result"
}
$completed = if ($status -eq "passed") {
    $total
} elseif ($verificationName -in @("selfhostdeferredtextstorage", "selfhostc424nestedwholeowner", "linuxownershipstorage", "additionalmoveownership", "c341finalselfhost", "c394finalcandidate")) {
    $focusedRouteCompleted
} elseif ($verificationName -eq "generictypecontexts") {
    $genericTypeContextsCompleted
} elseif ($verificationName -eq "binarychecksum") {
    $binaryChecksumCompleted
} elseif ($verificationName -eq "gzipselfhost") {
    $gzipSelfhostCompleted
} elseif ($current -gt 0) {
    $current - 1
} else {
    0
}
$reportedFailureIds = [Collections.Generic.List[string]]::new()
if ($null -ne $result) {
    foreach ($failureId in @($result.failureIds)) {
        $reportedFailureIds.Add($failureId)
    }
}
$incrementalFixtureProperty = $launch.PSObject.Properties['incrementalFixture']
$incrementalTargetProperty = $launch.PSObject.Properties['incrementalTarget']
$additionalMoveCompilerProperty = $launch.PSObject.Properties['additionalMoveOwnershipCompiler']
$additionalMoveExpectedHashProperty = $launch.PSObject.Properties['additionalMoveOwnershipExpectedCompilerSha256']
$additionalMoveOutputProperty = $launch.PSObject.Properties['additionalMoveOwnershipOutputDirectory']
$focusedResultPathProperty = $launch.PSObject.Properties['c341FinalResultPath']
if ($null -eq $focusedResultPathProperty -or [string]::IsNullOrWhiteSpace([string]$focusedResultPathProperty.Value)) { $focusedResultPathProperty = $launch.PSObject.Properties['c394FinalResultPath'] }
$focusedResultPath = if ($null -ne $focusedResultPathProperty) { [string]$focusedResultPathProperty.Value } else { $null }
$focusedResultSha256 = if (-not [string]::IsNullOrWhiteSpace($focusedResultPath) -and (Test-Path -LiteralPath $focusedResultPath -PathType Leaf)) { (Get-FileHash -LiteralPath $focusedResultPath -Algorithm SHA256).Hash } elseif ($null -ne $result -and $null -ne $result.PSObject.Properties['focusedResultSha256']) { [string]$result.focusedResultSha256 } else { $null }

[ordered]@{
    runId = $launch.runId
    verification = $launch.verification
    incrementalFixture = if ($null -ne $incrementalFixtureProperty) { [string]$incrementalFixtureProperty.Value } else { $null }
    incrementalTarget = if ($null -ne $incrementalTargetProperty) { [string]$incrementalTargetProperty.Value } else { $null }
    additionalMoveOwnershipCompiler = if ($null -ne $additionalMoveCompilerProperty) { [string]$additionalMoveCompilerProperty.Value } else { $null }
    additionalMoveOwnershipExpectedCompilerSha256 = if ($null -ne $additionalMoveExpectedHashProperty) { [string]$additionalMoveExpectedHashProperty.Value } else { $null }
    additionalMoveOwnershipOutputDirectory = if ($null -ne $additionalMoveOutputProperty) { [string]$additionalMoveOutputProperty.Value } else { $null }
    focusedResultPath = $focusedResultPath
    focusedResultSha256 = $focusedResultSha256
    status = $status
    completed = $completed
    total = $total
    percent = [math]::Round(($completed * 100.0) / $total, 1)
    currentStage = $current
    supervisorPid = [int]$launch.supervisorPid
    supervisorRunning = $supervisorRunning
    exitCode = if ($null -ne $result) { $result.exitCode } else { $null }
    failureIds = $reportedFailureIds
    logLength = (Get-Item -LiteralPath $launch.logPath).Length
    logLastWriteTimeUtc = (Get-Item -LiteralPath $launch.logPath).LastWriteTimeUtc.ToString("O")
} | ConvertTo-Json -Depth 5
