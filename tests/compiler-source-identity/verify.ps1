param([Parameter(Mandatory)][string]$Compiler,[Parameter(Mandatory)][string]$OutputDirectory,[string]$RepositoryRoot=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference='Stop'
. (Join-Path $RepositoryRoot 'scripts/verification-process.ps1')
if(Test-Path $OutputDirectory){throw 'Verification output must be fresh'}
[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
$dotnet=(Get-Command dotnet).Source
$compilerPath=(Resolve-Path $Compiler).Path
$compilerHash=(Get-FileHash $compilerPath).Hash
$fixtureRoot=Join-Path $RepositoryRoot 'tests/compiler-source-identity'
$relative='tests/compiler-source-identity/single.slg'
$absolute=Join-Path $fixtureRoot 'single.slg'
$crypto=@(Get-Content (Join-Path $RepositoryRoot 'examples/regression/expected/882-stdlib-hmac-hkdf.sources.txt')|ForEach-Object {Join-Path $RepositoryRoot $_})
$cases=@(
    @{id='882-explicit-stdlib';sources=$crypto;expected='hmac-hkdf=ok'},
    @{id='repeated-source-spelling';sources=@($relative,$absolute,(Join-Path $fixtureRoot './single.slg'));expected='13'},
    @{id='explicit-stdlib-spelling';sources=@($absolute,'stdlib/std/crypto/sha256.slg',(Join-Path $RepositoryRoot 'stdlib/std/crypto/./sha256.slg'));expected='13'},
    @{id='stdlib-only';sources=@('stdlib/std/crypto/sha256.slg',(Join-Path $RepositoryRoot 'stdlib/std/crypto/./sha256.slg'));expected=''},
    @{id='namespace-fragments';sources=@('fragments.slg','first.slg','second.slg'|ForEach-Object {Join-Path $fixtureRoot $_});expected="13`n17"},
    @{id='distinct-file-duplicate';sources=@('single.slg','first.slg','duplicate.slg'|ForEach-Object {Join-Path $fixtureRoot $_});reject=$true}
)
$results=@(foreach($case in $cases){
    $exe=Join-Path $OutputDirectory ($case.id+'.exe')
    $arguments=@($compilerPath,'build')+@($case.sources)+@('--target','windows-x64','--llvm',(Join-Path $RepositoryRoot '.tools/llvm-22.1.8'),'-o',$exe,'-O1')
    $build=Invoke-VerificationProcessCapture -FilePath $dotnet -ArgumentList $arguments -WorkingDirectory $RepositoryRoot -Description $case.id -TimeoutMilliseconds 120000
    [IO.File]::WriteAllText((Join-Path $OutputDirectory ($case.id+'.build.txt')),$build.Stdout+$build.Stderr)
    if($case.reject){
        $passed=$build.ExitCode -ne 0 -and $build.Stderr -match '(duplicate|already|defined|declared)' -and $build.Stderr -match 'first'
        @{id=$case.id;passed=$passed;buildExit=$build.ExitCode;diagnostic=$build.Stderr}
        continue
    }
    if($build.ExitCode -ne 0 -or $build.Stderr.Length -ne 0){@{id=$case.id;passed=$false;buildExit=$build.ExitCode;diagnostic=$build.Stderr};continue}
    $run=Invoke-VerificationProcessCapture -FilePath $exe -WorkingDirectory $RepositoryRoot -Description ($case.id+' execute') -TimeoutMilliseconds 20000
    $actual=$run.Stdout.Replace("`r`n","`n").TrimEnd("`n")
    @{id=$case.id;passed=($run.ExitCode -eq 0 -and $run.Stderr.Length -eq 0 -and $actual -ceq $case.expected);buildExit=$build.ExitCode;runExit=$run.ExitCode;stdout=$actual;stderr=$run.Stderr}
})
if((Get-FileHash $compilerPath).Hash -cne $compilerHash){throw 'Compiler changed during verification'}
$report=@{compilerSha256=$compilerHash;passed=@($results|Where-Object passed).Count;total=$cases.Count;cases=$results}
$report|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputDirectory 'results.json') -Encoding utf8
$results|Select-Object id,passed,buildExit|Format-Table
if($report.passed -ne $report.total){throw 'Source identity regression failed'}
