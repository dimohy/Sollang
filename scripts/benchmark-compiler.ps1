[CmdletBinding()]
param(
    [string]$Compiler = "",
    [string[]]$Fixture = @(
        "examples/regression/577-lazy-range-each.slg",
        "examples/regression/582-billion-sensor-alerts.slg"
    ),
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [ValidateRange(1, 100)]
    [int]$Iterations = 5,
    [ValidateRange(0, 20)]
    [int]$Warmup = 1,
    [string]$Baseline = "",
    [ValidateRange(0, 1000)]
    [double]$MaxRegressionPercent = 5,
    [switch]$WriteBaseline
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $repoRoot "artifacts\compiler-benchmark"))
$runRoot = Join-Path $artifactRoot $Target

function Assert-UnderArtifactRoot {
    param([string]$Path)

    $resolved = [System.IO.Path]::GetFullPath($Path)
    $prefix = $artifactRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to modify path outside compiler benchmark artifacts: $resolved"
    }
}

function Resolve-CompilerCommand {
    if (-not [string]::IsNullOrWhiteSpace($Compiler)) {
        $path = (Resolve-Path -LiteralPath $Compiler).Path
        if ([System.IO.Path]::GetExtension($path) -eq ".dll") {
            return @{
                FilePath = "dotnet"
                Prefix = @($path)
                Identity = $path
            }
        }
        return @{
            FilePath = $path
            Prefix = @()
            Identity = $path
        }
    }

    $command = Get-Command sollang -ErrorAction Stop
    return @{
        FilePath = $command.Source
        Prefix = @()
        Identity = $command.Source
    }
}

function Invoke-TimedCompiler {
    param(
        [hashtable]$Command,
        [string[]]$Arguments,
        [string]$OutputBase
    )

    $stdoutPath = "$OutputBase.stdout.txt"
    $stderrPath = "$OutputBase.stderr.txt"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process `
        -FilePath $Command.FilePath `
        -ArgumentList @($Command.Prefix + $Arguments) `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    $stopwatch.Stop()
    if ($process.ExitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath $stderrPath) {
            [System.IO.File]::ReadAllText($stderrPath)
        } else { "" }
        $stdout = if (Test-Path -LiteralPath $stdoutPath) {
            [System.IO.File]::ReadAllText($stdoutPath)
        } else { "" }
        throw "compiler failed with exit code $($process.ExitCode):`n$stderr$stdout"
    }
    return [double]$stopwatch.Elapsed.TotalMilliseconds
}

function Get-Percentile {
    param([double[]]$Values, [double]$Percentile)

    $ordered = @($Values | Sort-Object)
    $index = [Math]::Ceiling($Percentile * $ordered.Count) - 1
    return [double]$ordered[[Math]::Max(0, $index)]
}

$command = Resolve-CompilerCommand
if (Test-Path -LiteralPath $runRoot) {
    Assert-UnderArtifactRoot $runRoot
    Remove-Item -LiteralPath $runRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

# Keep the cold measurement about Sollang's compiler cache, not one-time WSL
# virtual-machine startup. Native Linux hosts do not need this host warmup.
if ($Target -eq "linux-x64" -and $IsWindows) {
    & wsl.exe --exec true
    if ($LASTEXITCODE -ne 0) {
        throw "failed to warm the WSL Linux linker host"
    }
}

$results = @()
foreach ($fixturePath in $Fixture) {
    $source = (Resolve-Path -LiteralPath (Join-Path $repoRoot $fixturePath)).Path
    $name = [System.IO.Path]::GetFileNameWithoutExtension($source)
    $caseRoot = Join-Path $runRoot $name
    New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null
    $extension = if ($Target -eq "windows-x64") { ".exe" } else { "" }
    $output = Join-Path $caseRoot ($name + $extension)
    $commonArguments = @(
        "build", $source,
        "--target", $Target,
        "-O1",
        "-o", $output
    )

    $cold = Invoke-TimedCompiler $command $commonArguments (Join-Path $caseRoot "cold")
    for ($index = 0; $index -lt $Warmup; $index++) {
        [void](Invoke-TimedCompiler `
            $command `
            $commonArguments `
            (Join-Path $caseRoot "warmup-$index"))
    }

    $warmValues = @()
    for ($index = 0; $index -lt $Iterations; $index++) {
        $warmValues += Invoke-TimedCompiler `
            $command `
            $commonArguments `
            (Join-Path $caseRoot "warm-$index")
    }

    $results += [ordered]@{
        fixture = $fixturePath.Replace("\", "/")
        coldMs = [Math]::Round($cold, 3)
        warmMedianMs = [Math]::Round((Get-Percentile $warmValues 0.5), 3)
        warmP95Ms = [Math]::Round((Get-Percentile $warmValues 0.95), 3)
        warmSamplesMs = @($warmValues | ForEach-Object { [Math]::Round($_, 3) })
    }
}

$report = [ordered]@{
    schema = 1
    timestampUtc = [DateTime]::UtcNow.ToString("O")
    compiler = $command.Identity
    target = $Target
    iterations = $Iterations
    warmup = $Warmup
    results = $results
}
$reportPath = Join-Path $runRoot "latest.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM

if (-not [string]::IsNullOrWhiteSpace($Baseline)) {
    $baselinePath = (Resolve-Path -LiteralPath $Baseline).Path
    $previous = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
    foreach ($result in $results) {
        $old = $previous.results |
            Where-Object { $_.fixture -eq $result.fixture } |
            Select-Object -First 1
        if ($null -eq $old) {
            throw "baseline has no fixture '$($result.fixture)'"
        }
        $limit = [double]$old.warmMedianMs * (1 + ($MaxRegressionPercent / 100))
        if ([double]$result.warmMedianMs -gt $limit) {
            throw "warm compiler regression for $($result.fixture): " +
                "$($result.warmMedianMs)ms > $([Math]::Round($limit, 3))ms"
        }
    }
}

if ($WriteBaseline) {
    $baselinePath = Join-Path $artifactRoot "baseline-$Target.json"
    Copy-Item -LiteralPath $reportPath -Destination $baselinePath -Force
    Write-Host "Wrote compiler baseline $baselinePath"
}

foreach ($result in $results) {
    Write-Host (
        "$($result.fixture): cold=$($result.coldMs)ms " +
        "warm-median=$($result.warmMedianMs)ms warm-p95=$($result.warmP95Ms)ms")
}
Write-Host "Wrote compiler benchmark $reportPath"
