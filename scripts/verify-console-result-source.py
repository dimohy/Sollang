"""Compile embedded fact programs with C# before building the SLG semantic probe."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import textwrap

ROOT = Path(__file__).resolve().parent.parent
DRIVER = ROOT / 'scripts/contracts/fixtures/c527-console-result-facts-driver.slg'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def embedded_programs():
    programs = re.findall(r'"""(.*?)"""\s*->\s*checks\.(\w+)', DRIVER.read_text(encoding='utf-8'), re.S)
    if [name for _, name in programs] != ['consoleResultFacts', 'consoleResultFacts', 'declaredResultFacts']:
        raise ValueError('CONSOLE_FACTS_EMBEDDED_PROGRAM_CONTRACT_CHANGED')
    return [textwrap.dedent(source).strip() + '\n' for source, _ in programs]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() or not output.is_relative_to(ROOT / 'artifacts'):
        raise ValueError('CONSOLE_FACTS_FRESH_ARTIFACT_OUTPUT_REQUIRED')
    programs = embedded_programs()
    driver_hash = sha(DRIVER)
    output.mkdir(parents=True)
    cases = []
    for index, (program, expected) in enumerate(zip(programs, ['ab', 'ab', '8']), 1):
        source = output / f'embedded-{index}.slg'
        source.write_bytes(program.encode('utf-8'))
        cases.append(dict(id=f'embedded-{index}', source=source.relative_to(ROOT).as_posix(), exit=0, stderr='', stdout=expected))
    contract = output / 'embedded-program-contract.json'
    contract.write_text(json.dumps(dict(schemaVersion=1, cases=cases, driverSha256=driver_hash), indent=2) + '\n', encoding='utf-8')
    runner = ROOT / 'scripts/verify-c385-preir-call-numeric.py'
    result = dict(schemaVersion=1, status='running', managedProgramsCompleted=0, managedProgramsTotal=3,
                  factChecksCompleted=0, factChecksTotal=1, driverSha256=driver_hash,
                  scope='Embedded C# programs first; current SLG semantic result facts second; no native compiler closure')
    record = output / 'result.json'
    def save():
        record.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    save()
    try:
        subprocess.run([sys.executable, str(runner), '--mode', 'managed', '--contract', str(contract), '--output', str(output / 'managed-programs')], cwd=ROOT, check=True)
        result['managedProgramsCompleted'] = 3
        save()
        if sha(DRIVER) != driver_hash:
            raise ValueError('CONSOLE_FACTS_DRIVER_CHANGED_AFTER_MANAGED_PROOF')
        subprocess.run([sys.executable, str(runner), '--mode', 'managed', '--contract', 'scripts/contracts/c527-console-result-source-facts.json', '--output', str(output / 'facts')], cwd=ROOT, check=True)
        if sha(DRIVER) != driver_hash:
            raise ValueError('CONSOLE_FACTS_DRIVER_CHANGED_DURING_FACT_PROOF')
        result.update(status='passed', factChecksCompleted=1,
                      managedProof=str(output / 'managed-programs/result.json'),
                      factsProof=str(output / 'facts/result.json'))
    except BaseException as exc:
        result.update(status='failed', failure=f'{type(exc).__name__}: {exc}')
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
