"""Inject null at each observed dictionary/Set storage allocation site.

Reuse emitted LLVM and one linked probe per implementation. The production
allocation CFG is preserved; only its allocator call is redirected to a C shim.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

from completed_artifact_plan import initialize_output, cleanup_output
from verification_execution import VerificationExecution

ROOT = Path(__file__).resolve().parent.parent
TRAP_EXIT = 0xC000001D  # llvm.trap on the frozen Windows x64 target.


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llvm', type=Path, required=True)
    parser.add_argument('--dialect', choices=('csharp', 'slg'), required=True)
    parser.add_argument('--contract', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    shim = ROOT / 'tests/native-interop/dictionary_allocation_failure.c'
    clang = ROOT / '.tools/llvm-22.1.8/bin/clang.exe'
    inputs = [args.llvm.resolve(), args.contract.resolve(), shim, clang, Path(__file__),
              ROOT / 'scripts/verification_execution.py',
              ROOT / 'scripts/completed_artifact_plan.py']
    pins = {str(path): sha(path) for path in inputs}
    contract = json.loads(args.contract.read_text(encoding='utf-8-sig'))
    expected = contract['cases'][0]['stdout'].strip()
    lines = args.llvm.read_text(encoding='utf-8-sig').splitlines()
    sites, function = {}, ''
    for number, line in enumerate(lines, 1):
        if line.startswith('define '):
            function = line
        pattern = (r'call ptr @sollang_alloc\((i64 %(?:generic_)?dict_bytes\d+)\)'
                   if args.dialect == 'csharp' else
                   r'call ptr @malloc\((i64 %[^ ]+_allocation_bytes)\)')
        changed = re.sub(pattern,
                         rf'call ptr @dictionary_failure_allocate(\1, i32 {number})', line)
        if changed != line:
            sites[number] = dict(function=function, instruction=line)
        lines[number - 1] = changed
    if not sites:
        raise ValueError('DICTIONARY_FAILURE_NO_ALLOCATION_SITES')
    text = '\n'.join(lines).replace('@sollang_start()', '@slg_program_main()')
    text = re.sub(r'^(define (?:dso_local )?i32 )@main\(\)',
                  r'\1@slg_program_main()', text, flags=re.M)
    if len(re.findall(r'^define (?:dso_local )?i32 @slg_program_main\(\)', text, re.M)) != 1:
        raise ValueError('DICTIONARY_FAILURE_ENTRY_SHAPE')
    text += '\ndeclare ptr @dictionary_failure_allocate(i64, i32)\n'
    output = args.output.resolve()
    initialize_output(ROOT, output)
    output.mkdir(parents=True, exist_ok=False)
    llvm, executable = output / 'fault.ll', output / 'fault.exe'
    llvm.write_bytes(text.encode('utf-8'))
    (output / 'sites.json').write_text(json.dumps(sites, indent=2), encoding='utf-8')
    result = dict(schemaVersion=1, status='running', dialect=args.dialect,
                  inputHashes=pins, completed=0, total=None, cases=[],
                  limitation='Only dynamically observed shared storage allocation sites; Windows x64')
    stable = lambda: all(Path(name).is_file() and sha(Path(name)) == value
                         for name, value in pins.items())
    execution = VerificationExecution(ROOT, output, result, stable, sha)
    execution.save()
    error = None
    try:
        command = [str(clang), '-Wno-override-module', str(llvm), str(shim),
                   '-O1', '-o', str(executable), '-lws2_32', '-lshell32', '-lbcrypt', '-lole32']
        if execution.run(command, output / 'link').returncode != 0:
            raise ValueError('DICTIONARY_FAILURE_LINK')
        if (output / 'link.stderr').read_text().strip():
            raise ValueError('DICTIONARY_FAILURE_LINK_DIAGNOSTICS')
        baseline = execution.run([str(executable), '0'], output / 'baseline')
        if baseline.returncode != 0 or (output / 'baseline.stdout').read_text(encoding='utf-8').strip() != expected:
            raise ValueError('DICTIONARY_FAILURE_BASELINE')
        stderr = (output / 'baseline.stderr').read_text()
        live = sorted(set(map(int, re.findall(r'^dictionary-allocation-site=(\d+)$', stderr, re.M))))
        if not live or any(site not in sites for site in live):
            raise ValueError('DICTIONARY_FAILURE_SITE_COVERAGE')
        if re.sub(r'^dictionary-allocation-site=\d+\r?\n?', '', stderr, flags=re.M).strip():
            raise ValueError('DICTIONARY_FAILURE_BASELINE_DIAGNOSTICS')
        result.update(total=len(live), observedSites=live, linkedProbeSha256=sha(executable))
        execution.save()
        for site in live:
            prefix = output / f'fail-{site}'
            run = execution.run([str(executable), str(site)], prefix)
            observed = prefix.with_suffix('.stderr').read_text()
            passed = run.returncode & 0xffffffff == TRAP_EXIT and f'dictionary-allocation-site={site}\n' in observed
            result['cases'].append(dict(site=site, exit=run.returncode, passed=passed, **sites[site]))
            result['completed'] += int(passed)
            execution.save()
        result['status'] = 'passed' if result['completed'] == result['total'] else 'failed'
    except BaseException as caught:
        error = caught
        raise
    finally:
        execution.finalize(error, cleanup=False)
    if result['status'] == 'passed':
        cleanup_output(ROOT, output, execute=True)
    print(json.dumps({key: result[key] for key in ('status', 'completed', 'total', 'inputsStable', 'processesStopped')}))
    if result['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
