"""Validate an existing compiler and its preserved LLVM before a focused gate."""
import argparse
import hashlib
import json
from pathlib import Path

from verification_source_proof import current_build_inputs

ROOT = Path(__file__).resolve().parents[1]


def validate(root, directory):
    directory = directory.resolve()
    result = directory / 'result.json'
    record = json.loads(result.read_text(encoding='utf-8-sig'))
    inputs = current_build_inputs(root, record)
    if any(record.get('steps', {}).get(key) != 0
           for key in ('semanticPreflight', 'build', 'llvmAs', 'v004')):
        raise ValueError('CURRENT_COMPILER_BUILD_STEPS_INCOMPLETE')
    compiler = directory / 'compiler.exe'
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest().upper()
    if not compiler.is_file() or digest(compiler) != record.get('compilerSha256'):
        raise ValueError('CURRENT_COMPILER_BINARY_DRIFT')
    llvm = [p for p in (directory / 'compiler.ll', directory / 'compiler.exe.ll') if p.is_file()]
    if len(llvm) != 1:
        raise ValueError('CURRENT_COMPILER_PRESERVED_LLVM_REQUIRED')
    generated = {row['path']: row['sha256'] for row in record.get('generatedArtifactHashes', [])}
    if generated.get(str(llvm[0])) != digest(llvm[0]):
        raise ValueError('CURRENT_COMPILER_LLVM_DRIFT')
    logs = [directory / 'build.stdout.txt', directory / 'build.stderr.txt']
    import re
    text = ''.join(path.read_text(encoding='utf-8-sig') for path in logs)
    if logs[1].stat().st_size or re.search(r'(?m)^(?:warning S\d+|note N\d+)\b', text):
        raise ValueError('CURRENT_COMPILER_BUILD_DIAGNOSTICS')
    paths = [*inputs, result, compiler, llvm[0], *logs, Path(__file__).resolve()]
    return dict(status='passed', compiler=str(compiler), llvm=str(llvm[0]),
                inputHashes={str(p): digest(p) for p in paths})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument('--output', type=Path)
    destination.add_argument('--stdout', action='store_true')
    args = parser.parse_args()
    if args.output is not None and args.output.exists():
        raise ValueError('CURRENT_COMPILER_FRESH_PROOF_REQUIRED')
    proof = validate(ROOT, args.build)
    if args.stdout:
        print(json.dumps(proof))
        return
    args.output.write_text(json.dumps(proof, indent=2) + '\n', encoding='utf-8')
    print('CURRENT_COMPILER_PRODUCT_VALIDATED')


if __name__ == '__main__':
    main()
