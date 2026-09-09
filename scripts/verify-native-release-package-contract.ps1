$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "native-release-package.ps1")

$systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path `
    $systemTemporaryRoot `
    ("sollang-native-release-contract-" + [guid]::NewGuid().ToString("N"))))
if (-not $temporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Native release contract escaped the OS temporary directory: $temporaryRoot"
}

try {
    $repositoryRoot = Join-Path $temporaryRoot "repo"
    $outputRoot = Join-Path $temporaryRoot "output\0.4.0"
    $stdlibIo = Join-Path $repositoryRoot "stdlib\sys\io.slg"
    $windowsCompiler = Join-Path $repositoryRoot "synthetic\selfhost-stage3.exe"
    $linuxCompiler = Join-Path $repositoryRoot "synthetic\selfhost-stage3-linux"
    New-Item -ItemType Directory -Force -Path `
        (Split-Path -Parent $stdlibIo), `
        (Split-Path -Parent $windowsCompiler), `
        $outputRoot | Out-Null
    [System.IO.File]::WriteAllText($stdlibIo, "module sys.io`n")
    [System.IO.File]::WriteAllText((Join-Path $repositoryRoot "README.md"), "synthetic readme`n")
    [System.IO.File]::WriteAllText((Join-Path $repositoryRoot "LICENSE"), "synthetic license`n")
    [System.IO.File]::WriteAllBytes($windowsCompiler, [byte[]](1, 2, 3, 4))
    [System.IO.File]::WriteAllBytes($linuxCompiler, [byte[]](5, 6, 7, 8))

    $unownedSentinel = Join-Path $outputRoot "keep-unowned.txt"
    $repositorySentinel = Join-Path $repositoryRoot "keep-repository.txt"
    [System.IO.File]::WriteAllText($unownedSentinel, "keep")
    [System.IO.File]::WriteAllText($repositorySentinel, "keep")
    New-Item -ItemType Directory -Force -Path (Join-Path $outputRoot "staging") | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $outputRoot "staging\stale.txt"), "stale")

    $result = Invoke-NativeReleasePackaging `
        -RepositoryRoot $repositoryRoot `
        -Version "0.4.0" `
        -OutputRoot $outputRoot `
        -WindowsStage3Path $windowsCompiler `
        -LinuxStage3Path $linuxCompiler `
        -DryRun

    foreach ($path in @($result.WindowsArchive, $result.LinuxArchive, $result.ChecksumPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Native release dry-run did not create expected output: $path"
        }
    }
    if ((Get-Content -LiteralPath $result.ChecksumPath).Count -ne 2) {
        throw "Native release dry-run checksum manifest must contain exactly two archives"
    }
    if (-not (Test-Path -LiteralPath $unownedSentinel -PathType Leaf)) {
        throw "Native release dry-run removed an unowned output-root sentinel"
    }
    if (-not (Test-Path -LiteralPath $repositorySentinel -PathType Leaf)) {
        throw "Native release dry-run removed a repository sentinel"
    }
    if (Test-Path -LiteralPath (Join-Path $outputRoot "staging\stale.txt")) {
        throw "Native release dry-run retained stale owned staging content"
    }

    $expandedZip = Join-Path $temporaryRoot "expanded-zip"
    Expand-Archive -LiteralPath $result.WindowsArchive -DestinationPath $expandedZip
    if (-not (Test-Path -LiteralPath (Join-Path $expandedZip "sollang-0.4.0-windows-x64\sollang.exe"))) {
        throw "Native release dry-run Windows archive omitted the compiler"
    }
    $tarEntries = & tar -tzf $result.LinuxArchive
    if ($LASTEXITCODE -ne 0 -or -not ($tarEntries -contains "sollang-0.4.0-linux-x64/sollang")) {
        throw "Native release dry-run Linux archive omitted the compiler"
    }

    foreach ($broadRoot in @($repositoryRoot, [System.IO.Path]::GetPathRoot($temporaryRoot))) {
        $rejected = $false
        try {
            Invoke-NativeReleasePackaging `
                -RepositoryRoot $repositoryRoot `
                -Version "0.4.0" `
                -OutputRoot $broadRoot `
                -WindowsStage3Path $windowsCompiler `
                -LinuxStage3Path $linuxCompiler `
                -DryRun | Out-Null
        } catch {
            $rejected = $true
        }
        if (-not $rejected) {
            throw "Native release dry-run accepted broad output root: $broadRoot"
        }
        if (-not (Test-Path -LiteralPath $repositorySentinel -PathType Leaf)) {
            throw "Broad-root negative control changed repository content: $broadRoot"
        }
    }

    Write-Host "[native release package contract] PASS two-platform dry-run, archive contents, unowned sentinel, and broad-root negative controls."
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
