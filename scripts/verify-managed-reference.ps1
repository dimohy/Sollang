[CmdletBinding()]
param([string]$RepositoryRoot=(Split-Path -Parent $PSScriptRoot),
      [Parameter(Mandatory)][string]$OutputDirectory,
      [ValidateRange(1,64)][int]$Jobs=16,
      [ValidateRange(1000,43200000)][int]$TimeoutMilliseconds=43200000,
      [switch]$ValidateInputsOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'managed-reference-snapshot.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
$compiler=Join-Path $repo 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$runner=Join-Path $repo 'tests/Sollang.ExampleTests/bin/Release/net11.0/Sollang.ExampleTests.dll'
$dotnet=(Get-Command dotnet -CommandType Application).Source
$arguments=@($runner,'--suite','reference','--target','windows-x64','--skip-bootstrap','--jobs',$Jobs.ToString())
$roots=@('src','selfhost','stdlib','syntax','examples','tests' | ForEach-Object { Join-Path $repo $_ })
# Include runtime binary directory membership separately from source bin/obj exclusions.
$roots+=@((Split-Path $compiler),(Split-Path $runner))
$required=@($compiler,$runner,$dotnet,$PSCommandPath,
    (Join-Path $PSScriptRoot 'managed-reference-snapshot.ps1'),
    (Join-Path $PSScriptRoot 'input-fingerprint-stability.ps1'),
    (Join-Path $PSScriptRoot 'verification-process.ps1'),
    (Join-Path $repo 'scripts/build-com-interop-fixture.ps1'),
    (Join-Path $repo 'scripts/build-native-interop-fixture.ps1'),
    (Join-Path $repo 'artifacts/native-interop/native_fixture.dll'),
    (Join-Path $repo 'Sollang.slnx'))
$required+=@('clang.exe','llvm-as.exe','lld-link.exe' | ForEach-Object { Join-Path $repo ".tools/llvm-22.1.8/bin/$_" })
$comLlvm=if([string]::IsNullOrWhiteSpace($env:SOLLANG_LLVM_HOME)){Join-Path $repo '.tools/llvm-22.1.8'}else{$env:SOLLANG_LLVM_HOME}
$required+=@('clang.exe','lld-link.exe' | ForEach-Object { Join-Path $comLlvm "bin/$_" })
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory,$repo)
foreach($root in $roots){
    if($OutputDirectory -eq $root -or $OutputDirectory.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
        throw "Verification output must be outside frozen input directories: $OutputDirectory"
    }
}
if($ValidateInputsOnly){
    Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet)+$arguments)
    return
}
Invoke-ManagedReferenceGuard -OutputDirectory $OutputDirectory -GetSnapshot {
    Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet)+$arguments)
} -Run {
    param($logDirectory)
    Invoke-ManagedReferenceProcess -FilePath $dotnet -ArgumentList $arguments -WorkingDirectory $repo -OutputDirectory $logDirectory -TimeoutMilliseconds $TimeoutMilliseconds
}
