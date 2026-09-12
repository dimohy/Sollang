[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$WslDistribution = 'Ubuntu'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$module = Join-Path $root 'stdlib/std/text/json.slg'
$contract = Join-Path $root 'scripts/contracts/json-typed-model.json'
$probe = Join-Path $root 'scripts/probes/json-typed-model/model-mapping.slg'
$expected = Join-Path $root 'scripts/probes/json-typed-model/model-mapping.stdout.txt'
$writerProbe = Join-Path $root 'scripts/probes/json-typed-model/model-writing.slg'
$writerExpected = Join-Path $root 'scripts/probes/json-typed-model/model-writing.stdout.txt'
$focused = Join-Path $root 'scripts/verify-json-typed-model.ps1'
$formatter = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$browserRunner = Join-Path $root 'scripts/verify-uri-browser-program.mjs'
$closure = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$dotnet = (Get-Command dotnet -CommandType Application -ErrorAction Stop).Source
$node = (Get-Command node -CommandType Application -ErrorAction Stop).Source
$wsl = (Get-Command wsl.exe -CommandType Application -All -ErrorAction Stop |
    Where-Object { $_.Source -like '*\System32\wsl.exe' } | Select-Object -First 1).Source
if ([string]::IsNullOrWhiteSpace($wsl)) { throw 'System32 wsl.exe was not found' }
$scratch = Join-Path $root ('artifacts/scratch/json-typed-model-targets-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$resultPath = Join-Path $scratch 'result.json'
$fixtureSpecs = @(
    [pscustomobject]@{ Id = 'model-mapping'; Source = $probe; Expected = $expected; SourceHash = '3A6A4BE5000DBB28DF867D1274DDA37470B9AA191EEAF02EE438DA42F8B38516'; ExpectedHash = 'F8C1FA011BB9F308F38DAA6AB3D7AD57A6311A40F8F4DB2006F6ED5B65FAF4AE' },
    [pscustomobject]@{ Id = 'model-writing'; Source = $writerProbe; Expected = $writerExpected; SourceHash = 'A21A9941CB6B4F4ED43A106C16C584B0F2CEF08EF1711DBA0A69954FE0FC8CD2'; ExpectedHash = '3ACE53374C0BEC5900D29797A4DBA58A39D0AC51DF2F706B5E3041C648DFC978' },
    [pscustomobject]@{ Id = '1036-json-token-reader'; Source = (Join-Path $root 'examples/regression/1036-json-token-reader.slg'); Expected = (Join-Path $root 'examples/regression/expected/1036-json-token-reader.stdout.txt'); SourceHash = '070D28BF648D3008B28BC968DC7604555529E363F0DCC0B94FDA093FD2AC6EAB'; ExpectedHash = '0F9A45F42686A2007C9D8F00E7534D4DA63D326EB45E9CDB5D2E8953CEA9E59B' },
    [pscustomobject]@{ Id = '1041-json-token-writer'; Source = (Join-Path $root 'examples/regression/1041-json-token-writer.slg'); Expected = (Join-Path $root 'examples/regression/expected/1041-json-token-writer.stdout.txt'); SourceHash = 'F476F790339CBAB12EC7FABBAF254849F6AF227D889AA3CE5985BBA56BD2143A'; ExpectedHash = '3F35AB46864DE311B5321A90516F4EF99AB641E32EEC920A0FC5C786DFF5121D' },
    [pscustomobject]@{ Id = '1707-json-integer-conversion'; Source = (Join-Path $root 'examples/regression/1707-json-integer-conversion.slg'); Expected = (Join-Path $root 'examples/regression/expected/1707-json-integer-conversion.stdout.txt'); SourceHash = 'F6931B442672F689E58771A39B2B4DCA7C36134BD7AA025A698295ABAC6E8948'; ExpectedHash = '424FF317056B9539491E7D0A2B214D1CEB295DA8B17B9543D4730D51A234090F' },
    [pscustomobject]@{ Id = '1710-json-boolean-null-conversion'; Source = (Join-Path $root 'examples/regression/1710-json-boolean-null-conversion.slg'); Expected = (Join-Path $root 'examples/regression/expected/1710-json-boolean-null-conversion.stdout.txt'); SourceHash = 'E16A54BE0AC185E22F096AC902947C5492F7B4800530FDDF248ADF00CA49EB7B'; ExpectedHash = '405A8895EDBE6F4AABE2C258B848C4C561B644F727690B922B7131D06DC26680' },
    [pscustomobject]@{ Id = '1714-json-skip-value'; Source = (Join-Path $root 'examples/regression/1714-json-skip-value.slg'); Expected = (Join-Path $root 'examples/regression/expected/1714-json-skip-value.stdout.txt'); SourceHash = 'BB1F0E0D10302E881FC3C15D7F63D289E602922A015DC4196CBD9AA7DE05E944'; ExpectedHash = 'BB2B03514868D122CF56850B7687CB42AFB17333967E5853DD3B160046922B87' }
)
$inputs = @($compiler, $module, $contract, $probe, $expected, $writerProbe, $writerExpected, $focused, $formatter, $browserRunner, $closure, $dotnet, $node, $wsl, (Join-Path $llvm 'bin/llvm-as.exe'), $PSCommandPath)
$inputs += @($fixtureSpecs | Select-Object -Skip 2 | ForEach-Object { $_.Source; $_.Expected })
$distinctInputs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$hashes = [ordered]@{}
$record = [ordered]@{
    schemaVersion = 1
    scope = 'managed-json-typed-model-windows-linux-browser'
    status = 'running'
    completed = 0
    total = 26
    targetCompleted = 0
    targetTotal = 21
    failureIds = @()
    artifactDirectory = $scratch
    inputHashes = $hashes
    checks = @()
    targets = @()
    residual = @('schema-driven-user-model-mapping', 'float32-float64-conversion-policy', 'fixed-decimal-type-and-conversion-policy')
}
function Write-Record {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 10) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Write-Record
}
function Invoke-Process {
    param([string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory = $root)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "process did not start: $FilePath" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill($true)
            $process.WaitForExit(10000) | Out-Null
            throw "process exceeded 60000ms: $FilePath"
        }
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = $stdoutTask.GetAwaiter().GetResult()
            Stderr = $stderrTask.GetAwaiter().GetResult()
        }
    } finally { $process.Dispose() }
}
function Normalize-ActualOutput([string]$Text) {
    $normalized = $Text.Replace("`r`n", "`n")
    if ($normalized.EndsWith("`n", [StringComparison]::Ordinal)) {
        return $normalized.Substring(0, $normalized.Length - 1)
    }
    $normalized
}
function Read-CanonicalExpected([string]$Path) {
    [byte[]]$bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        throw "JSON expected output must be BOM-free UTF-8: $Path"
    }
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    if ($text.Contains("`r", [StringComparison]::Ordinal) -or -not $text.EndsWith("`n", [StringComparison]::Ordinal) -or
        $text.EndsWith("`n`n", [StringComparison]::Ordinal)) {
        throw "JSON expected output must use LF and exactly one terminal newline: $Path"
    }
    $text.Substring(0, $text.Length - 1)
}
function Convert-ToWslPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    "/mnt/$($full.Substring(0, 1).ToLowerInvariant())/$($full.Substring(3).Replace([char]92, [char]47))"
}

try {
    foreach ($input in $inputs) {
        if (-not (Test-Path -LiteralPath $input -PathType Leaf)) { throw "JSON target input missing: $input" }
        if (-not $distinctInputs.Add([IO.Path]::GetFullPath($input))) { throw "JSON target duplicate input identity: $input" }
        $hashes[$input] = (Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash
    }
    foreach ($fixtureSpec in $fixtureSpecs) {
        if ($hashes[$fixtureSpec.Source] -cne $fixtureSpec.SourceHash -or $hashes[$fixtureSpec.Expected] -cne $fixtureSpec.ExpectedHash) {
            throw "JSON target fixture tuple differs from the independent source/expected matrix: $($fixtureSpec.Id)"
        }
    }
    $declaredContract = [IO.File]::ReadAllText($contract) | ConvertFrom-Json
    $fixedTargets = @('windows-x64', 'linux-x64', 'wasm32-browser')
    $fixedBrowserImports = @('env:sollang_browser_alloc', 'env:sollang_browser_realloc', 'env:memset', 'env:memcpy', 'env:sollang_browser_write', 'env:sollang_browser_panic')
    if ((@($declaredContract.targetMatrix.targets) -join "`n") -cne ($fixedTargets -join "`n") -or
        -not $declaredContract.targetMatrix.sameExactOutput -or
        (@($declaredContract.targetMatrix.browserAllowedImports) -join "`n") -cne ($fixedBrowserImports -join "`n")) {
        throw 'JSON target matrix differs from the independent fixed target/import contract'
    }
    & $formatter -Check -Source @($module, $probe, $writerProbe)
    if ($LASTEXITCODE -ne 0) { throw 'JSON target authoritative format failed' }
    Complete-Check 'authoritative-format'
    $focusedResult = Invoke-Process (Get-Command pwsh).Source @('-NoProfile', '-File', $focused, '-RepositoryRoot', $root)
    if ($focusedResult.ExitCode -ne 0 -or $focusedResult.Stdout -cnotmatch '\[JSON typed model\] PASS 5/5;') {
        throw "JSON Windows focused verifier failed: $($focusedResult.Stderr)$($focusedResult.Stdout)"
    }
    Complete-Check 'windows-static-and-focused-contract'

    $targetSpecs = @(
        [pscustomobject]@{ Name = 'windows-x64'; Suffix = 'windows.exe' },
        [pscustomobject]@{ Name = 'linux-x64'; Suffix = 'linux' },
        [pscustomobject]@{ Name = 'wasm32-browser'; Suffix = 'browser.wasm' }
    )
    $llvmPaths = [Collections.Generic.List[string]]::new()
    $artifacts = [Collections.Generic.List[object]]::new()
    foreach ($fixtureSpec in $fixtureSpecs) {
      $expectedText = Read-CanonicalExpected $fixtureSpec.Expected
      foreach ($target in $targetSpecs) {
        $artifact = Join-Path $scratch "$($fixtureSpec.Id).$($target.Suffix)"
        $compile = Invoke-Process $dotnet @($compiler, 'build', $fixtureSpec.Source, '--target', $target.Name, '-O0', '--llvm', $llvm, '-o', $artifact, '--keep-temps')
        if ($compile.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($compile.Stderr) -or
            $compile.Stdout -match '(?im)^\s*(warning|note)\b' -or -not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
            throw "JSON $($target.Name) warning-free build failed: $($compile.Stderr)$($compile.Stdout)"
        }
        $ir = [IO.Path]::ChangeExtension($artifact, '.ll')
        if (-not (Test-Path -LiteralPath $ir -PathType Leaf)) { throw "JSON $($target.Name) LLVM is missing: $ir" }
        $llvmPaths.Add($ir)
        if ($target.Name -eq 'windows-x64') {
            $execution = Invoke-Process $artifact @()
            $actual = Normalize-ActualOutput $execution.Stdout
            $detail = [ordered]@{ fixture = $fixtureSpec.Id; target = $target.Name; outputBytes = [Text.Encoding]::UTF8.GetByteCount($execution.Stdout); imports = @() }
        } elseif ($target.Name -eq 'linux-x64') {
            $execution = Invoke-Process $wsl @('-d', $WslDistribution, '--', (Convert-ToWslPath $artifact))
            $actual = Normalize-ActualOutput $execution.Stdout
            $detail = [ordered]@{ fixture = $fixtureSpec.Id; target = $target.Name; outputBytes = [Text.Encoding]::UTF8.GetByteCount($execution.Stdout); imports = @() }
        } else {
            $execution = Invoke-Process $node @($browserRunner, $artifact, $fixtureSpec.Expected)
            $browser = $execution.Stdout | ConvertFrom-Json
            $actual = $expectedText
            $imports = @($browser.imports)
            if ($browser.status -cne 'passed' -or @($imports | Where-Object { $fixedBrowserImports -cnotcontains $_ }).Count -ne 0 -or
                @($imports | Sort-Object -Unique).Count -ne $imports.Count) {
                throw 'JSON browser execution or import allowlist failed'
            }
            $detail = [ordered]@{ fixture = $fixtureSpec.Id; target = $target.Name; outputBytes = $browser.outputBytes; imports = $imports }
        }
        if ($execution.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($execution.Stderr) -or $actual -cne $expectedText) {
            throw "JSON $($target.Name) exact execution failed: $($execution.Stderr)$($execution.Stdout)"
        }
        $detail.artifactSha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
        $detail.llvmSha256 = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
        $record.targets += $detail
        $artifacts.Add([pscustomobject]@{ Target = $target.Name; Path = $artifact })
        $record.targetCompleted++
        Complete-Check "$($fixtureSpec.Id)-$($target.Name)-warning-free-build-and-exact-run"
      }
    }

    foreach ($artifactEntry in $artifacts) {
        [byte[]]$bytes = [IO.File]::ReadAllBytes($artifactEntry.Path)
        $identityMatches = switch ($artifactEntry.Target) {
            'windows-x64' { $bytes[0] -eq 77 -and $bytes[1] -eq 90 }
            'linux-x64' { $bytes[0] -eq 127 -and $bytes[1] -eq 69 -and $bytes[2] -eq 76 -and $bytes[3] -eq 70 }
            'wasm32-browser' { $bytes[0] -eq 0 -and $bytes[1] -eq 97 -and $bytes[2] -eq 115 -and $bytes[3] -eq 109 }
        }
        if (-not $identityMatches) { throw "JSON target artifact identity failed: $($artifactEntry.Path)" }
    }
    Complete-Check 'target-artifact-identities'
    foreach ($ir in $llvmPaths) {
        & (Join-Path $llvm 'bin/llvm-as.exe') $ir -o ([IO.Path]::ChangeExtension($ir, '.bc'))
        if ($LASTEXITCODE -ne 0) { throw "JSON target LLVM assembly failed: $ir" }
        & $closure -LlvmPath $ir
        if ($LASTEXITCODE -ne 0) { throw "JSON target direct-call closure failed: $ir" }
    }
    Complete-Check 'all-target-llvm-assembly-and-direct-call-closure'
    foreach ($input in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash -cne $hashes[$input]) {
            throw "JSON target input changed during execution: $input"
        }
    }
    $record.inputsStable = $true
    Complete-Check 'input-hash-stability'
    if ($record.completed -ne $record.total -or $record.targetCompleted -ne $record.targetTotal) {
        throw 'JSON target verifier denominator drifted'
    }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failureIds = @('JSON_TARGET_MATRIX_FAILED')
    $record.failure = $_.Exception.Message
    throw
} finally {
    Write-Record
    Write-Host "[JSON typed-model targets] $($record.status) $($record.completed)/$($record.total), targets $($record.targetCompleted)/$($record.targetTotal); $resultPath"
}
