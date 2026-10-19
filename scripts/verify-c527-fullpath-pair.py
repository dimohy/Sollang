#!/usr/bin/env python3
"""Check current full-path nominal interpolation and retained receiver forms."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-fully-qualified-compiler-o1-20260929-02")
OUT = ROOT / "artifacts/scratch/c527-fullpath-paired-20260929-01.json"
CASES = {
    "fullPathPositive": ("artifacts/scratch/c527-fully-qualified-managed-first-20260929-01/result.json",
                         "artifacts/scratch/c527-fullpath-positive-slg-20260929-02/result.json", "value=5\n"),
    "fullPathUnknown": ("artifacts/scratch/c527-fully-qualified-unknown-managed-20260929-01/result.json",
                        "artifacts/scratch/c527-fullpath-unknown-slg-20260929-02/result.json",
                        "sollang: semantic error at 1:2: [module '<main>'] unknown struct type 'c527.shapes.MissingPoint'\n"),
    "importAliasControl": ("artifacts/scratch/c527-imported-struct-managed-first-20260929-03/result.json",
                           "artifacts/scratch/c527-fullpath-retained-alias-20260929-01/result.json", "value=5\n"),
    "importAliasFieldTypeControl": ("artifacts/scratch/c527-imported-bad-field-managed-20260929-01/result.json",
                                    "artifacts/scratch/c527-fullpath-retained-alias-bad-field-20260929-01/result.json",
                                    "sollang: semantic error at 1:20: [module '<main>'] field 'x' expects Int, got Bool\n"),
    "localNamespaceControl": ("artifacts/scratch/c527-namespaced-struct-managed-20260929-01/result.json",
                              "artifacts/scratch/c527-fullpath-retained-local-20260929-01/result.json", "value=5\n"),
}
FIXTURES = {
    "scripts/probes/interpolation/c527-fully-qualified-struct-literal-field.slg":
        "examples/regression/2115-interpolation-fullpath-struct-literal-field.slg",
    "scripts/probes/interpolation/c527-fully-qualified-unknown-struct.slg":
        "examples/regression/diagnostics/2116-interpolation-fullpath-unknown-struct.slg",
    "scripts/probes/interpolation/c527-imported-struct-literal-library.slg":
        "examples/regression/fixtures/2112-imported-interpolation-point.slg",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    build = json.loads((BUILD / "result.json").read_text(encoding="utf-8"))
    assert build["status"] == "passed" and build["inputsStable"]
    assert build["compilerSha256"] == sha(BUILD / "compiler.exe")
    assert json.loads(read("artifacts/scratch/c527-fully-qualified-source-comparison-20260929-01.json"))["status"] == "passed"
    for probe, fixture in FIXTURES.items():
        assert read(probe) == read(fixture), (probe, fixture)
    results = {}
    for name, (managed_path, slg_path, expected) in CASES.items():
        managed, slg = (json.loads(read(path)) for path in (managed_path, slg_path))
        for actual in (managed, slg):
            if expected.startswith("sollang: "):
                assert actual["buildExit"] != 0
                assert actual["buildStderr"].replace("\r\n", "\n") == expected
            else:
                assert actual["buildExit"] == actual["runExit"] == 0
                assert actual["runStdout"] == expected
        results[name] = {"status": "passed", "managed": managed_path, "slg": slg_path}
    inputs = [ROOT / path for path in FIXTURES] + [ROOT / path for path in FIXTURES.values()]
    inputs += [ROOT / path for case in CASES.values() for path in case[:2]]
    inputs += [ROOT / "selfhost/ir/interpolation.slg", ROOT / "selfhost/semantic/expression_type_ids.slg",
               ROOT / "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs",
               ROOT / "src/Sollang.Compiler/Parsing/StringLiteralParser.cs", Path(__file__)]
    hashes = {str(path): sha(path) for path in inputs}
    record = {"schemaVersion": 1, "status": "passed", "completed": len(results),
              "total": len(results), "compilerSha256": build["compilerSha256"],
              "inputSha256": hashes, "cases": results, "fixturesEquivalentToProbes": True,
              "excludedRuns": ["artifacts/scratch/c527-fullpath-fully-positive-slg-20260929-01/result.json"]}
    assert hashes == {str(path): sha(path) for path in inputs}
    OUT.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {OUT.relative_to(ROOT)}: {len(results)}/{len(results)}")


if __name__ == "__main__":
    main()
