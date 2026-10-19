"""Validate C584 source-first materialize flow and exact diagnostic evidence."""

import hashlib
import argparse
import json
from pathlib import Path

from interpolation_current_source import historical_compiler_hash, validate_sources


ROOT = Path(__file__).resolve().parent.parent
PROOF = ROOT / "artifacts/scratch/c584-materialize-flow-unit-20260928-01.json"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--contract', type=Path, default=ROOT / 'scripts/contracts/interpolation-semantic-parity.json')
args = parser.parse_args()


def path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def read(value: str) -> dict:
    return json.loads(path(value).read_text(encoding="utf-8-sig"))


def sha(value: str) -> str:
    return hashlib.sha256(path(value).read_bytes()).hexdigest().upper()


proof = read(str(PROOF))
comparison = read(proof["sourceComparison"])
build = read(proof["selfhostBuild"])
positive = read(proof["positivePair"])
assert proof["status"] == "passed"
assert (proof["focusedCompleted"], proof["focusedTotal"]) == (4, 4)
assert comparison["status"] == "source-compared-before-slg-edit"
assert comparison["managedSourceSha256"] == proof["managedSourceSha256"]
validate_sources([comparison["managedSource"]], contract_path=args.contract)
assert comparison["negativeDiscovery"]["managedDecision"].startswith("Text.materialize checks argument count")
assert comparison["slgSources"]["selfhost/semantic/expression_type_ids_paths.slg"] != proof["changedSourceHashes"]["selfhost/semantic/expression_type_ids_paths.slg"]
assert build["status"] == "passed" and build["inputsStable"]
assert build["compilerSha256"] == proof["selfhostCompilerSha256"]
compiler = str(path(proof["selfhostBuild"]).parent / "compiler.exe")
assert historical_compiler_hash(compiler) == proof["selfhostCompilerSha256"]
validate_sources(list(proof["changedSourceHashes"]), contract_path=args.contract)
for value, expected in proof["fixtureHashes"].items():
    assert sha(value) == expected, value
assert positive["status"] == "passed" and positive["inputStable"]
assert (positive["completed"], positive["total"]) == (12, 12)
assert positive["inputHashesStart"][compiler] == proof["selfhostCompilerSha256"]
assert positive["inputHashesEnd"][compiler] == proof["selfhostCompilerSha256"]
fixtures = {row["fixture"] for row in positive["runs"]}
assert {
    "2024-materialized-if-result-interpolation",
    "2027-materialized-direct-result-interpolation",
}.issubset(fixtures)
assert len(positive["runs"]) == 24
for value in proof["negativePairs"]:
    negative = read(value)
    assert negative["state"] == "passed" and negative["inputsStable"]
    assert negative["selfhostCompilerSha256"] == proof["selfhostCompilerSha256"]
    directory = path(value).parent
    managed = (directory / "managed.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    selfhost = (directory / "selfhost.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    assert managed == selfhost and managed.startswith("sollang: semantic error at ")
assert proof["semanticOwnedKindsUnchanged"] == "4/12"
assert proof["structuralPhasesClosed"] == "0/7"
print("[C584 materialize flow] PASS retained historical pairs/diagnostics and current source identity; fresh whole parity remains separate")
