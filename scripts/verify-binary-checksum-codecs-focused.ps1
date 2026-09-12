[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = "",
    [string]$WslDistribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root "artifacts\scratch"))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $scratchRoot ("binary-checksum-codecs-" + [guid]::NewGuid().ToString("N"))
}
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
$scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $outputRoot.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Binary/checksum output must be a child of artifacts/scratch: $outputRoot"
}
if (Test-Path -LiteralPath $outputRoot) {
    if (-not (Test-Path -LiteralPath $outputRoot -PathType Container) -or
        @(Get-ChildItem -LiteralPath $outputRoot -Force).Count -ne 0) {
        throw "Binary/checksum output must be a new or empty directory: $outputRoot"
    }
}
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$resolvedOutput = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $outputRoot).Path)
if (-not $resolvedOutput.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Binary/checksum resolved output escaped artifacts/scratch: $resolvedOutput"
}

$contractPath = Join-Path $root "scripts\contracts\binary-checksum-codecs.json"
$verifierPath = Join-Path $root "scripts\verify-binary-checksum-codecs-focused.ps1"
$formatVerifier = Join-Path $root "scripts\format-authoritative-slg.ps1"
$compilerPath = Join-Path $root "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$llvmRoot = Join-Path $root ".tools\llvm-22.1.8"
$clangPath = Join-Path $llvmRoot "bin\clang.exe"
$wasmLdPath = Join-Path $llvmRoot "bin\wasm-ld.exe"
$dotnetPath = @((Get-Command dotnet -CommandType Application -ErrorAction Stop))[0].Source
$pwshPath = @((Get-Command pwsh -CommandType Application -ErrorAction Stop))[0].Source
$wslPath = @((Get-Command wsl.exe -CommandType Application -ErrorAction Stop))[0].Source
$nodePath = @((Get-Command node.exe -CommandType Application -ErrorAction Stop))[0].Source
$browserRunner = Join-Path $root "scripts\verify-uri-browser-program.mjs"

$positiveAuthority = @(
    [ordered]@{ id = "1085-binary-reader-writer-instances"; source = "examples/regression/1085-binary-reader-writer-instances.slg"; expected = "examples/regression/expected/1085-binary-reader-writer-instances.stdout.txt" },
    [ordered]@{ id = "1086-crc32-policy-hasher-instances"; source = "examples/regression/1086-crc32-policy-hasher-instances.slg"; expected = "examples/regression/expected/1086-crc32-policy-hasher-instances.stdout.txt" },
    [ordered]@{ id = "1087-crc32-fixed-input-instance-o0"; source = "examples/regression/1087-crc32-fixed-input-instance-o0.slg"; expected = "examples/regression/expected/1087-crc32-fixed-input-instance-o0.stdout.txt" },
    [ordered]@{ id = "1228-xxhash64-streaming"; source = "examples/regression/1228-xxhash64-streaming.slg"; expected = "examples/regression/expected/1228-xxhash64-streaming.stdout.txt" }
)
$negativeAuthority = @(
    [ordered]@{ id = "binary-reader-private-state"; source = "scripts/probes/binary-checksum-codecs/binary-reader-private-state.slg"; diagnostic = "sollang: semantic error at 6:5: [module '<main>'] cannot read private field 'offset' of struct 'std.encoding.binary.Reader' outside module 'std.encoding.binary'; use its public factory or public instance methods" },
    [ordered]@{ id = "crc32-hasher-private-state"; source = "scripts/probes/binary-checksum-codecs/crc32-hasher-private-state.slg"; diagnostic = "sollang: semantic error at 6:5: [module '<main>'] cannot read private field 'state' of struct 'std.hash.crc32.Hasher' outside module 'std.hash.crc32'; use its public factory or public instance methods" },
    [ordered]@{ id = "xxhash64-hasher-private-state"; source = "scripts/probes/binary-checksum-codecs/xxhash64-hasher-private-state.slg"; diagnostic = "sollang: semantic error at 6:5: [module '<main>'] cannot read private field 'buffered' of struct 'std.hash.xxhash64.Hasher' outside module 'std.hash.xxhash64'; use its public factory or public instance methods" }
)
$moduleSources = @(
    "stdlib/std/encoding/binary.slg",
    "stdlib/std/encoding/binary/error.slg",
    "stdlib/std/hash/crc32.slg",
    "stdlib/std/hash/xxhash64.slg"
)

$inputPaths = [Collections.Generic.List[string]]::new()
foreach ($relative in @($moduleSources) + @($contractPath, $verifierPath, $formatVerifier, $compilerPath, $clangPath, $wasmLdPath, $dotnetPath, $pwshPath, $wslPath, $nodePath, $browserRunner)) {
    $path = if ([IO.Path]::IsPathRooted($relative)) { $relative } else { Join-Path $root $relative }
    $inputPaths.Add([IO.Path]::GetFullPath($path))
}
foreach ($case in @($positiveAuthority) + @($negativeAuthority)) {
    $inputPaths.Add((Join-Path $root $case.source))
    if ($case.Contains("expected")) { $inputPaths.Add((Join-Path $root $case.expected)) }
}
foreach ($path in $inputPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Binary/checksum verifier input is missing: $path"
    }
}

function Get-HashKey {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return [IO.Path]::GetRelativePath($root, $full).Replace([char]92, [char]47)
    }
    $full.Replace([char]92, [char]47)
}

function Get-InputHashes {
    $hashes = [ordered]@{}
    foreach ($path in $inputPaths) {
        $key = Get-HashKey $path
        if ($hashes.Contains($key)) { throw "Binary/checksum input identity is duplicated: $key" }
        $hashes[$key] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    $hashes
}

function Invoke-CheckedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [AllowEmptyCollection()][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$Description
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $ArgumentList) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "$Description did not start" }
        $processId = $process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill($true)
            if (-not $process.WaitForExit(10000) -or -not $process.HasExited) {
                throw "$Description timed out and process tree $processId did not terminate"
            }
            throw "$Description exceeded 60000ms; terminated process tree rooted at $processId"
        }
        [pscustomobject]@{
            Stdout = $stdoutTask.GetAwaiter().GetResult()
            Stderr = $stderrTask.GetAwaiter().GetResult()
            ExitCode = $process.ExitCode
            ProcessId = $processId
            HasExited = $process.HasExited
        }
    } finally {
        $process.Dispose()
    }
}

function Normalize-ExactOutput {
    param([AllowEmptyString()][string]$Text)
    $normalized = $Text.Replace("`r`n", "`n")
    if ($normalized.EndsWith("`n", [StringComparison]::Ordinal)) {
        return $normalized.Substring(0, $normalized.Length - 1)
    }
    $normalized
}

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$WindowsPath)
    $full = [IO.Path]::GetFullPath($WindowsPath)
    "/mnt/$($full.Substring(0, 1).ToLowerInvariant())/$($full.Substring(3).Replace([char]92, [char]47))"
}

function Assert-Success {
    param([Parameter(Mandatory)]$Process, [Parameter(Mandatory)][string]$Description)
    if (-not $Process.HasExited -or $Process.ExitCode -ne 0) {
        throw "$Description failed with exit code $($Process.ExitCode)`n$($Process.Stderr)$($Process.Stdout)"
    }
    if (-not [string]::IsNullOrEmpty($Process.Stderr)) {
        throw "$Description produced stderr`n$($Process.Stderr)"
    }
}

function Assert-CompileTranscript {
    param([Parameter(Mandatory)]$Process, [Parameter(Mandatory)][string]$Artifact, [Parameter(Mandatory)][string]$Description)
    Assert-Success $Process $Description
    $lines = @($Process.Stdout -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -lt 5) { throw "$Description produced fewer than 5 compiler lines`n$($Process.Stdout)" }
    foreach ($prefix in @('[frontend-cache]', '[codegen-cache]', '[semantic-cache]', '[product-cache]')) {
        if (@($lines | Where-Object { $_.StartsWith($prefix + ' ', [StringComparison]::Ordinal) }).Count -ne 1) {
            throw "$Description did not produce exactly one $prefix line"
        }
    }
    $partitionLines = @($lines | Where-Object { $_.StartsWith('[native ', [StringComparison]::Ordinal) })
    for ($partitionIndex = 0; $partitionIndex -lt $partitionLines.Count; $partitionIndex++) {
        $expectedPartition = "[native $($partitionIndex + 1)/$($partitionLines.Count)] optimized partition"
        if ($partitionLines[$partitionIndex] -cne $expectedPartition) {
            throw "$Description produced a malformed or non-contiguous native partition transcript`n$($Process.Stdout)"
        }
    }
    $escapedArtifact = [regex]::Escape([IO.Path]::GetFullPath($Artifact))
    if ($lines[-1] -cnotmatch "^Wrote $escapedArtifact \([1-9][0-9,]* bytes\)$") {
        throw "$Description did not end with the exact requested artifact marker`n$($Process.Stdout)"
    }
    if ($lines.Count -ne 5 + $partitionLines.Count) {
        throw "$Description produced output outside the exact partition/cache/artifact transcript`n$($Process.Stdout)"
    }
}

$contractText = [IO.File]::ReadAllText($contractPath)
$contract = $contractText | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.contract -cne "Binary and checksum codecs" -or $contract.status -cne "in-progress") {
    throw "Binary/checksum contract identity drifted"
}
$expectedModules = @("std.encoding.binary", "std.hash.crc32", "std.hash.xxhash64")
if (@(Compare-Object $expectedModules @($contract.modules) -CaseSensitive).Count -ne 0 -or $contract.invariants.Count -ne 8) {
    throw "Binary/checksum contract dimensions drifted"
}
if (@(Compare-Object @($positiveAuthority.id) @($contract.positiveFixtures) -CaseSensitive).Count -ne 0) {
    throw "Binary/checksum positive fixture authority drifted"
}
if ($contract.negativeProbes.Count -ne $negativeAuthority.Count) { throw "Binary/checksum negative probe count drifted" }
for ($index = 0; $index -lt $negativeAuthority.Count; $index++) {
    $expected = $negativeAuthority[$index]
    $actual = $contract.negativeProbes[$index]
    if ($actual.id -cne $expected.id -or $actual.source -cne $expected.source -or $actual.diagnostic -cne $expected.diagnostic) {
        throw "Binary/checksum negative tuple drifted at index $index"
    }
}
if ($contract.limitations.Count -ne 3) { throw "Binary/checksum limitations drifted" }
if ($contract.executionMatrix.positiveCases -ne 4 -or
    (@($contract.executionMatrix.targets) -join ',') -cne 'windows-x64,linux-x64,wasm32-browser' -or
    (@($contract.executionMatrix.optimizations) -join ',') -cne 'O0,O2' -or
    $contract.executionMatrix.positiveTotal -ne 24 -or
    $contract.executionMatrix.negativeTotal -ne 3 -or
    $contract.executionMatrix.overallTotal -ne 27 -or
    @($contract.executionMatrix.unsupported).Count -ne 0) { throw "Binary/checksum execution matrix drifted" }
if (@($contract.independentReferences).Count -ne 3) { throw "Binary/checksum independent reference authority drifted" }

$binarySource = [IO.File]::ReadAllText((Join-Path $root "stdlib/std/encoding/binary.slg"))
$crcSource = [IO.File]::ReadAllText((Join-Path $root "stdlib/std/hash/crc32.slg"))
$xxSource = [IO.File]::ReadAllText((Join-Path $root "stdlib/std/hash/xxhash64.slg"))
$binaryReader = [regex]::Match($binarySource, '(?s)public struct Reader \{(.*?)\}')
$binaryWriter = [regex]::Match($binarySource, '(?s)public struct Writer \{(.*?)\}')
$crcHasher = [regex]::Match($crcSource, '(?s)public struct Hasher \{(.*?)\}')
$xxHasher = [regex]::Match($xxSource, '(?s)public struct Hasher \{(.*?)\}')
if (-not $binaryReader.Success -or -not $binaryWriter.Success -or -not $crcHasher.Success -or -not $xxHasher.Success) {
    throw "Binary/checksum public instance declarations are missing"
}
foreach ($declaration in @($binaryReader, $binaryWriter, $crcHasher, $xxHasher)) {
    if ($declaration.Groups[1].Value -match '(?m)^\s*public\s+') {
        throw "Binary/checksum mutable instance state is still public"
    }
}

$startingHashes = Get-InputHashes
$formatSources = @($moduleSources) + @($negativeAuthority.source)
$formatCompleted = 0
foreach ($formatSource in $formatSources) {
    $format = Invoke-CheckedProcess -FilePath $pwshPath -ArgumentList @(
        "-NoProfile", "-File", $formatVerifier, "-Check", "-Source", $formatSource
    ) -Description "Binary/checksum focused format $formatSource"
    Assert-Success $format "Binary/checksum focused format $formatSource"
    $formatCompleted++
}

$positiveResults = [Collections.Generic.List[object]]::new()
foreach ($case in $positiveAuthority) {
    $sourcePath = Join-Path $root $case.source
    $expectedPath = Join-Path $root $case.expected
    $expectedOutput = Normalize-ExactOutput ([IO.File]::ReadAllText($expectedPath))
    foreach ($target in @("windows-x64", "linux-x64", "wasm32-browser")) {
        foreach ($optimization in @("O0", "O2")) {
            $extension = if ($target -ceq "windows-x64") { ".exe" } elseif ($target -ceq "linux-x64") { ".linux" } else { ".wasm" }
            $artifact = Join-Path $outputRoot "$($case.id).$target.$optimization$extension"
            $compile = Invoke-CheckedProcess -FilePath $dotnetPath -ArgumentList @(
                $compilerPath, "build", $sourcePath, "-o", $artifact,
                "--target", $target, "-$optimization", "--llvm", $llvmRoot
            ) -Description "$($case.id) $target $optimization compilation"
            Assert-CompileTranscript $compile $artifact "$($case.id) $target $optimization compilation"
            $run = if ($target -ceq "windows-x64") {
                Invoke-CheckedProcess -FilePath $artifact -ArgumentList @() -Description "$($case.id) $target $optimization execution"
            } elseif ($target -ceq "linux-x64") {
                Invoke-CheckedProcess -FilePath $wslPath -ArgumentList @(
                    "-d", $WslDistribution, "--", (Convert-ToWslPath $artifact)
                ) -Description "$($case.id) $target $optimization execution"
            } else {
                Invoke-CheckedProcess -FilePath $nodePath -ArgumentList @(
                    $browserRunner, $artifact, $expectedPath
                ) -Description "$($case.id) $target $optimization execution"
            }
            Assert-Success $run "$($case.id) $target $optimization execution"
            if ($target -ceq "wasm32-browser") {
                $browser = $run.Stdout | ConvertFrom-Json
                if ($browser.status -cne "passed") { throw "$($case.id) browser result mismatch" }
            } else {
                $actualOutput = Normalize-ExactOutput $run.Stdout
                if ($actualOutput -cne $expectedOutput) { throw "$($case.id) $target $optimization output mismatch" }
            }
            $positiveResults.Add([ordered]@{
                id = $case.id
                target = $target
                optimization = $optimization
                status = "passed"
                artifactSha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
                artifactPath = [IO.Path]::GetFullPath($artifact)
                compilationProcessExited = $compile.HasExited
                executionProcessExited = $run.HasExited
            })
            Write-Host "[binary/checksum positive $($positiveResults.Count)/24] PASS $($case.id) $target $optimization"
        }
    }
}

$negativeResults = [Collections.Generic.List[object]]::new()
foreach ($case in $negativeAuthority) {
    $sourcePath = Join-Path $root $case.source
    $artifact = Join-Path $outputRoot "$($case.id).exe"
    $beforeFiles = @(Get-ChildItem -LiteralPath $outputRoot -Recurse -File | Select-Object -ExpandProperty FullName)
    $compile = Invoke-CheckedProcess -FilePath $dotnetPath -ArgumentList @(
        $compilerPath, "build", $sourcePath, "-o", $artifact,
        "--target", "windows-x64", "-O0", "--llvm", $llvmRoot
    ) -Description "$($case.id) negative compilation"
    if (-not $compile.HasExited -or $compile.ExitCode -eq 0) { throw "$($case.id) unexpectedly compiled" }
    if (-not [string]::IsNullOrEmpty($compile.Stdout)) { throw "$($case.id) negative compilation produced stdout`n$($compile.Stdout)" }
    $actualDiagnostic = Normalize-ExactOutput $compile.Stderr
    if ($actualDiagnostic -cne $case.diagnostic) {
        throw "$($case.id) diagnostic mismatch`nExpected: $($case.diagnostic)`nActual: $actualDiagnostic"
    }
    if (Test-Path -LiteralPath $artifact) { throw "$($case.id) produced an executable before semantic rejection" }
    $afterFiles = @(Get-ChildItem -LiteralPath $outputRoot -Recurse -File | Select-Object -ExpandProperty FullName)
    $newFiles = @($afterFiles | Where-Object { $beforeFiles -cnotcontains $_ })
    if ($newFiles.Count -ne 0) { throw "$($case.id) produced files before semantic rejection: $($newFiles -join ', ')" }
    $negativeResults.Add([ordered]@{
        id = $case.id
        status = "passed"
        exitCode = $compile.ExitCode
        processExited = $compile.HasExited
        diagnostic = $actualDiagnostic
        preArtifactRejection = $true
    })
    Write-Host "[binary/checksum negative $($negativeResults.Count)/3] PASS $($case.id)"
}

$endingHashes = Get-InputHashes
foreach ($key in $startingHashes.Keys) {
    if ($startingHashes[$key] -cne $endingHashes[$key]) { throw "Binary/checksum input changed during verification: $key" }
}
$toolHashes = [ordered]@{
    compiler = [ordered]@{ path = $compilerPath; sha256 = $endingHashes[(Get-HashKey $compilerPath)] }
    dotnet = [ordered]@{ path = $dotnetPath; sha256 = $endingHashes[(Get-HashKey $dotnetPath)] }
    pwsh = [ordered]@{ path = $pwshPath; sha256 = $endingHashes[(Get-HashKey $pwshPath)] }
    wsl = [ordered]@{ path = $wslPath; sha256 = $endingHashes[(Get-HashKey $wslPath)] }
    clang = [ordered]@{ path = $clangPath; sha256 = $endingHashes[(Get-HashKey $clangPath)] }
    node = [ordered]@{ path = $nodePath; sha256 = $endingHashes[(Get-HashKey $nodePath)] }
    wasmLd = [ordered]@{ path = $wasmLdPath; sha256 = $endingHashes[(Get-HashKey $wasmLdPath)] }
}
$productionSourceHashes = [ordered]@{}
foreach ($source in $moduleSources) {
    $productionSourceHashes[$source] = $endingHashes[$source]
}
$result = [ordered]@{
    schemaVersion = 1
    status = "passed"
    failureIds = @()
    unsupported = @()
    completed = $positiveResults.Count + $negativeResults.Count
    total = 27
    positive = [ordered]@{ completed = $positiveResults.Count; total = 24; checks = $positiveResults }
    negative = [ordered]@{ completed = $negativeResults.Count; total = 3; checks = $negativeResults }
    managedExecution = [ordered]@{
        status = "passed"
        compiler = "current-managed"
        completed = $positiveResults.Count
        total = 24
        optimizations = @("O0", "O2")
        platforms = @(
            [ordered]@{ target = "windows-x64"; host = "Windows"; completed = 8; total = 8 },
            [ordered]@{ target = "linux-x64"; host = "WSL:$WslDistribution"; completed = 8; total = 8 },
            [ordered]@{ target = "wasm32-browser"; host = "Node WebAssembly"; completed = 8; total = 8 }
        )
    }
    selfhostExecution = [ordered]@{
        status = "pending"
        completed = 0
        total = $null
        scope = "rebuilt-selfhost"
        reason = "Shared selfhost cache and rebuilt-selfhost execution are outside this focused lane."
    }
    browserExecution = [ordered]@{
        status = "passed"
        completed = 8
        total = 8
        scope = "browser-target"
        reason = "Pure-SLG codecs executed with exact output in the bounded Node-hosted browser ABI harness."
    }
    finalStageIntegration = [ordered]@{
        status = "pending"
        completed = 0
        total = 2
        stages = @("Stage2", "Stage3")
        reason = "Final Stage integration is root-owned and outside this focused lane."
    }
    contract = [ordered]@{ modules = 3; invariants = 8; positiveFixtures = 4; negativeProbes = 3; formattedSources = $formatCompleted }
    inputHashes = $endingHashes
    toolHashes = $toolHashes
    hashVerification = [ordered]@{
        status = "passed"
        inputs = [ordered]@{ completed = $endingHashes.Count; total = $endingHashes.Count }
        tools = [ordered]@{ completed = $toolHashes.Count; total = 7 }
        productionSources = [ordered]@{
            completed = $productionSourceHashes.Count
            total = 4
            hashes = $productionSourceHashes
        }
    }
    limitations = @($contract.limitations)
}
$resultPath = Join-Path $outputRoot "result.json"
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
$publishedText = [IO.File]::ReadAllText($resultPath)
$published = $publishedText | ConvertFrom-Json
if ($publishedText -cnotmatch '"failureIds"\s*:\s*\[\s*\]' -or
    $published.managedExecution.status -cne "passed" -or
    $published.managedExecution.completed -ne 24 -or
    $published.managedExecution.total -ne 24 -or
    $published.selfhostExecution.status -cne "pending" -or
    $published.browserExecution.status -cne "passed" -or
    $published.finalStageIntegration.status -cne "pending" -or
    $published.finalStageIntegration.completed -ne 0 -or
    $published.finalStageIntegration.total -ne 2 -or
    $published.hashVerification.inputs.completed -ne $endingHashes.Count -or
    $published.hashVerification.inputs.total -ne $endingHashes.Count -or
    $published.hashVerification.tools.completed -ne 7 -or
    $published.hashVerification.tools.total -ne 7 -or
    $published.hashVerification.productionSources.completed -ne 4 -or
    $published.hashVerification.productionSources.total -ne 4) {
    throw "Binary/checksum structured result contract failed after publication"
}
Write-Host "[binary/checksum focused] PASS 27/27; managed Windows/Linux/browser O0/O2 24/24; private-state negatives 3/3; $resultPath"
