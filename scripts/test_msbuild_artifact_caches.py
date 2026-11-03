"""MSBuild cache ownership at the existing verified-output cleanup boundary."""
import hashlib
import json
from pathlib import Path
import unittest

import completed_artifact_plan as policy
import test_completed_artifacts as fixtures


class MSBuildCacheTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.ArtifactLifecycleTests()
        self.fixture.setUp()
        self.repo = self.fixture.repo
        self.output = self.fixture.output()
        self.project = self.output / 'Harness.csproj'
        self.project.write_text('<Project />', encoding='utf-8')
        self.cache = self.output / 'obj/Release/Harness.assets.cache'
        self.cache.parent.mkdir(parents=True)
        self.cache.write_bytes(b'generated cache')
        self.record = json.loads((self.output / 'result.json').read_text(encoding='utf-8'))
        self.record['inputHashes'] = {str(self.project): self.sha(self.project)}
        self.record['processes'] = [dict(command=['dotnet', 'build', str(self.project)],
                                         exit=0, shutdownConfirmed=True)]
        self.save()

    def tearDown(self):
        self.fixture.tearDown()

    @staticmethod
    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def save(self):
        (self.output / 'result.json').write_text(json.dumps(self.record), encoding='utf-8')

    def caches(self, **options):
        return [Path(row['path']) for row in self.fixture.plan(**options)['targets']
                if Path(row['path']).suffix == '.cache']

    def test_owned_default_obj_cache(self):
        self.assertEqual(self.caches(), [self.cache])

    def test_actual_executor_and_idempotent_resume(self):
        plan = self.fixture.plan()
        result = self.fixture.execute(plan)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.cache.exists())
        self.assertTrue(self.project.exists())
        self.assertEqual(self.fixture.execute(plan).returncode, 0)

    def test_unrelated_cache_source_and_json_remain(self):
        paths = [self.output / 'user.cache', self.cache.parent / 'source.slg',
                 self.cache.parent / 'metadata.json']
        for path in paths:
            path.write_text('retained', encoding='utf-8')
        self.assertEqual(self.fixture.execute(self.fixture.plan()).returncode, 0)
        self.assertTrue(all(path.exists() for path in paths))

    def test_unproven_build_is_not_cache_ownership(self):
        for change in [dict(command=['other-tool', 'build', str(self.project)]),
                       dict(exit=1), dict(exit=False), dict(shutdownConfirmed=False)]:
            with self.subTest(change=change):
                original = dict(self.record['processes'][0])
                self.record['processes'][0].update(change)
                self.save()
                self.assertEqual(self.caches(), [])
                self.record['processes'][0] = original

    def test_missing_or_malformed_build_evidence(self):
        for processes in [[], None, 4, [None], [dict(command=None)]]:
            with self.subTest(processes=processes):
                self.record['processes'] = processes
                self.save()
                self.assertEqual(policy.msbuild_cache_roots(self.repo, self.output), set())

    def test_project_hash_drift_retains_cache(self):
        self.project.write_text('<Changed />', encoding='utf-8')
        self.assertEqual(self.caches(), [])

    def test_unpinned_project_retains_cache(self):
        self.record['inputHashes'] = {}
        self.save()
        self.assertEqual(self.caches(), [])

    def test_external_project_default_obj_is_not_owned(self):
        external = self.repo / 'external.csproj'
        external.write_text('<Project />', encoding='utf-8')
        self.record['inputHashes'] = {str(external): self.sha(external)}
        self.record['processes'][0]['command'] = ['dotnet', 'build', str(external)]
        self.save()
        self.assertEqual(self.caches(), [])

    def test_explicit_artifacts_path_for_external_project(self):
        external = self.repo / 'external.csproj'
        external.write_text('<Project />', encoding='utf-8')
        owned = self.output / 'dotnet-artifacts/obj/Harness/release/Harness.assets.cache'
        owned.parent.mkdir(parents=True)
        owned.write_bytes(b'generated')
        self.record['inputHashes'] = {str(external): self.sha(external)}
        self.record['processes'][0]['command'] = [
            'dotnet', 'build', str(external), '--artifacts-path', str(self.output / 'dotnet-artifacts')]
        self.save()
        self.assertEqual(self.caches(), [owned])

    def test_artifacts_path_escape_is_not_ownership(self):
        self.record['processes'][0]['command'] += ['--artifacts-path', str(self.output / '../outside')]
        self.save()
        self.assertEqual(self.caches(), [])

    def test_declared_cache_input_is_protected(self):
        self.record['inputHashes'][str(self.cache)] = self.sha(self.cache)
        self.save()
        self.assertEqual(self.caches(), [])

    def test_reusable_compiler_protects_cache(self):
        self.assertEqual(self.caches(reusable_directories=[self.output]), [])

    def test_failure_cancel_and_running_are_protected(self):
        for status in ['failed', 'cancelled', 'canceled', 'timed-out', 'running']:
            with self.subTest(status=status):
                self.record['status'] = status
                self.save()
                self.assertEqual(self.caches(), [])
                self.assertTrue(self.cache.exists())

    def test_active_output_is_protected(self):
        plan = policy.create_plan(self.repo, self.fixture.root, 0,
                                  active={str(self.output).casefold()}, reusable_directories=[])
        self.assertEqual(plan['targets'], [])

    def test_changed_project_invalidates_existing_plan(self):
        plan = self.fixture.plan()
        self.project.write_text('<Changed />', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'TARGET_NOT_GENERATED'):
            policy.validate_plan(plan)
        self.assertTrue(self.cache.exists())

    def test_changed_cache_invalidates_existing_plan(self):
        plan = self.fixture.plan()
        self.cache.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'TARGET_CHANGED'):
            policy.validate_plan(plan)
        self.assertTrue(self.cache.exists())


if __name__ == '__main__':
    unittest.main()
