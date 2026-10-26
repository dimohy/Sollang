[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$Compiler = '',
    [string]$ManagedCompiler = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'selfhost-stage-inputs.ps1')
. (Join-Path $PSScriptRoot 'compiler-emission-fingerprint.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$repo = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler) -ne [string]::IsNullOrWhiteSpace($ManagedCompiler)) {
    throw 'Actual runtime comparison requires both compiler paths'
}
$checkRuntime = -not [string]::IsNullOrWhiteSpace($Compiler)
if ($checkRuntime) {
    $Compiler = (Resolve-Path -LiteralPath $Compiler -ErrorAction Stop).Path
    $ManagedCompiler = (Resolve-Path -LiteralPath $ManagedCompiler -ErrorAction Stop).Path
    $clang = (Resolve-Path -LiteralPath (Join-Path $repo '.tools/llvm-22.1.8/bin/clang.exe') -ErrorAction Stop).Path
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "test output already exists: $output" }
$fixture = Join-Path $output 'fixture'
$manifestDirectory = Join-Path $fixture 'tests/Sollang.ExampleTests/Fixtures'
[IO.Directory]::CreateDirectory($manifestDirectory) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $fixture 'stdlib/std')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $fixture 'compat')) | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'examples/regression/01-function-basic-hello.slg') -Destination (Join-Path $fixture 'app.slg')
Copy-Item -LiteralPath (Join-Path $repo 'stdlib/std/time.slg') -Destination (Join-Path $fixture 'stdlib/std/time.slg')
Copy-Item -LiteralPath (Join-Path $repo 'selfhost/runtime/file.slg') -Destination (Join-Path $fixture 'compat/file.slg')
$compilerManifest = Join-Path $manifestDirectory 'selfhost-sollangc-driver.sources.txt'
$runtimeManifest = Join-Path $manifestDirectory 'selfhost-compiler-runtime.sources.txt'
[IO.File]::WriteAllText($compilerManifest, "app.slg`n")
[IO.File]::WriteAllText($runtimeManifest, "compat/file.slg`n")
$checks = [Collections.Generic.List[object]]::new()
function Assert-StageInput([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "Stage input assertion failed: $Name" }
    $checks.Add(@{id=$Name;status='passed'})
}
function Assert-StageInputRejection([string]$Name, [scriptblock]$Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert-StageInput $Name $rejected
}
$result = @{schemaVersion=1;status='running';completed=0;total=$(if ($checkRuntime) { 13 } else { 10 });checks=@();claimsStagePassed=$false}
try {
    $graph = Get-SelfhostStageCompilationInputs -RepositoryRoot $fixture -Jobs 4
    Assert-StageInput 'explicit-standard-library-mode' ($graph.EmissionArguments[0] -ceq 'windows-stdlib' -and $graph.EmissionArguments[1] -ceq (Join-Path $fixture 'stdlib'))
    Assert-StageInput 'legacy-file-projection-not-emitted' ($graph.EmissionArguments -notcontains (Join-Path $fixture 'compat/file.slg') -and $graph.FingerprintPaths -contains (Join-Path $fixture 'compat/file.slg'))
    Assert-StageInput 'full-standard-library-fingerprinted' ($graph.FingerprintPaths -contains (Join-Path $fixture 'stdlib/std/time.slg'))
    $before = Get-CompilerEmissionInputFingerprint -RepositoryRoot $fixture -Path $graph.FingerprintPaths
    $library = Join-Path $fixture 'stdlib/std/time.slg'
    $libraryBytes = [IO.File]::ReadAllBytes($library)
    [IO.File]::AppendAllText($library, "`n# input fingerprint control`n")
    $after = Get-CompilerEmissionInputFingerprint -RepositoryRoot $fixture -Path $graph.FingerprintPaths
    Assert-StageInput 'library-edit-invalidates-fingerprint' ($before -cne $after)
    [IO.File]::WriteAllBytes($library, $libraryBytes)
    Copy-Item -LiteralPath (Join-Path $repo 'stdlib/std/algorithm.slg') -Destination (Join-Path $fixture 'stdlib/std/algorithm.slg')
    $expanded = Get-SelfhostStageCompilationInputs -RepositoryRoot $fixture -Jobs 4
    Assert-StageInput 'new-library-module-invalidates-fingerprint' ($before -cne (Get-CompilerEmissionInputFingerprint -RepositoryRoot $fixture -Path $expanded.FingerprintPaths))
    [IO.File]::WriteAllText($compilerManifest, "app.slg`napp.slg`n")
    Assert-StageInputRejection 'duplicate-source-rejected' { Get-SelfhostStageCompilationInputs -RepositoryRoot $fixture }
    [IO.File]::WriteAllText($compilerManifest, "missing.slg`n")
    Assert-StageInputRejection 'missing-source-rejected' { Get-SelfhostStageCompilationInputs -RepositoryRoot $fixture }
    [IO.File]::WriteAllText($compilerManifest, "app.slg`n")
    Assert-StageInputRejection 'invalid-worker-count-rejected' { Get-SelfhostStageCompilationInputs -RepositoryRoot $fixture -Jobs 0 }
    foreach ($name in @('verify-selfhost-stage2.ps1','verify-selfhost-stage3.ps1')) {
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name), [ref]$tokens, [ref]$errors)
        $resolver = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Get-SelfhostStageCompilationInputs'}, $true))
        $emission = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.MemberExpressionAst] -and $node.Member.Value -ceq 'EmissionArguments'}, $true))
        Assert-StageInput ($name+'-consumes-resolved-command') ($errors.Count -eq 0 -and $resolver.Count -eq 1 -and $emission.Count -eq 1)
    }
    if ($checkRuntime) {
        $runtimeFixture = Join-Path $output 'runtime-fixture'
        $runtimeManifests = Join-Path $runtimeFixture 'tests/Sollang.ExampleTests/Fixtures'
        [IO.Directory]::CreateDirectory($runtimeManifests) | Out-Null
        foreach ($source in Get-ChildItem -LiteralPath (Join-Path $repo 'stdlib') -Recurse -File -Filter '*.slg') {
            $destination = Join-Path $runtimeFixture ([IO.Path]::GetRelativePath($repo, $source.FullName))
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
            Copy-Item -LiteralPath $source.FullName -Destination $destination
        }
        $originalRuntimeManifest = Join-Path $repo 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
        foreach ($entry in [IO.File]::ReadAllLines($originalRuntimeManifest)) {
            $destination = Join-Path $runtimeFixture $entry
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
            Copy-Item -LiteralPath (Join-Path $repo $entry) -Destination $destination
        }
        Copy-Item -LiteralPath $originalRuntimeManifest -Destination (Join-Path $runtimeManifests 'selfhost-compiler-runtime.sources.txt')
        [IO.File]::WriteAllText((Join-Path $runtimeManifests 'selfhost-sollangc-driver.sources.txt'), "app.slg`n")
        Copy-Item -LiteralPath (Join-Path $repo 'scripts/contracts/fixtures/selfhost-stage-stdlib-source-mode.slg') -Destination (Join-Path $runtimeFixture 'app.slg')
        $runtimeGraph = Get-SelfhostStageCompilationInputs -RepositoryRoot $runtimeFixture -Jobs 1
        function Invoke-StageInputProbe([string]$Name, [string]$Executable, [string[]]$Arguments) {
            Invoke-VerificationProcessCapture -FilePath $Executable -ArgumentList $Arguments -Description $Name `
                -TimeoutMilliseconds 180000 -ExecutionRecordPath (Join-Path $output ($Name+'.execution.json'))
        }
        $managedProgram = Join-Path $output 'managed.exe'
        $managedBuild = Invoke-StageInputProbe 'managed-build' $ManagedCompiler @('build', (Join-Path $runtimeFixture 'app.slg'), '-o', $managedProgram, '--llvm', (Join-Path $repo '.tools/llvm-22.1.8'), '--target', 'windows-x64', '-O0', '--jobs', '1')
        if ($managedBuild.ExitCode -ne 0 -or $managedBuild.Stderr.Length -ne 0) { throw 'Stage input managed reference build failed' }
        $managedRun = Invoke-StageInputProbe 'managed-run' $managedProgram @()
        Assert-StageInput 'managed-standard-library-reference' ($managedRun.ExitCode -eq 0 -and $managedRun.Stderr.Length -eq 0 -and $managedRun.Stdout -ceq 'stage-inputs')
        $raw = Invoke-StageInputProbe 'legacy-raw-package' $Compiler (@('windows', (Join-Path $runtimeFixture 'app.slg')) + $runtimeGraph.RuntimeSources)
        Assert-StageInput 'legacy-package-does-not-import-standard-print' ($raw.ExitCode -ne 0 -and ($raw.Stdout+$raw.Stderr).Contains("unknown value-flow target 'print'"))
        $emitted = Invoke-StageInputProbe 'standard-library-emission' $Compiler $runtimeGraph.EmissionArguments
        if ($emitted.ExitCode -ne 0 -or $emitted.Stderr.Length -ne 0) { throw 'Stage input full standard library emission failed' }
        $llvmPath = Join-Path $output 'native.ll'
        [IO.File]::WriteAllText($llvmPath, $emitted.Stdout, [Text.UTF8Encoding]::new($false))
        $nativeProgram = Join-Path $output 'native.exe'
        $linked = Invoke-StageInputProbe 'native-link' $clang @('-Wno-override-module', $llvmPath, '-o', $nativeProgram, '-lshell32', '-lbcrypt', '-lws2_32')
        if ($linked.ExitCode -ne 0 -or $linked.Stderr.Length -ne 0) { throw 'Stage input native link failed' }
        $nativeRun = Invoke-StageInputProbe 'native-run' $nativeProgram @()
        Assert-StageInput 'resolved-standard-library-runtime-matches-reference' ($nativeRun.ExitCode -eq 0 -and $nativeRun.Stderr.Length -eq 0 -and $nativeRun.Stdout -ceq $managedRun.Stdout)
    }
    $result.status = 'passed'
} catch {
    $result.status = 'failed'
    $result.failure = $_.Exception.Message
} finally {
    $result.checks = @($checks.ToArray())
    $result.completed = $checks.Count
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
}
if ($result.status -cne 'passed' -or $result.completed -ne $result.total) { throw 'Stage input contract failed' }
Write-Output "PASS Stage input contract $($result.completed)/$($result.total); no Stage execution credit"
