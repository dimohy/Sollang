"""Trace nonzero enum return tags to exact LLVM return instructions."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llvm', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--view-return-function', action='append', default=[])
    args = parser.parse_args()
    shim = ROOT / 'tests/native-interop/enum_return_trace.c'
    clang = ROOT / '.tools/llvm-22.1.8/bin/clang.exe'
    inputs = [args.llvm.resolve(), shim, clang, pathlib.Path(__file__)]
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    sites, view_sites, lines, function = {}, {}, [], ''
    selected = set(args.view_return_function)
    found = set()
    for number, line in enumerate(args.llvm.read_text(encoding='utf-8-sig').splitlines(), 1):
        if line.startswith('define '):
            function = line
        view_match = re.fullmatch(r'  ret (\{ ptr, i64 \}|%sollang\.int_slice) (%[\w]+)', line)
        owner_match = re.search(r'@([\w]+)\(', function)
        owner = owner_match.group(1) if owner_match else ''
        if line == 'entry:' and owner in selected:
            lines.append(line)
            for ordinal, argument in enumerate(re.findall(r'\{ ptr, i64 \} (%arg\d*)', function)):
                site = number * 1000 + ordinal
                view_sites[str(site)] = {'function': function, 'instruction': line,
                                         'kind': 'argument', 'ordinal': ordinal}
                lines.extend([f'  %trace_input_ptr_{site} = extractvalue {{ ptr, i64 }} {argument}, 0',
                              f'  %trace_input_len_{site} = extractvalue {{ ptr, i64 }} {argument}, 1',
                              f'  call void @audit_view_hash(ptr %trace_input_ptr_{site}, i64 %trace_input_len_{site}, i32 {site})'])
            continue
        if view_match and owner in selected:
            view_type, value = view_match.groups()
            found.add(owner)
            view_sites[str(number)] = {'function': function, 'instruction': line, 'kind': 'return'}
            lines.extend([f'  %trace_view_ptr_{number} = extractvalue {view_type} {value}, 0',
                          f'  %trace_view_len_{number} = extractvalue {view_type} {value}, 1',
                          f'  call void @audit_view_hash(ptr %trace_view_ptr_{number}, i64 %trace_view_len_{number}, i32 {number})'])
        match = re.fullmatch(r'  ret (%sollang\.enum\.[\w]+) (%[\w]+)', line)
        if match:
            enum_type, value = match.groups()
            sites[str(number)] = {'function': function, 'instruction': line}
            lines.extend([f'  %trace_tag_{number} = extractvalue {enum_type} {value}, 0',
                          f'  call void @audit_enum_return(i32 %trace_tag_{number}, i32 {number})'])
        lines.append(line)
    if not sites:
        raise ValueError('ENUM_TRACE_RETURNS_MISSING')
    if found != selected:
        raise ValueError('ENUM_TRACE_VIEW_FUNCTION_MISSING: ' + ','.join(sorted(selected - found)))
    args.output.mkdir(parents=True, exist_ok=False)
    ll, exe = args.output / 'trace.ll', args.output / 'trace.exe'
    ll.write_text('\n'.join(lines) + '\ndeclare void @audit_enum_return(i32,i32)\ndeclare void @audit_view_hash(ptr,i64,i32)\n', encoding='utf-8')
    record = {'status': 'running', 'inputs': hashes, 'sites': sites, 'events': [],
              'viewSites': view_sites, 'viewEvents': [], 'selectedViewFunctions': sorted(selected)}
    def save():
        (args.output / 'result.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    def run(command, name):
        with (args.output / (name + '.stdout')).open('wb') as out, (args.output / (name + '.stderr')).open('wb') as err:
            proc = subprocess.Popen([str(x) for x in command], stdout=out, stderr=err)
            try:
                return proc.wait(timeout=180)
            except (subprocess.TimeoutExpired, KeyboardInterrupt):
                subprocess.run(['taskkill', '/PID', str(proc.pid), '/T', '/F'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                proc.wait()
                raise
    save()
    try:
        record['linkExit'] = run([clang, '-Wno-override-module', ll, shim, '-O1', '-o', exe,
                                 '-lws2_32', '-lshell32', '-lbcrypt'], 'link')
        if record['linkExit'] != 0:
            raise RuntimeError('ENUM_TRACE_LINK_FAILED')
        record['runExit'] = run([exe.resolve()], 'run')
        for match in re.finditer(r'enum-return=(\d+),tag=(-?\d+)',
                                 (args.output / 'run.stderr').read_text(errors='replace')):
            site, tag = match.groups()
            record['events'].append({'site': int(site), 'tag': int(tag), **sites[site]})
        record['stdout'] = (args.output / 'run.stdout').read_text(errors='replace')
        for match in re.finditer(r'view-return=(\d+),length=(\d+),fingerprint=([0-9a-f]+)',
                                 (args.output / 'run.stderr').read_text(errors='replace')):
            site, length, fingerprint = match.groups()
            record['viewEvents'].append({'site': int(site), 'length': int(length),
                                         'fingerprint': fingerprint, **view_sites[site]})
        record['status'] = 'observed'
    except BaseException as exc:
        record['status'] = 'failed'
        record['failure'] = str(exc)
        raise
    finally:
        record['inputStable'] = all(hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest() == sha
                                    for p, sha in hashes.items())
        if not record['inputStable']:
            record['status'] = 'failed'
            record['failure'] = 'ENUM_TRACE_INPUT_DRIFT'
        save()
    print(json.dumps({'status': record['status'], 'events': record['events'][-12:],
                      'stdout': record['stdout']}))


if __name__ == '__main__':
    main()
