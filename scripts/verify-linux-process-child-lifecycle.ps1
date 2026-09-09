param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,
    [Parameter(Mandatory = $true)]
    [string]$Label,
    [Parameter(Mandatory = $true)]
    [string]$Distribution,
    [Parameter(Mandatory = $true)]
    [string]$LlvmHome,
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

function Convert-ToProcessLifecycleWslPath {
    param([string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmAsPath = Join-Path $LlvmHome "bin\llvm-as.exe"
$sourcePath = Join-Path $RepositoryRoot "examples\regression\1132-process-child-wait.slg"
$executablePath = Join-Path $OutputDirectory "$Label-check-process-child-wait"
$llvmPath = $executablePath + ".ll"
$bitcodePath = $executablePath + ".bc"
$buildOutputPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.build.stdout.txt"
$buildErrorPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.build.stderr.txt"
$runOutputPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.stdout.txt"
$runErrorPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.stderr.txt"

function Wait-LinuxProcessLifecycleStep {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutMilliseconds,
        [string]$Description
    )

    Wait-VerificationProcess $Process $Description $TimeoutMilliseconds
    $Process.Refresh()
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Remove-Item -LiteralPath $executablePath, $llvmPath, $bitcodePath, $buildOutputPath, $buildErrorPath, $runOutputPath, $runErrorPath -ErrorAction SilentlyContinue

$build = Start-Process `
    -FilePath "wsl.exe" `
    -ArgumentList @(
        "-d", $Distribution, "--", (Convert-ToProcessLifecycleWslPath $compilerPath),
        "build", (Convert-ToProcessLifecycleWslPath $sourcePath),
        "-o", (Convert-ToProcessLifecycleWslPath $executablePath),
        "--target", "linux-x64",
        "--stdlib", (Convert-ToProcessLifecycleWslPath $StdlibRoot),
        "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        "-O1", "--keep-temps") `
    -RedirectStandardOutput $buildOutputPath `
    -RedirectStandardError $buildErrorPath `
    -WindowStyle Hidden `
    -PassThru
Wait-LinuxProcessLifecycleStep $build 180000 "$Label Linux process Child lifecycle build"
if ($build.ExitCode -ne 0) {
    $details = [System.IO.File]::ReadAllText($buildErrorPath)
    throw "$Label Linux process Child lifecycle build failed with exit code $($build.ExitCode).`n$details"
}
$buildDiagnostics = [System.IO.File]::ReadAllText($buildOutputPath) + [System.IO.File]::ReadAllText($buildErrorPath)
if ($buildDiagnostics -match '(?m)^(?:warning S\d+|note N\d+)\b') {
    throw "$Label Linux process Child lifecycle build emitted a compiler warning or note.`n$buildDiagnostics"
}
if (-not (Test-Path -LiteralPath $llvmPath) -or -not (Test-Path -LiteralPath $executablePath)) {
    throw "$Label Linux process Child lifecycle build did not produce both LLVM and executable artifacts"
}

& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $llvmPath
& (Join-Path $PSScriptRoot "verify-process-child-drop-once.ps1") -LlvmPath $llvmPath
& $llvmAsPath $llvmPath -o $bitcodePath
if ($LASTEXITCODE -ne 0) {
    throw "$Label Linux process Child lifecycle LLVM assembly failed"
}

$run = Start-Process `
    -FilePath "wsl.exe" `
    -ArgumentList @("-d", $Distribution, "--", (Convert-ToProcessLifecycleWslPath $executablePath)) `
    -RedirectStandardOutput $runOutputPath `
    -RedirectStandardError $runErrorPath `
    -WindowStyle Hidden `
    -PassThru
Wait-LinuxProcessLifecycleStep $run 30000 "$Label Linux process Child lifecycle execution"
if ($run.ExitCode -ne 0) {
    $details = [System.IO.File]::ReadAllText($runErrorPath)
    throw "$Label Linux process Child lifecycle execution failed with exit code $($run.ExitCode).`n$details"
}
$actual = [System.IO.File]::ReadAllText($runOutputPath).Replace("`r`n", "`n").TrimEnd("`n")
$expected = "child`nid true`nwait 0"
if ($actual -cne $expected) {
    throw "$Label Linux process Child lifecycle output differed. Expected '$expected', actual '$actual'"
}

Write-Host "PASS $Label Linux process Child spawn/wait/drop lifecycle."
