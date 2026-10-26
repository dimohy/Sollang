"""Freeze changed interpolation source hashes against a completed current pair."""

import argparse
import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone

from context_suite_evidence import suite_required_inputs, validate_focused_suite


ROOT = Path(__file__).resolve().parent.parent
SOURCES = (
    "examples/regression/1100-selfhost-enum-match-variant-invariant.slg",
    "examples/regression/1000-selfhost-partition-route-type-invariant.slg",
    "selfhost/semantic/expression_type_ids_paths.slg",
    "selfhost/semantic/expression_type_ids.slg",
    "docs/AI_SLG_BEST_PRACTICES.md",
    "selfhost/semantic/diagnostics.slg",
    "selfhost/llvm/text/foundation.slg",
    "selfhost/ir/interpolation.slg",
    "docs/SPEC.md",
    "selfhost/semantic/interpolation_inference.slg",
    "examples/regression/1126-selfhost-console-emission-invariant.slg",
    "selfhost/llvm/text/context_prepare.slg",
    "selfhost/llvm/emitter/context.slg",
    "selfhost/llvm/emitter/diagnostics.slg",
    "examples/regression/1290-selfhost-provisional-unit-match-invariant.slg",
)
EXTRA_SOURCES = ("syntax/generated/sollang_grammar.slg",)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def refresh_focused(args) -> None:
    values = (args.focused_suite_result, args.focused_managed_result,
              args.focused_build_result, args.baseline)
    if not all(values) or args.pair:
        raise ValueError("CURRENT_SOURCE_EXPLICIT_FOCUSED_RECORDS_REQUIRED")
    paths = {role: Path(value).resolve() for role, value in zip(
        ("paired", "managed", "build"), values[:3])}
    baseline_path = (ROOT / args.baseline).resolve()
    if not baseline_path.is_relative_to(ROOT) or not baseline_path.is_file():
        raise ValueError("CURRENT_SOURCE_BASELINE_INVALID")
    baseline = json.loads(baseline_path.read_text(encoding="utf-8-sig"))
    fixture_path = (ROOT / args.fixture_proof).resolve()
    fixture = json.loads(fixture_path.read_text(encoding="utf-8-sig"))
    if baseline.get("schemaVersion") != 2 or fixture.get("status") != "passed":
        raise ValueError("CURRENT_SOURCE_FOCUSED_BASELINE_INVALID")
    references = {role: {"path": str(path), "sha256": sha(path)}
                  for role, path in paths.items()}
    if fixture.get("focusedSuiteProofs") != [references]:
        raise ValueError("CURRENT_SOURCE_FIXTURE_LINEAGE_INVALID")
    evidence = validate_focused_suite(
        ROOT, references, paths["build"].parent / "compiler.exe",
        suite_required_inputs(ROOT, fixture["currentSourceHashes"],
                              fixture["currentManifestHashes"]))
    records = {role: json.loads(path.read_text(encoding="utf-8-sig"))
               for role, path in paths.items()}
    drift = baseline["historicalDriftPaths"]
    if (not drift or len(drift) != len(set(drift))
            or {row["path"] for row in baseline["sources"]} != set(drift)):
        raise ValueError("CURRENT_SOURCE_HISTORICAL_DRIFT_INVALID")
    rows = []
    for relative in drift:
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError("CURRENT_SOURCE_PATH_INVALID")
        digest = sha(path)
        for role in ("managed", "paired"):
            if records[role]["inputHashes"].get(str(path)) != digest:
                raise ValueError(f"CURRENT_SOURCE_NOT_BOUND_TO_PAIR:{relative}:{role}")
        rows.append({"path": relative, "sha256": digest,
                     "kind": "document" if relative.startswith("docs/") else "paired-source"})
    output = (ROOT / args.output).resolve()
    if not output.is_relative_to(ROOT) or output.exists():
        raise ValueError("source proof output must be a new repository file")
    proof = {
        "schemaVersion": 2, "status": "passed",
        "scope": "Exact original-four focused suite and current source identities; no whole-source, standalone1290 or Stage credit.",
        "historicalDriftPaths": drift, "sources": rows,
        "pairResult": str(paths["paired"]), "pairResultSha256": sha(paths["paired"]),
        "managedResult": str(paths["managed"]), "managedResultSha256": sha(paths["managed"]),
        "fixtureProof": args.fixture_proof, "fixtureProofSha256": sha(fixture_path),
        "selfhostCompilerSha256": fixture["currentCompilerSha256"],
        "previousSourceProof": args.baseline,
        "observedAtUtc": datetime.now(timezone.utc).isoformat(),
        "qualifiedFixtures": evidence["fixtures"], "claimsWholeParityComplete": False,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[interpolation current sources] FROZEN {len(rows)}/{len(rows)}; original four exact focused cases; {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pair")
    parser.add_argument("--baseline")
    parser.add_argument("--focused-suite-result")
    parser.add_argument("--focused-managed-result")
    parser.add_argument("--focused-build-result")
    parser.add_argument("--fixture-proof", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if any((args.focused_suite_result, args.focused_managed_result,
            args.focused_build_result, args.baseline)):
        refresh_focused(args)
        return
    if not args.pair:
        parser.error("legacy --pair or all explicit focused record arguments are required")
    pair_path = Path(args.pair).resolve()
    pair = json.loads(pair_path.read_text(encoding="utf-8-sig"))
    fixture_proof_path = (ROOT / args.fixture_proof).resolve()
    fixture_proof = json.loads(fixture_proof_path.read_text(encoding="utf-8-sig"))
    if (pair["status"] != "passed" or not pair["inputStable"]
            or fixture_proof["status"] != "passed"
            or str(pair_path) not in fixture_proof["suitePairedProofs"]):
        raise ValueError("current interpolation source proof requires the completed suite pair")
    rows = []
    for relative in (*SOURCES, *EXTRA_SOURCES):
        path = (ROOT / relative).resolve()
        digest = sha(path)
        kind = "document" if relative.startswith("docs/") else "paired-source"
        if kind == "paired-source":
            key = str(path)
            if pair["inputHashesStart"].get(key) != digest or pair["inputHashesEnd"].get(key) != digest:
                raise ValueError(f"source not bound to exact pair input: {relative}")
        rows.append({"path": relative, "sha256": digest, "kind": kind})
    output = (ROOT / args.output).resolve()
    if not output.is_relative_to(ROOT.resolve()) or output.exists():
        raise ValueError("source proof output must be a new repository file")
    proof = {
        "schemaVersion": 1,
        "status": "passed",
        "scope": "fifteen historically drifted interpolation source claims; source identity only, not exhaustive parity",
        "historicalDriftPaths": SOURCES,
        "pairResult": str(pair_path),
        "pairResultSha256": sha(pair_path),
        "fixtureProof": args.fixture_proof,
        "fixtureProofSha256": sha(fixture_proof_path),
        "selfhostCompilerSha256": next(row["compilerSha256"] for row in pair["runs"] if row["compiler"] == "selfhost"),
        "sources": rows,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8")
    print(f"[interpolation current sources] FROZEN {len(rows)}/{len(rows)} (historical drift {len(SOURCES)}); {output}")


if __name__ == "__main__":
    main()
