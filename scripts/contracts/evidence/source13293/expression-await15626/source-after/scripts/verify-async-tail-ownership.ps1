[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$Distribution = 'Ubuntu',
    [string]$ContractFile = (Join-Path $PSScriptRoot 'contracts/async-tail-ownership.json'),
    [string]$LlvmHome = (Join-Path $PSScriptRoot '../.tools/llvm-22.1.8')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
if ([IO.Path]::GetExtension($compilerPath) -cne '.dll') { throw 'Explicit managed compiler DLL required' }
if ((Get-FileHash $compilerPath -Algorithm SHA256).Hash -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw 'ASYNC_TAIL_COMPILER_HASH' }
$contractPath = [IO.Path]::GetFullPath($ContractFile, $root)
if (-not $contractPath.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetExtension($contractPath) -cne '.json' -or -not (Test-Path -LiteralPath $contractPath -PathType Leaf)) { throw 'ASYNC_TAIL_CONTRACT_PATH' }
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -cne 'async-tail-ownership' -or $contract.expectedSanitizerExit -ne 0 -or $contract.cases.Count -lt 1) { throw 'ASYNC_TAIL_CONTRACT' }
$llvmPath = (Resolve-Path -LiteralPath $LlvmHome).Path
$llvmTools = @('clang.exe','llvm-as.exe','llvm-link.exe','opt.exe','llc.exe' | ForEach-Object { Join-Path $llvmPath "bin/$_" })
foreach ($tool in $llvmTools) { if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw 'ASYNC_TAIL_LLVM_TOOL_MISSING' } }
$inputs = @($compilerPath, $contractPath, $PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1'))
$inputs += $llvmTools
$inputs += @('Sollang.Compiler.deps.json','Sollang.Compiler.runtimeconfig.json' | ForEach-Object { Join-Path (Split-Path $compilerPath) $_ })
$inputs += @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg' | ForEach-Object FullName)
$inputs += @('src/Sollang.Compiler/CodeGen/LlvmEmitter.Async.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Utilities.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs','src/Sollang.Compiler/CodeGen/LlvmEmitter.Expressions.Control.cs','src/Sollang.Compiler/Semantics/SemanticCompiler.cs' | ForEach-Object { Join-Path $root $_ })
$ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($case in $contract.cases) {
    if ($case.id -notmatch '^[a-z-]+$' -or -not $ids.Add($case.id)) { throw 'ASYNC_TAIL_CASE_ID' }
    $source = [IO.Path]::GetFullPath((Join-Path $root $case.source))
    $fixtureRoot = [IO.Path]::GetFullPath((Join-Path $root 'scripts/contracts/fixtures/async-tail-ownership')).TrimEnd('\') + '\'
    if (-not $source.StartsWith($fixtureRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'ASYNC_TAIL_SOURCE' }
    $inputs += $source
}
$hashes = [ordered]@{}
foreach ($inputPath in $inputs) { $hashes[$inputPath] = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash }
$output = [IO.Path]::GetFullPath($OutputDirectory, $root)
if (Test-Path -LiteralPath $output) { throw 'ASYNC_TAIL_OUTPUT_EXISTS' }
[IO.Directory]::CreateDirectory($output) | Out-Null
function LinuxPath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if ($absolute -notmatch '^[A-Za-z]:\\') { throw 'ASYNC_TAIL_DRIVE_PATH' }
    return '/mnt/' + $absolute.Substring(0,1).ToLowerInvariant() + '/' + $absolute.Substring(3).Replace('\','/')
}
function Run([string]$Name, [string]$File, [string[]]$Arguments, [int]$Timeout = 20000) {
    return Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description "Async tail ownership $Name" -TimeoutMilliseconds $Timeout -ExecutionRecordPath (Join-Path $output "$Name.execution.json")
}
$record = [ordered]@{schemaVersion=1;status='running';completed=0;total=$contract.cases.Count;inputHashes=$hashes;inputsStable=$false;processesStopped=$false;compilerSha256=$ExpectedCompilerSha256.ToUpperInvariant();cases=@();scope='CSharp Linux native LLVM plus AddressSanitizer/LeakSanitizer; fixed ownership fixtures only'}
try {
    $windowsVersion = Run 'windows-clang-version' $llvmTools[0] @('--version')
    if ($windowsVersion.ExitCode -ne 0 -or $windowsVersion.Stdout -notmatch 'clang version 22\.1\.8') { throw 'ASYNC_TAIL_WINDOWS_CLANG_VERSION' }
    $version = Run 'clang-version' wsl.exe @('-d',$Distribution,'--','/usr/bin/clang','--version')
    if ($version.ExitCode -ne 0 -or $version.Stdout -notmatch 'clang version 18\.1\.3') { throw 'ASYNC_TAIL_CLANG_VERSION' }
    $toolHash = Run 'clang-hash' wsl.exe @('-d',$Distribution,'--','/usr/bin/sha256sum','/usr/lib/llvm-18/bin/clang')
    if ($toolHash.ExitCode -ne 0 -or $toolHash.Stdout -notmatch '^([a-f0-9]{64})\s') { throw 'ASYNC_TAIL_CLANG_HASH' }
    $record.clangSha256 = $Matches[1].ToUpperInvariant()
    $workspace = Run 'workspace-access' wsl.exe @('-d',$Distribution,'--','/usr/bin/test','-r',(LinuxPath (Join-Path $root $contract.cases[0].source)))
    if ($workspace.ExitCode -ne 0) { throw 'ASYNC_TAIL_WSL_SOURCE_UNAVAILABLE' }
    foreach ($case in $contract.cases) {
        $product = Join-Path $output $case.id
        $llvm = $product + '.ll'
        $row = [ordered]@{id=$case.id;compileExit=$null;sanitizerCompileExit=$null;nativeExit=$null;passed=$false}
        $compiled = Run "$($case.id)-build" dotnet @($compilerPath,'build',(Join-Path $root $case.source),'-o',$product,'--target','linux-x64','--llvm',$llvmPath,'-O0','--keep-temps')
        $row.compileExit = $compiled.ExitCode
        if ($compiled.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($compiled.Stderr) -and (Test-Path -LiteralPath $llvm -PathType Leaf)) {
            $ir = [IO.File]::ReadAllText($llvm)
            if ($ir -notmatch 'target triple = "([^"]+)"') { throw 'ASYNC_TAIL_MODULE_TRIPLE' }
            $triple = $Matches[1]
            $sanitizer = $product + '-asan'
            $built = Run "$($case.id)-asan-build" wsl.exe @('-d',$Distribution,'--','/usr/bin/clang',"--target=$triple",'-O0','-g','-fsanitize=address',(LinuxPath $llvm),'-pthread','-o',(LinuxPath $sanitizer))
            $row.sanitizerCompileExit = $built.ExitCode
            if ($built.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($built.Stderr)) {
                $run = Run "$($case.id)-run" wsl.exe @('-d',$Distribution,'--','env','ASAN_OPTIONS=detect_leaks=1',(LinuxPath $sanitizer)) 10000
                $row.nativeExit = $run.ExitCode
                $row.stdout = $run.Stdout
                $row.stderr = $run.Stderr
                $row.passed = $run.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($run.Stderr) -and $run.Stdout.Replace("`r`n","`n") -ceq $case.stdout
            }
        }
        $record.cases += $row
        $record.completed = @($record.cases | Where-Object passed).Count
        [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        Write-Host "$($case.id): passed=$($row.passed)"
    }
    $record.status = if ($record.completed -eq $record.total) { 'passed' } else { 'failed' }
} catch { $record.status='failed'; $record.failure=$_.Exception.Message }
finally {
    $record.inputsStable=$true
    foreach ($inputPath in $inputs) {
        if ((Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash -cne $hashes[$inputPath]) { $record.inputsStable=$false; $record.status='failed' }
    }
    $executions = @(Get-ChildItem -LiteralPath $output -Filter '*.execution.json' -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
    $record.processesStopped = $executions.Count -gt 0 -and @($executions | Where-Object { $_.processesStopped -ne $true }).Count -eq 0
    if (-not $record.processesStopped) { $record.status='failed' }
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}
Write-Host "$($record.status): $($record.completed)/$($record.total); result=$output/result.json"
if ($record.status -ne 'passed') { throw 'ASYNC_TAIL_OWNERSHIP_FAILED' }
