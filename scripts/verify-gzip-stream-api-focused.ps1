[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CompilerPath,
    [string]$ScratchRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
if (-not $ScratchRoot) { $ScratchRoot = Join-Path $root ('artifacts\scratch\gzip-stream-api-' + [guid]::NewGuid().ToString('N')) }
$scratch = [IO.Path]::GetFullPath($ScratchRoot)
if (-not $scratch.StartsWith((Join-Path $root 'artifacts\scratch') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'ScratchRoot must be below artifacts/scratch' }
New-Item -ItemType Directory -Path $scratch -Force | Out-Null

if (-not $CompilerPath) {
    $hostBin = Join-Path $scratch 'managed-host'
    $dotnetArtifacts = Join-Path $scratch 'dotnet-artifacts'
    & dotnet build (Join-Path $root 'src\Sollang.Compiler\Sollang.Compiler.csproj') -c Release -o $hostBin --artifacts-path $dotnetArtifacts -p:UseSharedCompilation=false --nologo
    if ($LASTEXITCODE -ne 0) { throw 'scratch managed compiler build failed' }
    $CompilerPath = Join-Path $hostBin 'Sollang.Compiler.dll'
}
$compiler = [IO.Path]::GetFullPath($CompilerPath)
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw "compiler missing: $compiler" }

function Invoke-Captured([string]$File, [string[]]$Arguments, [string]$Prefix) {
    $stdoutPath = "$Prefix.stdout.txt"
    $stderrPath = "$Prefix.stderr.txt"
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $File
    $info.WorkingDirectory = $root
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "could not start $File" }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdoutText = $stdout.GetAwaiter().GetResult()
    $stderrText = $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText($stdoutPath, $stdoutText, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, $stderrText, [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ ExitCode = $process.ExitCode; Stdout = $stdoutText; Stderr = $stderrText; StdoutPath = $stdoutPath; StderrPath = $stderrPath }
}
function Normalize([string]$Text) { $Text.Replace("`r`n", "`n") }
function Resolve-Input([string]$Relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $root $Relative))
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "input escapes repository: $Relative" }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "input missing: $Relative" }
    $path
}

& (Join-Path $root 'scripts\verify-gzip-stream-api-contract.ps1') -RepositoryRoot $root
$contractPath = Resolve-Input 'scripts/contracts/gzip-stream-api.json'
$contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
$failures = [Collections.Generic.List[string]]::new()
$positivePassed = 0
$negativePassed = 0
$dynamicBaseline = $null
$records = [Collections.Generic.List[object]]::new()

foreach ($case in $contract.positiveCases) {
    $source = Resolve-Input $case.source
    foreach ($optimization in $contract.managedOptimizations) {
        $id = "$($case.id)-$($optimization.ToLowerInvariant())"
        $caseDir = Join-Path $scratch $id
        New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
        $artifact = Join-Path $caseDir 'probe.exe'
        $compile = Invoke-Captured 'dotnet' @($compiler, 'build', $source, '-o', $artifact, '--target', 'windows-x64', "-$optimization") (Join-Path $caseDir 'compile')
        if ($compile.ExitCode -ne 0 -or $compile.Stderr.Length -ne 0 -or -not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
            $failures.Add("$id.compile")
            continue
        }
        $run = Invoke-Captured $artifact @() (Join-Path $caseDir 'run')
        if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0) { $failures.Add("$id.run"); continue }
        $actual = Normalize $run.Stdout
        if ($case.PSObject.Properties.Name -contains 'expected') {
            $expected = Normalize ([IO.File]::ReadAllText((Resolve-Input $case.expected)))
            if ($actual -cne $expected) { $failures.Add("$id.stdout"); continue }
        } else {
            $lines = @($actual.TrimEnd("`n").Split("`n"))
            if ($lines.Count -lt 2 -or $lines[0] -cne $case.expectedFirstLine) { $failures.Add("$id.stdout"); continue }
            try { $bytes = [byte[]]($lines[1..($lines.Count - 1)] | ForEach-Object { [byte]::Parse($_, [Globalization.CultureInfo]::InvariantCulture) }) } catch { $failures.Add("$id.bytes"); continue }
            if ((($bytes[10] -shr 1) -band 3) -ne 2) { $failures.Add("$id.btype"); continue }
            $inputStream = $null
            $gzipStream = $null
            $outputStream = $null
            try {
                $inputStream = [IO.MemoryStream]::new($bytes)
                $gzipStream = [IO.Compression.GZipStream]::new($inputStream, [IO.Compression.CompressionMode]::Decompress)
                $outputStream = [IO.MemoryStream]::new()
                $gzipStream.CopyTo($outputStream)
                $reference = [Text.Encoding]::ASCII.GetString($outputStream.ToArray())
            } catch { $failures.Add("$id.reference"); continue } finally {
                if ($null -ne $gzipStream) { $gzipStream.Dispose() }
                if ($null -ne $inputStream) { $inputStream.Dispose() }
                if ($null -ne $outputStream) { $outputStream.Dispose() }
            }
            if ($reference -cne $case.referenceText) { $failures.Add("$id.reference"); continue }
            $hash = (Get-FileHash -LiteralPath $run.StdoutPath -Algorithm SHA256).Hash
            if ($null -eq $dynamicBaseline) { $dynamicBaseline = $hash } elseif ($dynamicBaseline -cne $hash) { $failures.Add("$id.determinism"); continue }
        }
        $positivePassed++
        $records.Add([ordered]@{ id = $id; status = 'pass'; stdoutSha256 = (Get-FileHash -LiteralPath $run.StdoutPath -Algorithm SHA256).Hash })
    }
}

foreach ($case in $contract.negativeCases) {
    $source = Resolve-Input $case.source
    $caseDir = Join-Path $scratch $case.id
    New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
    $artifact = Join-Path $caseDir 'probe.exe'
    $compile = Invoke-Captured 'dotnet' @($compiler, 'build', $source, '-o', $artifact, '--target', 'windows-x64', '-O0') (Join-Path $caseDir 'compile')
    $expectedError = $case.diagnostic + "`n"
    if ($compile.ExitCode -eq 0 -or $compile.Stdout.Length -ne 0 -or (Normalize $compile.Stderr) -cne $expectedError -or (Test-Path -LiteralPath $artifact)) {
        $failures.Add("$($case.id).diagnostic")
        continue
    }
    $negativePassed++
    $records.Add([ordered]@{ id = $case.id; status = 'pass'; diagnostic = $case.diagnostic })
}

$hashInputs = @($contract.sources) + @($contract.positiveCases.source) + @($contract.negativeCases.source) + @('scripts/contracts/gzip-stream-api.json','scripts/contracts/gzip-stream-api.schema.json','scripts/verify-gzip-stream-api-contract.ps1','scripts/verify-gzip-stream-api-focused.ps1')
$hashes = @($hashInputs | Sort-Object -Unique | ForEach-Object { $path = Resolve-Input $_; [ordered]@{ path = $_; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } })
$dotnetPath = (Get-Command dotnet -ErrorAction Stop).Source
$toolHashes = @(
    [ordered]@{ path = $compiler; sha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash },
    [ordered]@{ path = $dotnetPath; sha256 = (Get-FileHash -LiteralPath $dotnetPath -Algorithm SHA256).Hash }
)
$result = [ordered]@{
    status = $(if ($failures.Count -eq 0) { 'pass' } else { 'fail' })
    failureIds = @($failures)
    positive = [ordered]@{ passed = $positivePassed; total = 20 }
    negative = [ordered]@{ passed = $negativePassed; total = 3 }
    managed = [ordered]@{ compiler = $compiler; target = 'windows-x64'; optimizations = @($contract.managedOptimizations) }
    reference = [ordered]@{ reader = 'System.IO.Compression.GZipStream'; dynamicBType = 2; deterministicAcrossOptimizations = ($null -ne $dynamicBaseline) }
    allocationCopy = [ordered]@{ boundedFixedHashTable = $true; retainsCompleteInput = $false; callerOwnedOutput = $true }
    pending = @($contract.pending)
    toolHashes = $toolHashes
    inputHashes = $hashes
    records = @($records)
}
$resultPath = Join-Path $scratch 'result.json'
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($failures.Count -ne 0) { throw "GZIP focused verification failed: $($failures -join ', '); result=$resultPath" }
Write-Host "[GZIP focused] PASS positive $positivePassed/20, negative $negativePassed/3, total $($positivePassed + $negativePassed)/23; result=$resultPath"
