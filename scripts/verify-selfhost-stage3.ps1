param(
    [switch]$RebuildStage2,
    [ValidateSet("Slg", "ManagedRecovery")]
    [string]$SeedMode = "Slg",
    [string]$SlgSeedCompiler = "",
    [ValidateRange(1, 64)]
    [int]$Jobs = 8,
    [switch]$ResumeCandidate
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "selfhost-verification-lock.ps1")
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
. (Join-Path $PSScriptRoot "stage3-seed-provenance.ps1")
. (Join-Path $PSScriptRoot "input-fingerprint-stability.ps1")
. (Join-Path $PSScriptRoot "verification-process.ps1")
$selfHostVerificationLock = Enter-SelfHostVerificationLock
try {

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$manifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"
$runtimeManifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
$stage1Path = Join-Path $artifactsDir "selfhost-stage1-verification.exe"
$compilerRuntimeSources = Get-Content $runtimeManifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_.Trim() }
$stage2LlvmPath = Join-Path $artifactsDir "selfhost-stage2.ll"
$stage2BitcodePath = Join-Path $artifactsDir "selfhost-stage2.bc"
$stage2Path = Join-Path $artifactsDir "selfhost-stage2.exe"
$stage2FingerprintPath = Join-Path $artifactsDir "selfhost-stage2.inputs.sha256"
$stage2ArtifactReceiptPath = Join-Path $artifactsDir "selfhost-stage2.outputs.sha256"
$stage3LlvmPath = Join-Path $artifactsDir "selfhost-stage3.ll"
$stage3BitcodePath = Join-Path $artifactsDir "selfhost-stage3.bc"
$stage3Path = Join-Path $artifactsDir "selfhost-stage3.exe"
$stage3FingerprintPath = Join-Path $artifactsDir "selfhost-stage3.inputs.sha256"
$stage3ArtifactReceiptPath = Join-Path $artifactsDir "selfhost-stage3.outputs.sha256"
$stage3CandidateFingerprintPath = Join-Path $artifactsDir "selfhost-stage3.candidate.inputs.sha256"
$stage3CandidateArtifactReceiptPath = Join-Path $artifactsDir "selfhost-stage3.candidate.outputs.sha256"
$publishedStage3LlvmPath = $stage3LlvmPath
$publishedStage3BitcodePath = $stage3BitcodePath
$publishedStage3Path = $stage3Path
$stage3ErrorPath = Join-Path $artifactsDir "selfhost-stage3.err.log"
$llvmRoot = Join-Path $repoRoot ".tools\llvm-22.1.8"
$llvmAsPath = Join-Path $llvmRoot "bin\llvm-as.exe"
$clangPath = Join-Path $llvmRoot "bin\clang.exe"
$stdlibRoot = Join-Path $repoRoot "stdlib"
$resultPropagationControlSource = Join-Path $repoRoot "examples\regression\1017-quic-friendly-ipv4-endpoints.slg"
$socketEndpointObservationSource = Join-Path $repoRoot "examples\regression\1117-socket-endpoint-observation.slg"
$socketNoDelaySource = Join-Path $repoRoot "examples\regression\1141-socket-no-delay-instance.slg"
$socketNoDelayExpected = Join-Path $repoRoot "examples\regression\expected\1141-socket-no-delay-instance.stdout.txt"
$timeCheckedArithmeticSource = Join-Path $repoRoot "examples\regression\1119-time-checked-instance-arithmetic.slg"
$timeCheckedArithmeticExpected = Join-Path $repoRoot "examples\regression\expected\1119-time-checked-instance-arithmetic.stdout.txt"
$singleSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-single-smoke.slg"

function Get-NormalizedHash {
    param([string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

function Get-ContentFingerprint {
    param([string[]]$Paths)

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    foreach ($path in $Paths) {
        $relative = [System.IO.Path]::GetRelativePath($repoRoot, $path).Replace("\", "/")
        $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes("$relative`0"))
        $hash.AppendData([System.IO.File]::ReadAllBytes($path))
    }
    return [Convert]::ToHexString($hash.GetHashAndReset())
}

function Get-Stage3CandidateInputFingerprint {
    $stage2ExecutableHash = (Get-FileHash -LiteralPath $stage2Path -Algorithm SHA256).Hash
    $sourceFingerprint = Get-ContentFingerprint $sourcePaths
    $text = "windows`0$stage2ExecutableHash`0$sourceFingerprint"
    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::UTF8.GetBytes($text)))
}

Write-Host "[stage3 policy] Verify the reviewed instance-first stdlib surface."
& (Join-Path $PSScriptRoot "verify-stdlib-instance-policy.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-stdlib-evolution-progress.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-runtime-intrinsic-layout.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-stdlib-module-layout.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-profile-schema.ps1")
& (Join-Path $PSScriptRoot "verify-emit-context-constructor-closure.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-compiler-contracts.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-quic-frame-consumers.ps1") -RepositoryRoot $repoRoot -Jobs 3
& (Join-Path $PSScriptRoot "verify-gzip-stream-api-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-zstd-foundation-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-brotli-foundation-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-body-framing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-portable-memory-io-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-response-writing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-request-writing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-client-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-server-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-compiler-defects.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "show-project-progress.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "format-authoritative-slg.ps1") -Check

Write-Host "[stage3 policy] Fail fast on managed source-style and formatter contracts."
& dotnet run `
    --project (Join-Path $repoRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj") `
    -c Release `
    -- `
    --exact 787-selfhost-file-write-match-subject-ir `
    --exact 1000-selfhost-partition-route-type-invariant `
    --exact 1081-control-condition-inline-limit-accepted `
    --exact 1082-control-condition-inline-limit-note `
    --exact 1083-selfhost-source-style-analysis `
    --exact 1084-selfhost-formatter-raw-indentation `
    --exact 1085-binary-reader-writer-instances `
    --exact 1086-crc32-policy-hasher-instances `
    --exact 1087-crc32-fixed-input-instance-o0 `
    --exact 1088-selfhost-source-style-analysis `
    --exact 1089-unsigned32-interpolation-contexts `
    --exact 1090-gzip-public-crc32-parity `
    --exact 1091-uuid-opt-in-presentations `
    --exact 1092-interpolation-chained-enum-method `
    --exact 1093-interpolation-call-chain-ir `
    --exact 1119-time-checked-instance-arithmetic `
    --exact 1120-selfhost-negated-long-literal-context `
    --exact 1121-selfhost-consecutive-control-consumers `
    --exact 1122-consecutive-control-consumer-runtime `
    --exact 1123-selfhost-materialized-console-call `
    --exact 1124-function-control-consumer-runtime `
    --exact 1125-control-region-consumer-runtime `
    --exact 1126-selfhost-console-emission-invariant `
    --exact 1127-unreachable-parallel-callback `
    --exact 1128-selfhost-late-set-intrinsic-classification `
    --exact 1129-selfhost-control-producer-call-shape `
    --exact 1130-four-term-logical-binding `
    --exact 1131-selfhost-four-term-logical-ir `
    --exact 1132-process-child-wait `
    --exact 1133-process-child-scope-drop `
    --exact 1140-selfhost-directory-intrinsic-ir `
    --exact 1143-enum-match-negative-unary-result `
    --exact 1147-mut-parameter-refresh-after-call `
    --exact 1148-second-mut-parameter-refresh-after-call `
    --exact 1149-control-region-mut-parameter-refresh `
    --exact 1150-while-region-mut-parameter-refresh `
    --exact 1151-mutable-parameter-indexing-matrix `
    --exact 1152-early-return-before-checked-index `
    --exact 1153-checked-index-control-before-logical-result `
    --exact 1157-call-wrapped-checked-index-after-early-return `
    --exact 1154-multiline-redundant-control-parentheses-note `
    --exact 1155-multiline-partial-control-parentheses-preserved `
    --exact 1156-interpolation-readonly-struct-reference `
    --exact 1162-selfhost-zero-argument-mut-receiver `
    --exact 1163-selfhost-method-receiver-metadata `
    --exact 1164-selfhost-unqualified-literal-receiver-resolution `
    --exact 1165-selfhost-method-receiver-invariant `
    --exact 1395-selfhost-aggregate-child-index-rules `
    --exact 1168-qualified-literal-instance-precedence `
    --exact 1169-selfhost-process-instance-precedence `
    --exact 1170-instance-call-after-each-return `
    --exact 1171-process-call-after-each-return `
    --exact 1172-selfhost-qualified-impl-receiver `
    --exact 1173-selfhost-projected-binding-method `
    --exact 987-selfhost-nested-arithmetic-width-contract `
    --exact 1174-selfhost-projected-socket-close-intrinsic `
    --exact 1175-ref-struct-receiver-inside-while `
    --exact 1176-ref-struct-direct-call-forwarding `
    --exact 1177-ref-struct-array-element-assignment `
    --exact 1178-call-result-receiver-before-literal-fallback `
    --exact 1179-process-stdio-file-instance `
    --exact 1180-process-stdio-null-instance `
    --exact 1181-process-status-to-file-configuration `
    --exact 1182-process-bounded-concurrent-capture `
    --exact 1183-process-zero-limit-concurrent-capture `
    --exact 1184-non-process-collect-has-no-process-runtime `
    --exact 1185-selfhost-projected-receiver-instance-call `
    --exact 1186-selfhost-interpolation-projected-call-topology `
    --exact 1187-selfhost-raw-string-no-interpolation `
    --exact 1188-io-memory-reader-caller-buffer `
    --exact 1189-selfhost-member-assignment-after-while `
    --exact 1192-readonly-captured-nested-parameter-projection `
    --exact 1193-struct-field-collection-binding-baseline `
    --exact 1194-struct-field-collection-binding-perturbed `
    --exact 1196-selfhost-cross-fragment-ref-dynamic-array `
    --exact 1197-control-struct-array-result `
    --exact 1198-parallel-transferable-struct-worker `
    --exact 1199-local-function-parallel-callback `
    --exact 1200-parallel-nominal-readonly-captures `
    --exact 1201-parallel-move-parameter `
    --exact 1202-array-element-owner-replacement-after-read `
    --exact 1203-selfhost-enum-payload-binary-binding `
    --exact 1204-selfhost-enum-payload-binary-binding-permuted `
    --exact 1206-quic-bidirectional-multi-stream-routing `
    --exact 1207-enum-owned-payload-projected-queue `
    --exact 1208-multiline-projected-assignment `
    --exact 1209-quic-connection-options-queue-limits `
    --exact 1210-quic-directional-control-frames `
    --exact 1211-quic-directional-owner-transitions `
    --exact 1212-selfhost-member-assignment-after-take `
    --exact 1213-selfhost-result-field-transfer-after-take `
    --exact 1214-gzip-transactional-streaming-decoder `
    --exact 1215-gzip-incremental-byte-boundaries `
    --exact 1216-late-indexed-element-array-type `
    --exact 1217-selfhost-late-indexed-array-type-contract `
    --exact 1220-zstd-raw-rle-streaming `
    --exact 1304-zstd-literal-only-compressed-block `
    --exact 1305-selfhost-interpolation-numeric-separator `
    --exact 1306-zstd-direct-huffman-literals `
    --exact 1308-selfhost-nested-result-many-argument-owner `
    --exact 1309-selfhost-terminating-if-branch-result `
    --exact 1321-parallel-additional-borrow-result `
    --exact 1228-xxhash64-streaming `
    --exact 1229-http-body-framing `
    --exact 1230-selfhost-short-circuit-array-argument `
    --exact 1231-selfhost-nested-result-match-value `
    --exact 1232-selfhost-console-call-owns-if-result `
    --exact 1233-http-response-head-writer `
    --exact 1385-http-request-head-writer `
    --exact 1386-http-client-connection-reuse `
    --exact 1388-selfhost-imported-ref-struct-value-receiver `
    --exact 1389-selfhost-nested-aggregate-partial-move-cleanup `
    --exact 1391-opaque-struct-instance-boundary `
    --exact 1392-selfhost-opaque-struct-ast `
    --exact 1393-selfhost-opaque-struct-diagnostics `
    --exact 1394-selfhost-when-binding-reassignment `
    --exact 1404-function-tail-each-statement `
    --exact 1405-selfhost-collection-comprehension-syntax `
    --exact 1406-selfhost-constant-integer-arithmetic `
    --exact 1407-module-local-enum-identity `
    --exact 1408-selfhost-qualified-value-shadow `
    --exact 1409-import-qualified-enum-pattern `
    --exact 1410-selfhost-constant-expression-plan `
    --exact 1411-borrowed-receiver-error-reuse `
    --exact 1412-direct-result-control-match `
    --exact 1413-selfhost-constant-collection-expansion `
    --exact 1414-module-local-range-identity `
    --exact 1415-imported-result-projected-each-element `
    --exact 1416-result-match-propagation-producer `
    --exact 1417-imported-result-match-propagation `
    --exact 1418-function-enum-constructor-call-chain `
    --exact 1419-selfhost-constant-collection-lowering `
    --exact 1420-owned-flow-result-preserves-input `
    --exact 1421-early-return-aggregate-move-input `
    --exact 1422-owned-enum-payload-block-result `
    --exact 1423-disjoint-owned-field-transfer `
    --exact 1424-nested-each-interpolation `
    --exact 1425-nested-match-result-constructor `
    --exact 1426-dictionary-index-interpolation `
    --exact 1427-enum-reference-payload-forwarding `
    --exact 1428-mutable-scalar-readonly-reference `
    --exact 1429-tap-side-call-argument-plan `
    --exact 1430-tap-explicit-side-chain `
    --exact 1431-trait-constant-method-receiver `
    --exact 1432-dyn-trait-reachable-implementations `
    --exact 1433-parallel-existing-role-array-references `
    --exact 1434-multistage-console-wrapper `
    --exact 1435-dyn-result-console-wrapper `
    --exact 1436-user-printer-method-flow `
    --exact 1437-generic-inherent-method `
    --exact 1438-generic-method-inference-types `
    --exact 1439-generic-method-trait-constraint `
    --exact 1440-generic-method-owner-scope `
    --exact 1441-generic-function-concrete-abi `
    --exact 1442-selfhost-generic-multi-input-unification `
    --exact 1443-selfhost-generic-method-call-type-isolation `
    --exact 1444-each-mutable-nested-control `
    --exact 1445-each-role-projected-readonly-array `
    --exact 1446-member-assignment-lexical-sibling `
    --exact 1447-generic-trait-constraint-isolation `
    --exact 1448-nested-generic-method-helper `
    --exact 1449-recursive-generic-call-closure `
    --exact 1450-selfhost-generic-closure-reuse `
    --exact 1451-dictionary-absent-instance-result `
    --exact 1452-each-call-result-record-type `
    --exact 1453-each-push-return-alias `
    --exact 857-dictionary-put-if-absent `
    --exact 858-dictionary-put-if-absent-owned `
    --exact 66-generic-dictionary-function-contracts `
    --exact 487-selfhost-borrowed-container-return-analysis `
    --exact diagnostic/opaque-struct-construction `
    --exact diagnostic/opaque-struct-field-read `
    --exact diagnostic/opaque-struct-field-write `
    --exact diagnostic/opaque-struct-modifier-rejected `
    --exact diagnostic/private-inferred-field-chain `
    --exact 1352-selfhost-consuming-call-owned-outcome `
    --exact 1234-selfhost-parallel-nested-flow-arguments `
    --exact 1236-socket-send-range-all `
    --exact 1240-http-one-request-server `
    --exact 1340-selfhost-result-arm-owned-field-transfer `
    --exact 1341-http-persistent-pipeline `
    --exact 1354-selfhost-read-before-direct-self-consume `
    --exact 1379-selfhost-nested-control-implicit-return `
    --exact 1380-selfhost-final-binding-return-selection `
    --exact 1381-selfhost-terminal-return-only-if `
    --exact 1382-selfhost-terminal-flow-control-return `
    --exact 1383-selfhost-inferred-receiver-method-owner `
    --exact 1384-nested-result-logical-condition `
    --exact 1477-typed-record-array-field-identity `
    --exact 1480-direct-repeat-readonly-slice `
    --exact 1482-signed-unary-contexts `
    --exact 1481-resolved-call-early-return-cleanup `
    --exact 1497-narrow-integer-parameter-print `
    --exact 1498-hmac-streaming-segments `
    --exact 1501-bound-imported-method-owner `
    --exact 1502-same-call-projected-owner-controls `
    --exact 1503-nested-call-statement-effect-order `
    --exact 1504-readonly-fixed-call-temporary-cleanup `
    --exact 1505-readonly-independent-copy-cleanup `
    --exact 1506-readonly-owned-element-temporary-cleanup `
    --exact 1507-empty-unit-function-contract `
    --exact 1508-named-fixed-named-reuse-cleanup `
    --exact 1509-named-fixed-stack-literal-cleanup `
    --exact 1510-named-fixed-implicit-return-cleanup `
    --exact 1511-named-fixed-explicit-return-cleanup `
    --exact 1512-named-fixed-early-scalar-return-cleanup `
    --exact 1513-named-fixed-owned-element-named-cleanup `
    --exact 1514-named-fixed-moved-owner-cleanup `
    --exact 1515-named-fixed-ref-return-cleanup `
    --exact 1516-named-fixed-before-binding-return-cleanup `
    --exact 1517-named-fixed-loop-region-cleanup `
    --exact 1518-local-function-intrinsic-collision `
    --exact 1519-fixed-stack-argument-return `
    --exact 1520-fixed-named-argument-return `
    --exact 1521-fixed-implicit-moving-wrapper `
    --exact 1522-fixed-explicit-moving-wrapper `
    --exact 1523-fixed-owned-explicit-wrapper `
    --exact 1524-fixed-owned-implicit-wrapper `
    --exact 1525-fixed-additional-argument-return `
    --exact 1526-fixed-branch-explicit-return `
    --exact 1527-projected-table-push-loop `
    --exact 1528-fixed-field-factory `
    --exact 1529-fixed-field-named `
    --exact 1530-fixed-field-stack `
    --exact 1531-fixed-field-owned `
    --exact 1532-fixed-field-region `
    --exact 1533-fixed-branch-binding `
    --exact 1534-fixed-branch-loop-binding `
    --exact 1535-branch-value-owner `
    --exact 1536-branch-value-fixed `
    --exact 1537-branch-fixed-mixed-storage `
    --exact 1538-branch-fixed-outer-reuse `
    --exact 1539-branch-fixed-owned-elements `
    --exact 1540-branch-fixed-mutable-local `
    --exact 1541-branch-fixed-return `
    --exact 1542-entry-branch-lifetime `
    --exact 1543-fixed-int-branch-result `
    --exact 1544-fixed-text-branch-result `
    --exact 1545-fixed-field-copy-independence `
    --exact 1546-logical-flow-bool `
    --exact 1547-owned-branch-taken `
    --exact 1548-owned-nested-terminating-branch `
    --exact 1549-owned-when-terminating-branch `
    --exact 1552-async-console-capability `
    --exact 1553-projected-push-sibling-reuse `
    --exact 1554-borrowed-fixed-field-copy-independence `
    --exact 1555-generic-stream-consumer-call-identity `
    --exact 1556-generic-inherent-open-import-precedence `
    --exact 1562-nested-bool-region-short-circuit-effects `
    --exact 1563-borrowed-fixed-return-copy-independence `
    --exact 1564-borrowed-nested-fixed-field-copy-independence `
    --exact 1567-borrowed-temporary-record-cleanup `
    --exact 1568-borrowed-named-record-reuse `
    --exact 1569-borrowed-flow-temporary-cleanup `
    --exact 1570-borrowed-temporary-enum-cleanup `
    --exact 1571-borrowed-temporary-independent-result `
    --exact 1572-borrowed-nested-flow-argument-cleanup `
    --exact 1573-named-mutable-receiver-borrow-reuse `
    --exact 1574-consuming-temporary-receiver-cleanup `
    --exact 1575-borrowed-enum-variant-tag-cleanup `
    --exact 1576-consuming-enum-match-cleanup `
    --exact 1577-consuming-enum-payload-transfer `
    --exact 1578-borrowed-named-enum-reuse `
    --exact 1579-borrowed-record-literal-cleanup `
    --exact 1580-borrowed-array-literal-cleanup `
    --exact 1581-borrowed-enum-literal-cleanup `
    --exact 1592-late-contextual-array-boundaries `
    --exact 1602-stream-mapped-text-flatmap-input `
    --exact 1603-stream-mapped-int-flatmap-arithmetic `
    --exact 1604-stream-mapped-flatmap-direct-roles `
    --exact 1605-stream-mapped-bool-flatmap-input `
    --exact 1606-stream-mapped-uint64-flatmap-input `
    --exact 1607-stream-bool-map-filter-input `
    --exact 1609-parameter-range-text-flatmap `
    --exact 1610-parameter-range-map-flatmap `
    --exact 1611-parameter-range-empty-flatmap `
    --exact 1612-parameter-upper-range-flatmap `
    --exact 1613-function-constant-range-flatmap `
    --exact 1614-parameter-range-direct-each `
    --exact 1598-recursive-enum-heap-owner `
    --exact 1599-recursive-enum-box-layout `
    --exact 1600-nested-enum-owned-payload `
    --exact 1601-nested-result-owned-payload `
    --exact 1619-finite-bounded-array-layout `
    --exact 1620-finite-bounded-dictionary-layout `
    --exact 1615-flatmap-single-receiver-scalar-int `
    --exact 1634-flatmap-single-receiver-text `
    --exact 1635-flatmap-single-receiver-parameter `
    --exact 1636-flatmap-single-receiver-take `
    --exact 1637-flatmap-single-receiver-empty `
    --exact 1638-flatmap-single-receiver-uint64 `
    --exact 1639-flatmap-single-receiver-bool `
    --exact 1640-flatmap-single-receiver-range-value `
    --exact 1626-boxed-recursive-enum-cleanup `
    --exact 1627-boxed-enum-named-match-reuse `
    --exact 1628-boxed-enum-payload-transfer `
    --exact 1629-boxed-primitive-cleanup `
    --exact 1630-boxed-nested-cleanup `
    --exact 1642-zero-fixed-recursive-layout `
    --exact 1643-nominal-enum-zero-fixed-payload `
    --exact 1649-static-factory-distinct-owners `
    --exact 1651-enum-integer-payload-boundaries `
    --exact 1658-unused-arguments-runtime `
    --exact 1659-arguments-runtime-lifetime `
    --exact 1660-arguments-runtime-function `
    --exact 1661-arguments-each-layout `
    --exact 1662-nominal-slice-each-direct `
    --exact 1663-nominal-slice-each-function `
    --exact 1664-nominal-slice-each-nested `
    --exact 1665-nominal-slice-each-boundary `
    --exact 1666-arguments-primary-parameter `
    --exact 1667-arguments-additional-parameter `
    --exact 1668-arguments-return-forwarding `
    --exact 1669-arguments-aggregate-storage `
    --exact 1670-arguments-branch-generic `
    --exact 1671-arguments-while-forwarding `
    --exact 1672-arguments-local-capture `
    --exact 1673-imported-struct-enum-field-prefix `
    --exact 1674-owned-field-extraction-repair `
    --exact 1675-owned-field-borrow-preserves-owner `
    --exact 1676-owned-field-replacement-keeps-drop `
    --exact 1677-scalar-enum-copy-with-sibling-text-borrow `
    --exact 1678-nested-enum-payload-move-consumer `
    --exact 1679-nested-enum-payload-borrow-inspection `
    --exact 1621-option-enum-payload-value `
    --exact 1622-nested-option-result-enum-payload `
    --exact 1623-owned-option-enum-payload-cleanup `
    --exact 1624-owned-result-enum-payload-cleanup `
    --exact 1645-runtime-result-nominal-field `
    --exact 1646-owned-runtime-result-field-cleanup `
    --exact 1647-borrowed-runtime-result-field-reuse `
    --exact 1631-boxed-enum-member-consume `
    --exact 1632-boxed-enum-member-borrow-reuse `
    --exact 1633-boxed-temporary-readonly-call `
    --exact 814-concurrent-latest-early-cancellation `
    --exact 816-concurrent-latest-uninitialized-completion `
    --exact 815-stream-join-return-signature-inference `
    --exact diagnostic/1565-borrowed-fixed-owned-element-store `
    --exact diagnostic/1566-borrowed-fixed-owned-element-return `
    --exact diagnostic/1550-mixed-owned-continuing-branches `
    --exact diagnostic/1551-partially-terminating-owned-branch `
    --exact diagnostic/1557-typed-int-array-to-byte-slice `
    --exact diagnostic/1558-additional-typed-array-element-mismatch `
    --exact diagnostic/1559-typed-fixed-array-element-mismatch `
    --exact diagnostic/1560-readonly-fixed-array-element-mismatch `
    --exact diagnostic/1561-returned-array-element-mismatch `
    --exact diagnostic/1507-empty-unit-u8-primary-overflow `
    --exact diagnostic/1507-empty-unit-u8-additional-overflow `
    --exact 1499-projected-owned-call-lifetime `
    --exact 1500-readonly-call-temporary-lifetime `
    --exact diagnostic/1499-projected-owned-call-branch `
    --exact diagnostic/1499-projected-owned-call-break `
    --exact diagnostic/1499-projected-owned-call-continue `
    --exact diagnostic/1499-projected-owned-call-loop `
    --exact diagnostic/1499-projected-owned-call-read-after-move `
    --exact diagnostic/1499-projected-owned-call-readonly `
    --exact diagnostic/1499-projected-owned-call-reuse `
    --exact diagnostic/1499-projected-owned-call-whole-owner `
    --exact diagnostic/1499-projected-owned-same-call `
    --exact diagnostic/1499-projected-owned-return-same-call `
    --exact diagnostic/1500-readonly-slice-alias-return-escape `
    --exact diagnostic/1500-readonly-slice-return-escape `
    --exact 1496-wide-integer-array-flow-context `
    --exact 1478-contextual-integer-field-boundaries `
    --exact 1486-interpolation-capacity-receivers `
    --exact diagnostic/typed-array-unknown-field `
    --exact diagnostic/typed-array-wrong-box-element `
    --exact diagnostic/typed-array-duplicate-field `
    --exact diagnostic/nominal-integer-variable-negative `
    --exact diagnostic/nominal-integer-minimum-negative `
    --exact diagnostic/array-integer-u8-primary-repeat-above `
    --exact diagnostic/array-integer-u8-additional-list-below `
    --exact diagnostic/array-integer-i8-primary-list-below `
    --exact diagnostic/array-integer-i8-additional-repeat-above `
    --exact diagnostic/array-integer-i16-primary-repeat-below `
    --exact diagnostic/nominal-codepoint-surrogate-negative `
    --exact diagnostic/contextual-array-element-missing-field `
    --exact diagnostic/contextual-struct-integer-literal-out-of-range `
    --exact diagnostic/struct-wrong-field-type `
    --exact diagnostic/1487-interpolation-capacity-fixed `
    --exact diagnostic/1488-interpolation-capacity-slice `
    --exact diagnostic/1489-interpolation-capacity-text `
    --exact 1221-numeric-subject-when-arm-result `
    --exact 1222-selfhost-numeric-subject-when-binding `
    --exact 1223-contextual-intrinsic-instance-precedence `
    --exact 631-selfhost-native-handle-type `
    --exact 582-billion-sensor-alerts `
    --exact 1095-selfhost-checked-borrowed-owned-return `
    --exact 892-quic-frame-codec `
    --exact 901-quic-ack-frame-ranges `
    --exact 941-quic-one-rtt-application-engine `
    --exact 942-owned-frame-result-field-match `
    --exact 965-consecutive-frame-encode-owned-payload `
    --exact 915-quic-version-negotiation `
    --exact 916-quic-version-packet `
    --exact 1015-quic-p2p-peer-record `
    --exact 854-set-key-only `
    --exact 377-selfhost-llvm-source-text-worker-transfer `
    --jobs 4
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-managed-owned-call-cleanup.ps1") -RepositoryRoot $repoRoot
Write-Host "[stage3 policy] PASS managed fail-fast contracts; native fixed-point proof remains required."

if ($RebuildStage2) {
    Write-Host "[stage3 1/3] Rebuild and verify stage 2."
    & (Join-Path $PSScriptRoot "verify-selfhost-stage2.ps1") -Rebuild -Stage2BuildJobs $Jobs -SeedMode $SeedMode -SlgSeedCompiler $SlgSeedCompiler
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[stage3 1/3] Verify that the existing stage 2 is current."
}

if (-not (Test-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -ReceiptPath $stage2ArtifactReceiptPath)) {
    throw "stage 2 artifacts are missing, empty, or differ from their completion receipt; rerun with -RebuildStage2"
}

$sourcePaths = Get-Content $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }
$sourcePaths += $compilerRuntimeSources | ForEach-Object { (Resolve-Path $_).Path }
$fingerprintInputs = @($stage1Path, $manifestPath, $runtimeManifestPath) + $sourcePaths
$currentStage2Fingerprint = Get-ContentFingerprint $fingerprintInputs
if (-not (Test-Path -LiteralPath $stage2FingerprintPath) -or
    [System.IO.File]::ReadAllText($stage2FingerprintPath).Trim() -ne $currentStage2Fingerprint) {
    throw "stage 2 input fingerprint differs; rerun with -RebuildStage2"
}
Write-Host "[stage3 1/3] PASS current stage 2."

Write-Host "[stage3 2/3] Generate stage 3 from the stage-2 compiler."
$stage3LlvmPath = Get-CandidateArtifactPath $publishedStage3LlvmPath
$stage3BitcodePath = Get-CandidateArtifactPath $publishedStage3BitcodePath
$stage3Path = Get-CandidateArtifactPath $publishedStage3Path
if ($ResumeCandidate) {
    if (-not (Test-Stage2ArtifactReceipt `
            -LlvmPath $stage3LlvmPath `
            -BitcodePath $stage3BitcodePath `
            -ExecutablePath $stage3Path `
            -ReceiptPath $stage3CandidateArtifactReceiptPath) -or
        -not (Test-Path -LiteralPath $stage3CandidateFingerprintPath) -or
        [System.IO.File]::ReadAllText($stage3CandidateFingerprintPath).Trim() -cne (Get-Stage3CandidateInputFingerprint)) {
        throw "Stage3 candidate artifacts do not match their input/output receipts; rerun without -ResumeCandidate"
    }
    Write-Host "[stage3 2/3] RESUME receipt-bound Stage3 candidate."
} else {
    Remove-Item -LiteralPath $stage3LlvmPath, $stage3BitcodePath, $stage3Path, $stage3ErrorPath, $stage3CandidateFingerprintPath, $stage3CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
    $process = Start-Process `
        -FilePath $stage2Path `
        -ArgumentList (@("windows", "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture)) + $sourcePaths) `
        -RedirectStandardOutput $stage3LlvmPath `
        -RedirectStandardError $stage3ErrorPath `
        -PassThru `
        -WindowStyle Hidden
    $stage3TimeoutMilliseconds = 3600000
    $stage3StartedAt = [DateTimeOffset]::Now
    $expectedStage3Bytes = (Get-Item -LiteralPath $stage2LlvmPath).Length
    while (-not $process.WaitForExit(60000)) {
        $process.Refresh()
        $elapsed = [DateTimeOffset]::Now - $stage3StartedAt
        $outputBytes = if (Test-Path -LiteralPath $stage3LlvmPath) { (Get-Item -LiteralPath $stage3LlvmPath).Length } else { 0 }
        $errorBytes = if (Test-Path -LiteralPath $stage3ErrorPath) { (Get-Item -LiteralPath $stage3ErrorPath).Length } else { 0 }
        $cpuSeconds = [int]$process.TotalProcessorTime.TotalSeconds
        $workingMiB = [int]($process.WorkingSet64 / 1MB)
        $percent = if ($expectedStage3Bytes -gt 0) {
            [Math]::Min(100.0, 100.0 * $outputBytes / $expectedStage3Bytes)
        } else {
            0.0
        }
        if ($outputBytes -eq 0) {
            Write-Host ("[stage3 2/3] phase 1/2 analyze active ({0:N0}s elapsed, {1:N0}s CPU, {2:N0} MiB; errors {3:N0} bytes)." -f $elapsed.TotalSeconds, $cpuSeconds, $workingMiB, $errorBytes)
        } else {
            Write-Host ("[stage3 2/3] phase 2/2 LLVM {0:N0}/{1:N0} bytes ({2:N1}%); {3:N0}s elapsed, {4:N0}s CPU, {5:N0} MiB; errors {6:N0} bytes." -f $outputBytes, $expectedStage3Bytes, $percent, $elapsed.TotalSeconds, $cpuSeconds, $workingMiB, $errorBytes)
        }
        if ($elapsed.TotalMilliseconds -gt $stage3TimeoutMilliseconds) {
            Wait-VerificationProcess `
                -Process $process `
                -Description "stage-3 LLVM emission" `
                -TimeoutMilliseconds $stage3TimeoutMilliseconds `
                -TimeoutStartedAt $stage3StartedAt
        }
    }
    $process.Refresh()
    if ($process.ExitCode -ne 0) {
        $details = if (Test-Path $stage3ErrorPath) { Get-Content $stage3ErrorPath -Raw } else { "" }
        throw "stage-3 LLVM emission failed with exit code $($process.ExitCode).`n$details"
    }
    Write-Host "[stage3 2/3] PASS $((Get-Item $stage3LlvmPath).Length) LLVM bytes."
}

Write-Host "[stage3 3/3] Verify LLVM structure, then compare the complete compiler fixed point."
& (Join-Path $PSScriptRoot "verify-selfhost-parallel-callback-llvm.ps1") `
    -LlvmPath $stage3LlvmPath `
    -MinimumCallbackCount 4 `
    -RequireNominalTransfer
if (-not $ResumeCandidate) {
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $stage3LlvmPath
    & $llvmAsPath $stage3LlvmPath -o $stage3BitcodePath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$stage2Hash = Get-NormalizedHash $stage2LlvmPath
$stage3Hash = Get-NormalizedHash $stage3LlvmPath
if ($stage2Hash -ne $stage3Hash) {
    throw "complete compiler fixed point differs: stage2=$stage2Hash stage3=$stage3Hash. Do not promote either artifact. Review the LLVM semantic diff; if it is an expected one-generation self-host source change, run verify-selfhost-stage2.ps1 -Rebuild -SeedMode Stage2Bridge and then rerun Stage3."
}
if (-not $ResumeCandidate) {
    & $clangPath -Wno-override-module $stage3LlvmPath -O1 -o $stage3Path -lws2_32 -lshell32 -lbcrypt
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage3LlvmPath `
        -BitcodePath $stage3BitcodePath `
        -ExecutablePath $stage3Path `
        -ReceiptPath $stage3CandidateArtifactReceiptPath
    [System.IO.File]::WriteAllText($stage3CandidateFingerprintPath, (Get-Stage3CandidateInputFingerprint))
}
foreach ($exactGeneration in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    & (Join-Path $PSScriptRoot "verify-selfhost-private-field-diagnostics.ps1") `
        -Compiler $exactGeneration.Compiler `
        -Label $exactGeneration.Name `
        -RepositoryRoot $repoRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-selfhost-trait-ownership-diagnostics.ps1") `
        -Compiler $exactGeneration.Compiler `
        -RepositoryRoot $repoRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-selfhost-interpolation-capacity-diagnostics.ps1") `
        -Compiler $exactGeneration.Compiler `
        -Label $exactGeneration.Name `
        -RepositoryRoot $repoRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-selfhost-owned-array-cleanup.ps1") `
        -Compiler $exactGeneration.Compiler `
        -RepositoryRoot $repoRoot `
        -LlvmRoot $llvmRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-selfhost-arguments-runtime.ps1") `
        -Compiler $exactGeneration.Compiler `
        -RepositoryRoot $repoRoot `
        -LlvmRoot $llvmRoot
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $argumentsCompilerHash = (Get-FileHash -LiteralPath $exactGeneration.Compiler -Algorithm SHA256).Hash
    Copy-Item -LiteralPath (Join-Path $repoRoot "artifacts/arguments-runtime/$argumentsCompilerHash/results.json") `
        -Destination (Join-Path $artifactsDir "stage3-arguments-runtime-$($exactGeneration.Name).json") -Force
    $cleanupCompilerHash = (Get-FileHash -LiteralPath $exactGeneration.Compiler -Algorithm SHA256).Hash
    $cleanupReport = Join-Path $repoRoot "artifacts/owned-array-cleanup/$cleanupCompilerHash/results.json"
    Copy-Item -LiteralPath $cleanupReport `
        -Destination (Join-Path $artifactsDir "stage3-owned-array-cleanup-$($exactGeneration.Name).json") -Force
    & (Join-Path $PSScriptRoot "verify-native-exact-fixture-batch.ps1") `
        -Compiler $exactGeneration.Compiler `
        -Label $exactGeneration.Name `
        -LlvmRoot $llvmRoot `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory (Join-Path $artifactsDir "stage3-exact") `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& (Join-Path $PSScriptRoot "verify-native-set-intrinsics.ps1") `
    -Compiler $stage3Path `
    -Label "stage3-candidate" `
    -LlvmHome $llvmRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-managed-cpu-aes-dispatch.ps1") `
    -Label "stage3-managed" `
    -LlvmHome $llvmRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-selfhost-cpu-aes-dispatch.ps1") `
    -Compiler $stage3Path `
    -Label "stage3-candidate" `
    -LlvmHome $llvmRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-cpu-aes-dispatch-differential.ps1") `
    -SelfhostCompiler $stage3Path `
    -LlvmHome $llvmRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-selfhost-static-readonly-array.ps1") `
    -Compiler $stage3Path `
    -Label "stage3-candidate" `
    -LlvmHome $llvmRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-selfhost-late-type-sealing.ps1") `
    -Compiler $stage3Path `
    -Label "stage3-candidate" `
    -LlvmHome $llvmRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($processGeneration in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    & (Join-Path $PSScriptRoot "verify-native-process-child-lifecycle.ps1") `
        -Compiler $processGeneration.Compiler `
        -Label $processGeneration.Name `
        -LlvmHome $llvmRoot `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& (Join-Path $PSScriptRoot "verify-native-quic-endpoint-ownership.ps1") `
    -Compiler $stage3Path `
    -Label "stage3-candidate" `
    -LlvmHome $llvmRoot `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -Jobs $Jobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-selfhost-owned-block-result-diagnostics.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-owned-block-result-diagnostics.ps1") `
    -Compiler $stage3Path `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-owned-container-rebind-diagnostic.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-owned-container-rebind-diagnostic.ps1") `
    -Compiler $stage3Path `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-semantic-parity-diagnostics.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-semantic-parity-diagnostics.ps1") `
    -Compiler $stage3Path `
    -RepositoryRoot $repoRoot
foreach ($diagnosticCompiler in @(
    [ordered]@{ Name = "stage2"; Path = $stage2Path },
    [ordered]@{ Name = "stage3"; Path = $stage3Path }
)) {
    & (Join-Path $PSScriptRoot "verify-selfhost-unresolved-call-diagnostic.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -RepositoryRoot $repoRoot
    & (Join-Path $PSScriptRoot "verify-selfhost-result-propagation-diagnostics.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -RepositoryRoot $repoRoot
}
$prepareSources = @(
    (Join-Path $repoRoot "examples\regression\1086-crc32-policy-hasher-instances.slg"),
    (Join-Path $repoRoot "stdlib\std\hash\crc32.slg")
)
$prepareOutputs = [System.Collections.Generic.List[string]]::new()
foreach ($generation in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    $prepareOutput = Join-Path $artifactsDir "$($generation.Name)-check-prepare.txt"
    $prepareError = Join-Path $artifactsDir "$($generation.Name)-check-prepare.err"
    $prepareProcess = Start-Process `
        -FilePath $generation.Compiler `
        -ArgumentList (@("prepare") + $prepareSources) `
        -RedirectStandardOutput $prepareOutput `
        -RedirectStandardError $prepareError `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $prepareProcess "$($generation.Name) semantic prepare"
    if ($prepareProcess.ExitCode -ne 0) {
        $details = [System.IO.File]::ReadAllText($prepareError)
        throw "$($generation.Name) semantic prepare failed with exit code $($prepareProcess.ExitCode).`n$details"
    }
    $diagnostics = [System.IO.File]::ReadAllText($prepareError)
    if (-not [string]::IsNullOrWhiteSpace($diagnostics)) {
        throw "$($generation.Name) semantic prepare emitted diagnostics.`n$diagnostics"
    }
    $prepareSummary = [System.IO.File]::ReadAllText($prepareOutput).Replace("`r`n", "`n")
    if ($prepareSummary -notmatch '^semantic prepare = \d+,\d+,\d+\n?$') {
        throw "$($generation.Name) semantic prepare emitted an invalid summary: $prepareSummary"
    }
    $prepareOutputs.Add($prepareSummary)
}
if ($prepareOutputs[0] -ne $prepareOutputs[1]) {
    throw "stage-2 and stage-3 semantic prepare summaries differ"
}
$socketEndpointOutputs = [System.Collections.Generic.List[string]]::new()
foreach ($generation in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    $socketExecutable = Join-Path $artifactsDir "$($generation.Name)-check-socket-endpoint-observation.exe"
    $socketLlvm = $socketExecutable + ".ll"
    $socketOutput = Join-Path $artifactsDir "$($generation.Name)-check-socket-endpoint-observation.stdout.txt"
    $socketError = Join-Path $artifactsDir "$($generation.Name)-check-socket-endpoint-observation.stderr.txt"
    Remove-Item -LiteralPath $socketExecutable, $socketLlvm, $socketOutput, $socketError -ErrorAction SilentlyContinue
    $socketBuild = Start-Process `
        -FilePath $generation.Compiler `
        -ArgumentList @(
            "build", $socketEndpointObservationSource,
            "-o", $socketExecutable,
            "--target", "windows-x64",
            "--llvm", $llvmRoot,
            "--stdlib", $stdlibRoot,
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "-O1", "--keep-temps") `
        -RedirectStandardOutput $socketOutput `
        -RedirectStandardError $socketError `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $socketBuild "$($generation.Name) socket endpoint observation build"
    if ($socketBuild.ExitCode -ne 0) {
        throw "$($generation.Name) socket endpoint observation build failed.`n$([System.IO.File]::ReadAllText($socketError))"
    }
    if (-not (Test-Path $socketLlvm) -or -not (Test-Path $socketExecutable)) {
        throw "$($generation.Name) socket endpoint observation artifacts are incomplete"
    }
    & $llvmAsPath $socketLlvm -o ([System.IO.Path]::ChangeExtension($socketExecutable, ".bc"))
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $socketRun = Invoke-VerificationProcessCapture `
        -FilePath $socketExecutable `
        -Description "$($generation.Name) socket endpoint observation executable"
    $socketActual = $socketRun.Stdout.TrimEnd("`r", "`n")
    if ($socketRun.ExitCode -ne 0 -or $socketActual -ne "socket-endpoints=ok") {
        throw "$($generation.Name) socket endpoint observation execution failed: '$socketActual'"
    }
    $socketEndpointOutputs.Add($socketActual)
}
if ($socketEndpointOutputs[0] -ne $socketEndpointOutputs[1]) {
    throw "stage-2 and stage-3 socket endpoint observation results differ"
}
$socketNoDelayExpectedText = [System.IO.File]::ReadAllText($socketNoDelayExpected).Replace("`r`n", "`n").TrimEnd("`n")
$socketNoDelayOutputs = [System.Collections.Generic.List[string]]::new()
foreach ($generation in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    $socketNoDelayExecutable = Join-Path $artifactsDir "$($generation.Name)-check-socket-no-delay.exe"
    $socketNoDelayLlvm = $socketNoDelayExecutable + ".ll"
    $socketNoDelayOutput = Join-Path $artifactsDir "$($generation.Name)-check-socket-no-delay.stdout.txt"
    $socketNoDelayError = Join-Path $artifactsDir "$($generation.Name)-check-socket-no-delay.stderr.txt"
    Remove-Item -LiteralPath $socketNoDelayExecutable, $socketNoDelayLlvm, $socketNoDelayOutput, $socketNoDelayError -ErrorAction SilentlyContinue
    $socketNoDelayBuild = Start-Process `
        -FilePath $generation.Compiler `
        -ArgumentList @(
            "build", $socketNoDelaySource,
            "-o", $socketNoDelayExecutable,
            "--target", "windows-x64",
            "--llvm", $llvmRoot,
            "--stdlib", $stdlibRoot,
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "-O1", "--keep-temps") `
        -RedirectStandardOutput $socketNoDelayOutput `
        -RedirectStandardError $socketNoDelayError `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $socketNoDelayBuild "$($generation.Name) socket no-delay build"
    if ($socketNoDelayBuild.ExitCode -ne 0) {
        throw "$($generation.Name) socket no-delay build failed.`n$([System.IO.File]::ReadAllText($socketNoDelayError))"
    }
    if (-not (Test-Path $socketNoDelayLlvm) -or -not (Test-Path $socketNoDelayExecutable)) {
        throw "$($generation.Name) socket no-delay artifacts are incomplete"
    }
    & $llvmAsPath $socketNoDelayLlvm -o ([System.IO.Path]::ChangeExtension($socketNoDelayExecutable, ".bc"))
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $socketNoDelayRun = Invoke-VerificationProcessCapture `
        -FilePath $socketNoDelayExecutable `
        -Description "$($generation.Name) socket no-delay executable"
    $socketNoDelayActual = $socketNoDelayRun.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
    if ($socketNoDelayRun.ExitCode -ne 0 -or $socketNoDelayActual -ne $socketNoDelayExpectedText) {
        throw "$($generation.Name) socket no-delay execution failed: '$socketNoDelayActual'"
    }
    $socketNoDelayOutputs.Add($socketNoDelayActual)
}
if ($socketNoDelayOutputs[0] -ne $socketNoDelayOutputs[1]) {
    throw "stage-2 and stage-3 socket no-delay results differ"
}
foreach ($generation in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    & (Join-Path $PSScriptRoot "verify-native-socket-timeouts.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform windows `
        -LlvmRoot $llvmRoot `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-native-mutable-parameter-indexing-batch.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform windows `
        -LlvmRoot $llvmRoot `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-native-interpolation-reference-arguments.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform windows `
        -LlvmRoot $llvmRoot `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & (Join-Path $PSScriptRoot "verify-native-projected-reference-places.ps1") `
        -Compiler $generation.Compiler `
        -Label $generation.Name `
        -Platform windows `
        -LlvmRoot $llvmRoot `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $artifactsDir `
        -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$timeExpected = [System.IO.File]::ReadAllText($timeCheckedArithmeticExpected).Replace("`r`n", "`n").TrimEnd("`n")
$timeOutputs = [System.Collections.Generic.List[string]]::new()
foreach ($generation in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    $timeExecutable = Join-Path $artifactsDir "$($generation.Name)-check-time-arithmetic.exe"
    $timeLlvm = $timeExecutable + ".ll"
    $timeOutput = Join-Path $artifactsDir "$($generation.Name)-check-time-arithmetic.stdout.txt"
    $timeError = Join-Path $artifactsDir "$($generation.Name)-check-time-arithmetic.stderr.txt"
    Remove-Item -LiteralPath $timeExecutable, $timeLlvm, $timeOutput, $timeError -ErrorAction SilentlyContinue
    $timeBuild = Start-Process `
        -FilePath $generation.Compiler `
        -ArgumentList @(
            "build", $timeCheckedArithmeticSource,
            "-o", $timeExecutable,
            "--target", "windows-x64",
            "--llvm", $llvmRoot,
            "--stdlib", $stdlibRoot,
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "-O1", "--keep-temps") `
        -RedirectStandardOutput $timeOutput `
        -RedirectStandardError $timeError `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $timeBuild "$($generation.Name) time arithmetic build"
    if ($timeBuild.ExitCode -ne 0) {
        throw "$($generation.Name) time arithmetic build failed.`n$([System.IO.File]::ReadAllText($timeError))"
    }
    if (-not (Test-Path $timeLlvm) -or -not (Test-Path $timeExecutable)) {
        throw "$($generation.Name) time arithmetic artifacts are incomplete"
    }
    & $llvmAsPath $timeLlvm -o ([System.IO.Path]::ChangeExtension($timeExecutable, ".bc"))
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $timeRun = Invoke-VerificationProcessCapture `
        -FilePath $timeExecutable `
        -Description "$($generation.Name) time arithmetic executable"
    $timeActual = $timeRun.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
    if ($timeRun.ExitCode -ne 0 -or $timeActual -ne $timeExpected) {
        throw "$($generation.Name) time arithmetic execution differed.`n$timeActual"
    }
    $timeOutputs.Add($timeActual)
}
if ($timeOutputs[0] -ne $timeOutputs[1]) {
    throw "stage-2 and stage-3 time arithmetic results differ"
}
$publicStdlibOutputs = [System.Collections.Generic.List[string]]::new()
foreach ($generation in @(
    [ordered]@{ Name = "stage2"; Compiler = $stage2Path },
    [ordered]@{ Name = "stage3"; Compiler = $stage3Path }
)) {
    $publicStdlibOutput = Join-Path $artifactsDir "$($generation.Name)-check-public-stdlib.ll"
    $publicStdlibError = Join-Path $artifactsDir "$($generation.Name)-check-public-stdlib.err"
    $publicStdlibProcess = Start-Process `
        -FilePath $generation.Compiler `
        -ArgumentList @(
            "windows-stdlib", $stdlibRoot,
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            $singleSource) `
        -RedirectStandardOutput $publicStdlibOutput `
        -RedirectStandardError $publicStdlibError `
        -WindowStyle Hidden `
        -PassThru
    Wait-VerificationProcess $publicStdlibProcess "$($generation.Name) public stdlib source-root emission"
    if ($publicStdlibProcess.ExitCode -ne 0) {
        $details = [System.IO.File]::ReadAllText($publicStdlibError)
        throw "$($generation.Name) public stdlib source-root emission failed with exit code $($publicStdlibProcess.ExitCode).`n$details"
    }
    $diagnostics = [System.IO.File]::ReadAllText($publicStdlibError)
    if (-not [string]::IsNullOrWhiteSpace($diagnostics)) {
        throw "$($generation.Name) public stdlib source-root emission produced diagnostics.`n$diagnostics"
    }
    $publicStdlibOutputs.Add((Get-NormalizedHash $publicStdlibOutput))
}
if ($publicStdlibOutputs[0] -ne $publicStdlibOutputs[1]) {
    throw "stage-2 and stage-3 public stdlib source-root LLVM differs"
}
$resultPropagationExecutable = Join-Path $artifactsDir "stage3-check-result-propagation-control.exe"
$resultPropagationOutput = Join-Path $artifactsDir "stage3-check-result-propagation-control.stdout.txt"
$resultPropagationError = Join-Path $artifactsDir "stage3-check-result-propagation-control.stderr.txt"
$resultPropagationBuild = Start-Process `
    -FilePath $stage3Path `
    -ArgumentList @(
        "build", $resultPropagationControlSource,
        "-o", $resultPropagationExecutable,
        "--target", "windows-x64",
        "--llvm", $llvmRoot,
        "--stdlib", $stdlibRoot,
        "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        "-O1", "--keep-temps") `
    -RedirectStandardOutput $resultPropagationOutput `
    -RedirectStandardError $resultPropagationError `
    -PassThru `
    -WindowStyle Hidden
Wait-VerificationProcess $resultPropagationBuild "stage3 Result propagation control build"
if ($resultPropagationBuild.ExitCode -ne 0) {
    throw "stage-3 Result propagation control build failed.`n$([System.IO.File]::ReadAllText($resultPropagationError))"
}
& $llvmAsPath ($resultPropagationExecutable + ".ll") -o ([System.IO.Path]::ChangeExtension($resultPropagationExecutable, ".bc"))
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$resultPropagationRun = Invoke-VerificationProcessCapture `
    -FilePath $resultPropagationExecutable `
    -Description "stage3 Result propagation control executable"
$resultPropagationActual = $resultPropagationRun.Stdout.TrimEnd("`r", "`n")
if ($resultPropagationRun.ExitCode -ne 0 -or $resultPropagationActual -ne "quic-endpoint=ok") {
    throw "stage-3 Result propagation control-order execution failed: expected 'quic-endpoint=ok', actual '$resultPropagationActual'"
}
& (Join-Path $PSScriptRoot "verify-native-source-style.ps1") -Compiler $stage3Path
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-cli-format.ps1") -Compiler $stage3Path
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-binary-codecs.ps1") -Compiler $stage3Path -LlvmHome $llvmRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Assert-InputFingerprintStable `
    -ExpectedFingerprint ([System.IO.File]::ReadAllText($stage3CandidateFingerprintPath)) `
    -CurrentFingerprint (Get-Stage3CandidateInputFingerprint) `
    -Phase "Stage3"
Move-Item -LiteralPath $stage3LlvmPath -Destination $publishedStage3LlvmPath -Force
Move-Item -LiteralPath $stage3BitcodePath -Destination $publishedStage3BitcodePath -Force
Move-Item -LiteralPath $stage3Path -Destination $publishedStage3Path -Force
$stage3LlvmPath = $publishedStage3LlvmPath
$stage3BitcodePath = $publishedStage3BitcodePath
$stage3Path = $publishedStage3Path
Write-Stage2ArtifactReceipt `
    -LlvmPath $stage3LlvmPath `
    -BitcodePath $stage3BitcodePath `
    -ExecutablePath $stage3Path `
    -ReceiptPath $stage3ArtifactReceiptPath
Move-Item -LiteralPath $stage3CandidateFingerprintPath -Destination $stage3FingerprintPath -Force
Remove-Item -LiteralPath $stage3CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
& (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
    -Platform windows `
    -Stage3Path $stage3Path `
    -RepositoryRoot $repoRoot
$incrementalSeedDirectory = Join-Path $repoRoot "artifacts\incremental-selfhost"
$incrementalSeedPath = Join-Path $incrementalSeedDirectory "selfhost-slg-seed.exe"
$incrementalSeedReceiptPath = Join-Path $incrementalSeedDirectory "selfhost-slg-seed.sha256"
$incrementalSeedCandidatePath = Get-CandidateArtifactPath $incrementalSeedPath
$incrementalSeedReceiptCandidatePath = Get-CandidateArtifactPath $incrementalSeedReceiptPath
New-Item -ItemType Directory -Force -Path $incrementalSeedDirectory | Out-Null
Remove-Item -LiteralPath $incrementalSeedCandidatePath, $incrementalSeedReceiptCandidatePath -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $stage3Path -Destination $incrementalSeedCandidatePath
$incrementalSeedHash = (Get-FileHash -LiteralPath $incrementalSeedCandidatePath -Algorithm SHA256).Hash
[System.IO.File]::WriteAllText($incrementalSeedReceiptCandidatePath, $incrementalSeedHash)
Move-Item -LiteralPath $incrementalSeedCandidatePath -Destination $incrementalSeedPath -Force
Move-Item -LiteralPath $incrementalSeedReceiptCandidatePath -Destination $incrementalSeedReceiptPath -Force
$incrementalSeedProvenancePath = Write-VerifiedStage3SeedProvenance `
    -RepositoryRoot $repoRoot `
    -Target windows `
    -Producer "verify-selfhost-stage3.ps1" `
    -Optimization O1 `
    -SeedPath $incrementalSeedPath `
    -Stage2ExecutablePath $stage2Path `
    -Stage2LlvmPath $stage2LlvmPath `
    -Stage2BitcodePath $stage2BitcodePath `
    -Stage2OutputReceiptPath $stage2ArtifactReceiptPath `
    -Stage3ExecutablePath $stage3Path `
    -Stage3LlvmPath $stage3LlvmPath `
    -Stage3BitcodePath $stage3BitcodePath `
    -Stage3InputReceiptPath $stage3FingerprintPath `
    -Stage3OutputReceiptPath $stage3ArtifactReceiptPath
Write-Host "[stage3 3/3] PASS fixed point $stage3Hash, Result propagation control order, source-style notes, native formatting, and binary codecs."
Write-Host "[stage3 3/3] Published verified SLG feedback seed $incrementalSeedHash with provenance $incrementalSeedProvenancePath."
}
finally {
    Release-SelfHostVerificationLock $selfHostVerificationLock
}
