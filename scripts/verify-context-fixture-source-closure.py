"""Prove direct EmitContext fixtures match the current context shape and pair."""

import hashlib
import argparse
import json
import re
import subprocess
import sys
import runpy
from pathlib import Path

from context_suite_evidence import suite_required_inputs, validate_focused_suite


ROOT = Path(__file__).resolve().parent.parent


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


parser = argparse.ArgumentParser()
parser.add_argument("--static-only", action="store_true")
parser.add_argument("--receipt")
args = parser.parse_args()

receipt = (Path(args.receipt) if args.receipt else
           ROOT / read(ROOT / "scripts/contracts/structural-parity-detail.json")["measuredSubscopes"]["sourceHashClosure"]["fixtureProof"])
proof = read(receipt)
assert sha(Path(proof["currentCompiler"])) == proof["currentCompilerSha256"]
context = (ROOT / proof["contextSource"]).read_text(encoding="utf-8-sig")
declaration = context.split("public struct EmitContext {", 1)[1].split("\n}", 1)[0]
fields = re.findall(r"(?m)^    public (\w+):", declaration)
assert fields and len(fields) == len(set(fields))
assert proof["status"] in ("pending-pair", "passed") and proof["contextFieldCount"] == len(fields)
assert sha(ROOT / proof["contextSource"]) == proof["contextSourceSha256"]
producer_path = ROOT / proof["producerSource"]
assert sha(producer_path) == proof["producerSourceSha256"]
producer = producer_path.read_text(encoding="utf-8-sig")
producer_initializer = producer.rsplit("    emitterContext.EmitContext {", 1)[1].split("\n    } => context!", 1)[0]
producer_keys = re.findall(r"(?m)^        (\w+):", producer_initializer)
assert len(producer_keys) == len(set(producer_keys)) and set(producer_keys) == set(fields)

for relative, expected in proof["currentSourceHashes"].items():
    source = ROOT / relative
    assert sha(source) == expected
    text = source.read_text(encoding="utf-8-sig")
    initializer = text.split("emitterContext.EmitContext {", 1)[1].split("\n    } => context", 1)[0]
    keys = re.findall(r"(?m)^        (\w+):", initializer)
    assert len(keys) == len(set(keys)), relative
    assert set(keys) == set(fields), (relative, set(fields) - set(keys), set(keys) - set(fields))
    assert "import sollang.compiler.semantic.diagnostics as semanticDiagnostics" in text

runpy.run_path(str(ROOT / 'scripts/verify-context-fixture-initializers.py'))['verify'](
    [ROOT / relative for relative in proof['currentSourceHashes']])

assert len(proof["currentManifestHashes"]) == len(proof["currentSourceHashes"])
for relative, expected in proof["currentManifestHashes"].items():
    assert sha(ROOT / relative) == expected

shared_manifest_sources = None
for relative in proof["currentSourceHashes"]:
    fixture = Path(relative).stem
    manifest = ROOT / "examples/regression/expected" / f"{fixture}.sources.txt"
    entries = [line.strip() for line in manifest.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    assert entries[0] == relative and len(entries) == len(set(entries))
    compiler_sources = entries[1:]
    assert len(compiler_sources) == proof["manifestCompilerSourcesPerFixture"]
    assert all((ROOT / source).is_file() for source in compiler_sources)
    if shared_manifest_sources is None:
        shared_manifest_sources = compiler_sources
    else:
        assert set(compiler_sources) == set(shared_manifest_sources), fixture

expected_fixtures = {Path(value).stem for value in proof["currentSourceHashes"]}
covered = set()
for references in proof.get('focusedSuiteProofs', []):
    evidence = validate_focused_suite(
        ROOT, references, Path(proof['currentCompiler']),
        suite_required_inputs(ROOT, proof['currentSourceHashes'], proof['currentManifestHashes']))
    subprocess.run([sys.executable, str(ROOT / 'scripts/generate-context-fixture-suite.py'),
                    '--check'], cwd=ROOT, check=True, capture_output=True, text=True)
    covered.update(evidence['fixtures'])
for value in proof.get("priorCandidatePairedProofs", []):
    prior = read(Path(value))
    assert prior["status"] == "passed" and prior["inputStable"]
    assert all(
        row["compilerSha256"] != proof["currentCompilerSha256"]
        for row in prior["runs"] if row["compiler"] == "selfhost"
    )
    assert {row["fixture"] for row in prior["runs"]}.issubset(expected_fixtures)
for value in proof["pairedProofs"]:
    result_path = Path(value)
    if not result_path.is_absolute():
        result_path = ROOT / result_path
    paired = read(result_path)
    assert paired["status"] == "passed" and paired["inputStable"]
    assert paired["completed"] == paired["total"]
    assert len(paired["runs"]) == 2 * paired["total"]
    assert all(
        row["compilerSha256"] == proof["currentCompilerSha256"]
        for row in paired["runs"] if row["compiler"] == "selfhost"
    )
    for row in paired["runs"]:
        covered.add(row["fixture"])
        fixture_source = str((ROOT / "examples/regression" / f"{row['fixture']}.slg").resolve())
        fixture_manifest = str((ROOT / "examples/regression/expected" / f"{row['fixture']}.sources.txt").resolve())
        for input_path in (fixture_source, fixture_manifest):
            assert input_path in paired["inputHashesStart"]
            assert paired["inputHashesStart"][input_path] == paired["inputHashesEnd"][input_path]
    for relative, expected in proof["currentSourceHashes"].items():
        source = str((ROOT / relative).resolve())
        if source in paired["inputHashesStart"]:
            assert paired["inputHashesStart"][source] == expected
            assert paired["inputHashesEnd"][source] == expected
    for relative, expected in proof["currentManifestHashes"].items():
        source = str((ROOT / relative).resolve())
        if source in paired["inputHashesStart"]:
            assert paired["inputHashesStart"][source] == expected
            assert paired["inputHashesEnd"][source] == expected
for value in proof.get("suitePairedProofs", []):
    subprocess.run([sys.executable, str(ROOT / "scripts/generate-context-fixture-suite.py"),
                    "--check"], cwd=ROOT, check=True, capture_output=True, text=True)
    suite = "1999-selfhost-context-fixture-suite"
    paired = read(Path(value))
    assert paired["status"] == "passed" and paired["inputStable"]
    assert paired["completed"] == paired["total"] == 1 and len(paired["runs"]) == 2
    assert {row["compiler"] for row in paired["runs"]} == {"managed", "selfhost"}
    assert {row["fixture"] for row in paired["runs"]} == {suite}
    assert next(row for row in paired["runs"] if row["compiler"] == "selfhost")["compilerSha256"] == proof["currentCompilerSha256"]
    for relative in (f"examples/regression/{suite}.slg",
                     f"examples/regression/expected/{suite}.sources.txt",
                     f"examples/regression/expected/{suite}.stdout.txt",
                     "scripts/generate-context-fixture-suite.py",
                     *proof["currentSourceHashes"].keys(), *proof["currentManifestHashes"].keys(),
                     *(f"examples/regression/expected/{Path(source).stem}.stdout.txt"
                       for source in proof["currentSourceHashes"])):
        path = str((ROOT / relative).resolve())
        assert paired["inputHashesStart"][path] == paired["inputHashesEnd"][path] == sha(Path(path))
    covered.update(expected_fixtures)
for value in proof.get("canceledAttempts", []):
    cancellation_path = Path(value).resolve()
    cancellation = read(cancellation_path)
    assert cancellation["status"] == "canceled"
    assert cancellation["runnerExitCode"] != 0
    assert cancellation["resultJsonPresent"] is False
    assert cancellation["selfhostResult"] == "unverified"
    assert not (cancellation_path.parent / "result.json").exists()
for value in proof.get("currentTimedOutAttempts", []):
    timed_out = read(Path(value).resolve())
    compiler_key = str(Path(proof["currentCompiler"]).resolve())
    assert timed_out["status"] == "failed" and timed_out["inputStable"]
    assert "exceeded the configured verification limit" in timed_out["failure"]
    assert timed_out["inputHashesStart"][compiler_key] == proof["currentCompilerSha256"]
    assert timed_out["inputHashesEnd"][compiler_key] == proof["currentCompilerSha256"]
assert covered.issubset(expected_fixtures)
if args.static_only:
    failed = sum(
        attempt["classification"] == "managed-pass-selfhost-semantic-diagnostic-mismatch"
        for attempt in proof.get("failedAttempts", [])
    )
    timeouts = sum(
        attempt["classification"] == "selfhost-build-timeout-20min-concurrent"
        for attempt in proof.get("failedAttempts", [])
    )
    print(f"[context fixture closure] PASS producer fields 1/1, fixture fields 4/4, shared manifests 4/4; paired native cases {len(covered)}/4 passed, {failed} prior semantic mismatches, {timeouts} concurrent timeouts, {len(proof.get('currentTimedOutAttempts', []))} current timeouts, {len(proof.get('canceledAttempts', []))} canceled unverified")
    raise SystemExit(0)

assert proof["status"] == "passed"
assert covered == expected_fixtures
print("[context fixture closure] PASS producer fields 1/1, fixture fields 4/4, shared manifests 4/4, paired native 4/4")
