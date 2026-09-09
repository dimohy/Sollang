param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,
    [Parameter(Mandatory = $true)]
    [string]$Label,
    [Parameter(Mandatory = $true)]
    [string]$Distribution,
    [Parameter(Mandatory = $true)]
    [string]$StdlibRoot,
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [ValidateRange(1, 64)]
    [int]$Jobs = 4
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "verification-process.ps1")

function Convert-ToQuicEndpointWslPath {
    param([string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$cases = @(
    [ordered]@{
        Name = "move-method-owned-field-drop"
        Source = Join-Path $RepositoryRoot "examples\regression\1166-move-method-owned-field-drop.slg"
        Expected = "closed"
    },
    [ordered]@{
        Name = "quic-endpoint-two-connection-routing"
        Source = Join-Path $RepositoryRoot "examples\regression\1167-quic-endpoint-two-connection-routing.slg"
        Expected = "quic-two-routes=true"
    },
    [ordered]@{
        Name = "quic-bidirectional-multi-stream-routing"
        Source = Join-Path $RepositoryRoot "examples\regression\1206-quic-bidirectional-multi-stream-routing.slg"
        Expected = "quic-multi-stream=true"
    },
    [ordered]@{
        Name = "quic-connection-options-queue-limits"
        Source = Join-Path $RepositoryRoot "examples\regression\1209-quic-connection-options-queue-limits.slg"
        Expected = "quic-options=true"
    },
    [ordered]@{
        Name = "quic-unidirectional-stream-owners"
        Source = Join-Path $RepositoryRoot "examples\regression\1297-quic-unidirectional-stream-owners.slg"
        Expected = "quic-unidirectional-owners=true"
    }
)

$completedCases = 0
$totalCases = $cases.Count
foreach ($case in $cases) {
    $caseNumber = $completedCases + 1
    Write-Host "[native QUIC Endpoint ownership $caseNumber/$totalCases] BUILD $Label Linux $($case.Name)."
    $executable = Join-Path $OutputDirectory "$Label-$($case.Name)"
    $buildOutput = "$executable.build.stdout.log"
    $buildError = "$executable.build.stderr.log"
    $runOutput = "$executable.stdout.log"
    $runError = "$executable.stderr.log"
    Remove-Item -LiteralPath $executable, $buildOutput, $buildError, $runOutput, $runError -ErrorAction SilentlyContinue

    $build = Start-Process `
        -FilePath "wsl.exe" `
        -ArgumentList @(
            "-d", $Distribution, "--", (Convert-ToQuicEndpointWslPath $compilerPath),
            "build", (Convert-ToQuicEndpointWslPath $case.Source),
            "-o", (Convert-ToQuicEndpointWslPath $executable),
            "--target", "linux-x64",
            "--stdlib", (Convert-ToQuicEndpointWslPath $StdlibRoot),
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "-O1", "--keep-temps") `
        -RedirectStandardOutput $buildOutput `
        -RedirectStandardError $buildError `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $build "$Label Linux $($case.Name) build" 180000
    $build.Refresh()
    if ($build.ExitCode -ne 0) {
        throw "$Label Linux $($case.Name) build failed: $([IO.File]::ReadAllText($buildError))"
    }
    $buildDiagnostics = [IO.File]::ReadAllText($buildOutput) + [IO.File]::ReadAllText($buildError)
    if ($buildDiagnostics -match '(?m)^(?:warning S\d+|note N\d+)\b') {
        throw "$Label Linux $($case.Name) emitted a compiler warning or note.`n$buildDiagnostics"
    }
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath "$executable.ll"
    if (-not $?) { throw "$Label Linux $($case.Name) LLVM direct-call closure verification failed" }

    $run = Start-Process `
        -FilePath "wsl.exe" `
        -ArgumentList @("-d", $Distribution, "--", (Convert-ToQuicEndpointWslPath $executable)) `
        -RedirectStandardOutput $runOutput `
        -RedirectStandardError $runError `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $run "$Label Linux $($case.Name) execution" 30000
    $run.Refresh()
    if ($run.ExitCode -ne 0) {
        throw "$Label Linux $($case.Name) exited $($run.ExitCode): $([IO.File]::ReadAllText($runError))"
    }
    $actual = [IO.File]::ReadAllText($runOutput).Replace("`r`n", "`n").Trim()
    if ($actual -cne $case.Expected) {
        throw "$Label Linux $($case.Name) output mismatch. Expected '$($case.Expected)', actual '$actual'"
    }
    $completedCases += 1
    Write-Host "[native QUIC Endpoint ownership $completedCases/$totalCases] PASS $Label Linux $($case.Name)."
}

Write-Host "[native QUIC Endpoint ownership] PASS $Label Linux $completedCases/$totalCases partial move cleanup, two-connection routing, bidirectional multi-stream demux, and atomic configured queue limits."
