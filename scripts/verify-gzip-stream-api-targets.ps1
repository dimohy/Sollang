[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CompilerPath,
    [string]$ScratchRoot,
    [string]$WslDistribution = 'Ubuntu'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
if (-not $CompilerPath) { $CompilerPath = Join-Path $root 'src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll' }
if (-not $ScratchRoot) { $ScratchRoot = Join-Path $root ('artifacts\scratch\gzip-targets-' + [guid]::NewGuid().ToString('N')) }
$scratch = [IO.Path]::GetFullPath($ScratchRoot)
if (-not $scratch.StartsWith((Join-Path $root 'artifacts\scratch') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'scratch must be below artifacts/scratch' }
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$logPath = Join-Path $scratch 'run.log'
$resultPath = Join-Path $scratch 'result.json'
[IO.File]::WriteAllText($logPath, "started=$(Get-Date -Format o)`n", [Text.UTF8Encoding]::new($false))
$compiler = [IO.Path]::GetFullPath($CompilerPath)
$llvm = Join-Path $root '.tools\llvm-22.1.8'
$browserRunner = Join-Path $root 'scripts\verify-uri-browser-program.mjs'
$contract = Get-Content (Join-Path $root 'scripts\contracts\gzip-stream-api.json') -Raw | ConvertFrom-Json
$checks = [Collections.Generic.List[object]]::new()
$failures = [Collections.Generic.List[string]]::new()

function Run([string]$File, [string[]]$Arguments, [string]$Prefix) {
    $out = "$Prefix.stdout"; $err = "$Prefix.stderr"
    $p = Start-Process -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    [pscustomobject]@{ Exit=$p.ExitCode; Out=[IO.File]::ReadAllText($out); Err=[IO.File]::ReadAllText($err); Exited=$p.HasExited }
}
function Norm([string]$s) { $s.Replace("`r`n","`n") }
function WslPath([string]$p) { $f=[IO.Path]::GetFullPath($p); "/mnt/$($f.Substring(0,1).ToLowerInvariant())/$($f.Substring(3).Replace('\','/'))" }
function Save([string]$status) {
    $tools = @('dotnet','wsl','node') | ForEach-Object { $p=(Get-Command $_).Source; [ordered]@{path=$p;sha256=(Get-FileHash $p -Algorithm SHA256).Hash} }
    $r=[ordered]@{status=$status;failureIds=@($failures);completed=$checks.Count;total=30;compiler=[ordered]@{path=$compiler;sha256=(Get-FileHash $compiler -Algorithm SHA256).Hash};toolHashes=@($tools)+@([ordered]@{path=(Join-Path $llvm 'bin\clang.exe');sha256=(Get-FileHash (Join-Path $llvm 'bin\clang.exe') -Algorithm SHA256).Hash},[ordered]@{path=(Join-Path $llvm 'bin\wasm-ld.exe');sha256=(Get-FileHash (Join-Path $llvm 'bin\wasm-ld.exe') -Algorithm SHA256).Hash},[ordered]@{path=$browserRunner;sha256=(Get-FileHash $browserRunner -Algorithm SHA256).Hash});checks=@($checks);unsupported=@();pending=@('rebuilt-selfhost','final-stage-integration')}
    [IO.File]::WriteAllText($resultPath,($r|ConvertTo-Json -Depth 8)+"`n",[Text.UTF8Encoding]::new($false))
}
Save 'running'
$dynamicExpected = $null
foreach($case in $contract.positiveCases) {
    $source=Join-Path $root $case.source
    foreach($opt in 'O0','O2') {
        $id="linux-$($case.id)-$($opt.ToLowerInvariant())"; $dir=Join-Path $scratch $id; New-Item -ItemType Directory -Path $dir -Force|Out-Null
        $artifact=Join-Path $dir 'probe'; $c=Run -File 'dotnet' -Arguments @($compiler,'build',$source,'-o',$artifact,'--target','linux-x64',"-$opt",'--llvm',$llvm) -Prefix (Join-Path $dir 'compile')
        if($c.Exit-ne 0-or $c.Err.Length-ne 0-or-not(Test-Path $artifact)){$failures.Add("$id.compile");Save 'running';continue}
        $e=Run -File 'wsl' -Arguments @('-d',$WslDistribution,'--',$(WslPath $artifact)) -Prefix (Join-Path $dir 'run'); $actual=Norm $e.Out
        if($case.PSObject.Properties.Name -contains 'expected'){$expected=Norm([IO.File]::ReadAllText((Join-Path $root $case.expected)))}else{$expected=$dynamicExpected;if($null-eq $expected){$expected=$actual;$dynamicExpected=$actual}}
        if($e.Exit-ne 0-or $e.Err.Length-ne 0-or $actual-cne $expected){$failures.Add("$id.execute");Save 'running';continue}
        if($case.id-ceq 'dynamic-writer'){
            $lines=@($actual.TrimEnd("`n").Split("`n"));$bytes=[byte[]]($lines[1..($lines.Count-1)]|ForEach-Object{[byte]$_});$gz=Join-Path $dir 'reference.gz';[IO.File]::WriteAllBytes($gz,$bytes)
            $r=Run -File 'wsl' -Arguments @('-d',$WslDistribution,'--','gzip','-dc',$(WslPath $gz)) -Prefix (Join-Path $dir 'reference')
            if($r.Exit-ne 0-or $r.Err.Length-ne 0-or $r.Out-cne $case.referenceText){$failures.Add("$id.reference");Save 'running';continue}
        }
        $checks.Add([ordered]@{id=$id;target='linux-x64';optimization=$opt;artifactSha256=(Get-FileHash $artifact -Algorithm SHA256).Hash});Add-Content -LiteralPath $logPath -Value "PASS $id";Save 'running'
    }
}
if($null-eq $dynamicExpected){$failures.Add('dynamic-baseline.missing')}
$dynamicExpectedPath=Join-Path $scratch 'dynamic.expected.txt';if($null-ne $dynamicExpected){[IO.File]::WriteAllText($dynamicExpectedPath,$dynamicExpected,[Text.UTF8Encoding]::new($false))}
foreach($case in $contract.positiveCases){
    $id="browser-$($case.id)-o0";$dir=Join-Path $scratch $id;New-Item -ItemType Directory -Path $dir -Force|Out-Null;$artifact=Join-Path $dir 'probe.wasm'
    $c=Run -File 'dotnet' -Arguments @($compiler,'build',(Join-Path $root $case.source),'-o',$artifact,'--target','wasm32-browser','-O0','--llvm',$llvm) -Prefix (Join-Path $dir 'compile')
    $expectedPath=if($case.PSObject.Properties.Name -contains 'expected'){Join-Path $root $case.expected}else{$dynamicExpectedPath}
    if($c.Exit-ne 0-or $c.Err.Length-ne 0-or-not(Test-Path $artifact)){$failures.Add("$id.compile");Save 'running';continue}
    $e=Run -File 'node' -Arguments @($browserRunner,$artifact,$expectedPath) -Prefix (Join-Path $dir 'run')
    if($e.Exit-ne 0-or $e.Err.Length-ne 0){$failures.Add("$id.execute");Save 'running';continue}
    try{$j=$e.Out|ConvertFrom-Json}catch{$failures.Add("$id.result");Save 'running';continue};if($j.status-cne 'passed'){$failures.Add("$id.result");Save 'running';continue}
    $checks.Add([ordered]@{id=$id;target='wasm32-browser';optimization='O0';artifactSha256=(Get-FileHash $artifact -Algorithm SHA256).Hash;imports=@($j.imports)});Add-Content -LiteralPath $logPath -Value "PASS $id";Save 'running'
}
$status=if($failures.Count-eq 0-and $checks.Count-eq 30){'pass'}else{'fail'};Save $status
if($status-cne 'pass'){throw "GZIP target closure failed: $($failures-join ','); $resultPath"}
Write-Host "[GZIP target closure] PASS $($checks.Count)/30; $resultPath"
