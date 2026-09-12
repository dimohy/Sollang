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
    $OutputDirectory = Join-Path $scratchRoot ("uri-normalization-targets-" + [guid]::NewGuid().ToString("N"))
}
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $outputRoot.StartsWith($scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "URI target output must be a child of artifacts/scratch: $outputRoot"
}
if (Test-Path -LiteralPath $outputRoot) {
    if (-not (Test-Path -LiteralPath $outputRoot -PathType Container) -or @(Get-ChildItem -LiteralPath $outputRoot -Force).Count -ne 0) {
        throw "URI target output must be a new or empty directory: $outputRoot"
    }
}
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$resolvedOutputRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $outputRoot).Path)
if (-not $resolvedOutputRoot.StartsWith($scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "URI target resolved output escaped artifacts/scratch: $resolvedOutputRoot"
}

$compilerPath = Join-Path $root "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$llvmRoot = Join-Path $root ".tools\llvm-22.1.8"
$browserRunner = Join-Path $root "scripts\verify-uri-browser-program.mjs"
$contractVerifier = Join-Path $root "scripts\verify-uri-normalization-contract.ps1"
$dotnetPath = (Get-Command dotnet -CommandType Application -ErrorAction Stop).Source
$pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
$nodePath = (Get-Command node -ErrorAction Stop).Source
$wslPath = (Get-Command wsl.exe -ErrorAction Stop).Source
$clangPath = Join-Path $llvmRoot "bin\clang.exe"
foreach ($path in @($compilerPath, $browserRunner, $contractVerifier, $dotnetPath, $pwshPath, $nodePath, $wslPath, $clangPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "URI target verifier input is missing: $path"
    }
}

$fixtures = @(
    "1031-uri-percent-codec",
    "1032-uri-reference-authority",
    "1697-uri-normalization-policy",
    "1698-uri-resolution-boundaries"
)
$inputPaths = [Collections.Generic.List[string]]::new()
foreach ($relative in @(
    "stdlib/std/uri.slg",
    "stdlib/std/uri/error.slg",
    "stdlib/std/uri/percent.slg",
    "stdlib/std/uri/percent/error.slg",
    "stdlib/std/uri/percent/types.slg",
    "scripts/contracts/uri-normalization.json",
    "scripts/verify-uri-normalization-contract.ps1",
    "scripts/verify-uri-normalization-targets.ps1",
    "scripts/verify-uri-browser-program.mjs")) {
    $inputPaths.Add((Join-Path $root $relative))
}
foreach ($toolPath in @($compilerPath, $dotnetPath, $pwshPath, $nodePath, $wslPath, $clangPath)) {
    $inputPaths.Add([IO.Path]::GetFullPath($toolPath))
}
foreach ($fixture in $fixtures) {
    $inputPaths.Add((Join-Path $root "examples\regression\$fixture.slg"))
    $inputPaths.Add((Join-Path $root "examples\regression\expected\$fixture.stdout.txt"))
}
foreach ($path in $inputPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "URI target verifier input is missing: $path"
    }
}

function Get-InputHashes {
    $hashes = [ordered]@{}
    foreach ($path in $inputPaths) {
        $full = [IO.Path]::GetFullPath($path)
        $key = if ($full.StartsWith($root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            [IO.Path]::GetRelativePath($root, $full).Replace([char]92, [char]47)
        } else {
            $full.Replace([char]92, [char]47)
        }
        if ($hashes.Contains($key)) { throw "URI target verifier input identity is duplicated: $key" }
        $hashes[$key] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    }
    $hashes
}

function Get-InputHashKey {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        return [IO.Path]::GetRelativePath($root, $full).Replace([char]92, [char]47)
    }
    $full.Replace([char]92, [char]47)
}

function Normalize-ExactProgramOutput {
    param([AllowEmptyString()][string]$Text)
    $normalized = $Text.Replace("`r`n", "`n")
    if ($normalized.EndsWith("`n", [StringComparison]::Ordinal)) {
        return $normalized.Substring(0, $normalized.Length - 1)
    }
    $normalized
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
                throw "$Description timed out and its process tree did not terminate"
            }
            throw "$Description exceeded 60000ms; terminated process tree rooted at $processId"
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
        if (-not $process.HasExited) { throw "$Description returned before process $processId exited" }
        if ($exitCode -ne 0) {
            throw "$Description failed with exit code $exitCode`n$stderr$stdout"
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            throw "$Description produced stderr`n$stderr"
        }
        [pscustomobject]@{ Stdout = $stdout; Stderr = $stderr; ExitCode = $exitCode; ProcessId = $processId; HasExited = $true }
    } finally {
        $process.Dispose()
    }
}

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$WindowsPath)
    $full = [IO.Path]::GetFullPath($WindowsPath)
    "/mnt/$($full.Substring(0, 1).ToLowerInvariant())/$($full.Substring(3).Replace([char]92, [char]47))"
}

$startingHashes = Get-InputHashes
$checks = [Collections.Generic.List[object]]::new()
$expectedBrowserImports = @(
    "env:sollang_browser_alloc",
    "env:sollang_browser_realloc",
    "env:memset",
    "env:memcpy",
    "env:sollang_browser_write",
    "env:sollang_browser_panic"
)
$staticContract = Invoke-CheckedProcess -FilePath $pwshPath -ArgumentList @(
    "-NoProfile", "-File", $contractVerifier, "-RepositoryRoot", $root
) -Description "URI static contract verification"
if ($staticContract.Stdout -cnotmatch '^\[URI normalization contract\] PASS ') {
    throw "URI static contract verifier did not emit its exact PASS prefix"
}
foreach ($fixture in $fixtures) {
    $sourcePath = Join-Path $root "examples\regression\$fixture.slg"
    $expectedPath = Join-Path $root "examples\regression\expected\$fixture.stdout.txt"
    $expected = Normalize-ExactProgramOutput ([IO.File]::ReadAllText($expectedPath))
    foreach ($target in @("windows-x64", "linux-x64", "wasm32-browser")) {
        $extension = switch ($target) {
            "windows-x64" { ".exe" }
            "linux-x64" { ".linux" }
            default { ".wasm" }
        }
        $outputPath = Join-Path $outputRoot "$fixture.$target$extension"
        $compile = Invoke-CheckedProcess -FilePath $dotnetPath -ArgumentList @(
            $compilerPath, "build", $sourcePath, "-o", $outputPath,
            "--target", $target, "-O0", "--llvm", $llvmRoot
        ) -Description "$fixture $target managed compilation"
        if ($compile.Stdout -match '(?im)^\s*(warning|note)\b') {
            throw "$fixture $target managed compilation produced a warning or note`n$($compile.Stdout)"
        }
        $compileLines = @($compile.Stdout -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $requiredCompilePrefixes = @('[frontend-cache]', '[codegen-cache]', '[semantic-cache]', '[product-cache]')
        if ($compileLines.Count -ne 5) {
            throw "$fixture $target managed compilation produced an unexpected line count: $($compileLines.Count)`n$($compile.Stdout)"
        }
        foreach ($prefix in $requiredCompilePrefixes) {
            if (@($compileLines | Where-Object { $_.StartsWith($prefix + ' ', [StringComparison]::Ordinal) }).Count -ne 1) {
                throw "$fixture $target managed compilation did not produce exactly one $prefix line`n$($compile.Stdout)"
            }
        }
        $escapedOutputPath = [regex]::Escape([IO.Path]::GetFullPath($outputPath))
        if ($compileLines[-1] -cnotmatch "^Wrote $escapedOutputPath \([1-9][0-9,]* bytes\)$") {
            throw "$fixture $target managed compilation did not end with the exact requested artifact marker`n$($compile.Stdout)"
        }

        $browserImports = @()
        if ($target -eq "windows-x64") {
            $execution = Invoke-CheckedProcess -FilePath $outputPath -ArgumentList @() -Description "$fixture Windows execution"
            $actual = Normalize-ExactProgramOutput $execution.Stdout
            if ($actual -cne $expected) { throw "$fixture Windows output differs from $expectedPath" }
        } elseif ($target -eq "linux-x64") {
            $execution = Invoke-CheckedProcess -FilePath $wslPath -ArgumentList @(
                "-d", $WslDistribution, "--", (Convert-ToWslPath $outputPath)
            ) -Description "$fixture Linux execution"
            $actual = Normalize-ExactProgramOutput $execution.Stdout
            if ($actual -cne $expected) { throw "$fixture Linux output differs from $expectedPath" }
        } else {
            $execution = Invoke-CheckedProcess -FilePath $nodePath -ArgumentList @(
                $browserRunner, $outputPath, $expectedPath
            ) -Description "$fixture browser execution"
            $browserResult = $execution.Stdout | ConvertFrom-Json
            if ($browserResult.status -cne "passed") { throw "$fixture browser runner did not report passed" }
            $browserImports = @($browserResult.imports)
            if (@($browserImports | Sort-Object -Unique).Count -ne $browserImports.Count) {
                throw "$fixture browser runner reported duplicate imports"
            }
            foreach ($browserImport in $browserImports) {
                if ($expectedBrowserImports -cnotcontains $browserImport) {
                    throw "$fixture browser runner reported an import outside the independent allowlist: $browserImport"
                }
            }
            if ($browserResult.outputBytes -isnot [long] -and $browserResult.outputBytes -isnot [int]) {
                throw "$fixture browser runner reported a non-integer output byte count"
            }
            if ($browserResult.outputBytes -lt 0 -or $browserResult.outputBytes -gt 1048576) {
                throw "$fixture browser runner output byte count escaped its bound: $($browserResult.outputBytes)"
            }
        }
        $checks.Add([ordered]@{
            fixture = $fixture
            target = $target
            status = "passed"
            outputSha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
            browserImports = $browserImports
            compilationProcessExited = $compile.HasExited
            executionProcessExited = $execution.HasExited
        })
        Write-Host "[URI target $($checks.Count)/12] PASS $fixture $target"
    }
}

$endingHashes = Get-InputHashes
foreach ($key in $startingHashes.Keys) {
    if ($startingHashes[$key] -cne $endingHashes[$key]) {
        throw "URI target verifier input changed during execution: $key"
    }
}
$result = [ordered]@{
    schemaVersion = 1
    status = "passed"
    completed = $checks.Count
    total = 12
    compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
    inputHashes = $endingHashes
    toolHashes = [ordered]@{
        compiler = [ordered]@{ path = [IO.Path]::GetFullPath($compilerPath); sha256 = $endingHashes[(Get-InputHashKey $compilerPath)] }
        dotnet = [ordered]@{ path = [IO.Path]::GetFullPath($dotnetPath); sha256 = $endingHashes[(Get-InputHashKey $dotnetPath)] }
        pwsh = [ordered]@{ path = [IO.Path]::GetFullPath($pwshPath); sha256 = $endingHashes[(Get-InputHashKey $pwshPath)] }
        node = [ordered]@{ path = [IO.Path]::GetFullPath($nodePath); sha256 = $endingHashes[(Get-InputHashKey $nodePath)] }
        wsl = [ordered]@{ path = [IO.Path]::GetFullPath($wslPath); sha256 = $endingHashes[(Get-InputHashKey $wslPath)] }
        clang = [ordered]@{ path = [IO.Path]::GetFullPath($clangPath); sha256 = $endingHashes[(Get-InputHashKey $clangPath)] }
    }
    checks = $checks
    limitations = @(
        "This is managed-compiler target execution, not rebuilt selfhost acceptance.",
        "Linux execution is under the selected WSL distribution, and browser-target execution uses a bounded Node-hosted WebAssembly ABI harness rather than a browser-engine E2E.",
        "Final accumulated Stage2/Stage3 promotion remains pending."
    )
}
$resultPath = Join-Path $outputRoot "result.json"
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "[URI managed target matrix] PASS 12/12; $resultPath"
