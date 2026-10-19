[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$compiler = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = [IO.Path]::GetFullPath($OutputDirectory, $root)
if (Test-Path -LiteralPath $output) { throw "C612 output already exists: $output" }

$cases = @(
    @{ Id = '1845-interpolation-numeric-conversion'; Mode = 'positive' },
    @{ Id = '1854-interpolation-float-width-conversion'; Mode = 'positive' },
    @{ Id = '1846-interpolation-nonnumeric-conversion'; Mode = 'negative' },
    @{ Id = '1848-interpolation-conversion-literal-range'; Mode = 'negative' }
)
$inputs = [ordered]@{
    compiler = $compiler
    compilerDll = [IO.Path]::ChangeExtension($compiler, '.dll')
    compilerDeps = [IO.Path]::ChangeExtension($compiler, '.deps.json')
    compilerRuntime = [IO.Path]::ChangeExtension($compiler, '.runtimeconfig.json')
    verifier = $PSCommandPath
    processHelper = (Join-Path $PSScriptRoot 'verification-process.ps1')
    llvmAs = (Join-Path $llvm 'bin/llvm-as.exe')
    clang = (Join-Path $llvm 'bin/clang.exe')
}
foreach ($case in $cases) {
    $base = if ($case.Mode -ceq 'positive') { 'examples/regression' } else { 'examples/regression/diagnostics' }
    $inputs["source:$($case.Id)"] = Join-Path $root "$base/$($case.Id).slg"
    $suffix = if ($case.Mode -ceq 'positive') { 'stdout.txt' } else { 'stderr.contains.txt' }
    $expectedBase = if ($case.Mode -ceq 'positive') { 'examples/regression/expected' } else { $base }
    $inputs["expected:$($case.Id)"] = Join-Path $root "$expectedBase/$($case.Id).$suffix"
}
foreach ($path in $inputs.Values) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C612 input missing: $path" }
}
function Hashes {
    $values = [ordered]@{}
    foreach ($entry in $inputs.GetEnumerator()) {
        $values[$entry.Key] = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash
    }
    $values
}
function Normalized([string]$value) { $value.Replace("`r`n", "`n") }

$start = Hashes
[IO.Directory]::CreateDirectory($output) | Out-Null
$rows = [Collections.Generic.List[object]]::new()
$failure = $null
try {
    foreach ($case in $cases) {
        $source = $inputs["source:$($case.Id)"]
        $expected = Normalized ([IO.File]::ReadAllText($inputs["expected:$($case.Id)"]))
        $product = Join-Path $output "$($case.Id).exe"
        $build = Invoke-VerificationProcessCapture -FilePath $compiler -WorkingDirectory $root `
            -Description "C612 managed build $($case.Id)" -TimeoutMilliseconds $TimeoutMilliseconds `
            -ArgumentList @('build', $source, '-o', $product, '--target', 'windows-x64', '--llvm', $llvm, '-O1', '--keep-temps')
        $native = $null
        if ($case.Mode -ceq 'positive' -and $build.ExitCode -eq 0) {
            $native = Invoke-VerificationProcessCapture -FilePath $product -WorkingDirectory $root `
                -Description "C612 managed native $($case.Id)" -TimeoutMilliseconds $TimeoutMilliseconds
        }
        $passed = if ($case.Mode -ceq 'positive') {
            $build.ExitCode -eq 0 -and $null -ne $native -and $native.ExitCode -eq 0 -and
                (Normalized $native.Stdout) -ceq $expected -and [string]::IsNullOrEmpty($native.Stderr)
        } else {
            $build.ExitCode -eq 1 -and (Normalized $build.Stderr).Contains($expected.TrimEnd("`n"), [StringComparison]::Ordinal) -and
                -not (Test-Path -LiteralPath $product)
        }
        $rows.Add([pscustomobject]@{
            id = $case.Id; mode = $case.Mode; passed = $passed
            buildExit = $build.ExitCode; nativeExit = if ($null -eq $native) { $null } else { $native.ExitCode }
            stdout = if ($null -eq $native) { Normalized $build.Stdout } else { Normalized $native.Stdout }
            stderr = Normalized $build.Stderr
        })
        if (-not $passed) { $failure = "C612 managed case failed: $($case.Id)"; break }
    }
} catch {
    $failure = $_.Exception.Message
}
$end = Hashes
$stable = ($start | ConvertTo-Json -Compress) -ceq ($end | ConvertTo-Json -Compress)
$result = [ordered]@{
    schemaVersion = 1; unit = 'C612-managed-first'; status = if ($null -eq $failure -and $stable -and $rows.Count -eq $cases.Count) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count; total = $cases.Count
    inputHashesStart = $start; inputHashesEnd = $end; inputsStable = $stable
    cases = @($rows); failure = $failure
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
if ($result.status -cne 'passed') { throw "C612 managed-first failed; result=$resultPath" }
Write-Host "[C612 managed first] PASS $($result.completed)/$($result.total); result=$resultPath"
