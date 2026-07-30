[CmdletBinding()]
param(
    [string]$Compiler,
    [string]$Distribution = "Ubuntu",
    [string]$StdlibRoot,
    [string]$LlvmHome
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3-linux"
}
if ([string]::IsNullOrWhiteSpace($StdlibRoot)) {
    $StdlibRoot = Join-Path $repoRoot "stdlib"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot "scripts\linux-cross-llvm"
}
$Compiler = [IO.Path]::GetFullPath($Compiler)
$StdlibRoot = [IO.Path]::GetFullPath($StdlibRoot)
$LlvmHome = [IO.Path]::GetFullPath($LlvmHome)
$artifacts = Join-Path $repoRoot "artifacts\native-cli-build-run-linux"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null

function Convert-ToWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

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

if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf)) {
    throw "Linux native compiler is missing: $Compiler"
}

$compilerWsl = Convert-ToWslPath $Compiler
$stdlibWsl = Convert-ToWslPath $StdlibRoot
$llvmHomeWsl = Convert-ToWslPath $LlvmHome

Write-Host "[linux native CLI 1/9] Version."
$version = (& wsl.exe -d $Distribution -- $compilerWsl --version | Out-String)
Assert-ExitCode 0 "version"
Assert-Output $version "Sollang 0.4.0" "version"

Write-Host "[linux native CLI 2/9] Help and empty invocation status."
$help = (& wsl.exe -d $Distribution -- $compilerWsl --help | Out-String)
Assert-ExitCode 0 "help"
if ($help -notmatch "usage: sollang <command> \[options\]") {
    throw "help did not contain the public usage line"
}
& wsl.exe -d $Distribution -- $compilerWsl *> $null
Assert-ExitCode 1 "empty invocation"

Write-Host "[linux native CLI 3/9] Named-input source build."
$namedSource = Convert-ToWslPath (Join-Path $repoRoot "examples\regression\02-function-named-input.slg")
$namedOutput = Join-Path $artifacts "named"
$namedOutputWsl = Convert-ToWslPath $namedOutput
& wsl.exe -d $Distribution -- $compilerWsl build $namedSource `
    -o $namedOutputWsl --target linux-x64 --stdlib $stdlibWsl --llvm $llvmHomeWsl -O1
Assert-ExitCode 0 "named build"
$namedRun = (& wsl.exe -d $Distribution -- $namedOutputWsl | Out-String)
Assert-ExitCode 0 "named executable"
Assert-Output $namedRun "Hello, dimohy. square = 49" "named executable"

Write-Host "[linux native CLI 4/9] Contextual-it source build."
$implicitSource = Convert-ToWslPath (Join-Path $repoRoot "examples\regression\03-flow-call-parens.slg")
$implicitOutput = Join-Path $artifacts "implicit"
$implicitOutputWsl = Convert-ToWslPath $implicitOutput
& wsl.exe -d $Distribution -- $compilerWsl build $implicitSource `
    -o $implicitOutputWsl --target linux-x64 --stdlib $stdlibWsl --llvm $llvmHomeWsl -O1 --keep-temps
Assert-ExitCode 0 "contextual-it build"
$implicitRun = (& wsl.exe -d $Distribution -- $implicitOutputWsl | Out-String)
Assert-ExitCode 0 "contextual-it executable"
Assert-Output $implicitRun "Hello, dimohy. square = 49" "contextual-it executable"

Write-Host "[linux native CLI 5/9] Project-directory and explicit alternate-product builds."
$projectRootWsl = Convert-ToWslPath (Join-Path $repoRoot "examples\regression\projects\272-project-manifest")
$projectOutput = Join-Path $artifacts "project"
$projectOutputWsl = Convert-ToWslPath $projectOutput
& wsl.exe -d $Distribution -- $compilerWsl build --project $projectRootWsl `
    -o $projectOutputWsl --target linux-x64 --stdlib $stdlibWsl --llvm $llvmHomeWsl -O1
Assert-ExitCode 0 "project build"
$projectRun = (& wsl.exe -d $Distribution -- $projectOutputWsl | Out-String)
Assert-ExitCode 0 "project executable"
Assert-Output $projectRun "42" "project executable"
$multiProductProjectWsl = Convert-ToWslPath (Join-Path $repoRoot "examples\regression\projects\273-package-graph\app")
$productOutputWsl = Convert-ToWslPath (Join-Path $artifacts "alternate-product")
& wsl.exe -d $Distribution -- $compilerWsl build --project $multiProductProjectWsl --product alternate `
    -o $productOutputWsl --target linux-x64 --stdlib $stdlibWsl --llvm $llvmHomeWsl -O1
Assert-ExitCode 0 "multi-product build"
$productRun = (& wsl.exe -d $Distribution -- $productOutputWsl | Out-String)
Assert-ExitCode 0 "multi-product executable"
Assert-Output $productRun "alternate" "multi-product executable"

Write-Host "[linux native CLI 6/9] Transitive path-dependency product build."
$dependencyOutputWsl = Convert-ToWslPath (Join-Path $artifacts "package-demo")
& wsl.exe -d $Distribution -- $compilerWsl build --project $multiProductProjectWsl --product package_demo `
    -o $dependencyOutputWsl --target linux-x64 --stdlib $stdlibWsl --llvm $llvmHomeWsl -O1
Assert-ExitCode 0 "path-dependency product build"
$dependencyRun = (& wsl.exe -d $Distribution -- $dependencyOutputWsl | Out-String)
Assert-ExitCode 0 "path-dependency product executable"
Assert-Output $dependencyRun "42" "path-dependency product executable"

Write-Host "[linux native CLI 7/9] Workspace package build."
$workspaceRootWsl = Convert-ToWslPath (Join-Path $repoRoot "examples\regression\projects\437-workspace")
$workspaceOutput = Join-Path $artifacts "workspace"
$workspaceOutputWsl = Convert-ToWslPath $workspaceOutput
& wsl.exe -d $Distribution -- $compilerWsl build --workspace $workspaceRootWsl --package app `
    -o $workspaceOutputWsl --target linux-x64 --stdlib $stdlibWsl --llvm $llvmHomeWsl -O1
Assert-ExitCode 0 "workspace build"
$workspaceRun = (& wsl.exe -d $Distribution -- $workspaceOutputWsl | Out-String)
Assert-ExitCode 0 "workspace executable"
Assert-Output $workspaceRun "42" "workspace executable"

Write-Host "[linux native CLI 8/9] Run and literal argv forwarding."
$argumentSource = Convert-ToWslPath (Join-Path $repoRoot "examples\regression\83-process-arguments.slg")
$argvVerifier = Convert-ToWslPath (Join-Path $PSScriptRoot "verify-native-cli-argv-linux.sh")
$runProgramWsl = Convert-ToWslPath (Join-Path $artifacts "run-arguments")
& wsl.exe -d $Distribution -- bash $argvVerifier `
    $compilerWsl $argumentSource $stdlibWsl $llvmHomeWsl $runProgramWsl
Assert-ExitCode 0 "run and argv forwarding"

Write-Host "[linux native CLI 9/9] Complete standard-library linkage."
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
$proofPath = Join-Path $proofRoot "linux-x64-$compilerHash.verified"
[IO.File]::WriteAllText($proofPath, $version.Trim())
Write-Host "Linux native source/project/dependency/workspace build/run CLI verification passed (9/9)."
