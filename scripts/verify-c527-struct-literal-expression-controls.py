#!/usr/bin/env python3
"""Bind current compiler to nominal initializer and contextual controls."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = Path(r"C:\Users\dimohy\AppData\Local\Sollang")
COMPILER = BASE / "c527-struct-literal-expression-compiler-o1-20260929-01/compiler.exe"
BUILD = BASE / "c527-struct-literal-expression-compiler-o1-20260929-01/result.json"
RESULTS = {
    "initializerCases": BASE / "c527-struct-literal-expression-initializers-retained-20260929-01/result.json",
    "unknownType": BASE / "c527-struct-literal-expression-unknown-retained-20260929-01/result.json",
    "sourceOrderAndContextual": BASE / "c527-struct-literal-expression-order-controls-20260929-01/result.json",
}
TEXT_RUN = BASE / "c527-struct-literal-expression-text-retained-20260929-01"
TEXT_SOURCE = ROOT / "scripts/probes/interpolation/c527-struct-literal-text-field.slg"
OUTPUT = ROOT / "artifacts/scratch/c527-struct-literal-expression-controls-20260929-01.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main() -> None:
    if OUTPUT.exists():
        raise ValueError(f"output already exists: {OUTPUT}")
    build = json.loads(read(BUILD))
    compiler_hash = sha(COMPILER)
    if build["status"] != "passed" or not build["inputsStable"] or build["compilerSha256"] != compiler_hash:
        raise ValueError("current compiler build is invalid")
    sources = [ROOT / "selfhost/semantic/expression_type_ids.slg",
               ROOT / "selfhost/semantic/interpolation_inference.slg",
               ROOT / "selfhost/llvm/text/context_prepare.slg"]
    inputs = [COMPILER, BUILD, *sources, *RESULTS.values(), TEXT_SOURCE, TEXT_RUN / "text.exe",
              TEXT_RUN / "text.build.stdout.txt", TEXT_RUN / "text.build.stderr.txt",
              TEXT_RUN / "text.native.stdout.txt", TEXT_RUN / "text.native.stderr.txt", Path(__file__).resolve()]
    for name, path in RESULTS.items():
        result = json.loads(read(path))
        if (result["status"] != "passed" or not result["inputsStable"]
                or result["inputSha256"][str(COMPILER)] != compiler_hash):
            raise ValueError(f"retained control failed: {name}")
        for source in sources:
            pinned = result["inputSha256"].get(str(source))
            if pinned is not None and pinned != sha(source):
                raise ValueError(f"retained control source changed: {name}")
    if (read(TEXT_RUN / "text.build.stderr.txt") != ""
            or read(TEXT_RUN / "text.native.stderr.txt") != ""
            or read(TEXT_RUN / "text.native.stdout.txt") != "value=hello\n"
            or not (TEXT_RUN / "text.exe").is_file()
            or TEXT_RUN.stat().st_mtime_ns < BUILD.stat().st_mtime_ns):
        raise ValueError("Text initializer current-compiler control failed")
    start = {str(path): sha(path) for path in inputs}
    if start != {str(path): sha(path) for path in inputs}:
        raise ValueError("control inputs changed")
    record = {"schemaVersion": 1, "unit": "C527 computed nominal initializer retained controls",
              "status": "passed", "completed": 4, "total": 4, "inputStable": True,
              "inputSha256": start, "compilerSha256": compiler_hash,
              "results": {name: str(path) for name, path in RESULTS.items()},
              "textRun": str(TEXT_RUN), "scope": "11 focused cases across four groups; not exhaustive parity"}
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUTPUT.relative_to(ROOT)}: four current-compiler control groups")


if __name__ == "__main__":
    main()
