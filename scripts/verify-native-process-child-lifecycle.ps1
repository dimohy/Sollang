param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,
    [Parameter(Mandatory = $true)]
    [string]$Label,
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

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmAsPath = Join-Path $LlvmHome "bin\llvm-as.exe"
$sourcePath = Join-Path $RepositoryRoot "examples\regression\1132-process-child-wait.slg"
$executablePath = Join-Path $OutputDirectory "$Label-check-process-child-wait.exe"
$llvmPath = $executablePath + ".ll"
$bitcodePath = [System.IO.Path]::ChangeExtension($executablePath, ".bc")
$buildOutputPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.build.stdout.txt"
$buildErrorPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.build.stderr.txt"
$runOutputPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.stdout.txt"
$runErrorPath = Join-Path $OutputDirectory "$Label-check-process-child-wait.stderr.txt"

function Wait-ProcessLifecycleStep {
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
    -FilePath $compilerPath `
    -ArgumentList @(
        "build", $sourcePath,
        "-o", $executablePath,
        "--target", "windows-x64",
        "--llvm", $LlvmHome,
        "--stdlib", $StdlibRoot,
        "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        "-O1", "--keep-temps") `
    -RedirectStandardOutput $buildOutputPath `
    -RedirectStandardError $buildErrorPath `
    -WindowStyle Hidden `
    -PassThru
Wait-ProcessLifecycleStep $build 180000 "$Label process Child lifecycle build"
if ($build.ExitCode -ne 0) {
    $details = [System.IO.File]::ReadAllText($buildErrorPath)
    throw "$Label process Child lifecycle build failed with exit code $($build.ExitCode).`n$details"
}
$buildDiagnostics = [System.IO.File]::ReadAllText($buildOutputPath) + [System.IO.File]::ReadAllText($buildErrorPath)
if ($buildDiagnostics -match '(?m)^(?:warning S\d+|note N\d+)\b') {
    throw "$Label process Child lifecycle build emitted a compiler warning or note.`n$buildDiagnostics"
}
if (-not (Test-Path -LiteralPath $llvmPath) -or -not (Test-Path -LiteralPath $executablePath)) {
    throw "$Label process Child lifecycle build did not produce both LLVM and executable artifacts"
}

& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $llvmPath
& (Join-Path $PSScriptRoot "verify-process-child-drop-once.ps1") -LlvmPath $llvmPath
& $llvmAsPath $llvmPath -o $bitcodePath
if ($LASTEXITCODE -ne 0) {
    throw "$Label process Child lifecycle LLVM assembly failed"
}

$run = Start-Process `
    -FilePath $executablePath `
    -RedirectStandardOutput $runOutputPath `
    -RedirectStandardError $runErrorPath `
    -WindowStyle Hidden `
    -PassThru
Wait-ProcessLifecycleStep $run 30000 "$Label process Child lifecycle execution"
if ($run.ExitCode -ne 0) {
    $details = [System.IO.File]::ReadAllText($runErrorPath)
    throw "$Label process Child lifecycle execution failed with exit code $($run.ExitCode).`n$details"
}
$actual = [System.IO.File]::ReadAllText($runOutputPath).Replace("`r`n", "`n").TrimEnd("`n")
$expected = "child`nid true`nwait 0"
if ($actual -cne $expected) {
    throw "$Label process Child lifecycle output differed. Expected '$expected', actual '$actual'"
}

Write-Host "PASS $Label process Child spawn/wait/drop lifecycle."
