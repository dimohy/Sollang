"""Resolve source names from the repository inventory before reading them."""

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
sys.stdout.reconfigure(encoding="utf-8")


def resolve_sources(scope, pattern):
    directory = (ROOT / scope).resolve()
    if not directory.is_relative_to(ROOT) or not directory.is_dir():
        raise ValueError("SOURCE_QUERY_INVALID_SCOPE")
    result = subprocess.run(
        ["rg", "--files", str(directory), "-g", pattern],
        cwd=ROOT, capture_output=True, text=True, check=False)
    if result.returncode not in (0, 1):
        raise ValueError("SOURCE_QUERY_INVENTORY_FAILED: " + result.stderr.strip())
    return sorted(Path(line).resolve() for line in result.stdout.splitlines())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope")
    parser.add_argument("pattern")
    parser.add_argument("--read", action="store_true")
    parser.add_argument("--start", type=int, default=1)
    parser.add_argument("--count", type=int, default=80)
    args = parser.parse_args()
    sources = resolve_sources(args.scope, args.pattern)
    if args.start < 1 or args.count < 1:
        parser.error("source line bounds must be positive")
    if args.read:
        if len(sources) != 1:
            parser.error("SOURCE_QUERY_REQUIRES_ONE_MATCH: " + json.dumps(
                [p.relative_to(ROOT).as_posix() for p in sources]))
        lines = sources[0].read_text(encoding="utf-8-sig").splitlines()
        for ordinal, line in enumerate(lines[args.start - 1:args.start - 1 + args.count], args.start):
            print(f"{ordinal}: {line}")
    else:
        print(json.dumps({"matches": [p.relative_to(ROOT).as_posix() for p in sources],
                          "count": len(sources)}))


if __name__ == "__main__":
    main()
