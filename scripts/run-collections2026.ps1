param(
    [ValidateRange(10, 100)]
    [int]$Runs = 10,
    [ValidateRange(0, 62)]
    [int]$Cpu = 0,
    [ValidateRange(0, 100)]
    [double]$IdleAverageLimit = 10.0,
    [ValidateRange(3, 30)]
    [int]$IdleSamples = 5,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $repoRoot "artifacts\benchmarks\collections2026"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("sollang-collections2026-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $outputRoot, $temporaryRoot -Force | Out-Null

function Invoke-Checked {
    param([string]$FilePath, [string[]]$Arguments)
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "command failed ($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
    }
}

function Get-Percentile {
    param([double[]]$Values, [double]$Percentile)
    $ordered = @($Values | Sort-Object)
    $index = [Math]::Ceiling($Percentile * $ordered.Count) - 1
    return $ordered[[Math]::Max(0, [Math]::Min($ordered.Count - 1, $index))]
}

try {
    $idle = for ($sample = 0; $sample -lt $IdleSamples; $sample++) {
        [double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
        if ($sample + 1 -lt $IdleSamples) { Start-Sleep -Seconds 1 }
    }
    $idleAverage = ($idle | Measure-Object -Average).Average
    if ($idleAverage -gt $IdleAverageLimit) {
        throw "idle CPU gate failed: average=$([Math]::Round($idleAverage, 2))% limit=$IdleAverageLimit% samples=$($idle -join ',')"
    }

    $clang = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\clang++.exe"
    $javaHome = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { "P:\Utils\jdk-17" }
    $java = Join-Path $javaHome "bin\java.exe"
    $javac = Join-Path $javaHome "bin\javac.exe"
    $javaClasses = Join-Path $outputRoot "java-classes"
    $apps = [ordered]@{
        Sollang = Join-Path $outputRoot "sollang-hash-set.exe"
        DotNetNativeAot = Join-Path $outputRoot "dotnet-hash-set.exe"
        Rust = Join-Path $outputRoot "rust-hash-set.exe"
        Cpp = Join-Path $outputRoot "cpp-hash-set.exe"
        Go = Join-Path $outputRoot "go-hash-set.exe"
        Java = $java
    }

    if (-not $SkipBuild) {
        Invoke-Checked dotnet @("run", "--project", (Join-Path $repoRoot "src\Sollang.Compiler"), "--", "build", (Join-Path $repoRoot "benchmarks\collections2026\sollang\hash_set_mixed.slg"), "-o", $apps.Sollang, "-O3")
        Invoke-Checked $clang @("-O3", "-std=c++20", (Join-Path $repoRoot "benchmarks\collections2026\cpp\hash_set_mixed.cpp"), "-o", $apps.Cpp)
        Invoke-Checked rustc @("-O", (Join-Path $repoRoot "benchmarks\collections2026\rust\hash_set_mixed.rs"), "-o", $apps.Rust)
        Invoke-Checked go @("build", "-ldflags", "-s -w", "-o", $apps.Go, (Join-Path $repoRoot "benchmarks\collections2026\go\hash_set_mixed.go"))
        Invoke-Checked dotnet @("publish", (Join-Path $repoRoot "benchmarks\collections2026\csharp\HashSetMixed.csproj"), "-c", "Release", "-r", "win-x64", "-p:PublishAot=true", "-o", (Join-Path $outputRoot "dotnet-publish"))
        Copy-Item -LiteralPath (Join-Path $outputRoot "dotnet-publish\HashSetMixed.exe") -Destination $apps.DotNetNativeAot -Force
        if (-not (Test-Path -LiteralPath $javac)) { throw "javac is missing: $javac" }
        New-Item -ItemType Directory -Path $javaClasses -Force | Out-Null
        Invoke-Checked $javac @("-d", $javaClasses, (Join-Path $repoRoot "benchmarks\collections2026\java\HashSetMixed.java"))
    }

    foreach ($app in $apps.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $app.Value)) { throw "benchmark artifact is missing: $($app.Value)" }
    }
    $javaClass = Join-Path $javaClasses "HashSetMixed.class"
    if (-not (Test-Path -LiteralPath $javaClass)) { throw "benchmark artifact is missing: $javaClass" }

    $measurements = [ordered]@{}
    foreach ($name in $apps.Keys) { $measurements[$name] = [Collections.Generic.List[object]]::new() }
    $affinity = [IntPtr](1L -shl $Cpu)

    # Interleave implementations each round so slow host drift cannot favor one
    # runtime. Managed programs contain their own untimed warmup workload.
    for ($round = 1; $round -le $Runs; $round++) {
        foreach ($name in $apps.Keys) {
            $stdoutPath = Join-Path $temporaryRoot "$name-$round.stdout.txt"
            $stderrPath = Join-Path $temporaryRoot "$name-$round.stderr.txt"
            $startArguments = if ($name -eq "Java") { @("-cp", $javaClasses, "HashSetMixed") } else { @() }
            $process = Start-Process -FilePath $apps[$name] -ArgumentList $startArguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
            try { $process.ProcessorAffinity = $affinity } catch { throw "failed to pin $name to logical CPU $Cpu`: $($_.Exception.Message)" }
            [long]$peakWorkingSet = 0
            while (-not $process.WaitForExit(5)) {
                $process.Refresh()
                $peakWorkingSet = [Math]::Max($peakWorkingSet, [long]$process.WorkingSet64)
            }
            $process.Refresh()
            if ($process.ExitCode -ne 0) {
                throw "$name run $round failed ($($process.ExitCode)): $([IO.File]::ReadAllText($stderrPath))"
            }
            $line = [IO.File]::ReadAllText($stdoutPath).Trim()
            $fields = @{}
            foreach ($part in $line -split '\s+') {
                $pair = $part -split '=', 2
                if ($pair.Count -eq 2) { $fields[$pair[0]] = $pair[1] }
            }
            if ($fields.checksum -ne "50000000000000" -or $fields.len -ne "5000000") {
                throw "$name run $round violated the result contract: $line"
            }
            $elapsedMs = if ($fields.elapsed_ns) { [double]$fields.elapsed_ns / 1000000.0 } else { [double]$fields.elapsed_ms }
            $measurements[$name].Add([pscustomobject]@{
                Round = $round
                ElapsedMs = $elapsedMs
                PeakWorkingSetBytes = $peakWorkingSet
                Allocations = if ($fields.allocations -and $fields.allocations -ne "unavailable") { [long]$fields.allocations } else { $null }
                AllocatedBytes = if ($fields.allocated_bytes -and $fields.allocated_bytes -ne "unavailable") { [long]$fields.allocated_bytes } else { $null }
                Capacity = $fields.capacity
                Raw = $line
            })
        }
    }

    $summary = foreach ($name in $apps.Keys) {
        $rows = $measurements[$name]
        $times = [double[]]@($rows.ElapsedMs)
        $allocated = @($rows | Where-Object { $null -ne $_.AllocatedBytes } | ForEach-Object AllocatedBytes)
        $allocations = @($rows | Where-Object { $null -ne $_.Allocations } | ForEach-Object Allocations)
        [pscustomobject]@{
            Implementation = $name
            Runs = $rows.Count
            MedianMs = Get-Percentile $times 0.5
            P95Ms = Get-Percentile $times 0.95
            LogicalOpsPerSecond = [long][Math]::Round(30000000.0 / ((Get-Percentile $times 0.5) / 1000.0))
            PeakWorkingSetBytes = [long](($rows.PeakWorkingSetBytes | Measure-Object -Maximum).Maximum)
            AllocationsMedian = if ($allocations.Count) { [long](Get-Percentile ([double[]]$allocations) 0.5) } else { $null }
            AllocatedBytesMedian = if ($allocated.Count) { [long](Get-Percentile ([double[]]$allocated) 0.5) } else { $null }
            Capacity = ($rows | Select-Object -First 1).Capacity
        }
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonPath = Join-Path $outputRoot "results-$stamp.json"
    $summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding utf8
    [pscustomobject]@{
        IdleAveragePercent = [Math]::Round($idleAverage, 2)
        IdleSamples = $idle
        Cpu = $Cpu
        Runs = $Runs
        Results = $summary
        JsonPath = $jsonPath
    } | ConvertTo-Json -Depth 6
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
