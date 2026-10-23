$ErrorActionPreference = 'Stop'
$base = 'artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/build-focused-selfhost-compiler.ps1 -SeedCompiler "$base/managed12710/compiler/Sollang.Compiler.exe" -OutputDirectory "$base/v12742/compiler-build01" -Optimization O1 -Jobs 4 -FormatCompiler "$base/v12432/compiler-build01/compiler.exe" -ReusableCompilerDirectories @("$base/v12432/compiler-build01", "$base/v12722/compiler-build01") -ManagedProofRecord @("$base/scratch12737-preflight/result.json", "$base/scratch12735-managed/result.json") -SlgEmissionProofRecord @("$base/scratch12740-runtime/result.json") -StdlibSourceProofRecord "$base/scratch12738-stdlib/result.json"
if ($LASTEXITCODE -ne 0) { throw "Native compiler build failed: $LASTEXITCODE" }
