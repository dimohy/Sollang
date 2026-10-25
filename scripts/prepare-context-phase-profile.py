"""Prepare a pinned context trace with the selected stdlib source authority."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from context_profile_source_contract import render_loader, validate_loader

root = Path.cwd()
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-directory', type=Path, required=True)
parser.add_argument('--base-plan', type=Path, required=True)
parser.add_argument('--harness-manifest', type=Path, required=True)
parser.add_argument('--stdlib-root', type=Path, required=True)
args = parser.parse_args()
out = args.output_directory.resolve()
if out.exists():
    raise ValueError('PROFILE_OUTPUT_ALREADY_EXISTS')
base_plan = args.base_plan.resolve()
harness_manifest = args.harness_manifest.resolve()
plan = json.loads(base_plan.read_text(encoding='utf-8-sig'))
paths = [Path(value).resolve() for value in plan['paths']]
stdlib_root = args.stdlib_root.resolve()
if stdlib_root != (root / 'stdlib').resolve():
    raise ValueError('PROFILE_SELECTED_STDLIB_ROOT_MISMATCH')
stdlib = set(stdlib_root.rglob('*.slg'))
count = len(stdlib)
if not stdlib or len(paths) != len(set(paths)) or set(paths[:count]) != stdlib:
    raise ValueError('PROFILE_STDLIB_PREFIX_MISMATCH')
if any(not path.is_relative_to(root) or not path.is_file() for path in paths):
    raise ValueError('PROFILE_RUNTIME_SOURCE_MISSING')
harness_rows = [line.strip() for line in harness_manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
if len(harness_rows) < 3 or not harness_rows[0].endswith('/main.slg') or not harness_rows[1].endswith('/profile.slg'):
    raise ValueError('PROFILE_BASE_HARNESS_INVALID')
harness = [out / 'main.slg', out / 'profile.slg', *[(root / row).resolve() for row in harness_rows[2:]]]
if any(not path.is_file() or not path.is_relative_to(root) for path in harness[2:]):
    raise ValueError('PROFILE_HARNESS_SOURCE_MISSING')
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
header = header.replace('prepareResolvedSnapshot request:', 'profileResolvedSnapshot request:', 1).replace(' -> emitterContext.EmitContext {', ' -> emitterContext.EmitContext uses Console {', 1)
prefix = text[:text.index('\nlowerPreparedIr ')].replace('import sys.file as file', 'import sollang.compiler.syntax.source_decoding as sourceDecoding\nimport sys.file as file', 1)
marker = '''
profileMark label: Text -> Unit uses Console {
    "context-stage $label" -> runtime.eprintln
}

'''
tail = render_loader(count)
main = '''import sollang.compiler.llvm.text as llvm
import sys.process as process

main {
    process.arguments() => arguments
    [Text; ~] => paths!
    UIntSize(1) => index!
    index! < (arguments -> len) -> while {
        paths! -> push(arguments[index!])
        index! + 1 => index!
    }
    paths! -> llvm.profileResolvedFiles => count
    "profile diagnostics = $count" -> println
}
'''
validate_loader(prefix + marker + header + '\n' + body + tail, count)
out.mkdir(parents=True)
for name, content in [('profile.slg', prefix + marker + header + '\n' + body + tail), ('main.slg', main)]:
    path = out / name
    assert not path.exists(), path
    path.write_text(content, encoding='utf-8', newline='\n')
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
inputs = [*paths, *harness, canonical, Path(__file__).resolve(), base_plan, harness_manifest, root / "scripts/context_profile_source_contract.py"]
plan.update(generator=str(Path(__file__).resolve()), schemaVersion=1, status='prepared-current-source-preflight-pending',
    scope='context-stage-trace-with-validated-selected-stdlib-prefix-no-acceptance-credit',
    source=str(canonical), sourceSha256=sha(canonical),
    originalFunctionSha256=hashlib.sha256(original.encode()).hexdigest().upper(),
    generatedProfileSha256=sha(out / 'profile.slg'), generatedMainSha256=sha(out / 'main.slg'),
    mechanicalBodyIdentityVerified=True, markers=list(anchors),
    harnessSources=list(map(str, harness)), paths=list(map(str, paths)),
    inputHashes={str(path): sha(path) for path in inputs},
    standardLibraryRoot=str(stdlib_root), verifiedStandardLibraryPrefixCount=count,
    maximumBuildInvocations=1, buildMaximumSeconds=180, maximumInvocations=1, maximumSeconds=180,
    maximumAdditionalTotalSeconds=360, retryCount=0, claimsPerformanceImprovement=False,
    claimsGoalComplete=False,
    limitations=['The checked borrowed-source preparation matches production ownership; the external artifact library catalog is still empty and caching is omitted.',
                 'Stdlib source authority is admitted only after exact selected-root prefix validation.',
                 'Trace timing is diagnostic evidence, not original acceptance or a production speed claim.'])
plan.pop('cumulativeDiagnosticMaximumSeconds', None)
(out / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n', encoding='utf-8')
(out / 'profile.sources.txt').write_text('\n'.join(str(path.relative_to(root)).replace('\\', '/') for path in harness) + '\n', encoding='utf-8')
print(json.dumps(dict(status='prepared', standardLibraryPrefixCount=count, runtimeSources=len(paths), harnessSources=len(harness))))
