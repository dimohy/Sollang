[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CandidateCompiler = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$compilerManifest = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$runtimeManifest = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
$fixture = Join-Path $root 'examples/regression/1759-array-inherent-selfhost.slg'
$fixtureModule = Join-Path $root 'examples/regression/fixtures/1759-array-inherent-methods.slg'
$expectedPath = Join-Path $root 'examples/regression/expected/1759-array-inherent-selfhost.stdout.txt'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clang = Join-Path $llvmRoot 'bin/clang.exe'
$closure = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$contract = Join-Path $root 'scripts/verify-selfhost-array-inherent-contract.ps1'
$output = Join-Path $root ('artifacts/scratch/selfhost-array-inherent-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)

foreach ($path in @($managed,$compilerManifest,$runtimeManifest,$fixture,$fixtureModule,$expectedPath,$llvmAs,$clang,$closure,$contract)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "array-inherent selfhost input is missing: $path" }
}
& pwsh -NoProfile -File $contract -RepositoryRoot $root
if ($LASTEXITCODE -ne 0) { throw 'array-inherent selfhost harness contract failed' }
$managedHash = (Get-FileHash -LiteralPath $managed -Algorithm SHA256).Hash

function Manifest([string]$Path) {
    @(Get-Content -LiteralPath $Path | Where-Object { $_.Trim() } | ForEach-Object {
        (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path
    })
}
function Normalize([string]$Text) { $Text.Replace("`r`n", "`n").TrimEnd("`n") }
function Capture([string]$File,[string[]]$Arguments,[string]$Description) {
    Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 3600000
}

$compilerSources = @(Manifest $compilerManifest)
$candidate = if ([string]::IsNullOrWhiteSpace($CandidateCompiler)) {
    Join-Path $output 'candidate-compiler.exe'
} else {
    [IO.Path]::GetFullPath((Join-Path $root $CandidateCompiler))
}
if ([string]::IsNullOrWhiteSpace($CandidateCompiler)) {
    $bootstrap = Capture 'dotnet' (@($managed,'build') + $compilerSources + @('-o',$candidate,'--target','windows-x64','-O0','--keep-temps')) 'array-inherent managed bootstrap of current selfhost sources'
    if ($bootstrap.ExitCode -ne 0 -or $bootstrap.Stdout -match '(?im)\b(?:warning|note)\b' -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "current-source selfhost bootstrap failed or diagnosed: $($bootstrap.Stdout) $($bootstrap.Stderr)"
    }
    $compilerLlvm = [IO.Path]::ChangeExtension($candidate, '.ll')
    & $llvmAs $compilerLlvm -o (Join-Path $output 'candidate-compiler.bc')
    if ($LASTEXITCODE -ne 0) { throw 'candidate compiler llvm-as failed' }
    & pwsh -NoProfile -File $closure -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'candidate compiler direct-call closure failed' }
} elseif (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "supplied current-source selfhost candidate is missing: $candidate"
}

$fixtureSources = @($fixture,$fixtureModule)
$ast = Capture $candidate (@('ast-nodes') + $fixtureSources) 'array-inherent selfhost parser'
if ($ast.ExitCode -ne 0) {
    throw "array-inherent selfhost parser topology failed: $($ast.Stdout) $($ast.Stderr)"
}
$astRecords = @($ast.Stdout -split "`r?`n" | ForEach-Object {
    if ($_ -match '^ast source (?<source>\d+) node (?<node>\d+) kind (?<kind>\d+) parent (?<parent>-?\d+) ') {
        [pscustomobject]@{ Source=[int]$Matches.source; Node=[int]$Matches.node; Kind=[int]$Matches.kind; Parent=[int]$Matches.parent }
    }
})
$impls = @($astRecords | Where-Object { $_.Source -eq 1 -and $_.Kind -eq 6 })
$nominalOwners = @($astRecords | Where-Object { $_.Source -eq 1 -and $_.Kind -eq 16 -and $impls.Node -contains $_.Parent })
$arrayOwners = @($astRecords | Where-Object { $_.Source -eq 1 -and $_.Kind -eq 12 -and $impls.Node -contains $_.Parent })
if ($impls.Count -ne 2 -or $nominalOwners.Count -ne 1 -or $arrayOwners.Count -ne 1) {
    throw "array-inherent AST owner topology differs: impl=$($impls.Count) nominal=$($nominalOwners.Count) array=$($arrayOwners.Count)"
}
$types = Capture $candidate (@('expression-type-ids') + $fixtureSources) 'array-inherent selfhost semantic types'
if ($types.ExitCode -ne 0 -or $types.Stdout -match '(?m)^expression .* status [^0]\s*$') {
    throw "array-inherent selfhost semantic typing failed: $($types.Stdout) $($types.Stderr)"
}
$calls = Capture $candidate (@('typed-ir-calls') + $fixtureSources) 'array-inherent selfhost calls'
if ($calls.ExitCode -ne 0 -or $calls.Stdout -match '(?m)^resolution .* status [^0]\s*$') {
    throw "array-inherent selfhost call resolution failed: $($calls.Stdout) $($calls.Stderr)"
}

$fixtureLlvm = Join-Path $output 'fixture.ll'
$fixtureError = Join-Path $output 'fixture.stderr.txt'
Invoke-VerificationProcessToFile -FilePath $candidate -ArgumentList (@('windows') + $fixtureSources) `
    -Description 'array-inherent selfhost LLVM emission' `
    -OutputPath $fixtureLlvm -ErrorPath $fixtureError -TimeoutMilliseconds 120000
$fixtureDiagnostics = [IO.File]::ReadAllText($fixtureError)
if ($fixtureDiagnostics -match '(?im)^(?:warning|note|;?\s*sollang .*error)') { throw "fixture emission diagnosed:`n$fixtureDiagnostics" }
& $llvmAs $fixtureLlvm -o (Join-Path $output 'fixture.bc')
if ($LASTEXITCODE -ne 0) { throw 'fixture llvm-as failed' }
& pwsh -NoProfile -File $closure -LlvmPath $fixtureLlvm
if ($LASTEXITCODE -ne 0) { throw 'fixture direct-call closure failed' }
$fixtureExe = Join-Path $output 'fixture.exe'
& $clang -Wno-override-module $fixtureLlvm -O0 -o $fixtureExe
if ($LASTEXITCODE -ne 0) { throw 'fixture native link failed' }
$run = Capture $fixtureExe @() 'array-inherent selfhost native execution'
$expected = Normalize ([IO.File]::ReadAllText($expectedPath))
if ($run.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($run.Stderr) -or (Normalize $run.Stdout) -cne $expected) {
    throw "fixture exact execution failed: $($run.Stdout) $($run.Stderr)"
}

$result = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    completed = 7
    total = 7
    bootstrap = if ([string]::IsNullOrWhiteSpace($CandidateCompiler)) { 'managed-current-source-selfhost' } else { 'reused-current-source-selfhost' }
    bootstrapCompilerSha256 = $managedHash
    candidateSha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
    checks = @('parser-array-owner','semantic-self-type','current-module-call','imported-qualified-call','borrow-reuse','llvm-assembly-closure','native-exact')
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 4) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "[selfhost array inherent] PASS 7/7; $resultPath"
