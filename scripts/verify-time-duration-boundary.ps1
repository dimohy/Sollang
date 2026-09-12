[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Compiler = "",
    [string]$Llvm = "",
    [string]$ResultPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
. (Join-Path $PSScriptRoot "verification-process.ps1")
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $root "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($Llvm)) {
    $Llvm = Join-Path $root ".tools\llvm-22.1.8"
}
$compilerPath = [System.IO.Path]::GetFullPath($Compiler)
$llvmPath = [System.IO.Path]::GetFullPath($Llvm)
$contractPath = Join-Path $root "scripts\contracts\time-duration-boundary.json"
$schemaPath = Join-Path $root "scripts\contracts\time-duration-boundary.schema.json"
$timePath = Join-Path $root "stdlib\std\time.slg"
foreach ($path in @($compilerPath, $contractPath, $schemaPath, $timePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "time Duration boundary input is missing: $path"
    }
}
if (-not (Test-Path -LiteralPath $llvmPath -PathType Container)) {
    throw "time Duration boundary LLVM root is missing: $llvmPath"
}

function Assert-ExactArray {
    param(
        [Parameter(Mandatory)][object[]]$Actual,
        [Parameter(Mandatory)][string[]]$Expected,
        [Parameter(Mandatory)][string]$Label
    )
    if ($Actual.Count -ne $Expected.Count) {
        throw "$Label count drifted: expected $($Expected.Count), actual $($Actual.Count)"
    }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ([string]$Actual[$index] -cne $Expected[$index]) {
            throw "$Label drifted at index $index"
        }
    }
}

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Path]::GetRelativePath($root, $Path).Replace('\', '/')
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "time Duration boundary contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
Assert-ExactArray -Actual @($contract.authoritativeFactories) `
    -Expected @("milliseconds", "seconds", "minutes", "hours") `
    -Label "authoritative Duration factories"
Assert-ExactArray -Actual @($contract.canonicalRfc3339Bytes) `
    -Expected @("-", "-", "T", ":", ":", ".", "Z") `
    -Label "canonical RFC 3339 bytes"
if ($contract.platformContract.authoritativeTotal -ne 30 -or
    $contract.platformContract.windows.total -ne 13 -or
    $contract.platformContract.linux.total -ne 11 -or
    $contract.platformContract.browser.total -ne 6 -or
    (@($contract.platformContract.optimizations) -join ',') -cne 'O0,O2' -or
    @($contract.platformContract.unsupported).Count -ne 0 -or
    @($contract.platformContract.blockers).Count -ne 4) {
    throw "time platform authority drifted"
}

$expectedInventory = @(
    "stdlib/std/time.slg|17|declaring-module",
    "examples/regression/260-selfhost-async-timer-plan.slg|1|embedded-declaring-module",
    "examples/regression/diagnostics/time-duration-private-construction.slg|1|intentional-external-forgery"
)
$actualInventoryContract = @($contract.directConstructionInventory | ForEach-Object {
    "$($_.path)|$($_.count)|$($_.classification)"
})
Assert-ExactArray -Actual $actualInventoryContract -Expected $expectedInventory `
    -Label "direct Duration construction contract"

$expectedHashes = [ordered]@{
    "stdlib/std/time.slg" = "04f29fbb75611b4d3256d9136edf4111321d3365c7f8b632fd8f9d6effbd5e07"
    "examples/regression/1062-time-values-and-injectable-clock.slg" = "7aed8302249e4b133d6dd8877a884678779df184b8520c9b31cf13f145f4a42e"
    "examples/regression/259-async-nonblocking-timer.slg" = "ce690381f9191c02332eb9c5d6c3c618f4dd1814ee9d26cd13a76dbdd6500a05"
    "examples/regression/1390-browser-time-domain-separation.slg" = "a470852aba5f6d43de081006661073f09ae780cc8384a56aeb61280f8c9ea939"
    "examples/regression/1695-time-affine-periodic-timer.slg" = "db2fa799826047e8b65295253f06cc21def5a89be8263c921170374d42a2689e"
    "examples/regression/1716-process-child-try-wait.slg" = "d0bc7f12f892d372904edb40a00448d20f8ff2dfe5266d353d7749360e9a6c52"
    "examples/regression/1717-process-child-exit-259.windows-x64.slg" = "93ecfcbf20148d7eb13fb82e16a9fd34e28fb1a4c80be739e2c9b432e5ee001a"
    "examples/regression/1737-process-child-kill.slg" = "aae89be960d7e510ab1aff9b7ed911b9578593b27788ac8350905e9a875f73ae"
    "examples/regression/260-selfhost-async-timer-plan.slg" = "89fe4166782e1e979457d3bff3a1513dc7514ae8e318ee7e4ed0b24747ffae2d"
    "examples/regression/diagnostics/time-duration-private-construction.slg" = "2ab357a6d7fdc5e15846d2114fc6035fe49a8b637cfc7fcb295680d57a35e856"
    "examples/regression/expected/1062-time-values-and-injectable-clock.stdout.txt" = "8613cb6fb70de5d9168a475263b56f9a2537ad27ad97ffd117cc822ad0005913"
    "examples/regression/expected/1390-browser-time-domain-separation.stdout.txt" = "f066293dffce0a0acd3383c1616143cd59b0b6beee68959fd661458c6ec43514"
    "examples/regression/expected/259-async-nonblocking-timer.stdout.txt" = "e39523ca712cf80b8fb3275c3f296c8bf4a15b2dd8190c711fd40cc289b404bb"
    "examples/regression/expected/1695-time-affine-periodic-timer.stdout.txt" = "b301954e1b63e845b4dfe7569af4f3043e9c740958e42f00f111bf121c658d2d"
    "examples/regression/expected/1716-process-child-try-wait.stdout.txt" = "6ed03ebafdfb12057769ce9cb0d389edf66c0502ca41a4fa97a2e09f4b04bb24"
    "examples/regression/expected/1717-process-child-exit-259.stdout.txt" = "5dd6c46f615b5143478f16fdb14a0d1852c68920f4a1ac731b9c2a1b6fd80ab8"
    "examples/regression/expected/1737-process-child-kill.stdout.txt" = "251e7b4c20959b0de6fc132ad9c98be7626a64d692851b74e7da1ee1b31d97b2"
}
$contractHashes = [ordered]@{}
foreach ($entry in $contract.trackedInputs) {
    if ($contractHashes.Contains($entry.path)) { throw "duplicate tracked input: $($entry.path)" }
    $contractHashes[$entry.path] = $entry.sha256
}
Assert-ExactArray -Actual @($contractHashes.Keys) -Expected @($expectedHashes.Keys) `
    -Label "tracked input paths"
$startHashes = [ordered]@{}
foreach ($relativePath in $expectedHashes.Keys) {
    if ($contractHashes[$relativePath] -cne $expectedHashes[$relativePath]) {
        throw "tracked hash contract drifted: $relativePath"
    }
    $absolutePath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "tracked time input is missing: $relativePath"
    }
    $startHashes[$relativePath] = Get-Sha256 $absolutePath
    if ($startHashes[$relativePath] -cne $expectedHashes[$relativePath]) {
        throw "tracked time input hash drifted: $relativePath"
    }
}

$sourceRoots = @("stdlib", "selfhost", "syntax", "examples", "scripts\probes", "scripts\contracts\fixtures")
$constructionCounts = [ordered]@{}
foreach ($sourceRoot in $sourceRoots) {
    $absoluteRoot = Join-Path $root $sourceRoot
    if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) { continue }
    $files = @(Get-ChildItem -LiteralPath $absoluteRoot -Recurse -File -Filter "*.slg" |
        Sort-Object -Property FullName)
    foreach ($file in $files) {
        $source = [System.IO.File]::ReadAllText($file.FullName)
        $constructionPattern = '(?ms)^(?![^\r\n]*\bstruct[ \t]+Duration[ \t]*\{)[^\r\n]*\bDuration[ \t]*\{[ \t\r\n]*millis[ \t]*:'
        $count = [regex]::Matches($source, $constructionPattern).Count
        if ($count -gt 0) { $constructionCounts[(Get-RelativePath $file.FullName)] = $count }
    }
}
$actualInventory = @($constructionCounts.Keys | ForEach-Object { "$_|$($constructionCounts[$_])" })
$expectedInventoryCounts = @($contract.directConstructionInventory | ForEach-Object { "$($_.path)|$($_.count)" })
Assert-ExactArray -Actual $actualInventory -Expected $expectedInventoryCounts `
    -Label "repository-wide direct Duration construction inventory"

$timeSource = [System.IO.File]::ReadAllText($timePath)
if ($timeSource -notmatch 'public struct Duration\s*\{\s*millis: Long\s*\}') {
    throw "Duration.millis must remain module-private"
}
if ($timeSource -match 'public\s+millis:\s*Long') {
    throw "Duration.millis became publicly forgeable"
}
foreach ($factory in @("milliseconds", "seconds", "minutes", "hours")) {
    if ($timeSource -notmatch "public $factory value: Long -> Result<Duration, Error>") {
        throw "authoritative Duration factory is missing: $factory"
    }
}
$canonicalWrites = @("'-' => output[4]", "'-' => output[7]", "'T' => output[10]", "':' => output[13]", "':' => output[16]", "'.' => output[19]", "'Z' => output[23]")
$numericWrites = @("45 => output[4]", "45 => output[7]", "84 => output[10]", "58 => output[13]", "58 => output[16]", "46 => output[19]", "90 => output[23]")
foreach ($write in $canonicalWrites) {
    if (-not $timeSource.Contains($write, [System.StringComparison]::Ordinal)) {
        throw "canonical RFC 3339 byte write is missing: $write"
    }
}
foreach ($write in $numericWrites) {
    if ($timeSource.Contains($write, [System.StringComparison]::Ordinal)) {
        throw "numeric RFC 3339 ASCII write returned: $write"
    }
}

$managed = [System.IO.Path]::GetExtension($compilerPath) -ceq ".dll"
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-time-duration-" + [Guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($scratch) | Out-Null
try {
    $positiveCases = @(
        [ordered]@{ source = "examples/regression/1062-time-values-and-injectable-clock.slg"; expected = "examples/regression/expected/1062-time-values-and-injectable-clock.stdout.txt" },
        [ordered]@{ source = "examples/regression/259-async-nonblocking-timer.slg"; expected = "examples/regression/expected/259-async-nonblocking-timer.stdout.txt" },
        [ordered]@{ source = "examples/regression/1695-time-affine-periodic-timer.slg"; expected = "examples/regression/expected/1695-time-affine-periodic-timer.stdout.txt" },
        [ordered]@{ source = "examples/regression/1716-process-child-try-wait.slg"; expected = "examples/regression/expected/1716-process-child-try-wait.stdout.txt" },
        [ordered]@{ source = "examples/regression/1717-process-child-exit-259.windows-x64.slg"; expected = "examples/regression/expected/1717-process-child-exit-259.stdout.txt" },
        [ordered]@{ source = "examples/regression/1737-process-child-kill.slg"; expected = "examples/regression/expected/1737-process-child-kill.stdout.txt" }
    )
    $completed = 0
    foreach ($case in $positiveCases) {
        $relativePath = $case.source
        $outputPath = Join-Path $scratch (([System.IO.Path]::GetFileNameWithoutExtension($relativePath)) + ".exe")
        $arguments = @("build", (Join-Path $root $relativePath), "--target", "windows-x64", "--llvm", $llvmPath, "-o", $outputPath)
        if ($managed) { & dotnet $compilerPath @arguments } else { & $compilerPath @arguments }
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw "managed positive Duration boundary build failed: $relativePath"
        }
        $result = Invoke-VerificationProcessCapture `
            -FilePath $outputPath `
            -Description "time Duration exact execution $relativePath" `
            -TimeoutMilliseconds 20000
        $expectedOutput = [System.IO.File]::ReadAllText((Join-Path $root $case.expected)).Replace("`r`n", "`n")
        $actualOutput = $result.Stdout.Replace("`r`n", "`n")
        if ($result.ExitCode -ne 0 -or $result.Stderr.Length -ne 0 -or $actualOutput -cne $expectedOutput) {
            throw "managed positive Duration boundary output drifted: $relativePath`nstdout:`n$($result.Stdout)`nstderr:`n$($result.Stderr)"
        }
        $completed += 1
        Write-Host "[time Duration boundary managed $completed/7] PASS build and exact run $relativePath"
    }

    $negativePath = Join-Path $root "examples\regression\diagnostics\time-duration-private-construction.slg"
    $negativeOutput = Join-Path $scratch "forgery.exe"
    $negativeArguments = @("build", $negativePath, "--target", "windows-x64", "--llvm", $llvmPath, "-o", $negativeOutput)
    $negativeText = if ($managed) {
        (& dotnet $compilerPath @negativeArguments 2>&1 | Out-String)
    } else {
        (& $compilerPath @negativeArguments 2>&1 | Out-String)
    }
    $negativeExitCode = $LASTEXITCODE
    $expectedDiagnostic = "sollang: semantic error at 4:5: [module '<main>'] cannot construct struct 'std.time.Duration' outside module 'std.time' because field 'millis' is private; use its public factory or public instance methods"
    if ($negativeExitCode -ne 1 -or
        [regex]::Matches($negativeText, [regex]::Escape($expectedDiagnostic)).Count -ne 1 -or
        $negativeText -match '(?m)^target (datalayout|triple)' -or
        (Test-Path -LiteralPath $negativeOutput)) {
        throw "Duration forgery did not fail exactly once before LLVM.`n$negativeText"
    }
    Write-Host "[time Duration boundary managed 7/7] PASS intentional external forgery rejected before LLVM"
} finally {
    if (Test-Path -LiteralPath $scratch) {
        [System.IO.Directory]::Delete($scratch, $true)
    }
}

foreach ($relativePath in $startHashes.Keys) {
    if ((Get-Sha256 (Join-Path $root $relativePath)) -cne $startHashes[$relativePath]) {
        throw "tracked time input changed during verification: $relativePath"
    }
}

if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    $absoluteResultPath = [System.IO.Path]::GetFullPath($ResultPath, $root)
    $resultDirectory = Split-Path -Parent $absoluteResultPath
    [System.IO.Directory]::CreateDirectory($resultDirectory) | Out-Null
    $result = [ordered]@{
        contract = "time-duration-boundary"
        status = "passed"
        completedCases = 7
        totalCases = 7
        failureIds = @()
        directConstructionCount = 19
        directConstructionFiles = 3
        trackedInputCount = 17
        trackedInputHashes = $startHashes
        authoritativeFactoryCount = 4
        canonicalRfc3339ByteCount = 7
        pending = @("selfhost", "Stage2", "Stage3")
    }
    $temporaryResultPath = "$absoluteResultPath.tmp"
    [System.IO.File]::WriteAllText(
        $temporaryResultPath,
        (($result | ConvertTo-Json -Depth 5) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($temporaryResultPath, $absoluteResultPath, $true)
}

Write-Host "[time Duration boundary] PASS exact 19-construction inventory (17 internal, 1 embedded internal, 1 rejected forgery), 17/17 hashes, 4/4 factories, 7/7 canonical RFC 3339 bytes, and 7/7 managed cases (6 exact runs plus 1 pre-LLVM rejection)."
