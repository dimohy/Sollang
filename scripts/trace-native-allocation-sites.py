"""Map native allocation failures to exact LLVM functions and instructions."""
import argparse
from collections import Counter
import hashlib
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent


def parse_live_allocation_sites(stderr, sites):
    counts = Counter(re.findall(r'^live-allocation=(\d+)\s*$', stderr, re.M))
    return [
        {'id': int(site), 'count': count, **sites.get(site, {})}
        for site, count in sorted(counts.items(), key=lambda item: int(item[0]))
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llvm', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--deterministic-p1206', action='store_true')
    args = parser.parse_args()
    shim = ROOT / 'tests/native-interop/allocation_site_audit.c'
    clang = ROOT / '.tools/llvm-22.1.8/bin/clang.exe'
    inputs = [args.llvm, shim, clang, pathlib.Path(__file__)]
    random_shim = ROOT / 'tests/native-interop/p1206_deterministic_bcrypt_audit.c'
    random_contract = ROOT / 'scripts/contracts/p1206-deterministic-allocation-audit.json'
    if args.deterministic_p1206:
        inputs += [random_shim, random_contract]
    hashes = {str(p.resolve()): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    lines, sites, function = [], {}, ''
    for number, line in enumerate(args.llvm.read_text(encoding='utf-8-sig').splitlines(), 1):
        if line.startswith('define '):
            function = line
        transformed = re.sub(r'call ptr @(?:malloc|sollang_alloc)\((i64 [^)]+)\)',
                             rf'call ptr @audit_malloc_site(\1, i32 {number})', line)
        transformed = re.sub(r'call void @(?:free|sollang_free)\((ptr [^)]+)\)',
                             rf'call void @audit_free_site(\1, i32 {number})', transformed)
        if transformed != line:
            sites[str(number)] = {'function': function, 'instruction': line}
        lines.append(transformed)
    text = '\n'.join(lines).replace('call ptr @realloc(', 'call ptr @audit_realloc(')
    text = text.replace('@sollang_start()', '@slg_program_main()')
    text = text.replace('define i32 @main()', 'define i32 @slg_program_main()')
    text = text.replace('define dso_local i32 @main()', 'define dso_local i32 @slg_program_main()')
    if len(re.findall(r'^define (?:dso_local )?i32 @slg_program_main\(\)', text, re.M)) != 1:
        raise ValueError('TRACE_ENTRY_SHAPE')
    if args.deterministic_p1206:
        if 'call i32 @BCryptGenRandom(' not in text:
            raise ValueError('TRACE_RANDOM_PROVIDER_MISSING')
        text = text.replace('declare dllimport i32 @BCryptGenRandom', 'declare i32 @audit_BCryptGenRandom')
        text = text.replace('call i32 @BCryptGenRandom(', 'call i32 @audit_BCryptGenRandom(')
    text += '\ndeclare ptr @audit_malloc_site(i64,i32)\ndeclare void @audit_free_site(ptr,i32)\ndeclare ptr @audit_realloc(ptr,i64)\n'
    args.output.mkdir(parents=True, exist_ok=False)
    ll, exe = args.output / 'trace.ll', args.output / 'trace.exe'
    ll.write_text(text, encoding='utf-8')
    (args.output / 'sites.json').write_text(json.dumps(sites, indent=2), encoding='utf-8')
    record = {'status': 'running', 'inputs': hashes,
              'invalidReleaseSites': [], 'liveAllocationSites': []}
    def save():
        (args.output / 'result.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    save()
    def run(command, name):
        with (args.output / (name + '.stdout')).open('wb') as out, (args.output / (name + '.stderr')).open('wb') as err:
            return subprocess.run([str(x) for x in command], stdout=out, stderr=err, timeout=180).returncode
    try:
        command = [clang, '-Wno-override-module', ll, shim, '-O1', '-o', exe, '-lws2_32', '-lshell32', '-lbcrypt']
        if args.deterministic_p1206:
            seed = json.loads(random_contract.read_text())['seedHex']
            command += [random_shim, '-DAUDIT_XORSHIFT_SEED=0x' + seed + 'ULL']
        record['linkExit'] = run(command, 'link')
        if record['linkExit'] != 0:
            raise RuntimeError('TRACE_LINK_FAILED')
        record['runExit'] = run([exe.resolve()], 'run')
        stderr = (args.output / 'run.stderr').read_text(errors='replace')
        for match in re.finditer(r'invalid-free=(\d+),allocation=(\d+),previous-free=(\d+)', stderr):
            record['invalidReleaseSites'].append({key: {'id': int(value), **sites.get(value, {})}
                for key, value in zip(['release', 'allocation', 'previousRelease'], match.groups())})
        record['stdout'] = (args.output / 'run.stdout').read_text(errors='replace')
        record['liveAllocationSites'] = parse_live_allocation_sites(stderr, sites)
        record['siteCounts'] = [
            {'id': int(site), **sites.get(site, {}),
             'allocations': int(allocations), 'releases': int(releases)}
            for site, allocations, releases in re.findall(
                r'site-count=(\d+),allocations=(\d+),releases=(\d+)', stderr)
        ]
        record['status'] = 'observed'
    except BaseException as exc:
        record['status'] = 'failed'
        record['failure'] = str(exc)
        raise
    finally:
        record['inputStable'] = all(hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest() == sha for p, sha in hashes.items())
        if not record['inputStable']:
            record['status'] = 'failed'
            record['failure'] = 'TRACE_INPUT_DRIFT'
        save()
    print(json.dumps({'status': record['status'], 'runExit': record['runExit'],
                      'invalidReleaseCount': len(record['invalidReleaseSites']), 'stdout': record['stdout']}))


if __name__ == '__main__':
    main()
