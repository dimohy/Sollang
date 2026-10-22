$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$out=Join-Path $b 'v12515/compiler-build01'
if(Test-Path -LiteralPath $out){throw 'OUTPUT_NOT_FRESH'}
$admission=Get-Content -LiteralPath (Join-Path $b 'admission12515.json') -Raw|ConvertFrom-Json
if(-not $admission.admitted){throw 'RESOURCE_ADMISSION_FAILED'}
$paths=@('source12511-source/result.json','source12513-runtime/result.json','source12513-runtime-proof.json','ownership12510-preflight/result.json','stdlib12514-current/result.json')
$pins=[ordered]@{}
foreach($relative in $paths){
 $p=Join-Path $b $relative;$d=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
 if($d.status -cne 'passed' -or -not $d.inputsStable -or -not $d.processesStopped -or $d.completed -ne $d.total){throw ('PREREQUISITE_FAILED '+$relative)}
 $pins[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
}
$plan=[ordered]@{schemaVersion=1;observedAtUtc=[DateTime]::UtcNow.ToString('o');scope='One canonical fresh native compiler for C687..C692 ownership21 and SourceText admission8. CSharp29, actual SLG source29, normal runtime23, canonical frontend4 and full-stdlib source1 passed. Existing C385/final original/source/frozen/Stage/platform scope remains.';prerequisiteHashes=$pins;nativeCompilerBuildBudget=1;buildInvocations=1;nativeCompilerBuildCompleted=0;optimization='O1';jobs=4;cacheSeed=$null;protectedExistingProducts=@('v12432/compiler-build01','v12443/compiler-build01');retiredProduct='v12405/compiler-build01/consumer-closure.json';newProtectedProduct='v12515/compiler-build01';onFailure='Preserve failed output and inspect cause; no identical repeated full build or weakened oracle';claimsGoalComplete=$false}
$planPath=Join-Path $b 'native12515-plan.json'
function SavePlan{[IO.File]::WriteAllText($planPath,($plan|ConvertTo-Json -Depth 10)+"`n",[Text.UTF8Encoding]::new($false))}
SavePlan
& scripts/build-focused-selfhost-compiler.ps1 -SeedCompiler (Join-Path $b 'managed12499/compiler/Sollang.Compiler.exe') -OutputDirectory $out -Optimization O1 -Jobs 4 -FormatCompiler (Join-Path $b 'v12432/compiler-build01/compiler.exe') -ReusableCompilerDirectories @((Join-Path $b 'v12432/compiler-build01'),(Join-Path $b 'v12443/compiler-build01')) -ManagedProofRecord @((Join-Path $b 'ownership12510-preflight/result.json')) -SlgEmissionProofRecord @((Join-Path $b 'source12513-runtime-proof.json')) -StdlibSourceProofRecord (Join-Path $b 'stdlib12514-current/result.json')
$result=Get-Content -LiteralPath (Join-Path $out 'result.json') -Raw|ConvertFrom-Json
if($result.status -cne 'passed' -or -not $result.inputsStable){throw 'CANONICAL_NATIVE_BUILD_FAILED'}
$plan.nativeCompilerBuildCompleted=1;$plan.compilerSha256=$result.compilerSha256;SavePlan
