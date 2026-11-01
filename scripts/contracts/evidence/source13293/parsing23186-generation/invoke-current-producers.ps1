param([string]$Producer,[string]$Root,[string]$Output)
$ErrorActionPreference='Stop'
$assembly=[Reflection.Assembly]::LoadFrom($Producer)
$flags=[Reflection.BindingFlags]'Static,Public,NonPublic'
foreach($kind in @('Lexer','Parser')) {
 $extension=if($kind -eq 'Lexer'){'lexer'}else{'grammar'}
 $path=Join-Path $Root "syntax/sollang.$extension"
 $specType=$assembly.GetType("Sollang.Compiler.Generators.$(if($kind -eq 'Lexer'){'LexerSpec'}else{'GrammarSpec'})",$true)
 $invokeArgs=[object[]]::new(2)
 $invokeArgs[0]=[string]$path
 $invokeArgs[1]=[string][IO.File]::ReadAllText($path)
 $spec=$specType.GetMethod('Parse',$flags).Invoke($null,$invokeArgs)
 $errorProperty=$specType.GetProperty('Error').GetValue($spec)
 if($null -ne $errorProperty){throw $errorProperty}
 $emitter=$assembly.GetType("Sollang.Compiler.Generators.$($kind)Emitter",$true)
 $code=$emitter.GetMethod('Emit',$flags).Invoke($null,@($spec))
 [IO.File]::WriteAllText((Join-Path $Output "Generated$kind.g.cs"),$code,[Text.UTF8Encoding]::new($true))
}
