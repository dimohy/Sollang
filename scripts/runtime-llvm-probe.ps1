# Shared native execution path for extracted authoritative runtime fragments.
function New-RuntimeLlvmProbe {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Harness
    )
    if (-not $IsWindows) { throw 'Native runtime probes currently require Windows.' }
    . (Join-Path $PSScriptRoot 'verification-process.ps1')
    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $output = Join-Path $root ("artifacts/scratch/$Name-" + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($output)
    $clang = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
    $llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
    $harnessLlvm = Join-Path $output 'harness.ll'
    $compiled = Invoke-VerificationProcessCapture -FilePath $clang -ArgumentList @('-S', '-emit-llvm', '-Wall', '-Wextra', '-Werror', $Harness, '-o', $harnessLlvm) -Description "$Name harness compilation" -TimeoutMilliseconds 20000
    [IO.File]::WriteAllText((Join-Path $output 'harness.compile.stdout.txt'), $compiled.Stdout)
    [IO.File]::WriteAllText((Join-Path $output 'harness.compile.stderr.txt'), $compiled.Stderr)
    if ($compiled.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($compiled.Stderr)) {
        throw "$Name harness compilation failed: $($compiled.Stderr); evidence: $output"
    }
    $targetHeader = [regex]::Match([IO.File]::ReadAllText($harnessLlvm), '(?m)^target triple = "[^"]+"').Value
    if ($targetHeader -notmatch 'x86_64-pc-windows-msvc') { throw "Unexpected Windows harness target: $targetHeader" }
    [pscustomobject]@{ Output = $output; Clang = $clang; LlvmAs = $llvmAs; HarnessLlvm = $harnessLlvm; TargetHeader = $targetHeader }
}

function Invoke-RuntimeLlvmProbe {
    param(
        [Parameter(Mandatory)]$Probe,
        [Parameter(Mandatory)][string]$Authority,
        [Parameter(Mandatory)][string]$Llvm,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)][string]$ExpectedOutput
    )
    . (Join-Path $PSScriptRoot 'verification-process.ps1')
    $llvmPath = Join-Path $Probe.Output "$Authority.ll"
    $bitcode = Join-Path $Probe.Output "$Authority.bc"
    $executable = Join-Path $Probe.Output "$Authority.exe"
    [IO.File]::WriteAllText($llvmPath, "$($Probe.TargetHeader)`n$Llvm`n", [Text.UTF8Encoding]::new($false))
    foreach ($step in @(
        @{ Name = 'assemble'; Tool = $Probe.LlvmAs; Arguments = @($llvmPath, '-o', $bitcode) },
        @{ Name = 'link'; Tool = $Probe.Clang; Arguments = @('-Wall', '-Wextra', '-Werror', $Probe.HarnessLlvm, $bitcode, '-o', $executable) },
        @{ Name = 'execute'; Tool = $executable; Arguments = $Arguments }
    )) {
        $result = Invoke-VerificationProcessCapture -FilePath $step.Tool -ArgumentList $step.Arguments -Description "$Authority runtime $($step.Name)" -TimeoutMilliseconds 20000
        [IO.File]::WriteAllText((Join-Path $Probe.Output "$Authority.$($step.Name).stdout.txt"), $result.Stdout)
        [IO.File]::WriteAllText((Join-Path $Probe.Output "$Authority.$($step.Name).stderr.txt"), $result.Stderr)
        if ($result.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($result.Stderr)) {
            throw "$Authority runtime $($step.Name) failed: $($result.Stderr) (exit $($result.ExitCode)); evidence: $($Probe.Output)"
        }
    }
    if ($result.Stdout.Trim() -cne $ExpectedOutput) { throw "Unexpected $Authority execution output: $($result.Stdout)" }
    [pscustomobject]@{ LlvmHash = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash; ExecutableHash = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash }
}
