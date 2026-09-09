[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$Output,
    [ValidateSet("windows", "linux")][string]$Target = "windows",
    [ValidateRange(1, 1024)][int]$Jobs = [System.Environment]::ProcessorCount,
    [ValidateRange(1000, 7200000)][int]$TimeoutMilliseconds = 3600000,
    [string[]]$Manifest = @(
        "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt",
        "tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt"
    ),
    [switch]$KeepLlvm
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "compiler-emission-fingerprint.ps1")
$schemaPath = Join-Path $repoRoot "scripts\contracts\selfhost-compiler-emission-profile.schema.json"
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$profilePath = [System.IO.Path]::GetFullPath($Output)
$profileDirectory = [System.IO.Path]::GetDirectoryName($profilePath)
[System.IO.Directory]::CreateDirectory($profileDirectory) | Out-Null
$llvmPath = [System.IO.Path]::ChangeExtension($profilePath, ".ll")
$errorPath = [System.IO.Path]::ChangeExtension($profilePath, ".stderr.txt")

function Resolve-ManifestSources {
    param([Parameter(Mandatory)][string[]]$Paths)

    $sources = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $Paths) {
        $manifestPath = if ([System.IO.Path]::IsPathRooted($path)) {
            [System.IO.Path]::GetFullPath($path)
        } else {
            [System.IO.Path]::GetFullPath((Join-Path $repoRoot $path))
        }
        foreach ($line in [System.IO.File]::ReadAllLines($manifestPath)) {
            $entry = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($entry) -or $entry.StartsWith("#")) { continue }
            $sourcePath = if ([System.IO.Path]::IsPathRooted($entry)) {
                [System.IO.Path]::GetFullPath($entry)
            } else {
                [System.IO.Path]::GetFullPath((Join-Path $repoRoot $entry))
            }
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                throw "manifest source does not exist: $sourcePath"
            }
            if ($seen.Add($sourcePath)) { $sources.Add($sourcePath) }
        }
    }
    $sources.ToArray()
}

$manifestPaths = @($Manifest | ForEach-Object {
    if ([System.IO.Path]::IsPathRooted($_)) {
        [System.IO.Path]::GetFullPath($_)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $_))
    }
})
$sources = @(Resolve-ManifestSources $manifestPaths)
$relativeManifests = @($manifestPaths | ForEach-Object {
    [System.IO.Path]::GetRelativePath($repoRoot, $_).Replace('\', '/')
})
$compilerFingerprint = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
$inputFingerprint = Get-CompilerEmissionInputFingerprint `
    -RepositoryRoot $repoRoot `
    -Path $sources

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $compilerPath
$startInfo.WorkingDirectory = $repoRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.ArgumentList.Add($Target)
$startInfo.ArgumentList.Add("--jobs")
$startInfo.ArgumentList.Add([string]$Jobs)
foreach ($source in $sources) { $startInfo.ArgumentList.Add($source) }

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
[long]$peakWorkingSetBytes = 0
[long]$cpuMilliseconds = 0
$llvmStream = $null
try {
    $llvmStream = [System.IO.File]::Create($llvmPath)
    if (-not $process.Start()) { throw "self-host compiler emission could not start" }
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($llvmStream)
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $deadline = [DateTimeOffset]::Now.AddMilliseconds($TimeoutMilliseconds)
    $nextTelemetry = [DateTimeOffset]::Now.AddSeconds(60)
    do {
        $process.Refresh()
        $peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, [long]$process.PeakWorkingSet64)
        $cpuMilliseconds = [Math]::Max($cpuMilliseconds, [long]$process.TotalProcessorTime.TotalMilliseconds)
        if ($process.WaitForExit(25)) { break }
        if ([DateTimeOffset]::Now -ge $deadline) {
            try { $process.Kill($true) } catch { $process.Kill() }
            [void]$process.WaitForExit(5000)
            throw "self-host compiler emission exceeded $TimeoutMilliseconds milliseconds"
        }
        if ([DateTimeOffset]::Now -ge $nextTelemetry) {
            Write-Host ("[compiler emission profile] active {0:N0}ms; CPU {1:N0}ms; peak {2:N0} MiB." -f `
                $stopwatch.ElapsedMilliseconds,
                $cpuMilliseconds,
                ($peakWorkingSetBytes / 1MB))
            $nextTelemetry = [DateTimeOffset]::Now.AddSeconds(60)
        }
    } while ($true)
    $process.WaitForExit()
    [void]$stdoutTask.GetAwaiter().GetResult()
    $llvmStream.Flush()
    $llvmStream.Dispose()
    $llvmStream = $null
    $stopwatch.Stop()
    $process.Refresh()
    $peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, [long]$process.PeakWorkingSet64)
    $cpuMilliseconds = [Math]::Max($cpuMilliseconds, [long]$process.TotalProcessorTime.TotalMilliseconds)
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) {
        [System.IO.File]::WriteAllText($errorPath, $stderr, [System.Text.UTF8Encoding]::new($false))
        throw "self-host compiler emission failed with exit code $($process.ExitCode); see $errorPath"
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        [System.IO.File]::WriteAllText($errorPath, $stderr, [System.Text.UTF8Encoding]::new($false))
        throw "self-host compiler emission wrote unexpected stderr; see $errorPath"
    }
    if ($peakWorkingSetBytes -le 0) { throw "compiler emission completed without an observed positive peak working set" }

    $llvmInfo = Get-Item -LiteralPath $llvmPath
    $profile = [ordered]@{
        schemaVersion = 1
        mode = "compiler-emission"
        measurement = "single-process-native-llvm-emission"
        target = $Target
        workerLimit = $Jobs
        environment = [ordered]@{
            osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
            processArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
            processorCount = [System.Environment]::ProcessorCount
        }
        sourceManifests = $relativeManifests
        sourceCount = $sources.Count
        compilerFingerprint = $compilerFingerprint
        inputFingerprint = $inputFingerprint
        outputFingerprint = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
        outputBytes = [long]$llvmInfo.Length
        wallMilliseconds = [long]$stopwatch.ElapsedMilliseconds
        cpuMilliseconds = $cpuMilliseconds
        peakWorkingSetBytes = $peakWorkingSetBytes
    }
    $json = ($profile | ConvertTo-Json -Depth 5) + "`n"
    if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "compiler emission profile does not match its schema"
    }
    $temporaryProfile = "$profilePath.tmp-$([Guid]::NewGuid().ToString('N'))"
    [System.IO.File]::WriteAllText($temporaryProfile, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryProfile -Destination $profilePath -Force
    Remove-Item -LiteralPath $errorPath -ErrorAction SilentlyContinue
    Write-Host $json.TrimEnd()
    Write-Host "[compiler emission profile] PASS deterministic workload receipt written to $profilePath."
} finally {
    if ($null -ne $llvmStream) { $llvmStream.Dispose() }
    $process.Dispose()
    if (-not $KeepLlvm -and (Test-Path -LiteralPath $llvmPath)) {
        Remove-Item -LiteralPath $llvmPath -Force
    }
}
