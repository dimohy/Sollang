$ErrorActionPreference='Stop'
$b='artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/verify-managed-pdb-source-identity.ps1 -AssemblyPath @("$b/managed12899/compiler/Sollang.Compiler.dll") -RequiredSource @('src/Sollang.Compiler/obj/generated/Sollang.Compiler.Generators/Sollang.Compiler.Generators.ParserSourceGenerator/GeneratedParser.g.cs','src/Sollang.Compiler/obj/generated/Sollang.Compiler.Generators/Sollang.Compiler.Generators.LexerSourceGenerator/GeneratedLexer.g.cs') -OutputJson "$b/parsing13015-pdb.json"
