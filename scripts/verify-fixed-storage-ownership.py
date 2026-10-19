"""Check paired fixed-storage behavior and exact allocation/release counts."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import time

from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output, cleanup_output, assert_output_shutdown, GENERATED

ROOT = pathlib.Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def finish_active_cases(record, status, failure=None):
    """Keep interrupted or failed cases distinct from live work."""
    for case in record['cases']:
        if case['status'] == 'running':
            case['status'] = status
            if failure is not None:
                case['failure'] = failure


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=pathlib.Path, required=True)
    parser.add_argument('--managed-compiler', type=pathlib.Path,
                        default=ROOT / 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll')
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--case', action='append')
    parser.add_argument('--side', choices=('managed', 'selfhost', 'both'), default='both')
    parser.add_argument('--prepare-cleanup', action='store_true',
                        help='Prepare and validate the cleanup plan without deleting products.')
    parser.add_argument('--contract', type=pathlib.Path,
                        default=ROOT / 'scripts/contracts/fixed-storage-ownership.json')
    args = parser.parse_args()
    contract_path = args.contract.resolve()
    contract = json.loads(contract_path.read_text(encoding='utf-8'))
    cases = contract['cases']
    assert contract['schemaVersion'] == 1
    assert len({c['id'] for c in cases}) == len(cases)
    assert all(type(c['allocations']) is int and c['allocations'] >= 0
               and isinstance(c['stdout'], str) for c in cases)
    if args.case:
        unknown = set(args.case) - {c['id'] for c in cases}
        if unknown:
            parser.error(f'Unknown cases: {sorted(unknown)}')
        cases = [c for c in cases if c['id'] in args.case]
    managed = args.managed_compiler.resolve()
    sides = ('managed', 'selfhost') if args.side == 'both' else (args.side,)
    llvm = ROOT / '.tools/llvm-22.1.8'
    shim = ROOT / 'tests/native-interop/owned_array_audit.c'
    random_shim = ROOT / 'tests/native-interop/p1206_deterministic_bcrypt_audit.c'
    closure = ROOT / 'scripts/verify-llvm-direct-call-closure.ps1'
    inputs = [pathlib.Path(__file__), contract_path,
              llvm / 'bin/clang.exe', llvm / 'bin/llvm-as.exe', shim, random_shim,
              closure]
    if 'managed' in sides:
        inputs += managed_runtime_inputs(managed)
    if 'selfhost' in sides:
        inputs.append(args.compiler.resolve())
    inputs += [ROOT / c['source'] for c in cases]
    inputs += sorted((ROOT / 'stdlib').rglob('*.slg'))
    inputs += [ROOT / 'scripts/completed_artifact_plan.py',
               ROOT / 'scripts/contracts/artifact-lifecycle.json',
               ROOT / 'scripts/Invoke-CompletedArtifactCleanup.ps1', ROOT / 'scripts/ArtifactLifecycle.ps1']
    hashes = {str(p): digest(p) for p in inputs}  # Fail before creating outputs.
    args.output = args.output.resolve()
    initialize_output(ROOT, args.output)
    args.output.mkdir(parents=True, exist_ok=False)
    record = {'schemaVersion': 1, 'status': 'running', 'completed': 0,
              'total': len(cases), 'inputHashes': hashes, 'cases': [],
              'outputOwner': str(args.output), 'processes': [],
              'processShutdownConfirmed': False, 'orphanProcessIds': []}

    def save():
        temporary = args.output / 'result.json.tmp'
        temporary.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
        temporary.replace(args.output / 'result.json')

    def run(argv, prefix, timeout=180):
        if any(digest(pathlib.Path(p)) != sha for p, sha in hashes.items()):
            raise RuntimeError('INPUT_DRIFT before ' + prefix)
        started = time.monotonic()
        with (args.output / f'{prefix}.stdout').open('wb') as out, \
             (args.output / f'{prefix}.stderr').open('wb') as err:
            proc = subprocess.Popen([str(a) for a in argv], cwd=ROOT, stdout=out, stderr=err)
            process_record = {'pid': proc.pid, 'step': prefix, 'status': 'running'}
            record['processes'].append(process_record)
            record['activeProcess'] = {'pid': proc.pid, 'step': prefix}
            save()
            try:
                code = proc.wait(timeout=timeout)
            except (subprocess.TimeoutExpired, KeyboardInterrupt):
                subprocess.run(['taskkill', '/PID', str(proc.pid), '/T', '/F'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                proc.wait()
                raise
            finally:
                process_record.update(status='terminal' if proc.poll() is not None else 'running',
                                      exitCode=proc.poll())
                if proc.poll() is not None:
                    record.pop('activeProcess', None)
                save()
        text = (args.output / f'{prefix}.stdout').read_text(errors='replace').replace('\r\n', '\n').strip()
        error = (args.output / f'{prefix}.stderr').read_text(errors='replace').strip()
        item['steps'][prefix] = {'exit': code, 'seconds': round(time.monotonic() - started, 3)}
        if code != 0 or error:
            raise RuntimeError(f'{prefix}: exit={code}; stderr={error[:1000]}; stdout={text[:500]}')
        return text

    save()
    try:
        for case in cases:
            item = {'id': case['id'], 'status': 'running', 'steps': {}}
            record['cases'].append(item)
            save()
            for side in sides:
                name = f"{case['id']}.{side}"
                exe = args.output / f'{name}.exe'
                command = ['dotnet', managed] if side == 'managed' else [args.compiler]
                build = command + ['build', ROOT / case['source'], '-o', exe,
                                   '--target', 'windows-x64', '--llvm', llvm, '-O1', '--keep-temps']
                if side == 'selfhost':
                    build += ['--stdlib', ROOT / 'stdlib', '--jobs', '1']
                run(build, name + '.build')
                if run([exe], name + '.run') != case['stdout']:
                    raise RuntimeError(f'{name}: output mismatch')
                ll = pathlib.Path(str(exe) + '.ll')
                run([llvm / 'bin/llvm-as.exe', ll, '-o', str(exe) + '.bc'], name + '.assemble')
                run(['pwsh', '-NoProfile', '-File', closure, '-LlvmPath', ll], name + '.closure')
                text = ll.read_text(encoding='utf-8-sig')
                for source, target in [('call ptr @sollang_alloc(', 'call ptr @audit_malloc('),
                                       ('call void @sollang_free(', 'call void @audit_free('),
                                       ('call ptr @realloc(', 'call ptr @audit_realloc('),
                                       ('@sollang_start()', '@slg_program_main()'),
                                       ('call ptr @malloc(', 'call ptr @audit_malloc('),
                                       ('call void @free(', 'call void @audit_free('),
                                       ('define i32 @main()', 'define i32 @slg_program_main()')]:
                    text = text.replace(source, target)
                if len(re.findall(r'^define (?:dso_local )?i32 @slg_program_main\(\)', text, re.M)) != 1:
                    raise RuntimeError(f'{name}: audit entry mismatch')
                text += '\ndeclare ptr @audit_malloc(i64)\ndeclare ptr @audit_realloc(ptr, i64)\ndeclare void @audit_free(ptr)\n'
                audit_ll = args.output / f'{name}.audit.ll'
                audit_ll.write_text(text, encoding='utf-8')
                audit_exe = args.output / f'{name}.audit.exe'
                run([llvm / 'bin/clang.exe', '-Wno-override-module',
                     f"-DEXPECTED_ALLOCATIONS={case['allocations']}", audit_ll, shim,
                     '-O1', '-o', audit_exe, '-lws2_32', '-lshell32', '-lbcrypt'], name + '.audit-link')
                expected = f"{case['stdout']}\nallocations={case['allocations']},releases={case['allocations']}"
                if run([audit_exe], name + '.audit-run') != expected:
                    raise RuntimeError(f'{name}: allocation output mismatch')
                item[side] = {'allocations': case['allocations'], 'releases': case['allocations'],
                              'invalidReleases': 0, 'stdout': case['stdout']}
                save()
            item['status'] = 'passed'
            record['completed'] += 1
            save()
            print(f"PASS {case['id']} {record['completed']}/{record['total']}", flush=True)
        record['status'] = 'passed'
    except KeyboardInterrupt:
        record['status'] = 'canceled'
        finish_active_cases(record, 'canceled')
        raise
    except Exception as exc:
        record['status'] = 'failed'
        record['failure'] = str(exc)
        finish_active_cases(record, 'failed', str(exc))
        raise
    finally:
        record['inputStable'] = all(pathlib.Path(p).is_file() and digest(pathlib.Path(p)) == sha for p, sha in hashes.items())
        if not record['inputStable']:
            record['status'] = 'failed'
            record['failure'] = 'INPUT_DRIFT'
        record['processShutdownConfirmed'] = all(p['status'] == 'terminal' for p in record['processes'])
        record['generatedOutputHashes'] = {str(path): digest(path) for path in args.output.rglob('*')
            if path.is_file() and (GENERATED.search(path.name)
                                  or '.sollang-cache' in path.parts)}
        save()
    if record['status'] == 'passed':
        assert_output_shutdown(ROOT, args.output)
        cleanup_output(ROOT, args.output, execute=not args.prepare_cleanup)
    return 0 if record['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
