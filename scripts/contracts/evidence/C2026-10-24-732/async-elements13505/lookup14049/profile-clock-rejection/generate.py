import hashlib
import json
import re
from pathlib import Path

out = Path(__file__).resolve().parent
root = Path.cwd()
canonical = root / 'selfhost/llvm/text/context_prepare.slg'
text = canonical.read_text(encoding='utf-8')
start = text.index('prepareResolvedSnapshot request:')
end = text.index('\nprepare request:', start)
original = text[start:end].rstrip()
header, body = original.split('\n', 1)
anchors = {
    'active-bodies': 'prepared -> semanticDiagnostics.activeInterpolationBodies',
    'inferred-input': 'prepared -> semanticDiagnostics.firstInferredInputConflict',
    'local-enums': 'prepared -> interpolationInference.uninvokedAssociatedMemberByNode',
    'numeric-literal': 'prepared -> semanticDiagnostics.firstNumericCallLiteralDiagnostic',
    'pre-ir-flow': 'prepared -> interpolationInference.preIrFlowCallTargets',
    'type-traits': 'typeIds.enumPayloadEdges(recursiveTypes!',
    'binding-declarations': 'prepared -> semanticDiagnostics.firstBindingDeclarationDiagnostic',
    'result-propagation': 'prepared -> interpolationInference.preIrResultPropagationDecisionByNode',
    'lower-ir': 'prepared -> lowerPreparedIr',
    'materialize-arrays': 'ir! -> typedIr.materializeContextualArrayOwners',
    'generic-bodies': 'ir! -> typedIr.bindGenericBodies',
    'operand-diagnostics': 'prepared.package -> semanticDiagnostics.firstExpressionOperandDiagnostic',
    'mutable-rebind': 'prepared -> semanticDiagnostics.firstMutableRebindDiagnostic',
    'stream-plan': 'prepared -> streamIr.build',
    'interpolation-receivers': 'prepared -> interpolationInference.classifyIntrinsicFlowReceivers',
    'interpolation-results': 'prepared -> interpolationInference.resultTypeByNode',
    'interpolation-targets': 'prepared -> interpolationInference.importedFlowCallTargets',
    'ownership-activity': 'prepared -> ownershipCheck.bodyDiagnosticActivity',
    'ownership-analysis': 'prepared -> ownershipCheck.analyzeResolvedLoweredContextWithInterpolationFactsAndPaths',
    'mutable-warnings': 'prepared -> mutableBindingWarnings.collect',
    'member-collision': 'prepared.package -> semanticDiagnostics.firstMemberFieldCollision',
}
counts = {label: sum(line.startswith('    ' + prefix) for line in body.splitlines()) for label, prefix in anchors.items()}
assert all(count > 0 for count in counts.values()), counts
seen = dict.fromkeys(anchors, 0)
lines = []
for line in body.splitlines():
    matched = [label for label, prefix in anchors.items() if line.startswith('    ' + prefix)]
    assert len(matched) <= 1, matched
    for label in matched:
        seen[label] += 1
        marker_label = label if counts[label] == 1 else label + '-' + str(seen[label])
        lines.append('    "' + marker_label + '" -> profileMark')
    lines.append(line)
body = '\n'.join(lines)
assert body.endswith('    context!\n}')
body = body[:-len('    context!\n}')] + '    "context-complete" -> profileMark\n    context!\n}'
unmarked = '\n'.join(line for line in body.splitlines() if not re.fullmatch(r'    "[a-z0-9-]+" -> profileMark', line))
assert original == header + '\n' + unmarked
header = header.replace('prepareResolvedSnapshot request:', 'profileResolvedSnapshot request:', 1).replace(' -> emitterContext.EmitContext {', ' -> emitterContext.EmitContext uses Console, Clock {', 1)
prefix = text[:text.index('\nlowerPreparedIr ')]
marker = '''
profileMark label: Text -> Unit uses Console, Clock {
    runtime.nowMillis() => tick
    "context-stage $label $tick" -> runtime.eprintln
}

'''
tail = '''

public profileResolvedFiles paths: [Text; ~] -> Int uses Console, Clock, File {
    "prepare-files" -> profileMark
    paths -> semanticContext.prepareFiles => prepared
    [Text; ~] => sources!
    prepared.package.sources -> each item { sources! -> push(item) }
    llvmTarget.windowsX64() => target
    PrepareRequest { sources: sources!, standardLibrarySourceStart: 0, standardLibrarySourceCount: 0, pointerBitWidth: target.pointerBitWidth, targetArchitecture: target.architecture, cpuDispatchPolicy: target.dispatchPolicy, requiredCpuFeatures: target.requiredFeatures, allowedCpuFeatures: target.allowedFeatures, forbiddenCpuFeatures: target.forbiddenFeatures, supportsComputePool: true, expectedPathStyle: 1 } => request
    prepared -> semanticDiagnostics.firstPreparedExplicitSignatureTypeDiagnostic => signatureDiagnostic
    prepared.package -> semanticDiagnostics.unresolvedMutableLocalReads => mutableNames
    libraryImports.empty() => libraries
    [libraryImports.LibraryFunctionResolution; ~] => libraryCalls
    prepared.package -> libraryImports.callResultTypes(prepared.semantic.types, libraries, libraryCalls) => externalResults
    "resolve-call-context" -> profileMark
    prepared -> expressionTypeIds.resolveCallContextWithExternalResults(externalResults) => resolved
    "resolved-context" -> profileMark
    request -> profileResolvedSnapshot(resolved, libraries, libraryCalls, mutableNames, signatureDiagnostic) => context
    "blocking-diagnostics" -> profileMark
    context -> diagnostics.blockingDiagnosticCount => count
    "complete" -> profileMark
    count
}
'''
main = '''import sollang.compiler.llvm.text as llvm
import sys.process as process

main {
    process.arguments() => arguments
    [Text; ~] => paths!
    1 => index!
    index! < (arguments -> len) -> while {
        paths! -> push(arguments[index!])
        index! + 1 => index!
    }
    paths! -> llvm.profileResolvedFiles => count
    "profile diagnostics = $count" -> println
}
'''
for name, content in [('profile.slg', prefix + marker + header + '\n' + body + tail), ('main.slg', main)]:
    path = out / name
    assert not path.exists(), path
    path.write_text(content, encoding='utf-8', newline='\n')
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
plan = json.loads((root / 'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/case1290-next14038/validate-plan14042.json').read_text())
plan.update(scope='temporary-context-stage-profile-no-production-source-edit-no-acceptance-credit', status='prepared-not-built', source=str(canonical), sourceSha256=sha(canonical), clonedFunction='prepareResolvedSnapshot', originalFunctionSha256=hashlib.sha256(original.encode()).hexdigest().upper(), mechanicalBodyIdentityVerified=True, markers=list(anchors), maximumBuildInvocations=1, buildMaximumSeconds=180, maximumInvocations=1, maximumSeconds=180, cumulativeDiagnosticMaximumSeconds=1155, maximumAdditionalBuildSeconds=180, buildOptimization='O2', buildJobs=4, claimsPerformanceImprovement=False, costChoice='Reuse CSharp seed and supervisor with one temporary mechanically verified context function, avoiding another compiler image and source100 replay.', limitations=['Serial raw-source prepareFiles and stdlibCount0, empty external-library catalog differ from the cached parallel production path.', 'Only name, Console/Clock permission and marker calls differ inside the cloned function.', 'No production speedup or original1290 acceptance from trace output.'])
(out / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n', encoding='utf-8')
print('CONTEXT_CLONE_BODY_IDENTITY_VERIFIED', len(anchors), 'markers')
