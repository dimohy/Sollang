$ErrorActionPreference = 'Stop'
$base = 'artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/build-focused-selfhost-compiler.ps1 -SeedCompiler "$base/managed12581/compiler/Sollang.Compiler.exe" -OutputDirectory "$base/v12693/compiler-build01" -Optimization O1 -Jobs 4 -FormatCompiler "$base/v12432/compiler-build01/compiler.exe" -ReusableCompilerDirectories @("$base/v12432/compiler-build01", "$base/v12626/compiler-build01") -ManagedProofRecord @("$base/scratch12688-preflight/result.json", 'scripts/contracts/evidence/source-review12648/csharp12648-proof.json') -SlgEmissionProofRecord @("$base/scratch12692-runtime/result.json") -StdlibSourceProofRecord "$base/scratch12690-stdlib/result.json"
if ($LASTEXITCODE -ne 0) { throw "Native compiler build failed: $LASTEXITCODE" }
