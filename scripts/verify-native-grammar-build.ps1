[CmdletBinding()]
param(
    [string]$ManagedCompiler = "",
    [string]$NativeCompiler = "",
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ManagedCompiler)) {
    $ManagedCompiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($NativeCompiler)) {
    $NativeCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
}
$ManagedCompiler = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$NativeCompiler = (Resolve-Path -LiteralPath $NativeCompiler).Path
$artifacts = Join-Path $repoRoot "artifacts\native-grammar-build"
$casesRoot = Join-Path $artifacts "cases"
New-Item -ItemType Directory -Path $casesRoot -Force | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)

function Convert-ToWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Convert-NativeArgument {
    param([string]$Argument)

    if ($Target -eq "linux-x64" -and $Argument -match '^[A-Za-z]:[\\/]') {
        return Convert-ToWslPath $Argument
    }
    $Argument
}

function Invoke-Compiler {
    param(
        [bool]$Native,
        [string[]]$Arguments
    )

    $start = [Diagnostics.ProcessStartInfo]::new()
    if ($Native) {
        if ($Target -eq "linux-x64") {
            $start.FileName = "wsl.exe"
            $start.ArgumentList.Add("-d")
            $start.ArgumentList.Add($Distribution)
            $start.ArgumentList.Add("--")
            $start.ArgumentList.Add((Convert-ToWslPath $NativeCompiler))
        }
        else {
            $start.FileName = $NativeCompiler
        }
    }
    else {
        $start.FileName = "dotnet"
        $start.ArgumentList.Add($ManagedCompiler)
    }
    foreach ($argument in $Arguments) {
        $start.ArgumentList.Add($(if ($Native) { Convert-NativeArgument $argument } else { $argument }))
    }
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdout.Replace("`r`n", "`n").Replace("`r", "`n")
        Stderr = $stderr.Replace("`r`n", "`n").Replace("`r", "`n")
    }
}

function Assert-EquivalentFailure {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $managed = Invoke-Compiler $false $Arguments
    $native = Invoke-Compiler $true $Arguments
    if ($managed.ExitCode -ne 1 -or $native.ExitCode -ne 1) {
        throw "$Name exit mismatch: managed=$($managed.ExitCode), native=$($native.ExitCode)"
    }
    $managedStdout = $managed.Stdout
    $managedStderr = $managed.Stderr
    $nativeStdout = $native.Stdout
    $nativeStderr = $native.Stderr
    for ($argumentIndex = 0; $argumentIndex -lt $Arguments.Count; $argumentIndex++) {
        $argument = $Arguments[$argumentIndex]
        if ([IO.Path]::IsPathFullyQualified($argument)) {
            $managedPath = [IO.Path]::GetFullPath($argument)
            $nativePath = if ($Target -eq "linux-x64") { Convert-ToWslPath $argument } else { $managedPath }
            $marker = "<path-$argumentIndex>"
            $managedStdout = $managedStdout.Replace($managedPath, $marker)
            $managedStderr = $managedStderr.Replace($managedPath, $marker)
            $nativeStdout = $nativeStdout.Replace($nativePath, $marker)
            $nativeStderr = $nativeStderr.Replace($nativePath, $marker)
        }
    }
    if ($managedStdout -ne $nativeStdout -or $managedStderr -ne $nativeStderr) {
        throw "$Name output mismatch.`nmanaged stdout: $($managed.Stdout)`nnative stdout: $($native.Stdout)`nmanaged stderr: $($managed.Stderr)`nnative stderr: $($native.Stderr)"
    }
}

function Assert-EquivalentBuild {
    param(
        [string]$Name,
        [string]$Lexer,
        [string]$Grammar
    )

    $managedOutput = Join-Path $artifacts "$Name-managed\deep\generated.slg"
    $nativeOutput = Join-Path $artifacts "$Name-native\deep\generated.slg"
    $managed = Invoke-Compiler $false @("grammar", "build", $Lexer, $Grammar, "-o", $managedOutput)
    $native = Invoke-Compiler $true @("grammar", "build", $Lexer, $Grammar, "-o", $nativeOutput)
    if ($managed.ExitCode -ne 0 -or $native.ExitCode -ne 0) {
        throw "$Name build failed.`nmanaged: exit=$($managed.ExitCode) stdout=$($managed.Stdout) stderr=$($managed.Stderr)`nnative: exit=$($native.ExitCode) stdout=$($native.Stdout) stderr=$($native.Stderr)"
    }
    $managedNormalized = $managed.Stdout.Replace([IO.Path]::GetFullPath($managedOutput), "<output>")
    $nativeOutputText = if ($Target -eq "linux-x64") {
        Convert-ToWslPath $nativeOutput
    }
    else {
        [IO.Path]::GetFullPath($nativeOutput)
    }
    $nativeNormalized = $native.Stdout.Replace($nativeOutputText, "<output>")
    if ($managedNormalized -ne $nativeNormalized -or $managed.Stderr -ne "" -or $native.Stderr -ne "") {
        throw "$Name success output mismatch.`nmanaged: $($managed.Stdout)`nnative: $($native.Stdout)"
    }
    $managedBytes = [IO.File]::ReadAllBytes($managedOutput)
    $nativeBytes = [IO.File]::ReadAllBytes($nativeOutput)
    if (-not [Linq.Enumerable]::SequenceEqual[byte]($managedBytes, $nativeBytes)) {
        throw "$Name generated module differs: managed=$((Get-FileHash $managedOutput -Algorithm SHA256).Hash), native=$((Get-FileHash $nativeOutput -Algorithm SHA256).Hash)"
    }
}

$canonicalLexer = Join-Path $repoRoot "syntax\sollang.lexer"
$canonicalGrammar = Join-Path $repoRoot "syntax\sollang.grammar"
Assert-EquivalentBuild "canonical" $canonicalLexer $canonicalGrammar
Write-Output "[1/4] PASS canonical generated-module byte parity"

$completeLexer = Join-Path $casesRoot "complete.lexer"
$completeGrammar = Join-Path $casesRoot "complete.grammar"
[IO.File]::WriteAllText($completeLexer, @"
skip Space = whitespace
skip Comment = line_comment
token Identifier = identifier
token String = quoted_string
token Number = number
token Newline = newline
token End = end
token Plus = "+"
token AlsoPlus = "+"
"@.TrimStart(), $utf8)
[IO.File]::WriteAllText($completeGrammar, @"
parser Complete
start Root
rule Root = Header? (Identifier("if") | Name)+ Tail* lookahead(End) notKeyword("else")
rule Header = Newline
rule Name = Identifier
rule Tail = Number
"@.TrimStart(), $utf8)
Assert-EquivalentBuild "complete" $completeLexer $completeGrammar
Write-Output "[2/4] PASS sequence, choice, grouping, predicates, and quantifier parity"

Assert-EquivalentFailure "usage" @("grammar", "build")
$missingLexer = Join-Path $casesRoot "missing.lexer"
$missingGrammar = Join-Path $casesRoot "missing.grammar"
Assert-EquivalentFailure "missing lexer" @("grammar", "build", $missingLexer, $missingGrammar, "-o", (Join-Path $artifacts "missing.slg"))
Assert-EquivalentFailure "missing grammar" @("grammar", "build", $canonicalLexer, $missingGrammar, "-o", (Join-Path $artifacts "missing.slg"))
Write-Output "[3/4] PASS usage and missing-input diagnostic parity"

$invalidCases = @(
    @{ Name = "lexer-no-token"; Lexer = "skip Space = whitespace`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier`n" },
    @{ Name = "lexer-pattern"; Lexer = "token Identifier = mystery`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier`n" },
    @{ Name = "lexer-duplicate"; Lexer = "token Identifier = identifier`ntoken Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier`n" },
    @{ Name = "grammar-missing-start"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nrule Root = Identifier`n" },
    @{ Name = "grammar-unknown-start"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Missing`nrule Root = Identifier`n" },
    @{ Name = "grammar-unknown-symbol"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = Missing`n" },
    @{ Name = "grammar-empty-choice"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier |`n" },
    @{ Name = "grammar-unclosed-group"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = (Identifier`n" },
    @{ Name = "grammar-unknown-token"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = lookahead(Missing)`n" },
    @{ Name = "grammar-predicate"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = mystery(Identifier)`n" }
)
foreach ($case in $invalidCases) {
    $lexer = Join-Path $casesRoot "$($case.Name).lexer"
    $grammar = Join-Path $casesRoot "$($case.Name).grammar"
    [IO.File]::WriteAllText($lexer, $case.Lexer, $utf8)
    [IO.File]::WriteAllText($grammar, $case.Grammar, $utf8)
    Assert-EquivalentFailure $case.Name @("grammar", "build", $lexer, $grammar, "-o", (Join-Path $artifacts "$($case.Name).slg"))
}
Write-Output "[4/4] PASS lexer and production diagnostic parity"
Write-Output "Native grammar build verification passed (4/4)."
