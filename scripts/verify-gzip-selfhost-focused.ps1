[CmdletBinding()]
param(
    [string]$Compiler = '',
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256 = '',
    [string]$OutputDirectory = '',
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd([IO.Path]::DirectorySeparatorChar)

if ($ValidateOnly) {
    if (-not [string]::IsNullOrWhiteSpace($Compiler) -or
        -not [string]::IsNullOrWhiteSpace($ExpectedCompilerSha256) -or
        -not [string]::IsNullOrWhiteSpace($OutputDirectory)) {
        throw 'GZIP selfhost -ValidateOnly does not accept execution inputs'
    }
    & (Join-Path $PSScriptRoot 'verify-gzip-selfhost-focused-contract.ps1') -RepositoryRoot $root
    exit 0
}
if ([string]::IsNullOrWhiteSpace($Compiler) -or
    [string]::IsNullOrWhiteSpace($ExpectedCompilerSha256) -or
    [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    throw 'GZIP selfhost execution requires -Compiler, -ExpectedCompilerSha256, and -OutputDirectory together'
}

. (Join-Path $PSScriptRoot 'verification-process.ps1')

function Resolve-RepositoryFile([string]$Relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $root $Relative))
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "GZIP selfhost input escapes repository: $Relative"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
        throw "GZIP selfhost input is missing or empty: $Relative"
    }
    $path
}
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Normalize-Lf([string]$Text) { $Text.Replace("`r`n", "`n") }
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 3600000
}
function Write-Utf8([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false)) }
function Write-ProcessLogs([string]$Directory, [string]$Name, [object]$Process) {
    Write-Utf8 (Join-Path $Directory "$Name.stdout.txt") $Process.Stdout
    Write-Utf8 (Join-Path $Directory "$Name.stderr.txt") $Process.Stderr
}

$scratchRoot = Join-Path $root 'artifacts\scratch'
$outputPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'GZIP selfhost OutputDirectory must be below artifacts/scratch'
}
if ((Test-Path -LiteralPath $outputPath) -and @(Get-ChildItem -LiteralPath $outputPath -Force).Count -ne 0) {
    throw 'GZIP selfhost OutputDirectory must not already contain files'
}
[IO.Directory]::CreateDirectory($outputPath) | Out-Null

$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$compilerPath = $null
$compilerSha256Start = $null
$compilerSha256End = $null
$resultSchemaPath = Join-Path $root 'scripts/contracts/gzip-selfhost-focused-result.schema.json'
$llvmAsPath = $null
$clangPath = $null
$closurePath = $null
$inputPaths = [ordered]@{}
$inputHashesStart = [ordered]@{}
$inputHashesEnd = [ordered]@{}
$inputDrift = [Collections.Generic.List[string]]::new()
$records = [Collections.Generic.List[object]]::new()
$failureIds = [Collections.Generic.List[string]]::new()
$positiveCompleted = 0
$negativeCompleted = 0
$dynamicHashes = [ordered]@{ O0 = $null; O2 = $null }
$dynamicBtype = $null
$dynamicDecodedExact = $false
$dynamicDeterministic = $false
$phase = 'preflight'

try {
    $compilerPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($Compiler)) { $Compiler } else { Join-Path $root $Compiler }))
    if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf) -or (Get-Item -LiteralPath $compilerPath).Length -eq 0) {
        throw "GZIP selfhost compiler is missing or empty: $compilerPath"
    }
    $compilerSha256Start = Hash $compilerPath
    if ($compilerSha256Start -cne $ExpectedCompilerSha256) {
        throw "GZIP selfhost compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256Start"
    }

$focusedContractPath = Resolve-RepositoryFile 'scripts/contracts/gzip-selfhost-focused.json'
$focusedSchemaPath = Resolve-RepositoryFile 'scripts/contracts/gzip-selfhost-focused.schema.json'
$resultSchemaPath = Resolve-RepositoryFile 'scripts/contracts/gzip-selfhost-focused-result.schema.json'
$authorityPath = Resolve-RepositoryFile 'scripts/contracts/gzip-stream-api.json'
$authoritySchemaPath = Resolve-RepositoryFile 'scripts/contracts/gzip-stream-api.schema.json'
$authorityVerifierPath = Resolve-RepositoryFile 'scripts/verify-gzip-stream-api-contract.ps1'
$contractVerifierPath = Resolve-RepositoryFile 'scripts/verify-gzip-selfhost-focused-contract.ps1'
$closurePath = Resolve-RepositoryFile 'scripts/verify-llvm-direct-call-closure.ps1'
$processHelperPath = Resolve-RepositoryFile 'scripts/verification-process.ps1'
$llvmAsPath = Resolve-RepositoryFile '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clangPath = Resolve-RepositoryFile '.tools/llvm-22.1.8/bin/clang.exe'

$focusedText = [IO.File]::ReadAllText($focusedContractPath)
if (-not ($focusedText | Test-Json -SchemaFile $focusedSchemaPath -ErrorAction Stop)) { throw 'GZIP selfhost focused contract schema failed' }
$focused = $focusedText | ConvertFrom-Json
$authorityText = [IO.File]::ReadAllText($authorityPath)
if (-not ($authorityText | Test-Json -SchemaFile $authoritySchemaPath -ErrorAction Stop)) { throw 'GZIP authority contract schema failed' }
$authority = $authorityText | ConvertFrom-Json
$moduleSourcePaths = @($authority.sources | ForEach-Object { Resolve-RepositoryFile $_ })
if ($moduleSourcePaths.Count -ne @($authority.sources).Count -or $moduleSourcePaths.Count -eq 0) {
    throw 'GZIP selfhost module source closure is empty or incomplete'
}

$positiveIds = @($authority.positiveCases.id)
$negativeIds = @($authority.negativeCases.id)
if (($positiveIds -join "`n") -cne (@($focused.positiveCaseIds) -join "`n") -or
    ($negativeIds -join "`n") -cne (@($focused.negativeCaseIds) -join "`n")) {
    throw 'GZIP selfhost case selection drifted from the stream API authority'
}

$inputPaths = [ordered]@{
    compiler = $compilerPath
    focusedContract = $focusedContractPath
    focusedSchema = $focusedSchemaPath
    resultSchema = $resultSchemaPath
    authorityContract = $authorityPath
    authoritySchema = $authoritySchemaPath
    authorityVerifier = $authorityVerifierPath
    contractVerifier = $contractVerifierPath
    verifier = $PSCommandPath
    processHelper = $processHelperPath
    closureVerifier = $closurePath
    llvmAs = $llvmAsPath
    clang = $clangPath
}
foreach ($relative in @($authority.sources)) { $inputPaths["source:$relative"] = Resolve-RepositoryFile $relative }
foreach ($property in @($focused.additionalSourcesByCase.PSObject.Properties)) {
    foreach ($relative in @($property.Value)) {
        $inputPaths["additional:$($property.Name):$relative"] = Resolve-RepositoryFile $relative
    }
}
foreach ($case in @($authority.positiveCases)) {
    $inputPaths["positive:$($case.id):source"] = Resolve-RepositoryFile $case.source
    if ($case.PSObject.Properties.Name -contains 'expected') { $inputPaths["positive:$($case.id):expected"] = Resolve-RepositoryFile $case.expected }
}
foreach ($case in @($authority.negativeCases)) { $inputPaths["negative:$($case.id):source"] = Resolve-RepositoryFile $case.source }

foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashesStart[$entry.Key] = Hash $entry.Value }
$phase = 'execution'

foreach ($case in @($authority.positiveCases)) {
    $caseRuns = [Collections.Generic.List[object]]::new()
    foreach ($optimization in @($focused.optimizations)) {
        $id = "$($case.id)-$($optimization.ToLowerInvariant())"
        $casePath = Join-Path $outputPath $id
        [IO.Directory]::CreateDirectory($casePath) | Out-Null
        $item = [ordered]@{ id = $id; kind = 'positive'; optimization = $optimization; passed = $false; compileExit = -1; diagnosticFree = $false; llvmProduced = $false; llvmAsExit = $null; closureExit = $null; linkExit = $null; nativeExit = $null; exact = $false; stdoutSha256 = $null; failure = $null }
        $caseRuns.Add([pscustomobject]@{
            optimization = $optimization
            id = $id
            path = $casePath
            llPath = Join-Path $casePath 'probe.ll'
            bcPath = Join-Path $casePath 'probe.bc'
            exePath = Join-Path $casePath 'probe.exe'
            item = $item
        })
    }

    $sharedFailure = $null
    try {
        $additionalProperty = $focused.additionalSourcesByCase.PSObject.Properties[$case.id]
        $additionalSourcePaths = if ($null -eq $additionalProperty) { @() } else { @($additionalProperty.Value | ForEach-Object { Resolve-RepositoryFile $_ }) }
        $compileArguments = @('windows', '--jobs', '1') + $moduleSourcePaths + $additionalSourcePaths + @((Resolve-RepositoryFile $case.source))
        $compile = Run $compilerPath $compileArguments "$($case.id) selfhost emit"
        $diagnosticFree = $compile.Stderr.Length -eq 0 -and $compile.Stdout -notmatch '(?im)^(?:warning S\d+|note N\d+|sollang: (?:semantic )?error)'
        $llvmProduced = $compile.Stdout -match '(?m)^target datalayout = ' -and $compile.Stdout -match '(?m)^define(?: [^{\r\n]+)? i32 @main\('
        foreach ($caseRun in $caseRuns) {
            $caseRun.item.compileExit = $compile.ExitCode
            $caseRun.item.diagnosticFree = $diagnosticFree
            $caseRun.item.llvmProduced = $llvmProduced
            Write-ProcessLogs $caseRun.path 'compile' $compile
        }
        if ($compile.ExitCode -ne 0 -or -not $diagnosticFree -or -not $llvmProduced) { throw 'selfhost compiler did not emit diagnostic-free complete LLVM' }

        $llvmText = $compile.Stdout + "`n"
        foreach ($caseRun in $caseRuns) { Write-Utf8 $caseRun.llPath $llvmText }
        $primaryRun = $caseRuns[0]
        $assemble = Run $llvmAsPath @($primaryRun.llPath, '-o', $primaryRun.bcPath) "$($case.id) llvm-as"
        foreach ($caseRun in $caseRuns) {
            $caseRun.item.llvmAsExit = $assemble.ExitCode
            Write-ProcessLogs $caseRun.path 'llvm-as' $assemble
        }
        if (Test-Path -LiteralPath $primaryRun.bcPath -PathType Leaf) {
            foreach ($caseRun in @($caseRuns | Select-Object -Skip 1)) { Copy-Item -LiteralPath $primaryRun.bcPath -Destination $caseRun.bcPath -Force }
        }
        if ($assemble.ExitCode -ne 0 -or ($assemble.Stdout + $assemble.Stderr).Length -ne 0) { throw 'llvm-as failed or emitted diagnostics' }

        $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $primaryRun.llPath) "$($case.id) V004"
        foreach ($caseRun in $caseRuns) {
            $caseRun.item.closureExit = $closure.ExitCode
            Write-ProcessLogs $caseRun.path 'v004' $closure
        }
        if ($closure.ExitCode -ne 0) { throw 'V004 direct-call closure failed' }
    } catch {
        $sharedFailure = $_.Exception.Message
    }

    if ($null -ne $sharedFailure) {
        foreach ($caseRun in $caseRuns) {
            $caseRun.item.failure = $sharedFailure
            $failureIds.Add($caseRun.id)
            $records.Add([pscustomobject]$caseRun.item)
        }
        continue
    }

    foreach ($caseRun in $caseRuns) {
        $optimization = $caseRun.optimization
        $id = $caseRun.id
        $casePath = $caseRun.path
        $item = $caseRun.item
        try {
            $link = Run $clangPath @('-Wno-override-module', "-$optimization", $caseRun.llPath, '-o', $caseRun.exePath) "$id native link"
            $item.linkExit = $link.ExitCode
            Write-ProcessLogs $casePath 'link' $link
            if ($link.ExitCode -ne 0 -or ($link.Stdout + $link.Stderr).Length -ne 0) { throw 'native link failed or emitted diagnostics' }
            $run = Run $caseRun.exePath @() "$id native execute"
            $item.nativeExit = $run.ExitCode
            Write-Utf8 (Join-Path $casePath 'run.stdout.txt') $run.Stdout
            Write-Utf8 (Join-Path $casePath 'run.stderr.txt') $run.Stderr
            $actual = Normalize-Lf $run.Stdout
            if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0) { throw 'native execution failed or emitted diagnostics' }
            if ($case.PSObject.Properties.Name -contains 'expected') {
                $expected = Normalize-Lf ([IO.File]::ReadAllText((Resolve-RepositoryFile $case.expected)))
                $item.exact = $actual -ceq $expected
            } else {
                $dynamicText = if ($actual.EndsWith("`n", [StringComparison]::Ordinal)) { $actual.Substring(0, $actual.Length - 1) } else { $actual }
                $lines = @($dynamicText.Split("`n"))
                if ($lines.Count -lt 2 -or $lines[0] -cne $case.expectedFirstLine) { throw 'dynamic-writer first line mismatch' }
                try { $bytes = [byte[]]@($lines[1..($lines.Count - 1)] | ForEach-Object { [byte]::Parse($_, [Globalization.CultureInfo]::InvariantCulture) }) } catch { throw 'dynamic-writer byte stream is not decimal UInt8 data' }
                if ($bytes.Count -lt 11) { throw 'dynamic-writer byte stream is too short' }
                $dynamicBtype = (($bytes[10] -shr 1) -band 3)
                $inputStream = $null; $gzipStream = $null; $decodedStream = $null
                try {
                    $inputStream = [IO.MemoryStream]::new($bytes)
                    $gzipStream = [IO.Compression.GZipStream]::new($inputStream, [IO.Compression.CompressionMode]::Decompress)
                    $decodedStream = [IO.MemoryStream]::new()
                    $gzipStream.CopyTo($decodedStream)
                    $decoded = [Text.Encoding]::ASCII.GetString($decodedStream.ToArray())
                } finally {
                    if ($null -ne $gzipStream) { $gzipStream.Dispose() }
                    if ($null -ne $inputStream) { $inputStream.Dispose() }
                    if ($null -ne $decodedStream) { $decodedStream.Dispose() }
                }
                $dynamicDecodedExact = $decoded -ceq $case.referenceText
                $item.exact = $dynamicBtype -eq 2 -and $dynamicDecodedExact
            }
            $item.stdoutSha256 = (Get-FileHash -LiteralPath (Join-Path $casePath 'run.stdout.txt') -Algorithm SHA256).Hash
            if ($case.id -ceq 'dynamic-writer') { $dynamicHashes[$optimization] = $item.stdoutSha256 }
            if (-not $item.exact) { throw 'native stdout or independent dynamic decode mismatch' }
            $item.passed = $true
            $positiveCompleted++
            Write-Host "[GZIP selfhost focused $($positiveCompleted + $negativeCompleted)/23] PASS $id"
        } catch { $item.failure = $_.Exception.Message; $failureIds.Add($id) }
        $records.Add([pscustomobject]$item)
    }
}

foreach ($case in @($authority.negativeCases)) {
    $item = [ordered]@{ id = $case.id; kind = 'negative'; optimization = $null; passed = $false; compileExit = -1; diagnosticFree = $false; llvmProduced = $false; llvmAsExit = $null; closureExit = $null; linkExit = $null; nativeExit = $null; exact = $false; stdoutSha256 = $null; failure = $null }
    try {
        $compileArguments = @('windows', '--jobs', '1') + $moduleSourcePaths + @((Resolve-RepositoryFile $case.source))
        $compile = Run $compilerPath $compileArguments "$($case.id) selfhost negative"
        $item.compileExit = $compile.ExitCode
        $negativePath = Join-Path $outputPath $case.id
        [IO.Directory]::CreateDirectory($negativePath) | Out-Null
        Write-ProcessLogs $negativePath 'compile' $compile
        $stdoutRaw = Normalize-Lf $compile.Stdout
        $stdout = if ($stdoutRaw.EndsWith("`n", [StringComparison]::Ordinal)) { $stdoutRaw.Substring(0, $stdoutRaw.Length - 1) } else { $stdoutRaw }
        $stdoutLines = @($stdout.Split("`n"))
        $targetDiagnostic = $focused.selfhostDiagnosticsByCase.PSObject.Properties[$case.id].Value
        $item.llvmProduced = $stdout -match '(?m)^target (?:datalayout|triple) = '
        $item.exact = $compile.ExitCode -eq 1 -and -not $item.llvmProduced -and
            $compile.Stderr.Length -eq 0 -and $stdoutLines.Count -eq 2 -and
            $stdoutLines[0] -ceq '; sollang workers = 1' -and
            $stdoutLines[1] -ceq $targetDiagnostic -and
            $stdout -notmatch '(?im)^(?:warning S\d+|note N\d+|; sollang compiler error)'
        if (-not $item.exact) { throw 'negative did not fail before LLVM with its exact selfhost diagnostic contract' }
        $item.passed = $true
        $negativeCompleted++
        Write-Host "[GZIP selfhost focused $($positiveCompleted + $negativeCompleted)/23] PASS $($case.id)"
    } catch { $item.failure = $_.Exception.Message; $failureIds.Add($case.id) }
    $records.Add([pscustomobject]$item)
}

foreach ($entry in $inputPaths.GetEnumerator()) {
    $inputHashesEnd[$entry.Key] = Hash $entry.Value
    if ($inputHashesStart[$entry.Key] -cne $inputHashesEnd[$entry.Key]) { $inputDrift.Add($entry.Key) }
}
$compilerSha256End = Hash $compilerPath
if ($compilerSha256End -cne $ExpectedCompilerSha256 -and -not $inputDrift.Contains('compiler')) { $inputDrift.Add('compiler') }
if ($inputDrift.Count -ne 0) { $failureIds.Add('GZIP_SELFHOST_INPUT_DRIFT') }
$dynamicDeterministic = $null -ne $dynamicHashes.O0 -and $dynamicHashes.O0 -ceq $dynamicHashes.O2
if (-not $dynamicDeterministic) { $failureIds.Add('dynamic-writer-determinism') }
} catch {
    $terminalFailure = $_.Exception.Message
    $failureId = if ($records.Count -eq 0) { 'GZIP_SELFHOST_PREFLIGHT_FAILED' } else { 'GZIP_SELFHOST_EXECUTION_FAILED' }
    if (-not $failureIds.Contains($failureId)) { $failureIds.Add($failureId) }
    if ($records.Count -eq 0 -and -not $inputDrift.Contains('preflight-unavailable')) { $inputDrift.Add('preflight-unavailable') }
    Write-Utf8 (Join-Path $outputPath 'terminal-error.txt') ($terminalFailure + "`n")
} finally {
    if ($null -ne $compilerPath -and (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
        try { $compilerSha256End = Hash $compilerPath } catch { $compilerSha256End = $null }
    }
    foreach ($entry in $inputPaths.GetEnumerator()) {
        try {
            $inputHashesEnd[$entry.Key] = Hash $entry.Value
            if ($inputHashesStart.Contains($entry.Key) -and $inputHashesStart[$entry.Key] -cne $inputHashesEnd[$entry.Key] -and -not $inputDrift.Contains($entry.Key)) { $inputDrift.Add($entry.Key) }
        } catch {
            if (-not $inputDrift.Contains($entry.Key)) { $inputDrift.Add($entry.Key) }
        }
    }
    if ($null -ne $compilerSha256End -and $compilerSha256End -cne $ExpectedCompilerSha256 -and -not $inputDrift.Contains('compiler')) { $inputDrift.Add('compiler') }
    if ($inputDrift.Count -ne 0 -and -not $failureIds.Contains('GZIP_SELFHOST_INPUT_DRIFT')) { $failureIds.Add('GZIP_SELFHOST_INPUT_DRIFT') }
    $uniqueFailureIds = @($failureIds | Select-Object -Unique)
    $completed = $positiveCompleted + $negativeCompleted
    $toolHashes = [ordered]@{
        compiler = $compilerSha256Start
        llvmAs = $(if ($null -ne $llvmAsPath -and (Test-Path -LiteralPath $llvmAsPath -PathType Leaf)) { Hash $llvmAsPath } else { $null })
        clang = $(if ($null -ne $clangPath -and (Test-Path -LiteralPath $clangPath -PathType Leaf)) { Hash $clangPath } else { $null })
        closureVerifier = $(if ($null -ne $closurePath -and (Test-Path -LiteralPath $closurePath -PathType Leaf)) { Hash $closurePath } else { $null })
    }
    $result = [ordered]@{
        schemaVersion = 1; mode = 'selfhost-native-gzip-focused'; status = $(if ($completed -eq 23 -and $uniqueFailureIds.Count -eq 0) { 'passed' } else { 'failed' }); platform = 'windows-x64'
        executionMode = 'detached-supervisor-worker'; processAuditAuthority = 'scripts/invoke-detached-selfhost-verification.ps1 completion record'; orphanProcessIds = $null
        phase = $phase; attempted = $records.Count; completed = $completed; total = 23
        positive = [ordered]@{ completed = $positiveCompleted; total = 20 }; negative = [ordered]@{ completed = $negativeCompleted; total = 3 }
        expectedCompilerSha256 = $(if ($ExpectedCompilerSha256 -match '^[A-F0-9]{64}$') { $ExpectedCompilerSha256 } else { $null }); compilerSha256Start = $compilerSha256Start; compilerSha256End = $compilerSha256End
        inputStable = $inputDrift.Count -eq 0 -and $inputHashesStart.Count -gt 0; inputDrift = @($inputDrift); inputHashesStart = $inputHashesStart; inputHashesEnd = $inputHashesEnd
        toolHashes = $toolHashes
        dynamic = [ordered]@{ caseId = 'dynamic-writer'; btype = $dynamicBtype; independentReader = 'System.IO.Compression.GZipStream'; decodedExact = $dynamicDecodedExact; deterministicAcrossOptimizations = $dynamicDeterministic; stdoutSha256O0 = $dynamicHashes.O0; stdoutSha256O2 = $dynamicHashes.O2 }
        cases = @($records); failureIds = $uniqueFailureIds
    }
    $resultPath = Join-Path $outputPath 'result.json'
    $json = ($result | ConvertTo-Json -Depth 10) + "`n"
    Write-Utf8 $resultPath $json
}

if (-not (Test-Path -LiteralPath $resultSchemaPath -PathType Leaf) -or -not ($json | Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw "GZIP selfhost result schema failed: $resultPath"
}
if ($result.status -cne 'passed') { throw "GZIP selfhost focused failed $completed/23: $($uniqueFailureIds -join ', '); result=$resultPath" }
Write-Host "[GZIP selfhost focused] PASS $completed/23 compiler=$compilerSha256Start result=$resultPath; process audit remains authoritative in the detached supervisor completion record"
