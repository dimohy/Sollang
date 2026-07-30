[CmdletBinding()]
param(
    [string]$Compiler,
    [string]$LlvmHome,
    [string]$StdlibRoot
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3.exe"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
if ([string]::IsNullOrWhiteSpace($StdlibRoot)) {
    $StdlibRoot = Join-Path $repoRoot "stdlib"
}
$Compiler = [IO.Path]::GetFullPath($Compiler)
$LlvmHome = [IO.Path]::GetFullPath($LlvmHome)
$StdlibRoot = [IO.Path]::GetFullPath($StdlibRoot)
$artifacts = Join-Path $repoRoot "artifacts\native-cli-build-run"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null

function Assert-ExitCode {
    param([int]$Expected, [string]$Step)
    if ($LASTEXITCODE -ne $Expected) {
        throw "$Step exited with $LASTEXITCODE; expected $Expected"
    }
}

function Assert-Output {
    param([string]$Actual, [string]$Expected, [string]$Step)
    $normalizedActual = $Actual.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
    $normalizedExpected = $Expected.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
    if ($normalizedActual -ne $normalizedExpected) {
        throw "$Step output mismatch.`nExpected:`n$Expected`nActual:`n$Actual"
    }
}

Write-Host "[native CLI 1/9] Version."
$version = (& $Compiler --version | Out-String)
Assert-ExitCode 0 "version"
Assert-Output $version "Sollang 0.4.0" "version"

Write-Host "[native CLI 2/9] Help and empty invocation status."
$help = (& $Compiler --help | Out-String)
Assert-ExitCode 0 "help"
if ($help -notmatch "usage: sollang <command> \[options\]") {
    throw "help did not contain the public usage line"
}
$emptyProcess = Start-Process -FilePath $Compiler -Wait -PassThru -NoNewWindow `
    -RedirectStandardOutput (Join-Path $artifacts "empty.stdout.txt") `
    -RedirectStandardError (Join-Path $artifacts "empty.stderr.txt")
if ($emptyProcess.ExitCode -ne 1) {
    throw "empty invocation exited with $($emptyProcess.ExitCode); expected 1"
}

Write-Host "[native CLI 3/9] Named-input source build."
$namedOutput = Join-Path $artifacts "named.exe"
& $Compiler build (Join-Path $repoRoot "examples\regression\02-function-named-input.slg") `
    -o $namedOutput --target windows-x64 --llvm $LlvmHome --stdlib $StdlibRoot -O1
Assert-ExitCode 0 "named build"
$namedRun = (& $namedOutput | Out-String)
Assert-ExitCode 0 "named executable"
Assert-Output $namedRun "Hello, dimohy. square = 49" "named executable"

Write-Host "[native CLI 4/9] Contextual-it source build."
$implicitOutput = Join-Path $artifacts "implicit.exe"
& $Compiler build (Join-Path $repoRoot "examples\regression\03-flow-call-parens.slg") `
    -o $implicitOutput --target windows-x64 --llvm $LlvmHome --stdlib $StdlibRoot -O1 --keep-temps
Assert-ExitCode 0 "contextual-it build"
$implicitRun = (& $implicitOutput | Out-String)
Assert-ExitCode 0 "contextual-it executable"
Assert-Output $implicitRun "Hello, dimohy. square = 49" "contextual-it executable"

Write-Host "[native CLI 5/9] Project-directory and explicit alternate-product builds."
$projectOutput = Join-Path $artifacts "project.exe"
& $Compiler build --project (Join-Path $repoRoot "examples\regression\projects\272-project-manifest") `
    -o $projectOutput --target windows-x64 --llvm $LlvmHome --stdlib $StdlibRoot -O1
Assert-ExitCode 0 "project build"
$projectRun = (& $projectOutput | Out-String)
Assert-ExitCode 0 "project executable"
Assert-Output $projectRun "42" "project executable"
$multiProductProject = Join-Path $repoRoot "examples\regression\projects\273-package-graph\app"
$productOutput = Join-Path $artifacts "alternate-product.exe"
& $Compiler build --project $multiProductProject --product alternate `
    -o $productOutput --target windows-x64 --llvm $LlvmHome --stdlib $StdlibRoot -O1
Assert-ExitCode 0 "multi-product build"
$productRun = (& $productOutput | Out-String)
Assert-ExitCode 0 "multi-product executable"
Assert-Output $productRun "alternate" "multi-product executable"

Write-Host "[native CLI 6/9] Transitive path-dependency product build."
$dependencyOutput = Join-Path $artifacts "package-demo.exe"
& $Compiler build --project $multiProductProject --product package_demo `
    -o $dependencyOutput --target windows-x64 --llvm $LlvmHome --stdlib $StdlibRoot -O1
Assert-ExitCode 0 "path-dependency product build"
$dependencyRun = (& $dependencyOutput | Out-String)
Assert-ExitCode 0 "path-dependency product executable"
Assert-Output $dependencyRun "42" "path-dependency product executable"

Write-Host "[native CLI 7/9] Workspace package build."
$workspaceOutput = Join-Path $artifacts "workspace.exe"
& $Compiler build --workspace (Join-Path $repoRoot "examples\regression\projects\437-workspace") `
    --package app -o $workspaceOutput --target windows-x64 --llvm $LlvmHome --stdlib $StdlibRoot -O1
Assert-ExitCode 0 "workspace build"
$workspaceRun = (& $workspaceOutput | Out-String)
Assert-ExitCode 0 "workspace executable"
Assert-Output $workspaceRun "42" "workspace executable"

Write-Host "[native CLI 8/9] Run and literal argv forwarding."
$runProgram = Join-Path $artifacts "run-arguments.exe"
$runOutput = (& $Compiler run (Join-Path $repoRoot "examples\regression\83-process-arguments.slg") `
    -o $runProgram --target windows-x64 --llvm $LlvmHome --stdlib $StdlibRoot -O1 -- `
    "hello world" "한글 인자" | Out-String)
Assert-ExitCode 0 "run"
Assert-Output $runOutput @"
argument count = 3
first argument = hello world
second argument = 한글 인자
"@ "run"

Write-Host "[native CLI 9/9] Complete standard-library linkage."
$llvmPath = "$implicitOutput.ll"
if (-not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
    throw "native build did not retain its LLVM input for audit: $llvmPath"
}
if (-not (Select-String -LiteralPath $llvmPath -SimpleMatch "@sollang_stage2_random_state" -Quiet)) {
    throw "native build did not compile the complete standard-library runtime"
}

$proofRoot = Join-Path $repoRoot "artifacts\native-cli-build-run"
New-Item -ItemType Directory -Path $proofRoot -Force | Out-Null
$compilerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Compiler).Hash
$proofPath = Join-Path $proofRoot "win-x64-$compilerHash.verified"
[IO.File]::WriteAllText($proofPath, $version.Trim())
Write-Host "Native source/project/dependency/workspace build/run CLI verification passed (9/9)."
