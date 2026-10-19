"""Inventory current structural evidence without promoting historical proofs."""

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRATCH = ROOT / "artifacts/scratch"
HISTORICAL = [
    "verify-c580-lexical-preir.py",
    "verify-c581-unary-preir.py",
    "verify-c582-member-preir.py",
    "verify-c583-index-preir.py",
    "verify-c584-materialize-flow.py",
    "verify-c585-materialize-owner.py",
    "verify-c586-materialize-parameter-owner.py",
    "verify-c587-dictionary-index-preir.py",
    "verify-c588-mapped-arguments-index-preir.py",
    "verify-c589-owned-index-preir.py",
    "verify-c590-nonlexical-index-preir.py",
]
CURRENT = [
    "verify-c591-contextual-key-substeps.py",
    "verify-c592-nested-unary.py",
    "verify-c593-unary-index-preir.py",
    "verify-c596-index-semantic-owner.py",
    "verify-c597-member-result.py",
]


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run_verifier(name: str) -> dict:
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / name)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    output = (result.stdout + result.stderr).strip()
    failure = "\n".join(output.splitlines()[-5:])
    status = "passed" if result.returncode == 0 else "failed"
    if status == "failed" and "AssertionError" in output and (
        "assert sha(" in output or "sha256" in output
    ):
        status = "stale-source-claim"
    return {"verifier": name, "status": status, "exitCode": result.returncode,
            "detail": output if status == "passed" else failure}


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
output = args.output.resolve()
if output.parent != SCRATCH.resolve() or output.exists():
    parser.error("output must be a new JSON file directly under artifacts/scratch")

detail_path = ROOT / "scripts/contracts/structural-parity-detail.json"
detail = read(detail_path)
closure = detail["measuredSubscopes"]["sourceHashClosure"]
source_rows = read(ROOT / closure["audit"])
source_checks = []
for row in source_rows:
    source = ROOT / row["source"]
    actual = sha(source)
    source_checks.append({"source": row["source"], "recordedSha256": row["currentSha"],
                          "currentSha256": actual, "matchesRecorded": actual == row["currentSha"]})

historical = [run_verifier(name) for name in HISTORICAL]
current = [run_verifier(name) for name in CURRENT]
record = {
    "schemaVersion": 1,
    "status": "audit-complete",
    "contract": "scripts/contracts/structural-parity-detail.json",
    "contractSha256": sha(detail_path),
    "phaseClosure": detail["phaseClosure"],
    "declaredSourceHashClosure": {"closed": closure["closed"], "total": closure["total"]},
    "sourceClaims": source_checks,
    "sourceClaimsMatchingCurrent": sum(row["matchesRecorded"] for row in source_checks),
    "historicalVerifiers": historical,
    "historicalPassed": sum(row["status"] == "passed" for row in historical),
    "historicalStaleSourceClaims": sum(row["status"] == "stale-source-claim" for row in historical),
    "currentVerifiers": current,
    "currentPassed": sum(row["status"] == "passed" for row in current),
}
output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(
    "[structural evidence audit] COMPLETE "
    f"historical passed {record['historicalPassed']}/{len(historical)}, "
    f"stale claims {record['historicalStaleSourceClaims']}/{len(historical)}, "
    f"current passed {record['currentPassed']}/{len(current)}, "
    f"source claims matching {record['sourceClaimsMatchingCurrent']}/{len(source_checks)}; "
    f"result={output}"
)
