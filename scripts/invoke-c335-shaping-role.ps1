param([Parameter(Mandatory)][ValidateSet('baseline','validator','consumer','candidate')][string]$Role,[Parameter(Mandatory)][string]$ConfigPath)
$ErrorActionPreference='Stop'
$config=Get-Content $ConfigPath -Raw|ConvertFrom-Json
. $config.helper
if($Role -eq 'candidate'){
    if(Test-Path $config.generatedDirectory){throw 'Generated output must be fresh'}
    & $config.cleanup -Compiler $config.compiler -RepositoryRoot $config.repository -Fixture @('1528-fixed-field-factory','1529-fixed-field-named','1530-fixed-field-stack','1531-fixed-field-owned','1532-fixed-field-region')
    $proof=@($config.consumer,$config.llvm,(Join-Path $config.generatedDirectory 'results.json')|ForEach-Object {@{path=$_;sha256=(Get-FileHash $_).Hash}})
    $proof|ConvertTo-Json -Depth 5|Set-Content (Join-Path $config.evidenceDirectory 'generated-output-hashes.json') -Encoding utf8
    exit 0
}
if($Role -ne 'baseline'){
    $proof=Get-Content (Join-Path $config.evidenceDirectory 'generated-output-hashes.json') -Raw|ConvertFrom-Json
    foreach($output in $proof){if((Get-FileHash $output.path).Hash -cne $output.sha256){throw 'Generated output changed after candidate role'}}
}
if($Role -eq 'validator'){
    $snapshot=Get-Content $config.snapshot -Raw|ConvertFrom-Json
    foreach($relative in @('selfhost/llvm/text/function_expressions.slg','selfhost/llvm/text/control_region_expressions.slg','selfhost/llvm/text/entry_expressions.slg')){
        $entry=@($snapshot.files|Where-Object {$_.path.Replace('\','/') -ceq $relative})
        if($entry.Count -ne 1 -or (Get-FileHash (Join-Path $config.repository $relative)).Hash -cne $entry[0].sha256){throw 'Owner does not match the compiled candidate snapshot'}
    }
    $build=Get-Content $config.buildReceipt -Raw|ConvertFrom-Json
    if($build.exitCode -ne 0 -or $build.compilerSha256 -cne (Get-FileHash $config.compiler).Hash -or
       $build.sourceManifestSha256 -cne (Get-FileHash $config.snapshot).Hash){throw 'Candidate build proof does not match compiler and source manifest'}
    $run=Invoke-VerificationProcessCapture -FilePath $config.assembler -ArgumentList @($config.llvm,'-o',(Join-Path $config.evidenceDirectory 'validated.bc')) -Description 'C335 LLVM validator' -WorkingDirectory $config.repository -TimeoutMilliseconds 20000
    if($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0){throw 'Assembly failed'}
    Write-Output 'Three owner hashes match compiled snapshot; current1528 LLVM assembled successfully.'
    exit 0
}
$exe=if($Role -eq 'baseline'){$config.baseline}else{$config.consumer}
$run=Invoke-VerificationProcessCapture -FilePath $exe -Description ('C335 '+$Role) -WorkingDirectory $config.repository -TimeoutMilliseconds 20000
$actual=$run.Stdout.Replace("`r`n","`n").TrimEnd("`n")
$expected=if($Role -eq 'baseline'){"13`nallocations=1,releases=0,invalid_releases=0"}else{"13`nallocations=1,releases=1"}
$exit=if($Role -eq 'baseline'){1}else{0}
if($run.ExitCode -ne $exit -or $run.Stderr.Length -ne 0 -or $actual -cne $expected){[Console]::Error.WriteLine('Executable contract mismatch; this is not an expected baseline failure.');exit 9}
[Console]::Write($run.Stdout)
exit $exit
