#!/usr/bin/env python3
"""Bind existing C# and SLG Text initializer runs to their pinned sources."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = Path(r"C:\Users\dimohy\AppData\Local\Sollang")
MANAGED_RUN = BASE / "c527-struct-literal-text-managed-first-20260929-01"
SELFHOST_RUN = BASE / "c527-struct-literal-text-selfhost-before-20260929-01"
BUILD = BASE / "c527-struct-literal-unknown-type-compiler-o1-20260929-01/result.json"
COMPILER = BASE / "c527-struct-literal-unknown-type-compiler-o1-20260929-01/compiler.exe"
MANAGED_PROOF = ROOT / "artifacts/scratch/c527-struct-literal-text-managed-first-20260929-01.json"
COMPARISON = ROOT / "artifacts/scratch/c527-struct-literal-text-source-comparison-20260929-01.json"
SOURCE = ROOT / "scripts/probes/interpolation/c527-struct-literal-text-field.slg"
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-text-reused-pair-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    managed = json.loads(read(MANAGED_PROOF))
    comparison = json.loads(read(COMPARISON))
    build = json.loads(read(BUILD))
    if (managed["status"] != "passed" or comparison["status"] != "passed"
            or build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(COMPILER)
            or managed["inputSha256"][str(SOURCE)] != sha(SOURCE)):
        raise ValueError("pinned compiler or source proof is invalid")
    files = [SOURCE, MANAGED_PROOF, COMPARISON, BUILD, COMPILER, Path(__file__).resolve()]
    for folder in (MANAGED_RUN, SELFHOST_RUN):
        files += [folder / "text.exe", folder / "text.build.stdout.txt",
                  folder / "text.build.stderr.txt", folder / "text.native.stdout.txt",
                  folder / "text.native.stderr.txt"]
        if (read(folder / "text.build.stderr.txt") != ""
                or read(folder / "text.native.stderr.txt") != ""
                or read(folder / "text.native.stdout.txt") != "value=hello\n"):
            raise ValueError(f"paired run differs: {folder}")
    if SELFHOST_RUN.stat().st_mtime_ns < BUILD.stat().st_mtime_ns:
        raise ValueError("self-host run predates compiler build")
    start = {str(path): sha(path) for path in files}
    if start != {str(path): sha(path) for path in files}:
        raise ValueError("paired run inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 nominal Text initializer reused paired proof",
              "status": "passed", "completed": 1, "total": 1, "inputStable": True,
              "inputSha256": start, "managedRun": str(MANAGED_RUN),
              "selfhostRun": str(SELFHOST_RUN), "nativeStdout": "value=hello\n",
              "sourceChangeRequired": False}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: reused C# and SLG Text initializer runs")


if __name__ == "__main__":
    main()
