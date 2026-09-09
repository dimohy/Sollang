[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-source-closure.ps1')
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$root = Join-Path $temporaryRoot ('sollang-native-closure-' + [Guid]::NewGuid().ToString('N'))
if (-not ([IO.Path]::GetFullPath($root)).StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'source-closure contract escaped its temporary scope'
}

function Write-ContractFile([string]$RelativePath, [string]$Content) {
    $path = Join-Path $root $RelativePath
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
    [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
}

try {
    Write-ContractFile 'compiler.exe' 'never execute'
    Write-ContractFile 'llvm/bin/llvm-as.exe' 'never execute'
    Write-ContractFile 'llvm/bin/clang.exe' 'never execute'
    [IO.Directory]::CreateDirectory((Join-Path $root 'stdlib')) | Out-Null
    Write-ContractFile 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt' ''
    foreach ($name in @('closure-one', 'closure-two')) {
        Write-ContractFile "examples/regression/$name.slg" "import sollang.compiler.required as required`nmain { 1 -> println }`n"
        Write-ContractFile "examples/regression/expected/$name.sources.txt" "examples/regression/$name.slg`n"
        Write-ContractFile "examples/regression/expected/$name.stdout.txt" "1`n"
    }
    $arguments = @{
        Compiler = Join-Path $root 'compiler.exe'
        Label = 'source-closure-contract'
        Platform = 'windows'
        LlvmRoot = Join-Path $root 'llvm'
        StdlibRoot = Join-Path $root 'stdlib'
        RepositoryRoot = $root
        OutputDirectory = Join-Path $root 'must-not-build'
        Jobs = 1
    }
    $singleFailure = $null
    try {
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') @arguments -Fixture 'closure-one'
    } catch { $singleFailure = $_.Exception.Message }
    if ($singleFailure -notmatch 'source manifest closure is incomplete' -or
        $singleFailure -notmatch 'sollang.compiler.required' -or
        (Test-Path -LiteralPath $arguments.OutputDirectory)) {
        throw "single native fixture did not reject closure before creating build artifacts: $singleFailure"
    }
    $batchFailure = $null
    try {
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') @arguments -Fixture @('closure-one', 'closure-two')
    } catch { $batchFailure = $_.Exception.Message }
    if ($batchFailure -notmatch 'source closure failed before compiler launch' -or
        $batchFailure -notmatch 'closure-one:' -or $batchFailure -notmatch 'closure-two:' -or
        (Test-Path -LiteralPath $arguments.OutputDirectory)) {
        throw "batch did not aggregate both missing closures before compiler launch: $batchFailure"
    }

    Write-ContractFile 'required.slg' "namespace sollang.compiler.required`n"
    Assert-NativeExactCompilerSourceClosure -RepositoryRoot $root -Fixture 'closure-one' -SourcePath @(
        (Join-Path $root 'examples/regression/closure-one.slg'), (Join-Path $root 'required.slg'))
    Write-ContractFile 'examples/regression/expected/closure-one.sources.txt' "examples/regression/closure-one.slg`nrequired.slg`n"
    Assert-NativeExactCompilerSourceClosure -RepositoryRoot $root -Fixture 'closure-one'
    $embeddedSource = @'
# Imports inside stored source text are not dependencies of this file.
import sollang.compiler.required as required
main {
    """"
    namespace decoy.namespace
    import unavailable.embedded as embedded
    """" => source
}
'@
    Write-ContractFile 'examples/regression/closure-one.slg' $embeddedSource
    Assert-NativeExactCompilerSourceClosure -RepositoryRoot $root -Fixture 'closure-one'
    Write-ContractFile 'examples/regression/expected/closure-one.sources.txt' "examples/regression/closure-one.slg`n"
    $embeddedNamespaceFailure = $null
    Write-ContractFile 'examples/regression/closure-one.slg' ($embeddedSource.Replace('decoy.namespace', 'sollang.compiler.required'))
    try { Assert-NativeExactCompilerSourceClosure -RepositoryRoot $root -Fixture 'closure-one' }
    catch { $embeddedNamespaceFailure = $_.Exception.Message }
    if ($embeddedNamespaceFailure -notmatch 'sollang.compiler.required imported by') {
        throw 'a namespace in stored source text satisfied a real import'
    }
    Write-ContractFile 'examples/regression/expected/closure-one.sources.txt' "examples/regression/closure-one.slg`nrequired.slg`n"
    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') @arguments -Fixture @('closure-one') -ValidateInputsOnly
    if (Test-Path -LiteralPath $arguments.OutputDirectory) { throw 'input-only validation created build artifacts' }

    Write-ContractFile 'examples/regression/expected/closure-one.sources.txt' "examples/regression/closure-one.slg`nrequired.slg`nrequired.slg`n"
    $duplicateFailure = $null
    try { Assert-NativeExactCompilerSourceClosure -RepositoryRoot $root -Fixture 'closure-one' }
    catch { $duplicateFailure = $_.Exception.Message }
    if ($duplicateFailure -notmatch 'duplicate source entry') { throw 'duplicate manifest source was accepted' }

    Write-ContractFile 'examples/regression/ordinary.slg' "main { 1 -> println }`n"
    Assert-NativeExactCompilerSourceClosure -RepositoryRoot $root -Fixture 'ordinary'
    Write-ContractFile 'examples/regression/ordinary.slg' ($embeddedSource.Substring($embeddedSource.IndexOf('main {')))
    Assert-NativeExactCompilerSourceClosure -RepositoryRoot $root -Fixture 'ordinary'
    . (Join-Path $PSScriptRoot 'source-module-header.ps1')
    $libraryHeader = @'
namespace actual.module # module comment
library external from """"
import fake.library.text
""""
import actual.dependency as dependency # import comment
main {}
'@
    $header = Get-SollangModuleHeader -Source $libraryHeader
    if ($header.Namespace -cne 'actual.module' -or
        $header.Imports.Count -ne 1 -or
        $header.Imports[0] -cne 'actual.dependency') {
        throw 'library text or trailing comments corrupted module header extraction'
    }
    Write-Host '[native exact source closure] PASS pre-launch rejection, aggregated failures, complete manifests, duplicate rejection, embedded import/namespace isolation, library text, comments, and ordinary fixture boundary.'
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
