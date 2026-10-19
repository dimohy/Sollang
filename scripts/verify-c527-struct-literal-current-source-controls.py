#!/usr/bin/env python3
"""Bind current compiler hash to four retained interpolation receiver paths."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = Path(r"C:\Users\dimohy\AppData\Local\Sollang")
COMPILER = BASE / "c527-struct-literal-unknown-type-compiler-o1-20260929-01/compiler.exe"
BUILD = BASE / "c527-struct-literal-unknown-type-compiler-o1-20260929-01/result.json"
RESULTS = {
    "nominalLiteral": BASE / "c527-struct-literal-latest-retained-20260929-01/result.json",
    "intrinsicFlow": BASE / "c527-struct-literal-latest-intrinsic-20260929-01/result.json",
    "methodIndexed": BASE / "c527-struct-literal-latest-kind10-20260929-02/result.json",
    "resultPropagation": BASE / "c527-struct-literal-latest-result-propagation-20260929-01/result.json",
}
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-current-source-controls-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    build = json.loads(BUILD.read_text(encoding="utf-8"))
    if build["status"] != "passed" or not build["inputsStable"] or build["compilerSha256"] != sha(COMPILER):
        raise ValueError("current compiler build is invalid")
    sources = [ROOT / "selfhost/ir/interpolation.slg",
               ROOT / "selfhost/semantic/expression_type_ids.slg",
               ROOT / "selfhost/semantic/interpolation_inference.slg",
               ROOT / "selfhost/llvm/text/foundation.slg",
               ROOT / "selfhost/llvm/emitter/diagnostics.slg"]
    inputs = [COMPILER, BUILD, *sources, *RESULTS.values(), Path(__file__).resolve()]
    checked = {}
    for name, path in RESULTS.items():
        result = json.loads(path.read_text(encoding="utf-8"))
        if (result["status"] != "passed" or not result["inputsStable"]
                or result["inputSha256"][str(COMPILER)] != sha(COMPILER)):
            raise ValueError(f"current-source receiver control failed: {name}")
        for source in sources:
            pinned = result["inputSha256"].get(str(source))
            if pinned is not None and pinned != sha(source):
                raise ValueError(f"current-source receiver input stale: {name}: {source}")
        checked[name] = str(path)
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("control inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 current-source retained receiver controls",
              "status": "passed", "completed": 4, "total": 4, "inputStable": True,
              "inputSha256": start, "compilerSha256": sha(COMPILER), "results": checked,
              "excludedFailure": str(BASE / "c527-struct-literal-latest-kind10-20260929-01/result.json")}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: 4/4 current-source receiver controls")


if __name__ == "__main__":
    main()
