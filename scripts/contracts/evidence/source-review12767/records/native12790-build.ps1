$ErrorActionPreference = 'Stop'
$base = 'artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/build-focused-selfhost-compiler.ps1 -SeedCompiler "$base/managed12768/compiler/Sollang.Compiler.exe" -OutputDirectory "$base/v12790/compiler-build01" -Optimization O1 -Jobs 4 -FormatCompiler "$base/v12432/compiler-build01/compiler.exe" -ReusableCompilerDirectories @("$base/v12432/compiler-build01", "$base/v12776/compiler-build01") -ManagedProofRecord @("$base/scratch12785-preflight/result.json", "$base/scratch12784-managed/result.json") -SlgEmissionProofRecord @("$base/scratch12789-runtime/result.json") -StdlibSourceProofRecord "$base/scratch12786-stdlib/result.json"
if ($LASTEXITCODE -ne 0) { throw "Native compiler build failed: $LASTEXITCODE" }
