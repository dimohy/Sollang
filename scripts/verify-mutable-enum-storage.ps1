[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot), [switch]$Baseline)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$source = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Utilities.cs'
$selfhostSlots = Join-Path $root 'selfhost/llvm/text/entry_expressions.slg'
$selfhostStores = Join-Path $root 'selfhost/llvm/text/functions.slg'
$fixture = Join-Path $root 'examples/regression/1730-mutable-enum-control-storage.slg'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/mutable-enum-storage-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'
$hashes = [ordered]@{}
foreach ($path in @($compiler,$source,$fixture,$PSCommandPath,$selfhostSlots,$selfhostStores)) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$record = [ordered]@{ schemaVersion=1; status='running'; mode=$(if($Baseline){'baseline'}else{'candidate'}); completed=0; total=$(if($Baseline){2}else{6}); inputHashes=$hashes; checks=@(); integration='selfhost structural parity only; selfhost native and final Stage pending' }
function Save { [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n")) }
function Pass([string]$name) { $record.completed++; $record.checks += $name; Save }
try {
    Save
    Add-Type -TypeDefinition @'
public static class MutableEnumReference {
    enum Choice { First = 1, Second, Third }
    static int Select(bool enabled, bool alternative) => (int)(enabled ? Choice.Second : alternative ? Choice.Third : Choice.First);
    static int Cycle(int count) => 1 + count % 3;
    static int Payload(bool enabled) { int? value = enabled ? 9 : null; return value ?? -1; }
    public static string Run() =>
        $"branch={Select(true,false)},{Select(false,false)}\n" +
        $"else={Select(true,true)},{Select(false,true)}\n" +
        $"loop={Cycle(0)},{Cycle(1)},{Cycle(2)},{Cycle(3)}\n" +
        $"payload={Payload(true)},{Payload(false)}\n" +
        $"direct={Select(true,false)}\nentry={(int)Choice.Third}\n";
}
'@
    $expected = [MutableEnumReference]::Run()
    [IO.File]::WriteAllText((Join-Path $output 'reference.stdout.txt'),$expected)
    $exe = Join-Path $output 'mutable-enum.exe'
    $actual = (& dotnet $compiler run $fixture --llvm $llvm -o $exe --keep-temps -O0 2>&1) -join "`n"
    $exit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'native.log'),$actual + "`n")
    if ($exit -ne 0 -or $actual -match '(?m)^(warning S|note N)' -or -not (Test-Path -LiteralPath $exe)) { throw "Mutable enum native run failed: $actual" }
    $actual = $actual.Replace("`r`n","`n").TrimEnd("`n") + "`n"
    $record.observed = $actual
    $record.expected = $expected
    $record.nativeExitCode = $exit
    if ($Baseline) {
        if ($actual -ceq $expected -or $actual -notmatch '(?m)^branch=1,1$' -or $actual -notmatch '(?m)^direct=2$') { throw 'Frozen baseline did not reproduce lost mutable enum storage with its working direct control' }
        Pass 'baseline-native-lost-enum-with-working-direct-control'
    } else {
        if ($actual -cne $expected) { throw "Mutable enum native differs from independent state sequence: $actual" }
        Pass 'native-exact-six-observations'
        $ir = [IO.Path]::ChangeExtension($exe,'.ll')
        & (Join-Path $llvm 'bin/llvm-as.exe') $ir -o (Join-Path $output 'mutable-enum.bc')
        if ($LASTEXITCODE -ne 0) { throw 'Mutable enum LLVM assembly failed' }
        & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $ir
        Pass 'llvm-assembly-and-direct-call-closure'
        $text = [IO.File]::ReadAllText($ir)
        $bodies = [regex]::Matches($text,'(?ms)^define internal [^\r\n]* @sollang_fn_(make|makeElse|makeLoop|makePayload)\([^\n]*\).*?^}')
        if ($bodies.Count -ne 4) { throw 'Expected exactly four mutable enum consumers' }
        foreach ($body in $bodies) {
            if ($body.Value -notmatch 'mutable_scalar_slot' -or
                $body.Value -notmatch 'load %sollang\.enum\.' -or
                $body.Value -notmatch 'store %sollang\.enum\..*, ptr %mutable_scalar_slot') { throw "Missing enum slot/load/store in $($body.Groups[1].Value)" }
        }
        $record.enumConsumerBodyCount = $bodies.Count
        Pass 'four-enum-consumer-slot-load-store'
        $scalar = Join-Path $root 'examples/regression/90-while-mutable-scalars.slg'
        $scalarExpected = Join-Path $root 'examples/regression/expected/90-while-mutable-scalars.stdout.txt'
        $record.scalarFixtureHash = (Get-FileHash -LiteralPath $scalar -Algorithm SHA256).Hash
        $record.scalarExpectedHash = (Get-FileHash -LiteralPath $scalarExpected -Algorithm SHA256).Hash
        $scalarOutput = (& dotnet $compiler run $scalar --llvm $llvm -o (Join-Path $output 'scalar.exe') --keep-temps -O0 2>&1) -join "`n"
        $scalarExit = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output 'scalar.log'),$scalarOutput + "`n")
        if ($scalarExit -ne 0 -or ($scalarOutput.Replace("`r`n","`n").TrimEnd("`n") + "`n") -cne [IO.File]::ReadAllText($scalarExpected).Replace("`r`n","`n")) { throw 'Existing mutable scalar90 native regression failed' }
        Pass 'existing-mutable-scalar90-native-exact'
        # Structural parity only: the selfhost allocator is rooted in the
        # mutable-binding flag, not a hand-maintained runtime-shape allowlist.
        $slotBodies = [regex]::Matches([IO.File]::ReadAllText($selfhostSlots),'(?ms)^emitScheduledMutableSlots [^\r\n]*\{.*?^\}')
        $storeBodies = [regex]::Matches([IO.File]::ReadAllText($selfhostStores),'(?ms)^            expression.kind == 17 and expression.flags == 1\r?\n.*?(?=^            expression.kind == 24)')
        if ($slotBodies.Count -ne 1 -or $storeBodies.Count -ne 1) { throw 'Expected one selfhost mutable-slot declaration and one typed-store consumer' }
        $slots = $slotBodies[0].Value
        $stores = $storeBodies[0].Value
        if ($slots -notmatch 'entryMutableSlotCandidate.kind == 17 and entryMutableSlotCandidate.flags == 1\s+-> if' -or
            $slots -notmatch 'entryMutableSlotRoot == entryMutableSlotIndex!\s+-> if' -or
            [regex]::Matches($slots,'-> if').Count -ne 2 -or
            $slots -notmatch 'entryMutableSlotCandidate -> writeIrType\(context, state\)' -or
            $slots -notmatch 'entryMutableSlotCandidate -> storageAlign\(context, state\)' -or
            $slots -match '(?i)enum|typeId|valueType') { throw 'Selfhost mutable-slot eligibility is no longer type-unrestricted' }
        if ($stores -notmatch '"  store " -> print\s+mutableBinding -> writeIrType\(context, state\)' -or
            $stores -notmatch 'mutableRoot -> writeMutableStoragePointer\(functionIndex, context, state\)' -or
            $stores -notmatch 'mutableBinding -> storageAlign\(context, state\)' -or
            $stores -match '(?i)enum|typeId|valueType') { throw 'Selfhost mutable store is no longer common typed storage' }
        [IO.File]::WriteAllText((Join-Path $output 'selfhost-slot-declaration.slg'),$slots + "`n")
        [IO.File]::WriteAllText((Join-Path $output 'selfhost-store-consumer.slg'),$stores + "`n")
        $record.selfhostParity = [ordered]@{kind='structural-not-native';slotDeclarationCount=1;typedStoreConsumerCount=1;slotControlPredicateCount=2;typeEligibilityRestrictions=0}
        Pass 'selfhost-common-typed-slot-store-structural-parity'
    }
    foreach ($path in $hashes.Keys) { if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $hashes[$path]) { throw "Input drift: $path" } }
    Pass 'input-hash-stability'
    if ($record.completed -ne $record.total) { throw 'Mutable enum gate denominator mismatch' }
    $record.status = 'completed'
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    $record.llvmSha256 = (Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($exe,'.ll')) -Algorithm SHA256).Hash
    Save
    Write-Output "PASS $($record.completed)/$($record.total) $resultPath"
} catch {
    $record.status = 'failed'; $record.failure = $_.Exception.Message; Save; throw
}
