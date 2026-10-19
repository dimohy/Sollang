"""Validate current source identity while retaining historical focused behavior."""

import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CONTRACT = ROOT / "scripts/contracts/interpolation-semantic-parity.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def validate_sources(paths: list[str] | tuple[str, ...], *, contract_path: Path = CONTRACT) -> None:
    from context_suite_evidence import suite_required_inputs, validate_focused_suite
    contract = json.loads(contract_path.read_text(encoding='utf-8-sig'))
    proof = json.loads((ROOT / contract['currentSourceProofEvidence']).read_text(encoding="utf-8-sig"))
    assert proof['schemaVersion'] == 2
    pair_path = (ROOT / proof["pairResult"]).resolve()
    pair = json.loads(pair_path.read_text(encoding="utf-8-sig"))
    managed_path = (ROOT / proof['managedResult']).resolve()
    managed = json.loads(managed_path.read_text(encoding='utf-8-sig'))
    fixture_path = ROOT / proof["fixtureProof"]
    fixture = json.loads(fixture_path.read_text(encoding="utf-8-sig"))
    assert proof["status"] == pair["status"] == fixture["status"] == "passed"
    assert pair["inputsStable"] and pair['processesStopped'] and sha(pair_path) == proof["pairResultSha256"]
    assert sha(managed_path) == proof['managedResultSha256']
    assert sha(fixture_path) == proof["fixtureProofSha256"]
    assert len(fixture['focusedSuiteProofs']) == 1
    references = fixture['focusedSuiteProofs'][0]
    assert (ROOT / references['paired']['path']).resolve() == pair_path
    assert (ROOT / references['managed']['path']).resolve() == managed_path
    compiler = Path(fixture['currentCompiler']).resolve()
    assert sha(compiler) == proof['selfhostCompilerSha256'] == fixture['currentCompilerSha256']
    validate_focused_suite(ROOT, references, compiler,
        suite_required_inputs(ROOT, fixture['currentSourceHashes'], fixture['currentManifestHashes']))
    entries = {row["path"]: row for row in proof["sources"]}
    assert len(entries) == len(proof["sources"])
    assert set(entries) == set(proof['historicalDriftPaths'])
    assert set(paths).issubset(entries)
    for relative, entry in entries.items():
        source = (ROOT / relative).resolve()
        assert source.is_relative_to(ROOT)
        digest = sha(source)
        assert digest == entry["sha256"], relative
        if entry["kind"] == "paired-source":
            key = str(source)
            assert source.suffix in ('.slg', '.cs')
            assert pair["inputHashes"][key] == managed["inputHashes"][key] == digest, relative
        else:
            assert entry["kind"] == "document" and relative in ('docs/SPEC.md', 'docs/AI_SLG_BEST_PRACTICES.md'), relative


def historical_compiler_hash(value: str) -> str:
    """Use the existing explicit archived-native-build identity authority."""
    path = (ROOT / value).resolve()
    if path.is_file():
        return sha(path)
    quote = lambda text: "'" + str(text).replace("'", "''") + "'"
    script = (". " + quote(ROOT / 'scripts/verification-artifact-identity.ps1')
        + "; Get-CompilerEvidenceHash -RepositoryRoot " + quote(ROOT)
        + " -LiteralPath " + quote(path) + " -ArchivedNativeBuild | ConvertTo-Json -Compress")
    result = subprocess.run(['pwsh', '-NoProfile', '-Command', script], cwd=ROOT,
                            capture_output=True, text=True, check=True, timeout=30)
    identity = json.loads(result.stdout)
    assert identity['IdentitySource'] == 'recorded-native-build'
    return identity['Hash']
