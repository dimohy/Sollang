[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$Label,
    [ValidateSet("windows", "linux")][string]$Platform = "windows",
    [string]$Distribution = "Ubuntu",
    [Parameter(Mandatory)][string]$LlvmRoot,
    [Parameter(Mandatory)][string]$StdlibRoot,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 64)][int]$Jobs = 4,
    [ValidateRange(1, 64)][int]$MinimumCompilerJobs = 1,
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 3600000,
    [switch]$ValidateInputsOnly,
    [string[]]$Fixture = @(
        "1094-io-memory-reader-writer",
        "1184-non-process-collect-has-no-process-runtime",
        "1185-selfhost-projected-receiver-instance-call",
        "1186-selfhost-interpolation-projected-call-topology",
        "1187-selfhost-raw-string-no-interpolation",
        "1188-io-memory-reader-caller-buffer",
        "1189-selfhost-member-assignment-after-while",
        "1196-selfhost-cross-fragment-ref-dynamic-array",
        "1192-readonly-captured-nested-parameter-projection",
        "1193-struct-field-collection-binding-baseline",
        "1194-struct-field-collection-binding-perturbed",
        "1198-parallel-transferable-struct-worker",
        "1199-local-function-parallel-callback",
        "1200-parallel-nominal-readonly-captures",
        "1201-parallel-move-parameter",
        "1202-array-element-owner-replacement-after-read",
        "1203-selfhost-enum-payload-binary-binding",
        "1204-selfhost-enum-payload-binary-binding-permuted",
        "1206-quic-bidirectional-multi-stream-routing",
        "1207-enum-owned-payload-projected-queue",
        "1208-multiline-projected-assignment",
        "1209-quic-connection-options-queue-limits",
        "1210-quic-directional-control-frames",
        "1211-quic-directional-owner-transitions",
        "1212-selfhost-member-assignment-after-take",
        "1213-selfhost-result-field-transfer-after-take",
        "1214-gzip-transactional-streaming-decoder",
        "1215-gzip-incremental-byte-boundaries",
        "1216-late-indexed-element-array-type",
        "1217-selfhost-late-indexed-array-type-contract",
        "1220-zstd-raw-rle-streaming",
        "1221-numeric-subject-when-arm-result",
        "1222-selfhost-numeric-subject-when-binding",
        "1223-contextual-intrinsic-instance-precedence",
        "1228-xxhash64-streaming",
        "1229-http-body-framing",
        "1336-http-body-range-leftover",
        "1337-contextual-member-assignment",
        "1338-http-request-body-cursor",
        "1339-http-empty-request-body",
        "1340-selfhost-result-arm-owned-field-transfer",
        "1341-http-persistent-pipeline",
        "1382-selfhost-terminal-flow-control-return",
        "1383-selfhost-inferred-receiver-method-owner",
        "1380-selfhost-final-binding-return-selection",
        "1381-selfhost-terminal-return-only-if",
        "1384-nested-result-logical-condition",
        "1354-selfhost-read-before-direct-self-consume",
        "1230-selfhost-short-circuit-array-argument",
        "1231-selfhost-nested-result-match-value",
        "1232-selfhost-console-call-owns-if-result",
        "1233-http-response-head-writer",
        "1385-http-request-head-writer",
        "1386-http-client-connection-reuse",
        "1389-selfhost-nested-aggregate-partial-move-cleanup",
        "1391-opaque-struct-instance-boundary",
        "1392-selfhost-opaque-struct-ast",
        "1352-selfhost-consuming-call-owned-outcome",
        "1234-selfhost-parallel-nested-flow-arguments",
        "1236-socket-send-range-all",
        "1240-http-one-request-server",
        "1335-http-server-local-endpoint",
        "1245-brotli-uncompressed-foundation",
        "1246-brotli-prefix-table",
        "1247-brotli-prefix-code-parser",
        "1248-brotli-context-map",
        "1249-brotli-tree-group",
        "1250-brotli-compressed-header",
        "1251-brotli-literal-context",
        "1252-brotli-command-executor",
        "1253-readonly-self-consecutive-owned-enum-fields",
        "1254-brotli-literal-context-values",
        "1396-selfhost-binary-operand-topology",
        "1397-selfhost-while-chained-wide-match-result",
        "1398-selfhost-borrowed-enum-payload-lifetime",
        "1399-selfhost-move-parameter-enum-field-transfer",
        "1400-selfhost-nested-consuming-local-cleanup",
        "1401-selfhost-reserve-before-aggregate-transfer",
        "1402-selfhost-entry-match-effect-order",
        "1403-selfhost-fresh-directory-payload-cleanup",
        "1256-postfix-match-arm-contextual-result",
        "1258-brotli-command-history",
        "1259-brotli-bulk-compressed",
        "1261-selfhost-mut-result-enum-rematch",
        "1263-brotli-compressed-prelude-stream",
        "1265-brotli-simple-prefix-description-stream",
        "1266-brotli-complex-prefix-description-stream",
        "1267-mutable-name-suffix-resolution",
        "1268-brotli-complex-prefix-repeat-stream",
        "1269-brotli-context-map-stream",
        "1270-brotli-tree-group-stream",
        "1271-brotli-command-stream",
        "1272-brotli-command-block-switch-stream",
        "1273-brotli-static-dictionary",
        "1274-brotli-block-stream-reader",
        "1275-brotli-header-reader-prelude",
        "1276-nested-owned-field-transfer",
        "1277-brotli-context-reader",
        "1278-brotli-tree-reader",
        "1279-brotli-decoder-compressed-stream",
        "1280-mutable-owned-projection-enum-transfer",
        "1264-selfhost-late-numeric-payload-subject",
        "1291-quic-unidirectional-stream-registry",
        "1292-selfhost-unary-not-enum-match-value",
        "1297-quic-unidirectional-stream-owners",
        "1300-quic-bounded-stream-reassembly",
        "1301-quic-reassembly-final-size-rejected",
        "1302-selfhost-imported-mutable-receiver-rebind",
        "1303-quic-reassembly-account-loop",
        "1304-zstd-literal-only-compressed-block",
        "1305-selfhost-interpolation-numeric-separator",
        "1306-zstd-direct-huffman-literals",
        "1309-selfhost-terminating-if-branch-result",
        "1308-selfhost-nested-result-many-argument-owner",
        "1321-parallel-additional-borrow-result",
        "1388-selfhost-imported-ref-struct-value-receiver",
        "1394-selfhost-when-binding-reassignment",
        "1310-zstd-fse-foundation",
        "1311-zstd-rle-sequence",
        "1312-zstd-sequence-frame",
        "1313-zstd-compressed-fse-frame",
        "945-quic-flow-control-frames",
        "1378-socket-reactor-wait-into",
        "1379-selfhost-nested-control-implicit-return",
        "1404-function-tail-each-statement",
        "1405-selfhost-collection-comprehension-syntax",
        "1406-selfhost-constant-integer-arithmetic",
        "1407-module-local-enum-identity",
        "1408-selfhost-qualified-value-shadow",
        "1409-import-qualified-enum-pattern",
        "1410-selfhost-constant-expression-plan",
        "1411-borrowed-receiver-error-reuse",
        "1412-direct-result-control-match",
        "1413-selfhost-constant-collection-expansion",
        "1414-module-local-range-identity",
        "1415-imported-result-projected-each-element",
        "1416-result-match-propagation-producer",
        "1417-imported-result-match-propagation",
        "1418-function-enum-constructor-call-chain",
        "1419-selfhost-constant-collection-lowering",
        "1420-owned-flow-result-preserves-input",
        "1421-early-return-aggregate-move-input",
        "1422-owned-enum-payload-block-result",
        "1423-disjoint-owned-field-transfer",
        "1424-nested-each-interpolation",
        "1425-nested-match-result-constructor",
        "1426-dictionary-index-interpolation",
        "1427-enum-reference-payload-forwarding",
        "1428-mutable-scalar-readonly-reference",
        "1429-tap-side-call-argument-plan",
        "1430-tap-explicit-side-chain",
        "1431-trait-constant-method-receiver",
        "1432-dyn-trait-reachable-implementations"
        "1433-parallel-existing-role-array-references"
        "1434-multistage-console-wrapper"
        "1435-dyn-result-console-wrapper"
        "1436-user-printer-method-flow"
        "1437-generic-inherent-method"
        "1438-generic-method-inference-types"
        "1439-generic-method-trait-constraint"
        "1440-generic-method-owner-scope"
        "1441-generic-function-concrete-abi"
        "1442-selfhost-generic-multi-input-unification"
        "1443-selfhost-generic-method-call-type-isolation",
        "1444-each-mutable-nested-control",
        "1445-each-role-projected-readonly-array",
        "1446-member-assignment-lexical-sibling",
        "1447-generic-trait-constraint-isolation",
        "1448-nested-generic-method-helper",
        "1449-recursive-generic-call-closure",
        "1450-selfhost-generic-closure-reuse",
        "1451-dictionary-absent-instance-result",
        "1452-each-call-result-record-type",
        "1453-each-push-return-alias",
        "1454-trait-imported-collision-main",
        "1455-trait-contract-buffer",
        "1456-trait-associated-array",
        "1457-trait-associated-dictionary",
        "1458-trait-associated-result",
        "1459-trait-associated-fixed",
        "1460-fixed-array-length-preservation",
        "1461-indexed-owned-readonly-positive",
        "1462-indexed-owned-additional-readonly-positive",
        "1463-generic-owned-take-positive",
        "1464-generic-owned-nested-take-positive",
        "1465-chained-match-fixed-enum-array",
        "1466-moving-fixed-array-implicit-cleanup",
        "1467-moving-fixed-array-explicit-cleanup",
        "1468-arena-explicit-return",
        "1469-region-array-scalar-parameters",
        "1470-region-array-bool-literals",
        "1471-region-array-readonly-values",
        "1472-region-array-owned-transfer",
        "1473-struct-initializer-effect-order",
        "1474-array-capacity-hint-contexts",
        "1475-region-array-partial-field-transfer",
        "1476-entry-mutable-binding-scope",
        "1486-interpolation-capacity-receivers",
        "29-typed-empty-containers",
        "58-owned-element-fixed-arrays",
        "1001-fixed-repeat-inside-while",
        "1072-entry-fixed-repeat-struct-field",
        "1477-typed-record-array-field-identity",
        "1480-direct-repeat-readonly-slice",
        "1482-signed-unary-contexts",
        "1496-wide-integer-array-flow-context",
        "1481-resolved-call-early-return-cleanup",
        "1497-narrow-integer-parameter-print",
        "1498-hmac-streaming-segments",
        "1501-bound-imported-method-owner",
        "1502-same-call-projected-owner-controls",
        "1503-nested-call-statement-effect-order",
        "1504-readonly-fixed-call-temporary-cleanup",
        "1505-readonly-independent-copy-cleanup",
        "1506-readonly-owned-element-temporary-cleanup",
        "1507-empty-unit-function-contract",
        "1508-named-fixed-named-reuse-cleanup",
        "1509-named-fixed-stack-literal-cleanup",
        "1510-named-fixed-implicit-return-cleanup",
        "1511-named-fixed-explicit-return-cleanup",
        "1512-named-fixed-early-scalar-return-cleanup",
        "1513-named-fixed-owned-element-named-cleanup",
        "1514-named-fixed-moved-owner-cleanup",
        "1515-named-fixed-ref-return-cleanup",
        "1516-named-fixed-before-binding-return-cleanup",
        "1517-named-fixed-loop-region-cleanup",
        "1518-local-function-intrinsic-collision",
        "1519-fixed-stack-argument-return",
        "1520-fixed-named-argument-return",
        "1521-fixed-implicit-moving-wrapper",
        "1522-fixed-explicit-moving-wrapper",
        "1523-fixed-owned-explicit-wrapper",
        "1524-fixed-owned-implicit-wrapper",
        "1525-fixed-additional-argument-return",
        "1526-fixed-branch-explicit-return",
        "1527-projected-table-push-loop",
        "1528-fixed-field-factory",
        "1529-fixed-field-named",
        "1530-fixed-field-stack",
        "1531-fixed-field-owned",
        "1532-fixed-field-region",
        "1533-fixed-branch-binding",
        "1534-fixed-branch-loop-binding",
        "1535-branch-value-owner",
        "1536-branch-value-fixed",
        "1537-branch-fixed-mixed-storage",
        "1538-branch-fixed-outer-reuse",
        "1539-branch-fixed-owned-elements",
        "1540-branch-fixed-mutable-local",
        "1541-branch-fixed-return",
        "1542-entry-branch-lifetime",
        "1543-fixed-int-branch-result",
        "1544-fixed-text-branch-result",
        "1545-fixed-field-copy-independence",
        "1546-logical-flow-bool",
        "1547-owned-branch-taken",
        "1548-owned-nested-terminating-branch",
        "1549-owned-when-terminating-branch",
        "1552-async-console-capability",
        "1553-projected-push-sibling-reuse",
        "1554-borrowed-fixed-field-copy-independence",
        "1555-generic-stream-consumer-call-identity",
        "1556-generic-inherent-open-import-precedence",
        "1562-nested-bool-region-short-circuit-effects",
        "1563-borrowed-fixed-return-copy-independence",
        "1564-borrowed-nested-fixed-field-copy-independence",
        "1567-borrowed-temporary-record-cleanup",
        "1568-borrowed-named-record-reuse",
        "1569-borrowed-flow-temporary-cleanup",
        "1570-borrowed-temporary-enum-cleanup",
        "1571-borrowed-temporary-independent-result",
        "1572-borrowed-nested-flow-argument-cleanup",
        "1573-named-mutable-receiver-borrow-reuse",
        "1574-consuming-temporary-receiver-cleanup",
        "1575-borrowed-enum-variant-tag-cleanup",
        "1576-consuming-enum-match-cleanup",
        "1577-consuming-enum-payload-transfer",
        "1578-borrowed-named-enum-reuse",
        "1579-borrowed-record-literal-cleanup",
        "1580-borrowed-array-literal-cleanup",
        "1581-borrowed-enum-literal-cleanup",
        "1592-late-contextual-array-boundaries",
        "1602-stream-mapped-text-flatmap-input",
        "1603-stream-mapped-int-flatmap-arithmetic",
        "1604-stream-mapped-flatmap-direct-roles",
        "1605-stream-mapped-bool-flatmap-input",
        "1606-stream-mapped-uint64-flatmap-input",
        "1607-stream-bool-map-filter-input",
        "1609-parameter-range-text-flatmap",
        "1610-parameter-range-map-flatmap",
        "1611-parameter-range-empty-flatmap",
        "1612-parameter-upper-range-flatmap",
        "1613-function-constant-range-flatmap",
        "1614-parameter-range-direct-each",
        "1598-recursive-enum-heap-owner",
        "1599-recursive-enum-box-layout",
        "1600-nested-enum-owned-payload",
        "1601-nested-result-owned-payload",
        "1619-finite-bounded-array-layout",
        "1620-finite-bounded-dictionary-layout",
        "1615-flatmap-single-receiver-scalar-int",
        "1634-flatmap-single-receiver-text",
        "1635-flatmap-single-receiver-parameter",
        "1636-flatmap-single-receiver-take",
        "1637-flatmap-single-receiver-empty",
        "1638-flatmap-single-receiver-uint64",
        "1639-flatmap-single-receiver-bool",
        "1640-flatmap-single-receiver-range-value",
        "1626-boxed-recursive-enum-cleanup",
        "1627-boxed-enum-named-match-reuse",
        "1628-boxed-enum-payload-transfer",
        "1629-boxed-primitive-cleanup",
        "1630-boxed-nested-cleanup",
        "1642-zero-fixed-recursive-layout",
        "1643-nominal-enum-zero-fixed-payload",
        "1649-static-factory-distinct-owners",
        "1651-enum-integer-payload-boundaries",
        "1658-unused-arguments-runtime",
        "1659-arguments-runtime-lifetime",
        "1660-arguments-runtime-function",
        "1661-arguments-each-layout",
        "1662-nominal-slice-each-direct",
        "1663-nominal-slice-each-function",
        "1664-nominal-slice-each-nested",
        "1665-nominal-slice-each-boundary",
        "1666-arguments-primary-parameter",
        "1667-arguments-additional-parameter",
        "1668-arguments-return-forwarding",
        "1669-arguments-aggregate-storage",
        "1670-arguments-branch-generic",
        "1671-arguments-while-forwarding",
        "1672-arguments-local-capture",
        "1673-imported-struct-enum-field-prefix",
        "1674-owned-field-extraction-repair",
        "1675-owned-field-borrow-preserves-owner",
        "1676-owned-field-replacement-keeps-drop",
        "1677-scalar-enum-copy-with-sibling-text-borrow",
        "1678-nested-enum-payload-move-consumer",
        "1679-nested-enum-payload-borrow-inspection",
        "1621-option-enum-payload-value",
        "1622-nested-option-result-enum-payload",
        "1623-owned-option-enum-payload-cleanup",
        "1624-owned-result-enum-payload-cleanup",
        "1645-runtime-result-nominal-field",
        "1646-owned-runtime-result-field-cleanup",
        "1647-borrowed-runtime-result-field-reuse",
        "1631-boxed-enum-member-consume",
        "1632-boxed-enum-member-borrow-reuse",
        "1633-boxed-temporary-readonly-call",
        "814-concurrent-latest-early-cancellation",
        "816-concurrent-latest-uninitialized-completion",
        "815-stream-join-return-signature-inference",
        "1478-contextual-integer-field-boundaries",
        "1479-conditional-fixed-array-unconsumed-cleanup",
        "857-dictionary-put-if-absent",
        "858-dictionary-put-if-absent-owned",
        "66-generic-dictionary-function-contracts",
        "487-selfhost-borrowed-container-return-analysis",
        "1680-io-shared-caller-buffer-traits",
        "1683-io-bounded-transfer-policy",
        "1682-selfhost-retained-array-branch-moves"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "native-exact-fixture-receipt.ps1")
. (Join-Path $PSScriptRoot "native-exact-batch-allocation.ps1")

Assert-NativeExactFixturePlan -Fixture $Fixture

$verifierPath = Join-Path $PSScriptRoot "verify-native-exact-fixture.ps1"
$requiredInputs = @(
    @{ Path = $Compiler; Type = "Leaf"; Name = "compiler" },
    @{ Path = $LlvmRoot; Type = "Container"; Name = "LLVM root" },
    @{ Path = $StdlibRoot; Type = "Container"; Name = "standard-library root" },
    @{ Path = $RepositoryRoot; Type = "Container"; Name = "repository root" },
    @{ Path = $verifierPath; Type = "Leaf"; Name = "exact-fixture verifier" }
)
foreach ($input in $requiredInputs) {
    if (-not (Test-Path -LiteralPath $input.Path -PathType $input.Type)) {
        throw "native exact batch $($input.Name) is missing or has the wrong kind: $($input.Path)"
    }
}
foreach ($fixtureName in $Fixture) {
    $fixtureSource = Join-Path $RepositoryRoot "examples/regression/$fixtureName.slg"
    if (-not (Test-Path -LiteralPath $fixtureSource -PathType Leaf)) {
        throw "native exact batch fixture input is missing: $fixtureSource"
    }
}
. (Join-Path $PSScriptRoot "native-exact-source-closure.ps1")
$closureFailures = [System.Collections.Generic.List[string]]::new()
foreach ($fixtureName in $Fixture) {
    try {
        Assert-NativeExactCompilerSourceClosure -RepositoryRoot $RepositoryRoot -Fixture $fixtureName
    } catch {
        $closureFailures.Add("${fixtureName}: $($_.Exception.Message)")
    }
}
if ($closureFailures.Count -gt 0) {
    throw "native exact batch source closure failed before compiler launch:`n$($closureFailures -join "`n")"
}
if ($ValidateInputsOnly) {
    Write-Host "[native exact input preflight] PASS $($Fixture.Count) fixture inputs; compilation and execution remain unverified."
    return
}
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmPath = (Resolve-Path -LiteralPath $LlvmRoot).Path
$stdlibPath = (Resolve-Path -LiteralPath $StdlibRoot).Path
$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$commonInputFingerprint = if ($Platform -eq "windows") {
    Get-NativeExactWindowsCommonInputFingerprint `
        -RepositoryRoot $repositoryPath `
        -CompilerPath $compilerPath `
        -StdlibRoot $stdlibPath `
        -LlvmRoot $llvmPath
} else {
    ""
}
$allocation = Get-NativeExactBatchAllocation `
    -Fixture $Fixture `
    -Jobs $Jobs `
    -MinimumCompilerJobs $MinimumCompilerJobs
$parallelism = $allocation.Parallelism
Write-Host "[native exact batch] $Label $Platform runs $($Fixture.Count) fixtures with $parallelism outer workers and a $Jobs-job shared budget."

$results = [System.Collections.Generic.List[object]]::new()
$completedCount = 0
$totalFixtures = $Fixture.Count
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$batchReportPath = Join-Path $outputPath "$Label-batch-results.json"
$batchCompilerHash = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
function Write-NativeExactBatchReport {
    param([ValidateSet('running', 'passed', 'failed')][string]$State)
    $passedCount = @($results | Where-Object Success).Count
    $report = [ordered]@{
        schemaVersion = 1
        label = $Label
        platform = $Platform
        state = $State
        compilerSha256 = $batchCompilerHash
        commonInputFingerprint = $commonInputFingerprint
        completed = $results.Count
        passed = $passedCount
        failed = $results.Count - $passedCount
        missing = $totalFixtures - $results.Count
        total = $totalFixtures
        results = @($results | Select-Object Fixture, Success, Error)
    }
    [IO.File]::WriteAllText($batchReportPath, ($report | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
}
Write-NativeExactBatchReport -State running
$allocation.Items | ForEach-Object -ThrottleLimit $parallelism -Parallel {
    $fixtureName = $_.Fixture
    $jobsPerFixture = $_.CompilerWorkerJobs
    try {
        $transcript = (& $using:verifierPath `
            -Compiler $using:compilerPath `
            -Label $using:Label `
            -Fixture $fixtureName `
            -Platform $using:Platform `
            -Distribution $using:Distribution `
            -LlvmRoot $using:llvmPath `
            -StdlibRoot $using:stdlibPath `
            -RepositoryRoot $using:repositoryPath `
            -OutputDirectory $using:outputPath `
            -Jobs $jobsPerFixture `
            -TimeoutMilliseconds $using:TimeoutMilliseconds `
            -CommonInputFingerprint $using:commonInputFingerprint 2>&1 | Out-String)
        [pscustomobject]@{
            Fixture = $fixtureName
            Success = $true
            Transcript = $transcript
            Error = ""
        }
    } catch {
        [pscustomobject]@{
            Fixture = $fixtureName
            Success = $false
            Transcript = ""
            Error = "$($_.Exception.Message)`n$($_.ScriptStackTrace)".Trim()
        }
    }
} | ForEach-Object {
    $result = $_
    $results.Add($result)
    $completedCount += 1
    Write-NativeExactBatchReport -State running
    $status = if ($result.Success) { "PASS" } else { "FAIL" }
    Write-Host "[native exact batch $completedCount/$totalFixtures] $status $($result.Fixture)."
    if (-not $result.Success) {
        Write-Host "[native exact failure] $($result.Fixture): $($result.Error)"
    }
}

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($fixtureName in $Fixture) {
    $result = $results | Where-Object { $_.Fixture -ceq $fixtureName } | Select-Object -First 1
    if ($null -eq $result) {
        $failures.Add("$fixtureName produced no batch result")
        continue
    }
    if (-not [string]::IsNullOrWhiteSpace($result.Transcript)) {
        Write-Host $result.Transcript.TrimEnd()
    }
    if (-not $result.Success) {
        $failures.Add("$fixtureName`: $($result.Error)")
    }
}

if ($failures.Count -gt 0) {
    Write-NativeExactBatchReport -State failed
    throw "native exact batch failed:`n$($failures -join "`n")"
}

Write-NativeExactBatchReport -State passed
Write-Host "[native exact batch] PASS $Label $Platform $($Fixture.Count) fixtures."
