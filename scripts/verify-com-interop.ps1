[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$compilerProject = Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$source = Join-Path $repoRoot "examples\604-com-interface.slg"
$capabilitySource = Join-Path $repoRoot "examples\diagnostics\com-wasm32-unavailable.slg"
$expectedPath = Join-Path $repoRoot "examples\expected\604-com-interface.stdout.txt"
$outputRoot = Join-Path $repoRoot "artifacts\com-interop"
$output = Join-Path $outputRoot "stage1-com-windows.exe"
$ir = [System.IO.Path]::ChangeExtension($output, ".ll")
$llvmRoot = if ([string]::IsNullOrWhiteSpace($env:SOLLANG_LLVM_HOME)) {
    Join-Path $repoRoot ".tools\llvm-22.1.8"
} else {
    $env:SOLLANG_LLVM_HOME
}
$llvmReadObj = Join-Path $llvmRoot "bin\llvm-readobj.exe"

dotnet build $compilerProject -c Release --nologo --no-restore
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $PSScriptRoot "build-com-interop-fixture.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dotnet $compiler build $source `
    -o $output `
    --target windows-x64 `
    --llvm $llvmRoot `
    -O2 `
    --keep-temps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$expected = ([System.IO.File]::ReadAllText($expectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$actual = (& $output | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) {
    throw "COM execution mismatch: expected '$expected', actual '$actual'"
}

$fixture = Join-Path $outputRoot "com_fixture.dll"
$exports = (& $llvmReadObj --coff-exports $fixture | Out-String)
$missingExports = $LASTEXITCODE -ne 0 `
    -or $exports -notmatch "Name: DllGetClassObject" `
    -or $exports -notmatch "Name: com_fixture_live_references"
if ($missingExports) {
    throw "COM fixture exports are incomplete"
}

$llvm = [System.IO.File]::ReadAllText($ir)
$required = @(
    "call i32 @CoInitializeEx(ptr null, i32 4)",
    "DllGetClassObject",
    "getelementptr ptr, ptr %com_add_ref_vtable",
    "i64 1",
    "getelementptr ptr, ptr %com_release_vtable",
    "i64 2",
    "getelementptr ptr, ptr %com_method_vtable",
    "i64 3",
    "call void @CoUninitialize()"
)
foreach ($fragment in $required) {
    if (-not $llvm.Contains($fragment, [System.StringComparison]::Ordinal)) {
        throw "COM LLVM is missing '$fragment'"
    }
}
if ([regex]::Matches($llvm, "call i32 @CoInitializeEx").Count -ne 1) {
    throw "COM must initialize its declared apartment exactly once"
}
if ([regex]::Matches($llvm, "call void @CoUninitialize").Count -ne 1) {
    throw "COM must balance apartment initialization exactly once"
}
if ($llvm -notmatch "call void @sollang_drop_[0-9]+\(%sollang\.enum\.[0-9]+ %com_activation_result") {
    throw "COM activation result does not deterministically release its owned interface"
}

$unavailableTargets = @("linux-x64", "wasm32-browser")
foreach ($target in $unavailableTargets) {
    $diagnosticOutput = Join-Path $outputRoot ("invalid-com-" + $target)
    $messages = (& dotnet $compiler build $capabilitySource -o $diagnosticOutput --target $target --llvm $llvmRoot -O0 2>&1 | Out-String)
    $invalidDiagnostic = $LASTEXITCODE -eq 0 `
        -or -not $messages.Contains(
            "COM declarations require target windows-x64; Linux and wasm32-browser do not provide COM",
            [System.StringComparison]::Ordinal)
    if ($invalidDiagnostic) {
        throw "COM target diagnostic failed for $target"
    }
}

Write-Host "PASS COM interop: activation, vtable call, clone/AddRef, deterministic Release, and target diagnostics"
