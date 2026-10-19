"""Observe canonical branch types over an exact failing input manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def manifest_sources(manifest):
    sources = [ROOT / line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    if not sources or len(set(sources)) != len(sources):
        raise ValueError('BRANCH_OBSERVER_MANIFEST_EMPTY_OR_DUPLICATED')
    for source in sources:
        if not source.resolve().is_relative_to(ROOT) or not source.is_file():
            raise ValueError('BRANCH_OBSERVER_SOURCE_MISSING: ' + str(source))
    return sources


def validate_helper(helper, type_source):
    body = helper.read_text(encoding='utf-8-sig')
    if re.search(r'\$[A-Za-z_]\w*!', body):
        raise ValueError('BRANCH_OBSERVER_MUTABLE_INTERPOLATION_REQUIRES_PARENTHESES')
    declaration = re.search(r'public struct SemanticType\s*\{([^}]+)\}', type_source.read_text(encoding='utf-8-sig'))
    if declaration is None:
        raise ValueError('BRANCH_OBSERVER_SEMANTIC_TYPE_CONTRACT_MISSING')
    fields = set(re.findall(r'public\s+(\w+)\s*:', declaration.group(1)))
    missing = set(re.findall(r'semanticType\.(\w+)', body)) - fields
    if missing:
        raise ValueError('BRANCH_OBSERVER_UNKNOWN_TYPE_FIELD: ' + ','.join(sorted(missing)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--first-line', type=int, required=True)
    parser.add_argument('--last-line', type=int, required=True)
    parser.add_argument('--format-compiler', type=Path, required=True)
    parser.add_argument('--mode', choices=('semantic', 'library-ir', 'native-ir', 'checked-native-ir', 'checked-native-emission'), default='semantic')
    parser.add_argument('--all-expressions', action='store_true', help='Include every AST kind and CST owner in semantic observations.')
    parser.add_argument('--optimization', choices=('O0', 'O1'), default='O0',
                        help='Compile the observer at the same optimization level as the compiler product.')
    args = parser.parse_args()
    if args.all_expressions and args.mode != 'semantic':
        parser.error('--all-expressions requires --mode semantic')
    output = args.output.resolve()
    manifest = args.manifest.resolve()
    sources = manifest_sources(manifest)
    target = args.source.resolve()
    if target not in [source.resolve() for source in sources]:
        raise ValueError('BRANCH_OBSERVER_TARGET_NOT_IN_MANIFEST')
    source_index = [source.resolve() for source in sources].index(target)
    lines = target.read_bytes().splitlines(keepends=True)
    if not 1 <= args.first_line <= args.last_line <= len(lines):
        raise ValueError('BRANCH_OBSERVER_LINE_RANGE_INVALID')
    start = sum(map(len, lines[:args.first_line - 1]))
    end = sum(map(len, lines[:args.last_line]))
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('BRANCH_OBSERVER_FRESH_ARTIFACT_OUTPUT_REQUIRED')
    helper = Path(__file__).with_name('context-branch-type-observer.slg' if args.mode == 'semantic' else 'context-branch-ir-observer.slg')
    type_source = ROOT / 'selfhost/semantic/type_ids.slg'
    validate_helper(helper, type_source)
    formatter = args.format_compiler.resolve()
    if not formatter.is_file():
        raise ValueError('BRANCH_OBSERVER_FORMATTER_MISSING')
    formatting = subprocess.run([str(formatter), 'format', '--check', str(helper)], cwd=ROOT,
                                capture_output=True, text=True, encoding='utf-8', timeout=60)
    if formatting.returncode or formatting.stderr.strip():
        raise ValueError('BRANCH_OBSERVER_FORMAT_PREFLIGHT_FAILED: ' + formatting.stderr.strip())
    compiler = ROOT / 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe'
    compiler_manifest = ROOT / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
    compiler_sources = [path for path in manifest_sources(compiler_manifest) if path.name != 'selfhost-sollangc-driver.slg']
    stdlib = sorted((ROOT / 'stdlib').rglob('*.slg'))
    observed_sources = list(dict.fromkeys([*sources, *stdlib]))
    llvm = ROOT / '.tools/llvm-22.1.8'
    tools = [*managed_runtime_inputs(compiler), llvm / 'bin/llvm-as.exe', llvm / 'bin/clang.exe']
    for path in [helper, manifest, compiler_manifest, *tools]:
        if not path.is_file():
            raise ValueError('BRANCH_OBSERVER_INPUT_MISSING: ' + str(path))
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    driver = output / 'driver.slg'
    namespace = 'sollang.compiler.probes.context_branch_types' if args.mode == 'semantic' else 'sollang.compiler.llvm.text'
    function = 'trace' if args.mode == 'semantic' else 'traceContextBranchIr'
    if args.mode == 'native-ir':
        function = 'traceNativeContextBranchIr'
    if args.mode == 'checked-native-ir':
        function = 'traceCheckedNativeContextBranchIr'
    if args.mode == 'checked-native-emission':
        function = 'traceCheckedNativeEmission'
    if args.all_expressions:
        function = 'traceAll'
    driver.write_bytes((f'import {namespace} as observer\nmain {{\n    [Text; ~] => paths!\n'
        + ''.join('    paths! -> push(' + json.dumps(path.as_posix()) + ')\n' for path in observed_sources)
        + f'    paths! -> observer.{function}({source_index}, {start}, {end})\n}}\n').encode('utf-8'))
    inputs = list(dict.fromkeys([helper, type_source, formatter, driver, manifest, compiler_manifest, Path(__file__).resolve(),
                               *observed_sources, *compiler_sources, *tools]))
    pins = {str(path): sha(path) for path in inputs}
    stable = lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in inputs)
    result = dict(schemaVersion=1, status='running', inputHashes=pins,
                  scope='Semantic branch type observation only; no paired acceptance or source phase closure',
                  sourceIndex=source_index, target=str(target), byteRange=[start, end],
                  sourceCount=len(observed_sources))
    result['formatPreflight'] = dict(exit=formatting.returncode, stdout=formatting.stdout, stderr=formatting.stderr)
    result['mode'] = args.mode
    result['allExpressions'] = args.all_expressions
    result['optimization'] = args.optimization
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        build = runner.run([str(compiler), 'build', str(driver), str(helper), *map(str, compiler_sources),
                            '-o', str(output / 'observer.exe'), '--target', 'windows-x64',
                            '--llvm', str(llvm), '--keep-temps', '-' + args.optimization], output / 'build', 600)
        if build.returncode or build.stderr.strip():
            raise ValueError('BRANCH_OBSERVER_BUILD_FAILED')
        run = runner.run([str(output / 'observer.exe')], output / 'run', 1200)
        if run.returncode or run.stderr.strip():
            raise ValueError('BRANCH_OBSERVER_RUN_FAILED')
        if not run.stdout.strip():
            raise ValueError('BRANCH_OBSERVER_EMPTY_OBSERVATION')
        result['status'] = 'observed'
        result['observationLines'] = len(run.stdout.splitlines())
        print('BRANCH_TYPES_OBSERVED: ' + str(result['observationLines']))
    except BaseException as exc:
        error = exc
        raise
    finally:
        runner.finalize(error)


if __name__ == '__main__':
    main()
