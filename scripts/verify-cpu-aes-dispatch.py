"""Run the existing AES checks through the production CLI and pinned linker."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time
from datetime import datetime, timezone

from completed_artifact_plan import initialize_output, cleanup_output, assert_build_space
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import managed_compilation_inputs, unique_input_files

ROOT = Path(__file__).resolve().parent.parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def resolve_bridge(proof_path, root=ROOT):
    if proof_path is None:
        raise ValueError('CPU_AES_LINK_BRIDGE_PROOF_REQUIRED')
    proof_path = Path(proof_path).resolve()
    proof = json.loads(proof_path.read_text(encoding='utf-8-sig'))
    if (proof.get('status') != 'passed' or type(proof.get('completed')) is not int
            or proof['completed'] != 1 or type(proof.get('total')) is not int
            or proof['total'] != 1 or proof.get('inputsStable') is not True
            or proof.get('processesStopped') is not True):
        raise ValueError('CPU_AES_LINK_BRIDGE_PROOF_INCOMPLETE')
    pins = proof.get('inputHashes')
    required = {str((root / 'scripts/tools/CompilerLinkBridge' / name).resolve())
                for name in ('Program.cs', 'CompilerLinkBridge.csproj')}
    if not isinstance(pins, dict) or not required <= pins.keys():
        raise ValueError('CPU_AES_LINK_BRIDGE_SOURCE_PROOF_MISSING')
    for path, digest in pins.items():
        if not Path(path).is_file() or sha(path) != digest:
            raise ValueError('CPU_AES_LINK_BRIDGE_SOURCE_CHANGED')
    product = Path(proof['bridgeProduct']).resolve()
    if not product.is_file() or sha(product) != proof.get('bridgeSha256'):
        raise ValueError('CPU_AES_LINK_BRIDGE_PRODUCT_CHANGED')
    inputs = [proof_path, product, *map(Path, pins)]
    for suffix in ('.deps.json', '.runtimeconfig.json'):
        path = product.with_suffix(suffix)
        if not path.is_file():
            raise ValueError('CPU_AES_LINK_BRIDGE_RUNTIME_MISSING')
        inputs.append(path)
    return product, inputs


def check_kernel(text, side, *, require_readonly_receiver=False):
    if not re.search(r'^target triple = "x86_64-pc-windows-msvc"$', text, re.M):
        raise ValueError('CPU_AES_TARGET_ABI_MISMATCH')
    # Both production CLI paths publish the same exact instance-owned identity.
    stem = r'sollang_fn_std_crypto_aes128_Key_encryptBlock'
    bodies = {}
    for mode in ('x86', 'portable'):
        matches = list(re.finditer(r'define[^\r\n]+@(' + stem + '_' + mode
                                  + r')\([^\r\n]+\)(?: #[0-9]+)? \{(.*?)\r?\n\}', text, re.S))
        if len(matches) != 1:
            raise ValueError('CPU_AES_EXACT_KERNEL_REQUIRED: ' + side + '/' + mode)
        bodies[mode] = matches[0].group(2)
    if (len(re.findall(r'@llvm\.x86\.aesni\.aesenc\(', bodies['x86'])) != 9
            or len(re.findall(r'@llvm\.x86\.aesni\.aesenclast\(', bodies['x86'])) != 1):
        raise ValueError('CPU_AES_ROUND_COUNT_MISMATCH')
    if re.search(r'sollang_cpu_features_once|alloca\s+\[176|memcpy[^\r\n]*176', bodies['x86']):
        raise ValueError('CPU_AES_HOT_KERNEL_PROBES_OR_COPIES_SCHEDULE')
    if 'llvm.x86.aesni' in bodies['portable']:
        raise ValueError('CPU_AES_PORTABLE_HAS_OPTIONAL_INSTRUCTIONS')
    for marker in ('target-features"="+aes,+sse2"',
                   'define internal i64 @sollang_cpu_features_once()', 'cpuid'):
        if marker not in text:
            raise ValueError('CPU_AES_DISPATCH_CONTRACT_MISSING: ' + marker)
    initializer = re.findall(r'@sollang_aes128_selected = internal global ptr '
                             r'(@[^,\r\n]+_resolve), align 8', text)
    if len(initializer) != 1:
        raise ValueError('CPU_AES_EXACT_RESOLVER_REQUIRED')
    if side == 'managed' and '%output = call ptr @sollang_alloc(i64 16)' not in text:
        raise ValueError('CPU_AES_PLATFORM_ALLOCATION_REQUIRED')
    if require_readonly_receiver and not (
            re.search(r'%call\d+_arg0_reference_value = load %sollang\.struct\.', text)
            or (re.search(r'getelementptr inbounds %sollang\.struct\.[^\r\n]+ptr %arg, i32 0, i32 0', text)
                and re.search(r'load %sollang\.struct\.[^\r\n]+ptr %v\d+_address', text))):
        raise ValueError('CPU_AES_READONLY_RECEIVER_LOAD_REQUIRED')
    return initializer[0]


def force_backend(text, resolver, mode):
    if mode not in ('portable', 'x86') or not resolver.endswith('_resolve'):
        raise ValueError('CPU_AES_FORCED_BACKEND_INVALID')
    selected = resolver[:-len('_resolve')] + '_' + mode
    if selected not in text:
        raise ValueError('CPU_AES_FORCED_BACKEND_MISSING')
    old = '@sollang_aes128_selected = internal global ptr ' + resolver + ', align 8'
    if text.count(old) != 1:
        raise ValueError('CPU_AES_EXACT_INITIALIZER_REQUIRED')
    return text.replace(old, '@sollang_aes128_selected = internal global ptr ' + selected + ', align 8')


def run(args):
    bridge = None
    bridge_inputs = []
    if args.mode != 'managed' or args.validate_bridge_only:
        bridge, bridge_inputs = resolve_bridge(args.bridge_proof)
    if args.validate_bridge_only:
        paths = unique_input_files([Path(__file__), *bridge_inputs,
            ROOT / 'scripts/verification_execution.py',
            ROOT / 'scripts/verification_contract_lease.py',
            ROOT / 'scripts/verification_fingerprints.py',
            ROOT / 'scripts/verification_json_records.py',
            ROOT / 'scripts/verify-managed-cpu-aes-dispatch.ps1',
            ROOT / 'scripts/verify-selfhost-cpu-aes-dispatch.ps1',
            ROOT / 'scripts/verify-cpu-aes-dispatch-differential.ps1'])
        print(json.dumps({'status': 'passed', 'bridge': str(bridge),
                          'inputPaths': list(map(str, paths)), 'codegenInvoked': False}))
        return
    if os.name != 'nt':
        raise ValueError('CPU_AES_WINDOWS_HOST_REQUIRED')
    managed = args.managed_compiler.resolve()
    native = args.selfhost_compiler.resolve() if args.selfhost_compiler else None
    if args.mode != 'managed' and (native is None or not native.is_file()):
        raise ValueError('CPU_AES_SELFHOST_COMPILER_REQUIRED')
    fixture = (args.fixture or ROOT / 'examples/regression' /
               ('1226-aes128-cpu-dispatch-differential.slg' if args.mode == 'differential'
                else '889-stdlib-aes128-gcm.slg')).resolve()
    expected = (args.expected or ROOT / 'examples/regression/expected' /
                (fixture.stem + '.stdout.txt')).resolve()
    tools = [args.llvm.resolve() / 'bin' / name for name in
             ('clang.exe', 'lld-link.exe', 'llvm-lib.exe', 'llvm-readobj.exe')]
    dotnet, pwsh = shutil.which('dotnet'), shutil.which('pwsh')
    if not dotnet or not pwsh:
        raise ValueError('CPU_AES_RUNTIME_TOOL_MISSING')
    inputs = unique_input_files([
        Path(__file__), ROOT / 'scripts/verification_execution.py',
        ROOT / 'scripts/verification_contract_lease.py', ROOT / 'scripts/completed_artifact_plan.py',
        ROOT / 'scripts/verification_json_records.py',
        ROOT / 'scripts/ArtifactLifecycle.ps1', ROOT / 'scripts/Invoke-CompletedArtifactCleanup.ps1',
        ROOT / 'scripts/contracts/artifact-lifecycle.json',
        ROOT / 'scripts/verify-managed-cpu-aes-dispatch.ps1',
        ROOT / 'scripts/verify-selfhost-cpu-aes-dispatch.ps1',
        ROOT / 'scripts/verify-cpu-aes-dispatch-differential.ps1', fixture, expected, *tools,
        Path(dotnet), Path(pwsh), *bridge_inputs,
        *managed_compilation_inputs(managed.with_suffix('.exe'), ROOT / 'stdlib'),
        *([ROOT / 'scripts/run-cpu-aes-dispatch-benchmark.ps1'] if args.keep_products else []),
        *([native] if native else [])])
    with VerificationContractLease(inputs):
        if bridge:
            current_bridge, current_inputs = resolve_bridge(args.bridge_proof)
            if current_bridge != bridge or set(current_inputs) != set(bridge_inputs):
                raise ValueError('CPU_AES_LINK_BRIDGE_PROOF_CHANGED_BEFORE_LEASE')
        pins = {str(path): sha(path) for path in inputs}
        stable = lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in inputs)
        output = (args.output or ROOT / 'artifacts/cpu-aes-dispatch' /
                  (args.label + '-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%f'))).resolve()
        initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
        output.mkdir(parents=True, exist_ok=False)
        result = dict(schemaVersion=1, status='running', mode=args.mode, completed=0,
                      total=4 if args.mode == 'differential' else 1, inputHashes=pins,
                      cases=[], claimsGoalComplete=False,
                      declaredVectorCases=args.case_count if args.mode == 'differential' else None,
                      wholeRunBudgetSeconds=180,
                      artifactCleanupMode='plan-only' if args.keep_products else 'execute')
        execution = VerificationExecution(ROOT, output, result, stable, sha)
        execution.save()
        deadline = time.monotonic() + 180

        def invoke(command, name, timeout=120):
            timeout = min(timeout, deadline - time.monotonic())
            if timeout <= 0:
                raise TimeoutError('CPU_AES_WHOLE_RUN_BUDGET_EXHAUSTED')
            completed = execution.run(list(map(str, command)), output / name, timeout=timeout)
            if completed.returncode != 0:
                raise ValueError('CPU_AES_COMMAND_FAILED: ' + name + '\n' + completed.stderr)
            return completed

        def verify_executable(path, label):
            headers = invoke([tools[-1], '--file-headers', path], label + '.headers', 30).stdout
            for marker in ('Format: COFF-x86-64', 'Arch: x86_64', 'AddressSize: 64bit',
                           'Machine: IMAGE_FILE_MACHINE_AMD64 (0x8664)', 'Magic: 0x20B'):
                if marker not in headers:
                    raise ValueError('CPU_AES_PE32_REQUIRED: ' + marker)
            observed = invoke([path], label + '.run', 120)
            if observed.stderr or observed.stdout.replace('\r\n', '\n').rstrip('\n') != expected.read_text(encoding='utf-8-sig').replace('\r\n', '\n').rstrip('\n'):
                raise ValueError('CPU_AES_EXACT_OUTPUT_MISMATCH: ' + label)
            result['cases'].append(dict(id=label, status='passed', passed=True, executableSha256=sha(path)))
            result['completed'] += 1
            execution.save()

        error = None
        try:
            if args.mode == 'differential':
                aes = invoke([pwsh, '-NoProfile', '-Command',
                              '[System.Runtime.Intrinsics.X86.Aes]::IsSupported'], 'host-aes', 30)
                if aes.stdout.strip() != 'True':
                    raise ValueError('CPU_AES_FORCED_X86_HOST_UNSUPPORTED')
            if bridge:
                policy = json.loads(invoke([dotnet, bridge, 'policy', managed, sha(managed)],
                                           'link-policy', 30).stdout)
                if policy.get('status') != 'passed':
                    raise ValueError('CPU_AES_LINK_POLICY_REJECTED')
                result['compiledLinkPolicy'] = policy
            sides = ['managed', 'selfhost'] if args.mode == 'differential' else [args.mode]
            for side in sides:
                executable = output / (side + '.exe')
                command = ([dotnet, managed] if side == 'managed' else [native]) + [
                    'build', fixture, '-o', executable, '--target', 'windows-x64',
                    '--llvm', args.llvm.resolve(), '-O0', '--jobs', str(args.jobs), '--keep-temps']
                if side == 'selfhost':
                    command += ['--stdlib', ROOT / 'stdlib']
                assert_build_space(output)
                built = invoke(command, side + '.compile', 180)
                if built.stderr:
                    raise ValueError('CPU_AES_UNEXPECTED_COMPILER_DIAGNOSTICS: ' + side)
                llvm = Path(str(executable) + '.ll')
                text = llvm.read_text(encoding='utf-8-sig')
                resolver = check_kernel(text, side,
                                        require_readonly_receiver=args.mode == 'selfhost')
                if args.mode != 'differential':
                    verify_executable(executable, side)
                    continue
                for mode in ('portable', 'x86'):
                    label = side + '-' + mode
                    forced = output / (label + '.ll')
                    forced.write_bytes(force_backend(text, resolver, mode).encode('utf-8'))
                    product = output / (label + '.exe')
                    work = output / (label + '.link-work')
                    work.mkdir()
                    invoke([dotnet, bridge, 'link', managed, sha(managed), args.llvm.resolve(),
                            forced, product, work, '-O1', str(args.jobs)], label + '.link', 120)
                    verify_executable(product, label)
            result['status'] = 'passed'
        except (Exception, KeyboardInterrupt) as caught:
            error = caught
            raise
        finally:
            execution.finalize(error, cleanup=False)
        if result['status'] != 'passed':
            raise ValueError(result.get('failure', 'CPU_AES_FAILED'))
        if args.keep_products:
            result.update(status='awaiting-consumer', pendingConsumer='cpu-aes-benchmark')
            execution.save()
    if not args.keep_products:
        cleanup_output(ROOT, output, reusable_directories=args.reusable_directory)
    print(json.dumps(dict(status=result['status'], completed=result['completed'], total=result['total'],
                          output=str(output), inputsStable=result['inputsStable'],
                          processesStopped=result['processesStopped'])))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=('managed', 'selfhost', 'differential'), default='differential')
    parser.add_argument('--label', default='aes')
    parser.add_argument('--managed-compiler', type=Path, default=ROOT / 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll')
    parser.add_argument('--selfhost-compiler', type=Path)
    parser.add_argument('--bridge-proof', type=Path)
    parser.add_argument('--validate-bridge-only', action='store_true')
    parser.add_argument('--llvm', type=Path, default=ROOT / '.tools/llvm-22.1.8')
    parser.add_argument('--fixture', type=Path)
    parser.add_argument('--expected', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--keep-products', action='store_true')
    parser.add_argument('--case-count', type=int, default=3)
    parser.add_argument('--jobs', type=int, choices=range(1, 65), default=4)
    parser.add_argument('--reusable-directory', type=Path, action='append')
    args = parser.parse_args()
    if args.case_count < 1:
        parser.error('--case-count must be positive')
    if not re.fullmatch('[a-z0-9-]+', args.label):
        parser.error('--label must use lowercase ASCII letters, digits or hyphens')
    run(args)


if __name__ == '__main__':
    main()
