[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 16)][int]$Jobs = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$compiler = (Resolve-Path -LiteralPath $Compiler).Path
$compilerHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$llvmRoot = (Resolve-Path -LiteralPath (Join-Path $root '.tools/llvm-22.1.8')).Path
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clang = Join-Path $llvmRoot 'bin/clang.exe'
$stdlib = (Resolve-Path -LiteralPath (Join-Path $root 'stdlib')).Path
$probeName = 'terminal-subject-when-all-return'
$fixtureNames = @(
    $probeName,
    '1352-selfhost-consuming-call-owned-outcome',
    '1361-selfhost-nested-all-return-control',
    '1382-selfhost-terminal-flow-control-return',
    '1381-selfhost-terminal-return-only-if',
    '1379-selfhost-nested-control-implicit-return',
    '1380-selfhost-final-binding-return-selection',
    '1214-gzip-transactional-streaming-decoder',
    '1215-gzip-incremental-byte-boundaries'
)
$levels = @('O0', 'O2')
$total = $fixtureNames.Count * $levels.Count
$completed = 0
$failureIds = [Collections.Generic.List[string]]::new()
$caseResults = [Collections.Generic.List[object]]::new()

$cases = @($fixtureNames | ForEach-Object {
    $name = $_
    $source = if ($name -ceq $probeName) {
        Join-Path $root 'scripts/probes/gzip-stream-api/terminal-subject-when-all-return.slg'
    } else {
        Join-Path $root "examples/regression/$name.slg"
    }
    $expected = if ($name -ceq $probeName) { $null } else {
        Join-Path $root "examples/regression/expected/$name.stdout.txt"
    }
    [pscustomobject]@{ Name = $name; Source = $source; Expected = $expected }
})

$compilerManifest = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$compilerSources = @(Get-Content -LiteralPath $compilerManifest |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $root $_.Trim() })
$inputPaths = @(
    $compiler,
    $compilerManifest,
    (Join-Path $PSScriptRoot 'verify-c435-optimization-matrix.ps1'),
    (Join-Path $PSScriptRoot 'verify-c435-terminal-control.ps1'),
    (Join-Path $PSScriptRoot 'verification-process.ps1'),
    (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
    (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'),
    (Join-Path $PSScriptRoot 'contracts/c435-terminal-control.json'),
    (Join-Path $PSScriptRoot 'contracts/c435-terminal-control.schema.json'),
    $llvmAs,
    $clang
) + $compilerSources + @(Get-NativeExactOrderedSourceClosure -Root $stdlib) +
    @($cases | ForEach-Object { $_.Source; if ($null -ne $_.Expected) { $_.Expected } })
foreach ($path in $inputPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "C435 matrix input is missing: $path"
    }
}
$settings = [ordered]@{
    compilerSha256 = $compilerHash
    jobs = $Jobs.ToString([Globalization.CultureInfo]::InvariantCulture)
    optimizationLevels = 'O0,O2'
    target = 'windows-x64'
}
function Get-CurrentInputFingerprint {
    Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath $inputPaths
}
$inputFingerprint = Get-CurrentInputFingerprint

function Save-Result([string]$Status, [int]$ExitCode) {
    $endFingerprint = Get-CurrentInputFingerprint
    if ($endFingerprint -cne $inputFingerprint -and -not $failureIds.Contains('C435_INPUT_DRIFT')) {
        $failureIds.Add('C435_INPUT_DRIFT')
        $Status = 'failed'
        $ExitCode = 1
    }
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-13-435'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        inputFingerprint = $inputFingerprint
        finalInputFingerprint = $endFingerprint
        inputsStable = $inputFingerprint -ceq $endFingerprint
        compilerSha256 = $compilerHash
        results = @($caseResults)
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"),
        [Text.UTF8Encoding]::new($false))
}

function Invoke-Logged([string]$File, [string[]]$Arguments, [string]$Description,
    [string]$LogPath, [int]$TimeoutMilliseconds = 600000) {
    $result = Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments `
        -Description $Description -TimeoutMilliseconds $TimeoutMilliseconds
    [IO.File]::WriteAllText($LogPath,
        "exitCode=$($result.ExitCode)`nstdout:`n$($result.Stdout)`nstderr:`n$($result.Stderr)",
        [Text.UTF8Encoding]::new($false))
    $result
}

try {
    & (Join-Path $PSScriptRoot 'verify-c435-terminal-control.ps1') -RepositoryRoot $root
    if (-not $?) { throw 'C435 static authority failed' }
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check `
        -Source (Join-Path $root 'selfhost/llvm/text/control.slg')
    if (-not $?) { throw 'C435 source format failed' }

    foreach ($level in $levels) {
        foreach ($case in $cases) {
            $caseId = "$($case.Name)-$level"
            $exe = Join-Path $output "$caseId.exe"
            $llvm = "$exe.ll"
            $bitcode = "$exe.bc"
            $build = Invoke-Logged $compiler @('build', $case.Source, '-o', $exe,
                '--target', 'windows-x64', '--llvm', $llvmRoot, '--stdlib', $stdlib,
                '--jobs', $Jobs.ToString([Globalization.CultureInfo]::InvariantCulture),
                "-$level", '--keep-temps') "C435 $caseId build" `
                (Join-Path $output "$caseId.build.txt")
            if ($build.ExitCode -ne 0 -or
                [regex]::IsMatch(($build.Stdout + $build.Stderr), '(?m)^(?:warning S\d+|note N\d+)\b') -or
                -not (Test-Path -LiteralPath $llvm -PathType Leaf) -or
                -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
                $failureIds.Add("C435_BUILD_$caseId")
                throw "C435 $caseId build failed or emitted a warning/note"
            }
            & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $llvm
            if ($LASTEXITCODE -ne 0) {
                $failureIds.Add("C435_V004_$caseId")
                throw "C435 $caseId direct-call closure failed"
            }
            $assembly = Invoke-Logged $llvmAs @($llvm, '-o', $bitcode) `
                "C435 $caseId llvm-as" (Join-Path $output "$caseId.llvm-as.txt")
            if ($assembly.ExitCode -ne 0) {
                $failureIds.Add("C435_LLVM_AS_$caseId")
                throw "C435 $caseId LLVM assembly failed"
            }
            $run = Invoke-Logged $exe @() "C435 $caseId exact execution" `
                (Join-Path $output "$caseId.run.txt")
            $actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
            $expected = if ($null -eq $case.Expected) { '7' } else {
                [IO.File]::ReadAllText($case.Expected).Replace("`r`n", "`n").TrimEnd("`n")
            }
            if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0 -or $actual -cne $expected) {
                $failureIds.Add("C435_EXACT_$caseId")
                throw "C435 $caseId exact execution differed"
            }
            $caseResults.Add([pscustomobject]@{
                name = $case.Name
                optimization = $level
                llvmSha256 = (Get-FileHash -LiteralPath $llvm -Algorithm SHA256).Hash
                executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
                status = 'passed'
            })
            $completed++
            Write-Host "[C435 matrix $completed/$total] PASS $caseId."
        }
    }
    if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -cne $compilerHash) {
        $failureIds.Add('C435_COMPILER_DRIFT')
        throw 'C435 compiler changed during verification'
    }
    Save-Result 'passed' 0
    $record = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($record.status -cne 'passed') { throw 'C435 inputs changed during verification' }
    Write-Host "[C435 matrix] PASS $completed/$total O0/O2 native exact cases."
} catch {
    if ($failureIds.Count -eq 0) { $failureIds.Add('C435_MATRIX_FAILED') }
    Save-Result 'failed' 1
    throw
}
