"""Create a current-source EmitContext fixture proof from pinned paired receipts."""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timezone

from context_suite_evidence import suite_required_inputs, validate_focused_suite
from completed_artifact_plan import assert_artifact_path


ROOT = Path(__file__).resolve().parent.parent


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def repo_file(value: str) -> Path:
    path = (ROOT / value.replace("\\", "/")).resolve()
    if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
        raise ValueError(f"missing or external repository input: {value}")
    return path


def focused_record_reference(role: str, value: str) -> dict:
    if role == 'build':
        path = (ROOT / value).resolve()
        assert_artifact_path(ROOT, path)
        if not path.is_file():
            raise ValueError(f"missing build record: {value}")
    elif role in ('managed', 'paired'):
        path = repo_file(value)
        if not path.is_relative_to(ROOT / 'artifacts'):
            raise ValueError(f"external repository input for {role} record: {value}")
    else:
        raise ValueError(f"unknown focused record role: {role}")
    return {'path': str(path), 'sha256': sha(path)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--paired", action="append", default=[])
    parser.add_argument("--suite-paired", action="append", default=[])
    parser.add_argument('--focused-suite-result')
    parser.add_argument('--focused-managed-result')
    parser.add_argument('--focused-build-result')
    parser.add_argument("--canceled", action="append", default=[])
    parser.add_argument("--timeout-result", action="append", default=[])
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    baseline = read(repo_file(args.baseline))
    compiler = Path(args.compiler).resolve()
    if not compiler.is_file() or compiler.suffix.lower() != ".exe":
        raise ValueError(f"missing compiler executable: {compiler}")
    output = (ROOT / args.output).resolve()
    if not output.is_relative_to(ROOT.resolve()) or output.exists():
        raise ValueError(f"proof output must be a new repository file: {args.output}")

    context = repo_file(baseline["contextSource"])
    declaration = context.read_text(encoding="utf-8-sig").split("public struct EmitContext {", 1)[1].split("\n}", 1)[0]
    field_count = len(re.findall(r"(?m)^    public \w+:", declaration))
    source_hashes = {source: sha(repo_file(source)) for source in baseline["currentSourceHashes"]}
    manifest_hashes = {manifest: sha(repo_file(manifest)) for manifest in baseline["currentManifestHashes"]}

    covered = set()
    focused_references = []
    focused_arguments = (args.focused_suite_result, args.focused_managed_result,
                         args.focused_build_result)
    if any(focused_arguments):
        if not all(focused_arguments):
            raise ValueError('CONTEXT_SUITE_EXPLICIT_RECORDS_REQUIRED')
        references = {role: focused_record_reference(role, value)
                      for role, value in zip(('paired', 'managed', 'build'), focused_arguments)}
        evidence = validate_focused_suite(ROOT, references, compiler,
                                         suite_required_inputs(ROOT, source_hashes, manifest_hashes))
        subprocess.run([sys.executable, str(ROOT / 'scripts/generate-context-fixture-suite.py'),
                        '--check'], cwd=ROOT, check=True, capture_output=True, text=True)
        focused_references.append(references)
        covered.update(evidence['fixtures'])
    for receipt in args.paired:
        paired = read(Path(receipt).resolve())
        if paired["status"] != "passed" or not paired["inputStable"]:
            raise ValueError(f"paired proof did not pass: {receipt}")
        if any(row["compilerSha256"] != sha(compiler)
               for row in paired["runs"] if row["compiler"] == "selfhost"):
            raise ValueError(f"paired proof used another self-host compiler: {receipt}")
        covered.update(row["fixture"] for row in paired["runs"])
    for receipt in args.suite_paired:
        subprocess.run([sys.executable, str(ROOT / "scripts/generate-context-fixture-suite.py"),
                        "--check"], cwd=ROOT, check=True, capture_output=True, text=True)
        paired = read(Path(receipt).resolve())
        suite = "1999-selfhost-context-fixture-suite"
        if (paired["status"] != "passed" or not paired["inputStable"]
                or paired["completed"] != 1 or paired["total"] != 1
                or len(paired["runs"]) != 2
                or {row["compiler"] for row in paired["runs"]} != {"managed", "selfhost"}
                or {row["fixture"] for row in paired["runs"]} != {suite}
                or next(row for row in paired["runs"] if row["compiler"] == "selfhost")["compilerSha256"] != sha(compiler)):
            raise ValueError(f"suite pair did not prove both compilers: {receipt}")
        for relative in (f"examples/regression/{suite}.slg",
                         f"examples/regression/expected/{suite}.sources.txt",
                         f"examples/regression/expected/{suite}.stdout.txt",
                         "scripts/generate-context-fixture-suite.py",
                         *source_hashes.keys(), *manifest_hashes.keys(),
                         *(f"examples/regression/expected/{Path(source).stem}.stdout.txt"
                           for source in source_hashes)):
            path = str(repo_file(relative))
            if (paired["inputHashesStart"].get(path) != sha(Path(path))
                    or paired["inputHashesEnd"].get(path) != sha(Path(path))):
                raise ValueError(f"suite paired input drifted: {relative}")
        covered.update(Path(source).stem for source in source_hashes)
    for receipt in args.canceled:
        cancellation = read(Path(receipt).resolve())
        if (cancellation["status"] != "canceled"
                or cancellation["runnerExitCode"] == 0
                or cancellation["resultJsonPresent"]
                or cancellation["selfhostResult"] != "unverified"
                or (Path(receipt).resolve().parent / "result.json").exists()):
            raise ValueError(f"cancellation is not an unverified stopped run: {receipt}")
    for receipt in args.timeout_result:
        timed_out = read(Path(receipt).resolve())
        compiler_key = str(compiler)
        if (timed_out["status"] != "failed" or not timed_out["inputStable"]
                or "exceeded the configured verification limit" not in timed_out["failure"]
                or timed_out["inputHashesStart"].get(compiler_key) != sha(compiler)
                or timed_out["inputHashesEnd"].get(compiler_key) != sha(compiler)):
            raise ValueError(f"timeout result does not match the current compiler: {receipt}")
    expected = {Path(source).stem for source in source_hashes}
    if not covered.issubset(expected):
        raise ValueError(f"paired proof has an unexpected fixture: {covered - expected}")

    proof = {
        **baseline,
        "previousProof": args.baseline,
        "previousObservedAtUtc": baseline.get("observedAtUtc"),
        "observedAtUtc": datetime.now(timezone.utc).isoformat(),
        "status": "passed" if covered == expected else "pending-pair",
        "contextSourceSha256": sha(context),
        "producerSourceSha256": sha(repo_file(baseline["producerSource"])),
        "contextFieldCount": field_count,
        "currentCompiler": str(compiler),
        "currentCompilerSha256": sha(compiler),
        "currentSourceHashes": source_hashes,
        "currentManifestHashes": manifest_hashes,
        "pairedProofs": args.paired,
        "suitePairedProofs": args.suite_paired,
        "focusedSuiteProofs": focused_references,
        "manifestCompilerSourcesPerFixture": len(next(iter(
            repo_file(manifest).read_text(encoding='utf-8-sig').splitlines()
            for manifest in manifest_hashes))) - 1,
        "canceledAttempts": args.canceled,
        "currentTimedOutAttempts": args.timeout_result,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(proof, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"[context fixture proof] {len(covered)}/{len(expected)} paired, {field_count} fields; {output}")


if __name__ == "__main__":
    main()
