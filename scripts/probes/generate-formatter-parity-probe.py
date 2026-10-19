"""Derive an actual SLG formatter probe from the verified C# format contract.

Raw source literals use the shared renderer so shell interpolation cannot alter
SLG expressions. --check verifies the same source and expected output without
rewriting either artifact.
"""
import argparse
import json
import subprocess
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from slg_fixture_literals import multiline_raw_literal


def repository_path(path):
    resolved = path.resolve()
    if not resolved.is_relative_to(ROOT):
        raise ValueError('FORMAT_PROBE_PATH_OUTSIDE_REPOSITORY')
    return resolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-contract', type=Path, required=True)
    parser.add_argument('--output-source', type=Path, required=True)
    parser.add_argument('--output-contract', type=Path, required=True)
    parser.add_argument('--format-compiler', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    source_contract = repository_path(args.source_contract)
    output_source = repository_path(args.output_source)
    output_contract = repository_path(args.output_contract)
    plan = json.loads(source_contract.read_text(encoding='utf-8-sig'))
    cases = plan.get('cases', [])
    if plan.get('schemaVersion') != 1 or not cases:
        raise ValueError('FORMAT_PROBE_CONTRACT_INVALID')
    identifiers = [case.get('id') for case in cases]
    if len(set(identifiers)) != len(cases):
        raise ValueError('FORMAT_PROBE_DUPLICATE_CASE')
    body = '''import sollang.compiler.cli_format as formatter
import sys.file as file

reportFormatted sourceText: Text, label: Text -> Unit uses Console {
    sourceText -> file.borrowText => source
    source -> formatter.format => result
    "case=$label,status=$(result.status)" -> println
    result.bytes -> file.borrowBytes => formatted
    formatted -> slice(UIntSize(0), formatted -> len) -> print
}

main {
'''
    expected = ''
    for ordinal, case in enumerate(cases):
        name = case['id']
        if (not isinstance(name, str) or not name.replace('-', '').isalnum()
                or case.get('mode') != 'format-stdin'
                or case.get('expected', {}).get('exitCode') != 0
                or case['expected'].get('stderr') != ''):
            raise ValueError('FORMAT_PROBE_CASE_INVALID')
        body += multiline_raw_literal(case['source']) + f' => source{ordinal}\n'
        body += f'    source{ordinal} -> reportFormatted("{name}")\n'
        expected += f'case={name},status=0\n' + case['expected']['stdout']
    body += '}\n'
    formatter = args.format_compiler.resolve(strict=True)
    formatting = subprocess.run([str(formatter), 'format', '--stdin'], cwd=ROOT,
                                input=body.encode('utf-8'), capture_output=True, timeout=60)
    if formatting.returncode or formatting.stderr.strip():
        raise ValueError('FORMAT_PROBE_CANONICAL_FORMAT_FAILED')
    body = formatting.stdout.decode('utf-8').replace('\r\n', '\n')
    manifest = ROOT / 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
    sources = [line.strip() for line in manifest.read_text(encoding='utf-8-sig').splitlines()
               if line.strip() and not line.strip().endswith('/selfhost-sollangc-driver.slg')]
    if len(sources) != len(set(sources)) or any(not (ROOT / source).is_file() for source in sources):
        raise ValueError('FORMAT_PROBE_SOURCE_CLOSURE_INVALID')
    relative_source = output_source.relative_to(ROOT).as_posix()
    contract = dict(schemaVersion=1,
                    scope='Actual SLG formatter output derived from C# formatter contract; native compiler acceptance is separate',
                    sourceContract=source_contract.relative_to(ROOT).as_posix(),
                    formatCheckSources=[relative_source],
                    cases=[dict(id='formatter-parity', source=relative_source,
                                additionalSources=sources, exit=0, stderr='', stdout=expected.strip())])
    rendered = json.dumps(contract, indent=2) + '\n'
    if args.check:
        if (output_source.read_bytes() != body.encode('utf-8')
                or output_contract.read_bytes() != rendered.encode('utf-8')):
            raise ValueError('FORMAT_PROBE_GENERATED_ARTIFACT_DRIFT')
        print('FORMAT_PROBE_GENERATION_CHECK_PASSED')
        return
    if output_source.exists() or output_contract.exists():
        raise ValueError('FORMAT_PROBE_FRESH_OUTPUT_REQUIRED')
    output_source.write_bytes(body.encode('utf-8'))
    output_contract.write_bytes(rendered.encode('utf-8'))
    print(f'FORMAT_PROBE_GENERATED: {len(cases)} cases, {len(sources)} compiler sources')


if __name__ == '__main__':
    main()
