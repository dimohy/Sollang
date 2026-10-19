"""Rebase a historical source-hash claim audit on the current Sollang tree."""

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def under_root(relative: str) -> Path:
    target = (ROOT / relative.replace("\\", "/")).resolve()
    if not target.is_relative_to(ROOT.resolve()) or not target.is_file():
        raise ValueError(f"missing or external audit input: {relative}")
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    baseline = json.loads(under_root(args.baseline).read_text(encoding="utf-8-sig"))
    if not isinstance(baseline, list) or len(baseline) != 9:
        raise ValueError("source-hash audit requires the nine frozen source claims")
    output = (ROOT / args.output).resolve()
    if not output.is_relative_to(ROOT.resolve()) or output.exists():
        raise ValueError(f"audit output must be a new repository file: {args.output}")

    refreshed = []
    for row in baseline:
        source = row["source"]
        current_sha = hashlib.sha256(under_root(source).read_bytes()).hexdigest().upper()
        receipts = row["claimReceipts"]
        if len(receipts) != row["claimCount"]:
            raise ValueError(f"claim count differs from receipts: {source}")
        matches = 0
        for receipt in receipts:
            claim = json.loads(under_root(receipt).read_text(encoding="utf-8-sig"))
            if "currentSourceHashes" not in claim:
                raise ValueError(f"receipt has no currentSourceHashes: {receipt}")
            if claim["currentSourceHashes"].get(source, "").upper() == current_sha:
                matches += 1
        refreshed.append({**row, "currentSha": current_sha, "currentMatchCount": matches})

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(refreshed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"[source-hash audit] {len(refreshed)} sources, {sum(row['currentMatchCount'] for row in refreshed)} matching historical claims; {output}")


if __name__ == "__main__":
    main()
