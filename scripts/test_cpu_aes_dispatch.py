"""Check bridge admission and reject mutations of real compiler AES output."""
import argparse
import importlib.util
import json
import re
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('cpu_aes_dispatch', Path(__file__).with_name('verify-cpu-aes-dispatch.py'))
AES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AES)


class BridgeInputs(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='sollang-aes-proof-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        sources = self.root / 'scripts/tools/CompilerLinkBridge'
        sources.mkdir(parents=True)
        self.sources = [sources / name for name in ('Program.cs', 'CompilerLinkBridge.csproj')]
        for path in self.sources:
            path.write_text('source witness', encoding='utf-8')
        self.product = self.root / 'CompilerLinkBridge.dll'
        self.product.write_bytes(b'verified product witness')
        for suffix in ('.deps.json', '.runtimeconfig.json'):
            self.product.with_suffix(suffix).write_text('{}', encoding='utf-8')
        self.proof = self.root / 'result.json'
        self.record = dict(status='passed', completed=1, total=1, inputsStable=True,
                           processesStopped=True, bridgeProduct=str(self.product),
                           bridgeSha256=AES.sha(self.product),
                           inputHashes={str(path): AES.sha(path) for path in self.sources})
        self.save()

    def save(self):
        self.proof.write_text(json.dumps(self.record), encoding='utf-8')

    def reject(self, message):
        with self.assertRaisesRegex(ValueError, message):
            AES.resolve_bridge(self.proof, self.root)

    def test_verified_product_and_sources(self):
        product, paths = AES.resolve_bridge(self.proof, self.root)
        self.assertEqual(product, self.product)
        self.assertTrue(set(self.sources) <= set(paths))

    def test_no_implicit_bridge(self):
        with self.assertRaisesRegex(ValueError, 'PROOF_REQUIRED'):
            AES.resolve_bridge(None, self.root)

    def test_failed_proof(self):
        self.record['status'] = 'failed'
        self.save()
        self.reject('PROOF_INCOMPLETE')

    def test_partial_proof(self):
        self.record['completed'] = 0
        self.save()
        self.reject('PROOF_INCOMPLETE')

    def test_boolean_is_not_a_count(self):
        self.record['completed'] = True
        self.save()
        self.reject('PROOF_INCOMPLETE')

    def test_running_process(self):
        self.record['processesStopped'] = False
        self.save()
        self.reject('PROOF_INCOMPLETE')

    def test_unstable_source_proof(self):
        self.record['inputsStable'] = False
        self.save()
        self.reject('PROOF_INCOMPLETE')

    def test_missing_official_source_pin(self):
        del self.record['inputHashes'][str(self.sources[0])]
        self.save()
        self.reject('SOURCE_PROOF_MISSING')

    def test_changed_source(self):
        self.sources[0].write_text('changed', encoding='utf-8')
        self.reject('SOURCE_CHANGED')

    def test_changed_product(self):
        self.product.write_bytes(b'changed')
        self.reject('PRODUCT_CHANGED')

    def test_missing_runtime(self):
        self.product.with_suffix('.runtimeconfig.json').unlink()
        self.reject('RUNTIME_MISSING')


def kernel_controls(managed, native, direct):
    resolver = AES.check_kernel(managed, 'managed')
    assert AES.check_kernel(native, 'selfhost', require_readonly_receiver=True) == resolver
    assert AES.check_kernel(direct, 'selfhost') == resolver
    rows = [dict(id='current-managed-native-profiles', status='passed')]
    accelerated = re.search(r'define[^\r\n]+_x86\([^\r\n]+\) #[0-9]+ \{(?P<body>.*?)\r?\n\}', managed, re.S)
    assert accelerated

    def mutate_accelerated(transform):
        begin, end = accelerated.span('body')
        return managed[:begin] + transform(managed[begin:end]) + managed[end:]

    for name, source, expected in [
        ('foreign-target', managed.replace('x86_64-pc-windows-msvc', 'x86_64-unknown-linux-gnu'), 'TARGET_ABI'),
        ('unrelated-instance', managed.replace('sollang_fn_std_crypto_aes128_Key_encryptBlock', 'sollang_fn_unrelated_encryptBlock'), 'EXACT_KERNEL'),
        ('missing-round', mutate_accelerated(lambda body: body.replace('@llvm.x86.aesni.aesenc(', '@missing.round(', 1)), 'ROUND_COUNT'),
        ('hot-feature-probe', mutate_accelerated(lambda body: '\n  call i64 @sollang_cpu_features_once()' + body), 'HOT_KERNEL'),
        ('missing-target-feature', managed.replace('target-features"="+aes,+sse2"', 'target-features"="+sse2"'), 'DISPATCH_CONTRACT'),
    ]:
        try:
            AES.check_kernel(source, 'managed')
        except ValueError as error:
            assert expected in str(error), (name, error)
        else:
            raise AssertionError('Broken AES output accepted: ' + name)
        rows.append(dict(id=name, status='rejected'))
    try:
        AES.check_kernel(direct, 'selfhost', require_readonly_receiver=True)
    except ValueError as error:
        assert 'READONLY_RECEIVER' in str(error)
    else:
        raise AssertionError('Direct fixture incorrectly satisfied the readonly receiver control')
    rows.append(dict(id='readonly-profile-remains-required', status='rejected'))
    for mode in ('portable', 'x86'):
        forced = AES.force_backend(managed, resolver, mode)
        original = '@sollang_aes128_selected = internal global ptr ' + resolver + ', align 8'
        selected = original.replace(resolver, resolver[:-8] + '_' + mode)
        assert forced.replace(selected, original) == managed
        rows.append(dict(id='force-only-initializer-' + mode, status='passed'))
    for name, source, mode in [('duplicate-initializer', managed + '\n@sollang_aes128_selected = internal global ptr ' + resolver + ', align 8', 'portable'),
                               ('forbidden-fallback', managed, 'automatic')]:
        try:
            AES.force_backend(source, resolver, mode)
        except ValueError:
            rows.append(dict(id=name, status='rejected'))
        else:
            raise AssertionError('Invalid forced dispatch was accepted: ' + name)
    return rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('managed-sample', 'native-sample', 'direct-sample'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(BridgeInputs))
    if not result.wasSuccessful():
        raise SystemExit(1)
    controls = kernel_controls(*[path.read_text(encoding='utf-8-sig') for path in
                                (args.managed_sample, args.native_sample, args.direct_sample)])
    print(json.dumps(dict(status='passed', proofTests=result.testsRun,
                          kernelControls=len(controls), controls=controls)))
